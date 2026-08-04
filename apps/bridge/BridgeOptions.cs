using Thrustline.Bridge.Telemetry;

namespace Thrustline.Bridge;

public sealed record BridgeOptions(
    int Port,
    string InstanceToken,
    BridgeTelemetryOptions Telemetry)
{
    public const int MinimumPort = 49152;
    public const int MaximumPort = 65535;
    public const string PortArgument = "--port";
    public const string TelemetrySourceArgument = "--telemetry-source";
    public const string TelemetryTraceArgument = "--telemetry-trace";

    public static bool TryParse(
        IReadOnlyList<string> arguments,
        out int port,
        out BridgeTelemetryOptions telemetry)
    {
        ArgumentNullException.ThrowIfNull(arguments);

        port = 0;
        telemetry = BridgeTelemetryOptions.Default;
        if (arguments.Count < 2 || arguments.Count % 2 != 0)
        {
            return false;
        }

        var source = TelemetrySource.Replay;
        string? tracePath = null;
        var parsedPort = 0;
        var seenPort = false;
        var seenSource = false;
        var seenTrace = false;

        for (var index = 0; index < arguments.Count; index += 2)
        {
            var name = arguments[index];
            var value = arguments[index + 1];
            switch (name)
            {
                case PortArgument when !seenPort && int.TryParse(value, out parsedPort):
                    seenPort = true;
                    break;
                case TelemetrySourceArgument
                    when !seenSource && BridgeTelemetryOptions.TryParseSource(value, out source):
                    seenSource = true;
                    break;
                case TelemetryTraceArgument
                    when !seenTrace && BridgeTelemetryOptions.IsSupportedTracePath(value):
                    tracePath = value;
                    seenTrace = true;
                    break;
                default:
                    return false;
            }
        }

        if (!seenPort
            || parsedPort is not (>= MinimumPort and <= MaximumPort)
            || (tracePath is not null && source != TelemetrySource.Replay))
        {
            return false;
        }

        port = parsedPort;
        telemetry = BridgeTelemetryOptions.Default with { Source = source, TracePath = tracePath };
        return telemetry.IsBounded;
    }

    public static bool TryCreate(
        int port,
        string? token,
        BridgeTelemetryOptions telemetry,
        out BridgeOptions options)
    {
        options = null!;
        if (port is not (>= MinimumPort and <= MaximumPort)
            || token is null
            || !IsHexToken(token)
            || telemetry is null
            || !telemetry.IsBounded)
        {
            return false;
        }

        options = new BridgeOptions(port, token, telemetry);
        return true;
    }

    private static bool IsHexToken(string value) =>
        value.Length == 64 && value.All(Uri.IsHexDigit);
}
