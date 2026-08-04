using Thrustline.Bridge.SimConnect;

namespace Thrustline.Bridge.Telemetry;

public static class TelemetryAdapterFactory
{
    public static Func<ISimConnectAdapter>? TryCreate(BridgeTelemetryOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);

        return options.Source switch
        {
            TelemetrySource.Native => static () => new NativeSimConnectAdapter(),
            TelemetrySource.Replay when options.TracePath is { Length: > 0 } tracePath =>
                () => new ReplaySimConnectAdapter(() => File.OpenRead(tracePath)),
            _ => null,
        };
    }
}
