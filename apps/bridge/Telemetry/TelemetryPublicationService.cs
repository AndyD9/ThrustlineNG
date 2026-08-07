using Microsoft.Extensions.Hosting;

namespace Thrustline.Bridge.Telemetry;

public sealed class TelemetryPublicationService(TelemetryPublisher publisher) : BackgroundService
{
    // Une passe de publication par session de mesure : chaque réarmement
    // accepté rejoue la source depuis le début sous sa nouvelle génération.
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await publisher.RunAsync(stoppingToken).ConfigureAwait(false);
            if (!await publisher.WaitForRearmAsync(stoppingToken).ConfigureAwait(false))
            {
                return;
            }
        }
    }
}
