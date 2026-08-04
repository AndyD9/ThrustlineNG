using Microsoft.AspNetCore.SignalR;

using Thrustline.Bridge.Telemetry;

namespace Thrustline.Bridge;

public sealed class BridgeHub(TelemetryPublisher publisher, IHubContext<BridgeHub> hub) : Hub
{
    public override Task OnConnectedAsync()
    {
        publisher.Subscribe(Context.ConnectionId, new SignalRTelemetrySink(hub, Context));
        return Task.CompletedTask;
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        publisher.Unsubscribe(Context.ConnectionId);
        return Task.CompletedTask;
    }
}
