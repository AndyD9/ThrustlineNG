using System.Net;
using System.Net.Sockets;
using System.Text;

using Thrustline.Bridge;
using Thrustline.Bridge.SimConnect;

var tests = new (string Name, Func<Task> Execute)[]
{
    ("health starts healthy and becomes stopping", TestHealthTransitions),
    ("health-check reports healthy", TestHealthCheck),
    ("unknown arguments are rejected", TestUnknownArgument),
    ("server arguments are validated", TestOptions),
    ("local contract requires the instance token", TestLocalContract),
    ("flight samples reject invalid values", TestFlightSampleValidation),
    ("synthetic trace replays in order", TestSyntheticReplay),
    ("trace rejects non-monotonic offsets", TestInvalidTrace),
    ("trace rejects oversized lines", TestOversizedTrace),
    ("replay observes cancellation", TestReplayCancellation),
    ("fake adapter preserves the domain contract", TestFakeAdapter),
    ("native adapter fails safely when unavailable", TestNativeAdapterProbe),
    ("public contracts contain no SDK types", TestPublicContracts),
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

static Task TestFlightSampleValidation()
{
    _ = FlightSample.Create(
        0,
        DateTimeOffset.UnixEpoch,
        48,
        2,
        1_000,
        100,
        90,
        180,
        0,
        false);

    Throws<ArgumentOutOfRangeException>(
        () => FlightSample.Create(
            0,
            DateTimeOffset.UnixEpoch,
            double.NaN,
            2,
            1_000,
            100,
            90,
            180,
            0,
            false),
        "NaN latitude");
    return Task.CompletedTask;
}

static async Task TestSyntheticReplay()
{
    var tracePath = Path.Combine(
        AppContext.BaseDirectory,
        "traces",
        "synthetic-golden-flight.jsonl");
    await using var adapter = new ReplaySimConnectAdapter(() => File.OpenRead(tracePath));
    var samples = new List<FlightSample>();

    await foreach (var sample in adapter.ReadAllAsync(CancellationToken.None))
    {
        samples.Add(sample);
    }

    Equal(8, samples.Count, "sample count");
    Equal(0L, samples[0].Sequence, "first sequence");
    Equal(7L, samples[^1].Sequence, "last sequence");
    True(samples[0].OnGround, "starts on ground");
    True(samples.Any(sample => !sample.OnGround), "contains airborne sample");
    True(samples[^1].OnGround, "ends on ground");
    True(
        samples.Zip(samples.Skip(1), (left, right) => left.CapturedAt < right.CapturedAt).All(value => value),
        "timestamps are monotonic");
}

static async Task TestInvalidTrace()
{
    const string content = """
        {"format":"thrustline.simconnect.trace","schemaVersion":1,"source":"synthetic"}
        {"offsetMilliseconds":1000,"latitudeDegrees":48,"longitudeDegrees":2,"altitudeFeet":1000,"groundSpeedKnots":100,"indicatedAirspeedKnots":90,"headingDegrees":180,"verticalSpeedFeetPerMinute":0,"onGround":false}
        {"offsetMilliseconds":500,"latitudeDegrees":48,"longitudeDegrees":2,"altitudeFeet":1000,"groundSpeedKnots":100,"indicatedAirspeedKnots":90,"headingDegrees":180,"verticalSpeedFeetPerMinute":0,"onGround":false}
        """;
    await using var stream = new MemoryStream(Encoding.UTF8.GetBytes(content));

    await ThrowsAsync<InvalidDataException>(
        async () =>
        {
            await foreach (var _ in SimConnectTraceReader.ReadAllAsync(stream))
            {
            }
        },
        "non-monotonic trace");
}

static async Task TestOversizedTrace()
{
    var content = $$"""
        {"format":"thrustline.simconnect.trace","schemaVersion":1,"source":"synthetic","padding":"{{new string('x', SimConnectTraceReader.MaximumLineBytes)}}"}
        """;
    await using var stream = new MemoryStream(Encoding.UTF8.GetBytes(content));

    await ThrowsAsync<InvalidDataException>(
        async () =>
        {
            await foreach (var _ in SimConnectTraceReader.ReadAllAsync(stream))
            {
            }
        },
        "oversized trace line");
}

static async Task TestReplayCancellation()
{
    var tracePath = Path.Combine(
        AppContext.BaseDirectory,
        "traces",
        "synthetic-golden-flight.jsonl");
    await using var adapter = new ReplaySimConnectAdapter(() => File.OpenRead(tracePath));
    using var cancellation = new CancellationTokenSource();
    cancellation.Cancel();

    await ThrowsAsync<OperationCanceledException>(
        async () =>
        {
            await foreach (var _ in adapter.ReadAllAsync(cancellation.Token))
            {
            }
        },
        "cancelled replay");
}

static async Task TestFakeAdapter()
{
    var expected = FlightSample.Create(
        12,
        DateTimeOffset.UnixEpoch,
        48,
        2,
        1_000,
        100,
        90,
        180,
        0,
        false);
    await using var adapter = new FakeSimConnectAdapter([expected]);
    var received = new List<FlightSample>();

    await foreach (var sample in adapter.ReadAllAsync(CancellationToken.None))
    {
        received.Add(sample);
    }

    Equal(1, received.Count, "fake count");
    Equal(expected, received[0], "fake sample");
}

static async Task TestNativeAdapterProbe()
{
    await using var adapter = new NativeSimConnectAdapter();
    using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));

    try
    {
        await foreach (var sample in adapter.ReadAllAsync(timeout.Token))
        {
            True(sample.CapturedAt.Offset == TimeSpan.Zero, "native UTC timestamp");
            return;
        }
    }
    catch (Exception exception) when (
        exception is DllNotFoundException
            or InvalidOperationException
            or PlatformNotSupportedException
            or OperationCanceledException)
    {
        True(
            !exception.Message.Contains(@":\", StringComparison.Ordinal),
            "native error does not expose a local path");
        True(
            exception is OperationCanceledException
                || exception.Message.Contains("SimConnect", StringComparison.OrdinalIgnoreCase)
                || exception.Message.Contains("MSFS", StringComparison.OrdinalIgnoreCase)
                || exception.Message.Contains("Windows", StringComparison.OrdinalIgnoreCase),
            "native error is actionable");
    }
}

static Task TestPublicContracts()
{
    var publicContractTypes = new[] { typeof(ISimConnectAdapter), typeof(FlightSample) };
    var exposedTypes = publicContractTypes
        .SelectMany(
            type => type.GetMethods().SelectMany(
                method => method.GetParameters().Select(parameter => parameter.ParameterType)
                    .Append(method.ReturnType)))
        .Select(type => type.Assembly.GetName().Name ?? string.Empty);

    True(
        exposedTypes.All(name => !name.Contains("SimConnect", StringComparison.OrdinalIgnoreCase)),
        "SDK type leakage");
    return Task.CompletedTask;
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

static void Throws<TException>(Action action, string subject)
    where TException : Exception
{
    try
    {
        action();
    }
    catch (TException)
    {
        return;
    }

    throw new InvalidOperationException($"{subject}: expected {typeof(TException).Name}.");
}

static async Task ThrowsAsync<TException>(Func<Task> action, string subject)
    where TException : Exception
{
    try
    {
        await action();
    }
    catch (TException)
    {
        return;
    }

    throw new InvalidOperationException($"{subject}: expected {typeof(TException).Name}.");
}

sealed class FakeSimConnectAdapter(IEnumerable<FlightSample> samples) : ISimConnectAdapter
{
    public async IAsyncEnumerable<FlightSample> ReadAllAsync(
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken)
    {
        foreach (var sample in samples)
        {
            cancellationToken.ThrowIfCancellationRequested();
            yield return sample;
            await Task.Yield();
        }
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}
