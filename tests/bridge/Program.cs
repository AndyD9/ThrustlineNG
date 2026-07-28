using Thrustline.Bridge;

var tests = new (string Name, Func<Task> Execute)[]
{
    ("health starts healthy and becomes stopping", TestHealthTransitions),
    ("health-check reports healthy", TestHealthCheck),
    ("unknown arguments are rejected", TestUnknownArgument),
    ("cancellation stops the process cleanly", TestCancellation),
};

var failures = 0;

foreach (var test in tests)
{
    try
    {
        await test.Execute();
        Console.WriteLine($"PASS {test.Name}");
    }
    catch (Exception exception)
    {
        failures++;
        Console.Error.WriteLine($"FAIL {test.Name}: {exception.Message}");
    }
}

Console.WriteLine($"{tests.Length - failures}/{tests.Length} tests passed.");
return failures == 0 ? 0 : 1;

static Task TestHealthTransitions()
{
    var health = new BridgeHealth();
    Equal(BridgeHealthStatus.Healthy, health.GetStatus(), "initial status");
    health.MarkStopping();
    Equal(BridgeHealthStatus.Stopping, health.GetStatus(), "stopping status");
    return Task.CompletedTask;
}

static async Task TestHealthCheck()
{
    using var output = new StringWriter();
    using var error = new StringWriter();

    var exitCode = await BridgeApplication.RunAsync(
        ["--health-check"],
        output,
        error,
        CancellationToken.None);

    Equal(BridgeApplication.SuccessExitCode, exitCode, "exit code");
    Equal($"Healthy{Environment.NewLine}", output.ToString(), "standard output");
    Equal(string.Empty, error.ToString(), "standard error");
}

static async Task TestUnknownArgument()
{
    using var output = new StringWriter();
    using var error = new StringWriter();

    var exitCode = await BridgeApplication.RunAsync(
        ["--unknown"],
        output,
        error,
        CancellationToken.None);

    Equal(BridgeApplication.InvalidArgumentsExitCode, exitCode, "exit code");
    Equal(string.Empty, output.ToString(), "standard output");
    Contains("Usage:", error.ToString(), "standard error");
}

static async Task TestCancellation()
{
    using var shutdown = new CancellationTokenSource();
    using var output = new StringWriter();
    using var error = new StringWriter();

    var run = BridgeApplication.RunAsync([], output, error, shutdown.Token);
    shutdown.Cancel();
    var exitCode = await run.WaitAsync(TimeSpan.FromSeconds(2));

    Equal(BridgeApplication.SuccessExitCode, exitCode, "exit code");
    Contains("Thrustline bridge ready.", output.ToString(), "ready output");
    Contains("Thrustline bridge stopped.", output.ToString(), "stopped output");
    Equal(string.Empty, error.ToString(), "standard error");
}

static void Equal<T>(T expected, T actual, string subject)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException(
            $"{subject}: expected '{expected}', received '{actual}'.");
    }
}

static void Contains(string expected, string actual, string subject)
{
    if (!actual.Contains(expected, StringComparison.Ordinal))
    {
        throw new InvalidOperationException(
            $"{subject}: expected to contain '{expected}', received '{actual}'.");
    }
}
