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
        var sample = new FlightSample(
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

        if (!sample.IsWithinDomain())
        {
            throw new ArgumentOutOfRangeException(nameof(sequence), "Flight sample is outside the supported domain.");
        }

        return sample;
    }

    public bool IsWithinDomain() =>
        Sequence >= 0
        && CapturedAt.Offset == TimeSpan.Zero
        && IsInRange(LatitudeDegrees, -90, 90)
        && IsInRange(LongitudeDegrees, -180, 180)
        && IsInRange(AltitudeFeet, -2_000, 100_000)
        && IsInRange(GroundSpeedKnots, 0, 2_000)
        && IsInRange(IndicatedAirspeedKnots, 0, 1_500)
        && IsInRange(HeadingDegrees, 0, 360)
        && IsInRange(VerticalSpeedFeetPerMinute, -20_000, 20_000);

    private static bool IsInRange(double value, double minimum, double maximum) =>
        double.IsFinite(value) && value >= minimum && value <= maximum;
}
