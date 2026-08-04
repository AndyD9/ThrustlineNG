using Thrustline.Bridge.SimConnect;

namespace Thrustline.Bridge.Telemetry;

public interface ITelemetrySink
{
    Task SendAsync(FlightSample sample, CancellationToken cancellationToken);

    void Abort();
}
