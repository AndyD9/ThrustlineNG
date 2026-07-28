namespace Thrustline.Bridge;

public sealed record BridgeOptions(int Port, string InstanceToken)
{
    public const int MinimumPort = 49152;
    public const int MaximumPort = 65535;

    public static bool TryParse(IReadOnlyList<string> arguments, out int port)
    {
        port = 0;
        if (arguments.Count != 2
            || !string.Equals(arguments[0], "--port", StringComparison.Ordinal)
            || !int.TryParse(arguments[1], out port))
        {
            return false;
        }

        return port is >= MinimumPort and <= MaximumPort;
    }

    public static bool TryCreate(int port, string? token, out BridgeOptions options)
    {
        options = null!;
        if (port is not (>= MinimumPort and <= MaximumPort)
            || token is null
            || !IsHexToken(token))
        {
            return false;
        }

        options = new BridgeOptions(port, token);
        return true;
    }

    private static bool IsHexToken(string value) =>
        value.Length == 64 && value.All(Uri.IsHexDigit);
}
