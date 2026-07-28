using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Thrustline.Bridge;

public static class BridgeServer
{
    public static async Task<int> RunAsync(
        BridgeOptions options,
        TextWriter output,
        CancellationToken shutdownToken)
    {
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(output);

        var builder = WebApplication.CreateSlimBuilder();
        builder.Logging.ClearProviders();
        builder.WebHost.UseUrls($"http://127.0.0.1:{options.Port}");
        builder.Services.AddSignalR();

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
            () => Results.Json(new HealthResponse(BridgeContract.Version, "healthy")));
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

    private sealed record HealthResponse(string ContractVersion, string Status);
}
