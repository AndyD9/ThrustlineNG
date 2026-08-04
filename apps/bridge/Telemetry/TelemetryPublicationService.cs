using Microsoft.Extensions.Hosting;

namespace Thrustline.Bridge.Telemetry;

public sealed class TelemetryPublicationService(TelemetryPublisher publisher) : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        publisher.RunAsync(stoppingToken);
}
