namespace Thrustline.Bridge.Telemetry;

public enum TelemetrySource
{
    Replay,
    Native,
}

public enum TelemetryState
{
    Idle,
    Streaming,
    Completed,
    Unavailable,
    Stopped,
}

public sealed record BridgeTelemetryOptions(
    TelemetrySource Source,
    string? TracePath,
    TimeSpan Cadence,
    TimeSpan SendTimeout)
{
    public const string ReplayArgument = "replay";
    public const string NativeArgument = "native";
    public const int MaximumTracePathLength = 260;

    public static TimeSpan PublicationCadence => TimeSpan.FromSeconds(1);

    public static TimeSpan SubscriberSendTimeout => TimeSpan.FromSeconds(5);

    public static BridgeTelemetryOptions Default { get; } = new(
        TelemetrySource.Replay,
        null,
        PublicationCadence,
        SubscriberSendTimeout);

    public bool IsBounded =>
        Cadence > TimeSpan.Zero
        && SendTimeout > TimeSpan.Zero
        && (TracePath is null || (Source == TelemetrySource.Replay && IsSupportedTracePath(TracePath)));

    public static bool TryParseSource(string? value, out TelemetrySource source)
    {
        switch (value)
        {
            case ReplayArgument:
                source = TelemetrySource.Replay;
                return true;
            case NativeArgument:
                source = TelemetrySource.Native;
                return true;
            default:
                source = TelemetrySource.Replay;
                return false;
        }
    }

    public static bool IsSupportedTracePath(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && value.Length <= MaximumTracePathLength
        && value.IndexOfAny(Path.GetInvalidPathChars()) < 0;
}
