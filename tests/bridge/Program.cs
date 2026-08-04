using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;

using Thrustline.Bridge;
using Thrustline.Bridge.SimConnect;
using Thrustline.Bridge.Telemetry;

var tests = new (string Name, Func<Task> Execute)[]
{
    ("health starts healthy and becomes stopping", TestHealthTransitions),
    ("health-check reports healthy", TestHealthCheck),
    ("unknown arguments are rejected", TestUnknownArgument),
    ("server arguments are validated", TestOptions),
    ("telemetry arguments stay bounded", TestTelemetryArguments),
    ("local contract requires the instance token", TestLocalContract),
    ("flight samples reject invalid values", TestFlightSampleValidation),
    ("synthetic trace replays in order", TestSyntheticReplay),
    ("trace rejects non-monotonic offsets", TestInvalidTrace),
    ("trace rejects oversized lines", TestOversizedTrace),
    ("replay observes cancellation", TestReplayCancellation),
    ("fake adapter preserves the domain contract", TestFakeAdapter),
    ("native adapter fails safely when unavailable", TestNativeAdapterProbe),
    ("telemetry stays idle without a configured source", TestTelemetryWithoutSource),
    ("telemetry keeps the source closed without a subscriber", TestTelemetryWithoutSubscriber),
    ("telemetry publishes validated samples in order", TestTelemetryOrdering),
    ("telemetry rejects out-of-domain samples", TestTelemetryDomainGuard),
    ("telemetry cadence is bounded", TestTelemetryCadence),
    ("telemetry keeps only the latest pending sample", TestTelemetryLatestPendingSample),
    ("telemetry drops a subscriber that stops draining", TestTelemetryStalledSubscriber),
    ("telemetry cancellation releases the adapter", TestTelemetryCancellation),
    ("native telemetry source never fails the harness", TestNativeTelemetrySource),
    ("hub streams the synthetic trace to an authenticated subscriber", TestTelemetryContract),
    ("hub refuses an interface other than 127.0.0.1", TestNonLoopbackRefusal),
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
    True(BridgeOptions.TryParse(["--port", "55000"], out var port, out var telemetry), "valid port");
    Equal(55000, port, "port");
    True(BridgeOptions.TryCreate(port, token, telemetry, out var options), "valid token");
    Equal(token, options.InstanceToken, "token");
    True(!BridgeOptions.TryParse(["--port", "80"], out _, out _), "privileged port");
    True(!BridgeOptions.TryCreate(port, "short", telemetry, out _), "short token");
    return Task.CompletedTask;
}

static Task TestTelemetryArguments()
{
    var token = new string('a', 64);
    var tracePath = TracePath();

    True(BridgeOptions.TryParse(["--port", "55000"], out _, out var defaults), "default telemetry");
    Equal(TelemetrySource.Replay, defaults.Source, "default source");
    True(defaults.TracePath is null, "default trace path");
    Equal(TimeSpan.FromSeconds(1), defaults.Cadence, "default cadence");
    Equal(TimeSpan.FromSeconds(5), defaults.SendTimeout, "default send timeout");

    True(
        BridgeOptions.TryParse(
            ["--port", "55000", "--telemetry-source", "native"],
            out _,
            out var native),
        "native source");
    Equal(TelemetrySource.Native, native.Source, "parsed source");
    Equal(TimeSpan.FromSeconds(1), native.Cadence, "native cadence stays bounded");

    True(
        BridgeOptions.TryParse(
            ["--port", "55000", "--telemetry-trace", tracePath],
            out _,
            out var replay),
        "replay trace");
    Equal(tracePath, replay.TracePath, "parsed trace path");
    Equal(TimeSpan.FromSeconds(1), replay.Cadence, "replay cadence stays bounded");

    True(
        !BridgeOptions.TryParse(["--port", "55000", "--telemetry-source", "fake"], out _, out _),
        "unknown source");
    True(
        !BridgeOptions.TryParse(
            ["--port", "55000", "--telemetry-source", "native", "--telemetry-trace", tracePath],
            out _,
            out _),
        "native source with a trace");
    True(
        !BridgeOptions.TryParse(["--port", "55000", "--telemetry-trace", "   "], out _, out _),
        "blank trace path");
    True(
        !BridgeOptions.TryParse(["--port", "55000", "--telemetry-source"], out _, out _),
        "missing value");
    True(
        !BridgeOptions.TryParse(["--port", "55000", "--unknown", "1"], out _, out _),
        "unknown argument");
    True(
        !BridgeOptions.TryCreate(
            55000,
            token,
            BridgeTelemetryOptions.Default with { Cadence = TimeSpan.Zero },
            out _),
        "unbounded cadence");
    Throws<ArgumentOutOfRangeException>(
        () => _ = new TelemetryPublisher(
            BridgeTelemetryOptions.Default with { SendTimeout = TimeSpan.Zero },
            null),
        "unbounded send timeout");
    return Task.CompletedTask;
}

static async Task TestLocalContract()
{
    var port = ReservePort();
    var token = new string('b', 64);
    using var shutdown = new CancellationTokenSource();
    using var output = new StringWriter();
    var run = BridgeServer.RunAsync(
        new BridgeOptions(port, token, BridgeTelemetryOptions.Default),
        output,
        shutdown.Token);

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
    Contains("\"telemetrySource\":\"replay\"", body, "telemetry source");
    Contains("\"telemetryState\":\"idle\"", body, "telemetry state");

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
    await using var adapter = new ReplaySimConnectAdapter(() => File.OpenRead(TracePath()));
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
    await using var adapter = new ReplaySimConnectAdapter(() => File.OpenRead(TracePath()));
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

static async Task TestTelemetryWithoutSource()
{
    var options = BridgeTelemetryOptions.Default;
    True(TelemetryAdapterFactory.TryCreate(options) is null, "no adapter without a trace");
    await using var publisher = new TelemetryPublisher(options, TelemetryAdapterFactory.TryCreate(options));
    publisher.Subscribe("subscriber", new RecordingTelemetrySink());

    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(5));
    await publisher.RunAsync(cancellation.Token);

    Equal(TelemetryState.Idle, publisher.State, "idle state");
    Equal(TelemetrySource.Replay, publisher.Source, "default source");
}

static async Task TestTelemetryWithoutSubscriber()
{
    var adapter = new GeneratedSimConnectAdapter(0);
    await using var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default with { Cadence = TimeSpan.FromMilliseconds(5) },
        () => adapter);

    using var cancellation = new CancellationTokenSource();
    var run = publisher.RunAsync(cancellation.Token);
    await Task.Delay(200);

    True(!adapter.Started, "the source stays closed without a subscriber");
    Equal(TelemetryState.Idle, publisher.State, "idle state");

    await cancellation.CancelAsync();
    await run.WaitAsync(TimeSpan.FromSeconds(5));
    Equal(TelemetryState.Stopped, publisher.State, "stopped state");
    True(!adapter.Started, "the source is never opened");
}

static async Task TestTelemetryOrdering()
{
    var adapter = new GeneratedSimConnectAdapter(5);
    await using var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default with { Cadence = TimeSpan.FromMilliseconds(5) },
        () => adapter);
    var sink = new RecordingTelemetrySink();
    publisher.Subscribe("subscriber", sink);

    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(15));
    await publisher.RunAsync(cancellation.Token);

    Equal(TelemetryState.Completed, publisher.State, "completed state");
    await WaitUntilAsync(() => sink.Count == 5, "five published samples");
    var received = sink.Received;
    for (var index = 0; index < received.Count; index++)
    {
        Equal((long)index, received[index].Sequence, $"sample {index} sequence");
    }

    True(adapter.Disposed, "adapter released");
    True(!sink.Aborted, "subscriber kept");
}

static async Task TestTelemetryDomainGuard()
{
    var adapter = new ScriptedSimConnectAdapter(
        [TelemetrySamples.OutOfDomain(0), TelemetrySamples.Create(1)]);
    await using var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default with { Cadence = TimeSpan.FromMilliseconds(5) },
        () => adapter);
    var sink = new RecordingTelemetrySink();
    publisher.Subscribe("subscriber", sink);

    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(15));
    await publisher.RunAsync(cancellation.Token);

    await WaitUntilAsync(() => sink.Count == 1, "one published sample");
    Equal(1L, sink.Received[0].Sequence, "only the valid sample is published");
    Equal(TelemetryState.Completed, publisher.State, "streaming survives a rejected sample");
}

static async Task TestTelemetryCadence()
{
    var time = new ManualTimeProvider();
    var adapter = new GeneratedSimConnectAdapter(0);
    await using var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default,
        () => adapter,
        time);
    var sink = new RecordingTelemetrySink();
    publisher.Subscribe("subscriber", sink);

    using var cancellation = new CancellationTokenSource();
    var run = publisher.RunAsync(cancellation.Token);
    await WaitUntilAsync(() => sink.Count == 1, "first sample");

    time.Advance(TimeSpan.FromMilliseconds(999));
    await Task.Delay(150);
    Equal(1, sink.Count, "cadence holds the next sample");

    time.Advance(TimeSpan.FromMilliseconds(1));
    await WaitUntilAsync(() => sink.Count == 2, "second sample after one second");

    await cancellation.CancelAsync();
    await run.WaitAsync(TimeSpan.FromSeconds(5));
    Equal(TelemetryState.Stopped, publisher.State, "stopped state");
}

static async Task TestTelemetryLatestPendingSample()
{
    using var gate = new SemaphoreSlim(0);
    var slow = new RecordingTelemetrySink(gate);
    var fast = new RecordingTelemetrySink();
    var adapter = new GeneratedSimConnectAdapter(0);
    await using var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default with
        {
            Cadence = TimeSpan.FromMilliseconds(2),
            SendTimeout = TimeSpan.FromSeconds(30),
        },
        () => adapter);
    publisher.Subscribe("slow", slow);
    publisher.Subscribe("fast", fast);

    using var cancellation = new CancellationTokenSource();
    var run = publisher.RunAsync(cancellation.Token);
    await WaitUntilAsync(() => fast.Count >= 30, "fast subscriber keeps streaming");

    gate.Release(2);
    await WaitUntilAsync(() => slow.Count >= 2, "slow subscriber resumes");

    var received = slow.Received;
    Equal(0L, received[0].Sequence, "first pending sample");
    True(received[1].Sequence >= 10, "only the latest pending sample is kept");
    True(!slow.Aborted, "slow subscriber is not aborted before its timeout");

    await cancellation.CancelAsync();
    await run.WaitAsync(TimeSpan.FromSeconds(5));
}

static async Task TestTelemetryStalledSubscriber()
{
    using var gate = new SemaphoreSlim(0);
    var stalled = new RecordingTelemetrySink(gate);
    var healthy = new RecordingTelemetrySink();
    var adapter = new GeneratedSimConnectAdapter(0);
    await using var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default with
        {
            Cadence = TimeSpan.FromMilliseconds(5),
            SendTimeout = TimeSpan.FromMilliseconds(200),
        },
        () => adapter);
    publisher.Subscribe("stalled", stalled);
    publisher.Subscribe("healthy", healthy);

    using var cancellation = new CancellationTokenSource();
    var run = publisher.RunAsync(cancellation.Token);

    await WaitUntilAsync(() => stalled.Aborted, "stalled subscriber is dropped");
    Equal(0, stalled.Count, "stalled subscriber received nothing");

    var observed = healthy.Count;
    await WaitUntilAsync(() => healthy.Count >= observed + 3, "reading survives the drop");
    True(!healthy.Aborted, "healthy subscriber kept");

    await cancellation.CancelAsync();
    await run.WaitAsync(TimeSpan.FromSeconds(5));
}

static async Task TestTelemetryCancellation()
{
    var adapter = new GeneratedSimConnectAdapter(0);
    var publisher = new TelemetryPublisher(
        BridgeTelemetryOptions.Default with { Cadence = TimeSpan.FromMilliseconds(5) },
        () => adapter);
    var sink = new RecordingTelemetrySink();
    publisher.Subscribe("subscriber", sink);

    using var cancellation = new CancellationTokenSource();
    var run = publisher.RunAsync(cancellation.Token);
    await WaitUntilAsync(() => sink.Count >= 2, "streaming started");

    await cancellation.CancelAsync();
    await run.WaitAsync(TimeSpan.FromSeconds(5));

    Equal(TelemetryState.Stopped, publisher.State, "stopped state");
    True(adapter.Disposed, "adapter released");

    await publisher.DisposeAsync();
    Equal(0, publisher.SubscriberCount, "no residual subscriber");
}

static async Task TestNativeTelemetrySource()
{
    var options = BridgeTelemetryOptions.Default with
    {
        Source = TelemetrySource.Native,
        Cadence = TimeSpan.FromMilliseconds(10),
    };
    await using var publisher = new TelemetryPublisher(options, TelemetryAdapterFactory.TryCreate(options));
    publisher.Subscribe("subscriber", new RecordingTelemetrySink());

    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(5));
    await publisher.RunAsync(cancellation.Token);

    Equal(TelemetrySource.Native, publisher.Source, "native source");
    True(publisher.State != TelemetryState.Idle, "native source is attempted");
    True(
        publisher.State is TelemetryState.Unavailable
            or TelemetryState.Stopped
            or TelemetryState.Completed,
        "native source terminates without failing the harness");
}

static async Task TestTelemetryContract()
{
    var port = ReservePort();
    var token = new string('d', 64);
    var telemetry = BridgeTelemetryOptions.Default with
    {
        TracePath = TracePath(),
        Cadence = TimeSpan.FromMilliseconds(25),
    };
    await using var publisher = new TelemetryPublisher(
        telemetry,
        TelemetryAdapterFactory.TryCreate(telemetry));
    using var shutdown = new CancellationTokenSource();
    using var output = new StringWriter();
    var run = BridgeServer.RunAsync(
        new BridgeOptions(port, token, telemetry),
        output,
        shutdown.Token,
        publisher);

    await WaitUntilReady(output);
    using var client = new HttpClient { BaseAddress = new Uri($"http://127.0.0.1:{port}") };
    client.DefaultRequestHeaders.Add(BridgeContract.TokenHeader, token);

    var idle = await client.GetStringAsync(BridgeContract.HealthPath);
    Contains("\"telemetrySource\":\"replay\"", idle, "published source");
    Contains("\"telemetryState\":\"idle\"", idle, "state before the first subscriber");

    await ThrowsAsync<WebSocketException>(
        async () => await TelemetrySubscriber.ConnectAsync(port, null),
        "anonymous subscriber");
    await ThrowsAsync<WebSocketException>(
        async () => await TelemetrySubscriber.ConnectAsync(port, new string('e', 64)),
        "incorrect token subscriber");
    Equal(0, publisher.SubscriberCount, "refused negotiations create no subscriber");

    await using var subscriber = await TelemetrySubscriber.ConnectAsync(port, token);
    for (var expected = 0L; expected < 8; expected++)
    {
        var sample = await subscriber.ReadSampleAsync(TimeSpan.FromSeconds(10));
        Equal(expected, sample.GetProperty("sequence").GetInt64(), $"sample {expected} sequence");
        True(sample.TryGetProperty("altitudeFeet", out _), "sample exposes the bounded domain");
        True(!sample.TryGetProperty("companyId", out _), "sample exposes no business field");
    }

    await WaitUntilAsync(
        () => publisher.State == TelemetryState.Completed,
        "replay reaches its last sample");
    var completed = await client.GetStringAsync(BridgeContract.HealthPath);
    Contains("\"telemetryState\":\"completed\"", completed, "state after the last sample");
    Contains("\"contractVersion\":\"1\"", completed, "contract version is preserved");

    shutdown.Cancel();
    Equal(
        BridgeApplication.SuccessExitCode,
        await run.WaitAsync(TimeSpan.FromSeconds(10)),
        "exit code");
}

static async Task TestNonLoopbackRefusal()
{
    var port = ReservePort();
    var token = new string('f', 64);
    using var shutdown = new CancellationTokenSource();
    using var output = new StringWriter();
    var run = BridgeServer.RunAsync(
        new BridgeOptions(port, token, BridgeTelemetryOptions.Default),
        output,
        shutdown.Token);

    await WaitUntilReady(output);
    var hosts = new List<string> { "[::1]" };
    var external = NonLoopbackAddress();
    if (external is not null)
    {
        hosts.Add(external);
    }

    foreach (var host in hosts)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri($"http://{host}:{port}"),
            Timeout = TimeSpan.FromSeconds(3),
        };
        client.DefaultRequestHeaders.Add(BridgeContract.TokenHeader, token);
        var refused = false;
        try
        {
            using var response = await client.PostAsync(
                $"{BridgeContract.HubPath}/negotiate?negotiateVersion=1",
                new StringContent(string.Empty));
        }
        catch (Exception exception) when (
            exception is HttpRequestException or TaskCanceledException)
        {
            refused = true;
        }

        True(refused, $"{host} is refused");
    }

    shutdown.Cancel();
    Equal(
        BridgeApplication.SuccessExitCode,
        await run.WaitAsync(TimeSpan.FromSeconds(10)),
        "exit code");
}

static Task TestPublicContracts()
{
    var publicContractTypes = new[]
    {
        typeof(ISimConnectAdapter),
        typeof(FlightSample),
        typeof(ITelemetrySink),
        typeof(TelemetryPublisher),
        typeof(BridgeTelemetryOptions),
    };
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

static string TracePath() =>
    Path.Combine(AppContext.BaseDirectory, "traces", "synthetic-golden-flight.jsonl");

static async Task WaitUntilAsync(Func<bool> condition, string subject)
{
    for (var attempt = 0; attempt < 1_000; attempt++)
    {
        if (condition())
        {
            return;
        }

        await Task.Delay(20);
    }

    throw new TimeoutException($"{subject}: condition was not observed.");
}

static string? NonLoopbackAddress()
{
    foreach (var address in Dns.GetHostAddresses(Dns.GetHostName()))
    {
        if (address.AddressFamily == AddressFamily.InterNetwork
            && !IPAddress.IsLoopback(address))
        {
            return address.ToString();
        }
    }

    return null;
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
        [EnumeratorCancellation] CancellationToken cancellationToken)
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

static class TelemetrySamples
{
    public static FlightSample Create(long sequence) =>
        FlightSample.Create(
            sequence,
            DateTimeOffset.UnixEpoch.AddSeconds(sequence),
            48,
            2,
            1_000,
            100,
            90,
            180,
            0,
            false);

    public static FlightSample OutOfDomain(long sequence) =>
        new(sequence, DateTimeOffset.UnixEpoch, 999, 2, 1_000, 100, 90, 180, 0, false);
}

sealed class GeneratedSimConnectAdapter(int count) : ISimConnectAdapter
{
    public bool Started { get; private set; }

    public bool Disposed { get; private set; }

    public async IAsyncEnumerable<FlightSample> ReadAllAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        Started = true;
        for (var sequence = 0L; count <= 0 || sequence < count; sequence++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            yield return TelemetrySamples.Create(sequence);
            await Task.Yield();
        }
    }

    public ValueTask DisposeAsync()
    {
        Disposed = true;
        return ValueTask.CompletedTask;
    }
}

sealed class ScriptedSimConnectAdapter(IReadOnlyList<FlightSample> samples) : ISimConnectAdapter
{
    public bool Disposed { get; private set; }

    public async IAsyncEnumerable<FlightSample> ReadAllAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        foreach (var sample in samples)
        {
            cancellationToken.ThrowIfCancellationRequested();
            yield return sample;
            await Task.Yield();
        }
    }

    public ValueTask DisposeAsync()
    {
        Disposed = true;
        return ValueTask.CompletedTask;
    }
}

sealed class RecordingTelemetrySink(SemaphoreSlim? gate = null) : ITelemetrySink
{
    private readonly List<FlightSample> _received = [];
    private int _aborted;

    public bool Aborted => Volatile.Read(ref _aborted) != 0;

    public int Count
    {
        get
        {
            lock (_received)
            {
                return _received.Count;
            }
        }
    }

    public IReadOnlyList<FlightSample> Received
    {
        get
        {
            lock (_received)
            {
                return _received.ToArray();
            }
        }
    }

    public async Task SendAsync(FlightSample sample, CancellationToken cancellationToken)
    {
        if (gate is not null)
        {
            await gate.WaitAsync(cancellationToken);
        }

        lock (_received)
        {
            _received.Add(sample);
        }
    }

    public void Abort() => Interlocked.Exchange(ref _aborted, 1);
}

sealed class ManualTimeProvider : TimeProvider
{
    private readonly object _gate = new();
    private readonly List<ManualTimer> _timers = [];
    private DateTimeOffset _now = DateTimeOffset.UnixEpoch;

    public override DateTimeOffset GetUtcNow()
    {
        lock (_gate)
        {
            return _now;
        }
    }

    public override ITimer CreateTimer(
        TimerCallback callback,
        object? state,
        TimeSpan dueTime,
        TimeSpan period)
    {
        var timer = new ManualTimer(this, callback, state);
        lock (_gate)
        {
            _timers.Add(timer);
        }

        timer.Change(dueTime, period);
        return timer;
    }

    public void Advance(TimeSpan delta)
    {
        DateTimeOffset now;
        ManualTimer[] candidates;
        lock (_gate)
        {
            _now += delta;
            now = _now;
            candidates = _timers.ToArray();
        }

        foreach (var timer in candidates)
        {
            timer.Fire(now);
        }
    }

    internal void Remove(ManualTimer timer)
    {
        lock (_gate)
        {
            _timers.Remove(timer);
        }
    }
}

sealed class ManualTimer(ManualTimeProvider provider, TimerCallback callback, object? state) : ITimer
{
    private readonly object _gate = new();
    private DateTimeOffset? _dueAt;
    private TimeSpan _period = Timeout.InfiniteTimeSpan;

    public bool Change(TimeSpan dueTime, TimeSpan period)
    {
        var now = provider.GetUtcNow();
        lock (_gate)
        {
            _dueAt = dueTime == Timeout.InfiniteTimeSpan ? null : now + dueTime;
            _period = period;
        }

        return true;
    }

    public void Fire(DateTimeOffset now)
    {
        lock (_gate)
        {
            if (_dueAt is not { } dueAt || dueAt > now)
            {
                return;
            }

            _dueAt = _period > TimeSpan.Zero && _period != Timeout.InfiniteTimeSpan
                ? now + _period
                : null;
        }

        callback(state);
    }

    public void Dispose() => provider.Remove(this);

    public ValueTask DisposeAsync()
    {
        Dispose();
        return ValueTask.CompletedTask;
    }
}

sealed class TelemetrySubscriber : IAsyncDisposable
{
    private const byte RecordSeparator = 0x1E;

    private readonly ClientWebSocket _socket = new();
    private readonly List<byte> _buffer = [];
    private readonly Queue<string> _records = new();

    public static async Task<TelemetrySubscriber> ConnectAsync(int port, string? token)
    {
        var subscriber = new TelemetrySubscriber();
        if (token is not null)
        {
            subscriber._socket.Options.SetRequestHeader(BridgeContract.TokenHeader, token);
        }

        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        await subscriber._socket.ConnectAsync(
            new Uri($"ws://127.0.0.1:{port}{BridgeContract.HubPath}"),
            cancellation.Token);
        await subscriber.SendRecordAsync(
            "{\"protocol\":\"json\",\"version\":1}",
            cancellation.Token);

        var handshake = await subscriber.ReadRecordAsync(cancellation.Token);
        using var document = JsonDocument.Parse(handshake);
        if (document.RootElement.TryGetProperty("error", out _))
        {
            throw new InvalidOperationException("The bridge refused the telemetry handshake.");
        }

        return subscriber;
    }

    public async Task<JsonElement> ReadSampleAsync(TimeSpan timeout)
    {
        using var cancellation = new CancellationTokenSource(timeout);
        while (true)
        {
            var record = await ReadRecordAsync(cancellation.Token);
            using var document = JsonDocument.Parse(record);
            var root = document.RootElement;
            if (!root.TryGetProperty("type", out var type) || type.GetInt32() != 1)
            {
                continue;
            }

            if (root.GetProperty("target").GetString() != BridgeContract.TelemetryMessage)
            {
                continue;
            }

            return root.GetProperty("arguments")[0].Clone();
        }
    }

    public async ValueTask DisposeAsync()
    {
        try
        {
            if (_socket.State == WebSocketState.Open)
            {
                using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                await _socket.CloseAsync(
                    WebSocketCloseStatus.NormalClosure,
                    string.Empty,
                    cancellation.Token);
            }
        }
        catch (WebSocketException)
        {
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            _socket.Dispose();
        }
    }

    private Task SendRecordAsync(string payload, CancellationToken cancellationToken) =>
        _socket.SendAsync(
            Encoding.UTF8.GetBytes(payload + (char)RecordSeparator),
            WebSocketMessageType.Text,
            true,
            cancellationToken);

    private async Task<string> ReadRecordAsync(CancellationToken cancellationToken)
    {
        while (_records.Count == 0)
        {
            var chunk = new byte[4_096];
            var result = await _socket.ReceiveAsync(chunk, cancellationToken);
            if (result.MessageType == WebSocketMessageType.Close)
            {
                throw new InvalidOperationException("The bridge closed the telemetry channel.");
            }

            for (var index = 0; index < result.Count; index++)
            {
                if (chunk[index] == RecordSeparator)
                {
                    _records.Enqueue(Encoding.UTF8.GetString(_buffer.ToArray()));
                    _buffer.Clear();
                    continue;
                }

                _buffer.Add(chunk[index]);
            }
        }

        return _records.Dequeue();
    }
}
