using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

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

        var telemetry = publisher ?? new TelemetryPublisher(
            options.Telemetry,
            TelemetryAdapterFactory.TryCreate(options.Telemetry));

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
                    Describe(telemetry.State))));
        app.MapGet(
            BridgeContract.FlightSummaryPath,
            () =>
            {
                var summary = telemetry.Summary;
                return Results.Json(
                    new FlightSummaryResponse(
                        BridgeContract.Version,
                        Describe(summary.State),
                        summary.BlockMinutes));
            });
        app.MapHub<BridgeHub>(BridgeContract.HubPath);

        await app.StartAsync(shutdownToken).ConfigureAwait(false);
        await output.WriteLineAsync(
            $"BRIDGE_READY {BridgeContract.Version} {options.Port}").ConfigureAwait(false);

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
        string TelemetryState);

    private sealed record FlightSummaryResponse(
        string ContractVersion,
        string State,
        int? BlockMinutes);
}
