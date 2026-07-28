using System.Runtime.CompilerServices;

namespace Thrustline.Bridge.SimConnect;

public sealed class ReplaySimConnectAdapter(
    Func<Stream> streamFactory,
    bool preserveTiming = false,
    TimeProvider? timeProvider = null) : ISimConnectAdapter
{
    private readonly TimeProvider _timeProvider = timeProvider ?? TimeProvider.System;

    public async IAsyncEnumerable<FlightSample> ReadAllAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        await using var stream = streamFactory();
        long previousOffset = 0;
        long sequence = 0;
        var origin = _timeProvider.GetUtcNow();

        await foreach (var traceSample in SimConnectTraceReader.ReadAllAsync(stream, cancellationToken))
        {
            if (preserveTiming)
            {
                await Task.Delay(
                    TimeSpan.FromMilliseconds(traceSample.OffsetMilliseconds - previousOffset),
                    _timeProvider,
                    cancellationToken).ConfigureAwait(false);
            }

            yield return traceSample.ToFlightSample(sequence, origin);
            sequence++;
            previousOffset = traceSample.OffsetMilliseconds;
        }
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}
