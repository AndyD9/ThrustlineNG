using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using Thrustline.Bridge.SimConnect;
using Thrustline.Bridge.Telemetry;

namespace Thrustline.Bridge;

public static class BridgeServer
{
    public static async Task<int> RunAsync(
        BridgeOptions options,
        TextWriter output,
        CancellationToken shutdownToken,
        TelemetryPublisher? publisher = null)
    {
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(output);

        var telemetry = publisher ?? CreatePublisher(options.Telemetry);

        var builder = WebApplication.CreateSlimBuilder();
        builder.Logging.ClearProviders();
        builder.WebHost.UseUrls($"http://127.0.0.1:{options.Port}");
        builder.Services
            .AddSignalR()
            .AddJsonProtocol(protocol =>
                protocol.PayloadSerializerOptions.PropertyNamingPolicy =
                    JsonNamingPolicy.CamelCase);
        builder.Services.AddSingleton(telemetry);
        builder.Services.AddHostedService<TelemetryPublicationService>();

        var app = builder.Build();
        app.Use(async (context, next) =>
        {
            if (!HasValidToken(context, options.InstanceToken))
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                return;
            }

            await next(context).ConfigureAwait(false);
        });
        app.MapGet(
            BridgeContract.HealthPath,
            () => Results.Json(
                new HealthResponse(
                    BridgeContract.Version,
                    "healthy",
                    Describe(telemetry.Source),
                    Describe(telemetry.State),
                    DescribeNativeLibrary(telemetry),
                    Describe(telemetry.NativeLibrary.Origin))));
        app.MapGet(
            BridgeContract.FlightSummaryPath,
            () =>
            {
                var reading = telemetry.Reading;
                return Results.Json(
                    new FlightSummaryResponse(
                        BridgeContract.Version,
                        Describe(reading.Summary.State),
                        reading.Summary.BlockMinutes,
                        reading.Generation));
            });
        app.MapPost(
            BridgeContract.FlightSummaryRearmPath,
            () => telemetry.TryRearm(out var generation)
                ? Results.Json(new FlightSummaryRearmResponse(BridgeContract.Version, generation))
                : Results.Json(
                    new FlightSummaryRearmResponse(BridgeContract.Version, generation),
                    statusCode: StatusCodes.Status409Conflict));
        app.MapHub<BridgeHub>(BridgeContract.HubPath);

        await app.StartAsync(shutdownToken).ConfigureAwait(false);
        await output.WriteLineAsync(
            $"BRIDGE_READY {BridgeContract.Version} {options.Port}").ConfigureAwait(false);
        if (telemetry.Source == TelemetrySource.Native
            && telemetry.NativeLibrary.Origin == SimConnectLibraryOrigin.None)
        {
            // Diagnostic actionnable, sans aucun chemin : la sonde bornée n'a
            // trouvé la bibliothèque dans aucune source digne de confiance.
            await output.WriteLineAsync(
                "SIMCONNECT_LIBRARY unavailable: install the MSFS 2024 SDK "
                + "or pass --simconnect-library with an absolute SimConnect.dll path.")
                .ConfigureAwait(false);
        }

        try
        {
            await app.WaitForShutdownAsync(shutdownToken).ConfigureAwait(false);
        }
        finally
        {
            await app.StopAsync(CancellationToken.None).ConfigureAwait(false);
            if (publisher is null)
            {
                await telemetry.DisposeAsync().ConfigureAwait(false);
            }
        }

        return BridgeApplication.SuccessExitCode;
    }

    private static bool HasValidToken(HttpContext context, string expected)
    {
        var supplied = context.Request.Headers[BridgeContract.TokenHeader].ToString();
        if (supplied.Length != expected.Length)
        {
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(
            Encoding.ASCII.GetBytes(supplied),
            Encoding.ASCII.GetBytes(expected));
    }

    private static TelemetryPublisher CreatePublisher(BridgeTelemetryOptions telemetry)
    {
        var adapterFactory = TelemetryAdapterFactory.TryCreate(telemetry, out var nativeLibrary);
        return new TelemetryPublisher(telemetry, adapterFactory, nativeLibrary: nativeLibrary);
    }

    private static string Describe(TelemetrySource source) =>
        source switch
        {
            TelemetrySource.Native => BridgeTelemetryOptions.NativeArgument,
            _ => BridgeTelemetryOptions.ReplayArgument,
        };

    private static string Describe(TelemetryState state) =>
        state switch
        {
            TelemetryState.Streaming => "streaming",
            TelemetryState.Completed => "completed",
            TelemetryState.Unavailable => "unavailable",
            TelemetryState.Stopped => "stopped",
            _ => "idle",
        };

    // L'état de localisation est publié en champs additifs, sans jamais
    // divulguer un chemin ni une version de SDK : seulement l'issue et
    // l'origine retenue par la sonde bornée.
    private static string DescribeNativeLibrary(TelemetryPublisher telemetry) =>
        telemetry.Source != TelemetrySource.Native
            ? "not-required"
            : telemetry.NativeLibrary.Origin == SimConnectLibraryOrigin.None
                ? "unavailable"
                : "located";

    private static string Describe(SimConnectLibraryOrigin origin) =>
        origin switch
        {
            SimConnectLibraryOrigin.Explicit => "explicit",
            SimConnectLibraryOrigin.Application => "application",
            SimConnectLibraryOrigin.SdkInstallation => "sdk",
            _ => "none",
        };

    private static string Describe(FlightSummaryState state) =>
        state switch
        {
            FlightSummaryState.Running => "running",
            FlightSummaryState.Completed => "completed",
            FlightSummaryState.Incomplete => "incomplete",
            _ => "idle",
        };

    private sealed record HealthResponse(
        string ContractVersion,
        string Status,
        string TelemetrySource,
        string TelemetryState,
        string NativeLibrary,
        string NativeLibraryOrigin);

    private sealed record FlightSummaryResponse(
        string ContractVersion,
        string State,
        int? BlockMinutes,
        int Generation);

    private sealed record FlightSummaryRearmResponse(
        string ContractVersion,
        int Generation);
}
