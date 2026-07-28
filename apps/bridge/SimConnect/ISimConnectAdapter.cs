namespace Thrustline.Bridge.SimConnect;

public interface ISimConnectAdapter : IAsyncDisposable
{
    IAsyncEnumerable<FlightSample> ReadAllAsync(CancellationToken cancellationToken);
}
