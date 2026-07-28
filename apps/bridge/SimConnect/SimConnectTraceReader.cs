using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Thrustline.Bridge.SimConnect;

public static class SimConnectTraceReader
{
    public const string Format = "thrustline.simconnect.trace";
    public const int SchemaVersion = 1;
    public const int MaximumLineBytes = 16_384;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = false,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public static async IAsyncEnumerable<TraceSample> ReadAllAsync(
        Stream stream,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(stream);

        using var reader = new StreamReader(
            stream,
            new UTF8Encoding(false, true),
            detectEncodingFromByteOrderMarks: false,
            bufferSize: 4096,
            leaveOpen: true);

        var headerLine = await ReadBoundedLineAsync(reader, cancellationToken).ConfigureAwait(false);
        var header = Deserialize<TraceHeader>(headerLine, 1);
        if (header.Format != Format || header.SchemaVersion != SchemaVersion || header.Source != "synthetic")
        {
            throw new InvalidDataException("Trace header is not supported.");
        }

        long previousOffset = -1;
        var lineNumber = 1;
        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var line = await ReadBoundedLineAsync(reader, cancellationToken).ConfigureAwait(false);
            if (line is null)
            {
                yield break;
            }

            lineNumber++;
            var sample = Deserialize<TraceSample>(line, lineNumber);
            if (sample.OffsetMilliseconds < 0 || sample.OffsetMilliseconds <= previousOffset)
            {
                throw new InvalidDataException($"Trace line {lineNumber} has a non-monotonic offset.");
            }

            _ = sample.ToFlightSample(lineNumber - 2, DateTimeOffset.UnixEpoch);
            previousOffset = sample.OffsetMilliseconds;
            yield return sample;
        }
    }

    private static async Task<string?> ReadBoundedLineAsync(
        StreamReader reader,
        CancellationToken cancellationToken)
    {
        var builder = new StringBuilder();
        var buffer = new char[1];
        while (true)
        {
            var count = await reader.ReadAsync(buffer, cancellationToken).ConfigureAwait(false);
            if (count == 0)
            {
                return builder.Length == 0 ? null : builder.ToString();
            }

            if (buffer[0] == '\n')
            {
                return builder.ToString().TrimEnd('\r');
            }

            builder.Append(buffer[0]);
            if (Encoding.UTF8.GetByteCount(builder.ToString()) > MaximumLineBytes)
            {
                throw new InvalidDataException("Trace line exceeds the size limit.");
            }
        }
    }

    private static T Deserialize<T>(string? line, int lineNumber)
    {
        if (string.IsNullOrWhiteSpace(line))
        {
            throw new InvalidDataException($"Trace line {lineNumber} is empty.");
        }

        try
        {
            return JsonSerializer.Deserialize<T>(line, JsonOptions)
                ?? throw new InvalidDataException($"Trace line {lineNumber} is invalid.");
        }
        catch (JsonException exception)
        {
            throw new InvalidDataException($"Trace line {lineNumber} is invalid.", exception);
        }
    }

    private sealed record TraceHeader(string Format, int SchemaVersion, string Source);
}

public sealed record TraceSample(
    long OffsetMilliseconds,
    double LatitudeDegrees,
    double LongitudeDegrees,
    double AltitudeFeet,
    double GroundSpeedKnots,
    double IndicatedAirspeedKnots,
    double HeadingDegrees,
    double VerticalSpeedFeetPerMinute,
    bool OnGround)
{
    public FlightSample ToFlightSample(long sequence, DateTimeOffset origin) =>
        FlightSample.Create(
            sequence,
            origin.AddMilliseconds(OffsetMilliseconds),
            LatitudeDegrees,
            LongitudeDegrees,
            AltitudeFeet,
            GroundSpeedKnots,
            IndicatedAirspeedKnots,
            HeadingDegrees,
            VerticalSpeedFeetPerMinute,
            OnGround);
}
