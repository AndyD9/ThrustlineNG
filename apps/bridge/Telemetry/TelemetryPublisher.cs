using System.Collections.Concurrent;
using System.Threading.Channels;

using Thrustline.Bridge.SimConnect;

namespace Thrustline.Bridge.Telemetry;

public sealed class TelemetryPublisher : IAsyncDisposable
{
    private readonly BridgeTelemetryOptions _options;
    private readonly Func<ISimConnectAdapter>? _adapterFactory;
    private readonly TimeProvider _timeProvider;
    private readonly ConcurrentDictionary<string, Subscription> _subscriptions =
        new(StringComparer.Ordinal);

    private readonly TaskCompletionSource _firstSubscriber =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    // La session de mesure courante : tracker et génération ne changent
    // qu'ensemble, sous _measurementGate, et jamais pendant un streaming.
    private readonly object _measurementGate = new();
    private FlightSummaryTracker _summary = new();
    private int _generation = 1;
    private bool _rearmPending;
    private TaskCompletionSource? _rearmSignal;

    private int _state = (int)TelemetryState.Idle;

    public TelemetryPublisher(
        BridgeTelemetryOptions options,
        Func<ISimConnectAdapter>? adapterFactory,
        TimeProvider? timeProvider = null)
    {
        ArgumentNullException.ThrowIfNull(options);
        if (!options.IsBounded)
        {
            throw new ArgumentOutOfRangeException(
                nameof(options),
                "Telemetry options must keep a positive cadence and send timeout.");
        }

        _options = options;
        _adapterFactory = adapterFactory;
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public TelemetrySource Source => _options.Source;

    public TelemetryState State => (TelemetryState)Volatile.Read(ref _state);

    public int SubscriberCount => _subscriptions.Count;

    public FlightSummary Summary => Reading.Summary;

    public FlightSummaryReading Reading
    {
        get
        {
            lock (_measurementGate)
            {
                return new FlightSummaryReading(_summary.Snapshot(), _generation);
            }
        }
    }

    /// <summary>
    /// Ouvre une nouvelle session de mesure : tracker neuf, génération
    /// incrémentée. Refusé pendant un streaming pour ne jamais perdre une
    /// mesure en cours ; aucune identité métier n'entre ici — la génération
    /// est un entier local que seul le détenteur du jeton peut faire avancer.
    /// </summary>
    public bool TryRearm(out int generation)
    {
        lock (_measurementGate)
        {
            if (State == TelemetryState.Streaming)
            {
                generation = _generation;
                return false;
            }

            _generation++;
            _summary = new FlightSummaryTracker();
            Volatile.Write(ref _state, (int)TelemetryState.Idle);
            _rearmPending = true;
            _rearmSignal?.TrySetResult();
            generation = _generation;
            return true;
        }
    }

    /// <summary>
    /// Attend le prochain réarmement ; rend faux sur annulation. Un
    /// réarmement survenu avant l'attente est consommé immédiatement.
    /// </summary>
    public async Task<bool> WaitForRearmAsync(CancellationToken cancellationToken)
    {
        TaskCompletionSource signal;
        lock (_measurementGate)
        {
            if (_rearmPending)
            {
                _rearmPending = false;
                return true;
            }

            signal = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            _rearmSignal = signal;
        }

        try
        {
            await signal.Task.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            return false;
        }
        finally
        {
            lock (_measurementGate)
            {
                if (ReferenceEquals(_rearmSignal, signal))
                {
                    _rearmSignal = null;
                }

                _rearmPending = false;
            }
        }

        return true;
    }

    public void Subscribe(string subscriberId, ITelemetrySink sink)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(subscriberId);
        ArgumentNullException.ThrowIfNull(sink);

        var subscription = new Subscription(sink, _options.SendTimeout, _timeProvider);
        if (!_subscriptions.TryAdd(subscriberId, subscription))
        {
            subscription.Complete();
            return;
        }

        _firstSubscriber.TrySetResult();
    }

    public void Unsubscribe(string subscriberId)
    {
        if (!string.IsNullOrEmpty(subscriberId)
            && _subscriptions.TryRemove(subscriberId, out var subscription))
        {
            subscription.Complete();
        }
    }

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        if (_adapterFactory is null)
        {
            return;
        }

        try
        {
            await _firstSubscriber.Task.WaitAsync(cancellationToken).ConfigureAwait(false);
            await using var adapter = _adapterFactory();
            Transition(TelemetryState.Streaming);

            await foreach (var sample in adapter
                .ReadAllAsync(cancellationToken)
                .ConfigureAwait(false))
            {
                if (sample is null || !sample.IsWithinDomain())
                {
                    continue;
                }

                Dispatch(sample);
                await Task.Delay(_options.Cadence, _timeProvider, cancellationToken)
                    .ConfigureAwait(false);
            }

            Transition(TelemetryState.Completed);
        }
        catch (OperationCanceledException)
        {
            Transition(TelemetryState.Stopped);
        }
        catch (Exception)
        {
            Transition(TelemetryState.Unavailable);
        }
    }

    public async ValueTask DisposeAsync()
    {
        var pending = new List<Task>();
        foreach (var subscriberId in _subscriptions.Keys)
        {
            if (_subscriptions.TryRemove(subscriberId, out var subscription))
            {
                subscription.Complete();
                pending.Add(subscription.Completion);
            }
        }

        await Task.WhenAll(pending).ConfigureAwait(false);
    }

    private void Dispatch(FlightSample sample)
    {
        FlightSummaryTracker summary;
        lock (_measurementGate)
        {
            summary = _summary;
        }

        summary.Observe(sample);
        foreach (var subscription in _subscriptions.Values)
        {
            subscription.Publish(sample);
        }
    }

    private void Transition(TelemetryState state)
    {
        // Le résumé devient terminal avant que l'état soit visible du health
        // check : qui observe `completed` peut lire un résumé déjà final.
        lock (_measurementGate)
        {
            _summary.OnPublisherState(state);
            Volatile.Write(ref _state, (int)state);
        }
    }

    private sealed class Subscription
    {
        private readonly Channel<FlightSample> _pending = Channel.CreateBounded<FlightSample>(
            new BoundedChannelOptions(1)
            {
                FullMode = BoundedChannelFullMode.DropOldest,
                SingleReader = true,
                SingleWriter = false,
            });

        private readonly Task _pump;

        public Subscription(ITelemetrySink sink, TimeSpan sendTimeout, TimeProvider timeProvider) =>
            _pump = Task.Run(() => PumpAsync(sink, sendTimeout, timeProvider));

        public Task Completion => _pump;

        public void Publish(FlightSample sample) => _pending.Writer.TryWrite(sample);

        public void Complete() => _pending.Writer.TryComplete();

        private async Task PumpAsync(
            ITelemetrySink sink,
            TimeSpan sendTimeout,
            TimeProvider timeProvider)
        {
            try
            {
                await foreach (var sample in _pending.Reader.ReadAllAsync().ConfigureAwait(false))
                {
                    using var sendCancellation = new CancellationTokenSource(
                        sendTimeout,
                        timeProvider);
                    try
                    {
                        await sink.SendAsync(sample, sendCancellation.Token)
                            .WaitAsync(sendTimeout, timeProvider)
                            .ConfigureAwait(false);
                    }
                    catch (Exception)
                    {
                        Complete();
                        sink.Abort();
                        return;
                    }
                }
            }
            catch (Exception)
            {
                Complete();
                sink.Abort();
            }
        }
    }
}
