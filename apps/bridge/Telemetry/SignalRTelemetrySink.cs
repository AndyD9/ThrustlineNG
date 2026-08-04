using Microsoft.AspNetCore.SignalR;

using Thrustline.Bridge.SimConnect;

namespace Thrustline.Bridge.Telemetry;

public sealed class SignalRTelemetrySink(IHubContext<BridgeHub> hub, HubCallerContext context)
    : ITelemetrySink
{
    public Task SendAsync(FlightSample sample, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(sample);

        return hub.Clients
            .Client(context.ConnectionId)
            .SendAsync(BridgeContract.TelemetryMessage, sample, cancellationToken);
    }

    public void Abort() => context.Abort();
}
