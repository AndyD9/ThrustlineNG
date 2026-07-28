namespace Thrustline.Bridge;

public enum BridgeHealthStatus
{
    Healthy,
    Stopping,
}

public sealed class BridgeHealth
{
    private int _stopping;

    public BridgeHealthStatus GetStatus() =>
        Volatile.Read(ref _stopping) == 0
            ? BridgeHealthStatus.Healthy
            : BridgeHealthStatus.Stopping;

    public void MarkStopping() => Interlocked.Exchange(ref _stopping, 1);
}
