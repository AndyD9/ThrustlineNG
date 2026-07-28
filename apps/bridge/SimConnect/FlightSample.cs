namespace Thrustline.Bridge.SimConnect;

public sealed record FlightSample(
    long Sequence,
    DateTimeOffset CapturedAt,
    double LatitudeDegrees,
    double LongitudeDegrees,
    double AltitudeFeet,
    double GroundSpeedKnots,
    double IndicatedAirspeedKnots,
    double HeadingDegrees,
    double VerticalSpeedFeetPerMinute,
    bool OnGround)
{
    public static FlightSample Create(
        long sequence,
        DateTimeOffset capturedAt,
        double latitudeDegrees,
        double longitudeDegrees,
        double altitudeFeet,
        double groundSpeedKnots,
        double indicatedAirspeedKnots,
        double headingDegrees,
        double verticalSpeedFeetPerMinute,
        bool onGround)
    {
        if (sequence < 0
            || capturedAt.Offset != TimeSpan.Zero
            || !IsInRange(latitudeDegrees, -90, 90)
            || !IsInRange(longitudeDegrees, -180, 180)
            || !IsInRange(altitudeFeet, -2_000, 100_000)
            || !IsInRange(groundSpeedKnots, 0, 2_000)
            || !IsInRange(indicatedAirspeedKnots, 0, 1_500)
            || !IsInRange(headingDegrees, 0, 360)
            || !IsInRange(verticalSpeedFeetPerMinute, -20_000, 20_000))
        {
            throw new ArgumentOutOfRangeException(nameof(sequence), "Flight sample is outside the supported domain.");
        }

        return new FlightSample(
            sequence,
            capturedAt,
            latitudeDegrees,
            longitudeDegrees,
            altitudeFeet,
            groundSpeedKnots,
            indicatedAirspeedKnots,
            headingDegrees,
            verticalSpeedFeetPerMinute,
            onGround);
    }

    private static bool IsInRange(double value, double minimum, double maximum) =>
        double.IsFinite(value) && value >= minimum && value <= maximum;
}
