namespace Thrustline.Bridge;

public static class BridgeApplication
{
    public const int SuccessExitCode = 0;
    public const int InvalidArgumentsExitCode = 2;

    public static async Task<int> RunAsync(
        IReadOnlyList<string> arguments,
        TextWriter output,
        TextWriter error,
        CancellationToken shutdownToken)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(error);

        var health = new BridgeHealth();

        if (arguments.Count > 1)
        {
            await WriteUsageErrorAsync(error).ConfigureAwait(false);
            return InvalidArgumentsExitCode;
        }

        if (arguments.Count == 1)
        {
            return await RunCommandAsync(arguments[0], health, output, error)
                .ConfigureAwait(false);
        }

        await output.WriteLineAsync("Thrustline bridge ready.").ConfigureAwait(false);

        try
        {
            await Task.Delay(Timeout.InfiniteTimeSpan, shutdownToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (shutdownToken.IsCancellationRequested)
        {
            health.MarkStopping();
        }

        await output.WriteLineAsync("Thrustline bridge stopped.").ConfigureAwait(false);
        return SuccessExitCode;
    }

    private static async Task<int> RunCommandAsync(
        string argument,
        BridgeHealth health,
        TextWriter output,
        TextWriter error)
    {
        if (string.Equals(argument, "--health-check", StringComparison.Ordinal))
        {
            await output.WriteLineAsync(health.GetStatus().ToString()).ConfigureAwait(false);
            return SuccessExitCode;
        }

        await WriteUsageErrorAsync(error).ConfigureAwait(false);
        return InvalidArgumentsExitCode;
    }

    private static Task WriteUsageErrorAsync(TextWriter error) =>
        error.WriteLineAsync("Usage: Thrustline.Bridge [--health-check]");
}
