using System.Net;
using System.Net.Sockets;

using Thrustline.Bridge;

var tests = new (string Name, Func<Task> Execute)[]
{
    ("health starts healthy and becomes stopping", TestHealthTransitions),
    ("health-check reports healthy", TestHealthCheck),
    ("unknown arguments are rejected", TestUnknownArgument),
    ("server arguments are validated", TestOptions),
    ("local contract requires the instance token", TestLocalContract),
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
        TextReader.Null,
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
        TextReader.Null,
        output,
        error,
        CancellationToken.None);

    Equal(BridgeApplication.InvalidArgumentsExitCode, exitCode, "exit code");
    Equal(string.Empty, output.ToString(), "standard output");
    Contains("Usage:", error.ToString(), "standard error");
}

static Task TestOptions()
{
    var token = new string('a', 64);
    True(BridgeOptions.TryParse(["--port", "55000"], out var port), "valid port");
    Equal(55000, port, "port");
    True(BridgeOptions.TryCreate(port, token, out var options), "valid token");
    Equal(token, options.InstanceToken, "token");
    True(!BridgeOptions.TryParse(["--port", "80"], out _), "privileged port");
    True(!BridgeOptions.TryCreate(port, "short", out _), "short token");
    return Task.CompletedTask;
}

static async Task TestLocalContract()
{
    var port = ReservePort();
    var token = new string('b', 64);
    using var shutdown = new CancellationTokenSource();
    using var output = new StringWriter();
    var run = BridgeServer.RunAsync(new BridgeOptions(port, token), output, shutdown.Token);

    await WaitUntilReady(output);
    using var client = new HttpClient { BaseAddress = new Uri($"http://127.0.0.1:{port}") };

    var anonymous = await client.GetAsync(BridgeContract.HealthPath);
    Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode, "anonymous status");

    client.DefaultRequestHeaders.Add(BridgeContract.TokenHeader, new string('c', 64));
    var incorrect = await client.GetAsync(BridgeContract.HealthPath);
    Equal(HttpStatusCode.Unauthorized, incorrect.StatusCode, "incorrect token status");

    client.DefaultRequestHeaders.Remove(BridgeContract.TokenHeader);
    client.DefaultRequestHeaders.Add(BridgeContract.TokenHeader, token);
    var response = await client.GetAsync(BridgeContract.HealthPath);
    Equal(HttpStatusCode.OK, response.StatusCode, "authenticated status");
    var body = await response.Content.ReadAsStringAsync();
    Contains("\"contractVersion\":\"1\"", body, "contract version");
    Contains("\"status\":\"healthy\"", body, "health status");

    var negotiate = await client.PostAsync(
        $"{BridgeContract.HubPath}/negotiate?negotiateVersion=1",
        new StringContent(string.Empty));
    Equal(HttpStatusCode.OK, negotiate.StatusCode, "SignalR negotiate status");

    shutdown.Cancel();
    Equal(BridgeApplication.SuccessExitCode, await run.WaitAsync(TimeSpan.FromSeconds(5)), "exit code");
}

static int ReservePort()
{
    var listener = new TcpListener(IPAddress.Loopback, 0);
    listener.Start();
    var port = ((IPEndPoint)listener.LocalEndpoint).Port;
    listener.Stop();
    return port;
}

static async Task WaitUntilReady(StringWriter output)
{
    for (var attempt = 0; attempt < 100; attempt++)
    {
        if (output.ToString().Contains("BRIDGE_READY", StringComparison.Ordinal))
        {
            return;
        }

        await Task.Delay(20);
    }

    throw new TimeoutException("bridge did not become ready");
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

static void True(bool condition, string subject)
{
    if (!condition)
    {
        throw new InvalidOperationException($"{subject}: expected true.");
    }
}
