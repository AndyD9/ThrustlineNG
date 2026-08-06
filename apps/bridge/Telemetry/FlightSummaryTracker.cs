using Thrustline.Bridge.SimConnect;

namespace Thrustline.Bridge.Telemetry;

public enum FlightSummaryState
{
    Idle,
    Running,
    Completed,
    Incomplete,
}

public sealed record FlightSummary(FlightSummaryState State, int? BlockMinutes);

/// <summary>
/// Dérive le résumé de vol des échantillons déjà validés, sans en persister
/// aucun : seuls deux instants et le dernier état au sol sont retenus.
/// Règle décidée le 6 août 2026 (F0004) : le temps de bloc va du premier
/// échantillon en mouvement (vitesse sol non nulle ou airborne) au dernier
/// retour au sol de la trace, arrondi à la minute supérieure, minimum une
/// minute ; une trace sans retour au sol reste « incomplete » sans temps
/// inventé. Le résumé n'est « completed » que si la trace se termine au sol :
/// un vol qui redécolle après un toucher et finit en l'air reste incomplet
/// plutôt que de déclarer un temps plausible mais faux.
/// </summary>
internal sealed class FlightSummaryTracker
{
    private readonly object _gate = new();
    private DateTimeOffset? _movementStartedAt;
    private DateTimeOffset? _lastGroundReturnAt;
    private bool? _previousOnGround;
    private bool _observed;
    private bool _terminal;
    private bool _traceCompleted;

    public void Observe(FlightSample sample)
    {
        ArgumentNullException.ThrowIfNull(sample);

        lock (_gate)
        {
            if (_terminal)
            {
                return;
            }

            _observed = true;
            if (_movementStartedAt is null
                && (sample.GroundSpeedKnots > 0 || !sample.OnGround))
            {
                _movementStartedAt = sample.CapturedAt;
            }

            if (sample.OnGround && _previousOnGround == false)
            {
                _lastGroundReturnAt = sample.CapturedAt;
            }

            _previousOnGround = sample.OnGround;
        }
    }

    public void OnPublisherState(TelemetryState state)
    {
        if (state is not (TelemetryState.Completed
            or TelemetryState.Unavailable
            or TelemetryState.Stopped))
        {
            return;
        }

        lock (_gate)
        {
            if (_terminal)
            {
                return;
            }

            _terminal = true;
            _traceCompleted = state == TelemetryState.Completed;
        }
    }

    public FlightSummary Snapshot()
    {
        lock (_gate)
        {
            if (!_terminal)
            {
                return new FlightSummary(
                    _observed ? FlightSummaryState.Running : FlightSummaryState.Idle,
                    null);
            }

            // Le « dernier retour au sol de la trace » n'est connaissable que
            // si la trace a été rejouée jusqu'à sa fin et se termine au sol ;
            // une lecture tronquée ou un vol qui finit en l'air reste
            // incomplet même si un atterrissage a été observé.
            if (_traceCompleted
                && _previousOnGround == true
                && ComputeBlockMinutes() is { } blockMinutes)
            {
                return new FlightSummary(FlightSummaryState.Completed, blockMinutes);
            }

            return new FlightSummary(
                _observed || _traceCompleted
                    ? FlightSummaryState.Incomplete
                    : FlightSummaryState.Idle,
                null);
        }
    }

    private int? ComputeBlockMinutes()
    {
        if (_movementStartedAt is not { } movementStartedAt
            || _lastGroundReturnAt is not { } lastGroundReturnAt
            || lastGroundReturnAt < movementStartedAt)
        {
            return null;
        }

        var elapsed = lastGroundReturnAt - movementStartedAt;
        return Math.Max(1, (int)Math.Ceiling(elapsed.TotalMinutes));
    }
}
