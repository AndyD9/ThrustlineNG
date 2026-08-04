namespace Thrustline.Bridge;

public static class BridgeApplication
{
    public const int SuccessExitCode = 0;
    public const int InvalidArgumentsExitCode = 2;

    public static async Task<int> RunAsync(
        IReadOnlyList<string> arguments,
        TextReader input,
        TextWriter output,
        TextWriter error,
        CancellationToken shutdownToken)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        ArgumentNullException.ThrowIfNull(input);
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(error);

        if (arguments.Count == 1 && string.Equals(arguments[0], "--health-check", StringComparison.Ordinal))
        {
            await output.WriteLineAsync(BridgeHealthStatus.Healthy.ToString()).ConfigureAwait(false);
            return SuccessExitCode;
        }

        if (!BridgeOptions.TryParse(arguments, out var port, out var telemetry))
        {
            await WriteUsageErrorAsync(error).ConfigureAwait(false);
            return InvalidArgumentsExitCode;
        }

        var token = await input.ReadLineAsync(shutdownToken).ConfigureAwait(false);
        if (!BridgeOptions.TryCreate(port, token, telemetry, out var options))
        {
            await WriteUsageErrorAsync(error).ConfigureAwait(false);
            return InvalidArgumentsExitCode;
        }

        return await BridgeServer.RunAsync(options, output, shutdownToken).ConfigureAwait(false);
    }

    private static async Task WriteUsageErrorAsync(TextWriter error)
    {
        await error.WriteLineAsync(
            "Usage: Thrustline.Bridge --port <49152-65535>").ConfigureAwait(false);
        await error.WriteLineAsync(
            "       [--telemetry-source replay|native] [--telemetry-trace <file>]").ConfigureAwait(false);
        await error.WriteLineAsync(
            "       | --health-check").ConfigureAwait(false);
    }
}
