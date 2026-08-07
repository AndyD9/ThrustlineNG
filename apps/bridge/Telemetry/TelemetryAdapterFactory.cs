using Thrustline.Bridge.SimConnect;

namespace Thrustline.Bridge.Telemetry;

public static class TelemetryAdapterFactory
{
    public static Func<ISimConnectAdapter>? TryCreate(BridgeTelemetryOptions options) =>
        TryCreate(options, out _);

    /// <summary>
    /// Construit la fabrique d'adaptateur et, pour la source native, rend la
    /// localisation retenue par la sonde bornée. Une source native sans
    /// bibliothèque localisée rend une fabrique nulle : le processus reste
    /// démarré et l'état devient <c>unavailable</c> au lieu de planter.
    /// </summary>
    public static Func<ISimConnectAdapter>? TryCreate(
        BridgeTelemetryOptions options,
        out SimConnectLibraryLocation nativeLibrary,
        Func<string, string?>? environment = null,
        string? applicationDirectory = null)
    {
        ArgumentNullException.ThrowIfNull(options);
        nativeLibrary = SimConnectLibraryLocation.Unavailable;

        switch (options.Source)
        {
            case TelemetrySource.Native:
                var location = SimConnectLibraryLocator.Locate(
                    options.SimConnectLibraryPath,
                    environment,
                    applicationDirectory);
                nativeLibrary = location;
                return location.Origin == SimConnectLibraryOrigin.None
                    ? null
                    : () => new NativeSimConnectAdapter(location);
            case TelemetrySource.Replay when options.TracePath is { Length: > 0 } tracePath:
                return () => new ReplaySimConnectAdapter(() => File.OpenRead(tracePath));
            default:
                return null;
        }
    }
}
