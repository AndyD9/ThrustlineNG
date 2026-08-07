namespace Thrustline.Bridge;

public static class BridgeContract
{
    public const string Version = "1";
    public const string TokenHeader = "X-Thrustline-Instance";
    public const string HealthPath = "/api/v1/health";
    public const string FlightSummaryPath = "/api/v1/flight-summary";
    public const string FlightSummaryRearmPath = "/api/v1/flight-summary/rearm";
    public const string HubPath = "/hubs/v1/bridge";
    public const string TelemetryMessage = "telemetry.v1";
}
