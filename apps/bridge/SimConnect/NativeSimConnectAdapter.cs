using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading.Channels;

namespace Thrustline.Bridge.SimConnect;

public sealed class NativeSimConnectAdapter : ISimConnectAdapter
{
    private readonly CancellationTokenSource _disposeCancellation = new();
    private Task? _pumpTask;
    private int _started;

    public async IAsyncEnumerable<FlightSample> ReadAllAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        if (Interlocked.Exchange(ref _started, 1) != 0)
        {
            throw new InvalidOperationException("The SimConnect adapter can only be read once.");
        }

        using var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken,
            _disposeCancellation.Token);
        var channel = Channel.CreateBounded<FlightSample>(
            new BoundedChannelOptions(16)
            {
                FullMode = BoundedChannelFullMode.DropOldest,
                SingleReader = true,
                SingleWriter = true,
            });

        _pumpTask = Task.Factory.StartNew(
            () => RunPump(channel.Writer, linkedCancellation.Token),
            CancellationToken.None,
            TaskCreationOptions.LongRunning,
            TaskScheduler.Default);

        await foreach (var sample in channel.Reader.ReadAllAsync(cancellationToken))
        {
            yield return sample;
        }
    }

    public async ValueTask DisposeAsync()
    {
        await _disposeCancellation.CancelAsync().ConfigureAwait(false);
        if (_pumpTask is not null)
        {
            try
            {
                await _pumpTask.ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
            }
        }

        _disposeCancellation.Dispose();
    }

    private static void RunPump(
        ChannelWriter<FlightSample> writer,
        CancellationToken cancellationToken)
    {
        Exception? failure = null;
        try
        {
            if (!OperatingSystem.IsWindows())
            {
                throw new PlatformNotSupportedException("SimConnect requires Windows 11.");
            }

            using var api = SimConnectNativeApi.Load();
            using var messageEvent = new EventWaitHandle(false, EventResetMode.AutoReset);
            api.Open(messageEvent);
            try
            {
                api.ConfigureFlightData();
                var sequence = 0L;
                var disconnected = false;
                api.RequestFlightData();

                while (!cancellationToken.IsCancellationRequested && !disconnected)
                {
                    var signal = WaitHandle.WaitAny([messageEvent, cancellationToken.WaitHandle]);
                    if (signal == 1)
                    {
                        break;
                    }

                    api.Dispatch(
                        sample => writer.TryWrite(sample with { Sequence = sequence++ }),
                        () => disconnected = true);
                }

                cancellationToken.ThrowIfCancellationRequested();
                if (disconnected)
                {
                    throw new InvalidOperationException("MSFS closed the SimConnect connection.");
                }
            }
            finally
            {
                api.Close();
            }
        }
        catch (Exception exception)
        {
            failure = exception;
        }
        finally
        {
            writer.TryComplete(failure);
        }
    }

    private sealed class SimConnectNativeApi : IDisposable
    {
        private const string LibraryName = "SimConnect.dll";
        private const uint FlightDataDefinition = 1;
        private const uint FlightDataRequest = 1;
        private const uint UserAircraft = 0;
        private const uint PeriodSecond = 4;
        private const uint Float64DataType = 4;
        private const uint ReceiveIdQuit = 3;
        private const uint ReceiveIdSimObjectData = 8;
        private const int ReceiveRequestIdOffset = 12;
        private const int ReceiveDefineCountOffset = 36;
        private const int ReceiveDataOffset = 40;
        private const int FlightDataValueCount = 8;

        private readonly nint _library;
        private readonly OpenDelegate _open;
        private readonly CloseDelegate _close;
        private readonly AddToDataDefinitionDelegate _addToDataDefinition;
        private readonly RequestDataDelegate _requestData;
        private readonly CallDispatchDelegate _callDispatch;
        private nint _connection;
        private DispatchDelegate? _dispatchCallback;
        private Action<FlightSample>? _onSample;
        private Action? _onDisconnected;
        private Exception? _dispatchFailure;

        private SimConnectNativeApi(nint library)
        {
            _library = library;
            _open = GetExport<OpenDelegate>("SimConnect_Open");
            _close = GetExport<CloseDelegate>("SimConnect_Close");
            _addToDataDefinition = GetExport<AddToDataDefinitionDelegate>(
                "SimConnect_AddToDataDefinition");
            _requestData = GetExport<RequestDataDelegate>("SimConnect_RequestDataOnSimObject");
            _callDispatch = GetExport<CallDispatchDelegate>("SimConnect_CallDispatch");
        }

        public static SimConnectNativeApi Load()
        {
            if (!NativeLibrary.TryLoad(
                    LibraryName,
                    typeof(NativeSimConnectAdapter).Assembly,
                    DllImportSearchPath.SafeDirectories,
                    out var library))
            {
                throw new DllNotFoundException(
                    "SimConnect is unavailable. Install and start a supported MSFS 2024 build.");
            }

            try
            {
                return new SimConnectNativeApi(library);
            }
            catch
            {
                NativeLibrary.Free(library);
                throw;
            }
        }

        public void Open(EventWaitHandle messageEvent)
        {
            var result = _open(
                out _connection,
                "ThrustlineNG",
                nint.Zero,
                0,
                messageEvent.SafeWaitHandle.DangerousGetHandle(),
                0);
            ThrowIfFailed(result, "Unable to connect to MSFS 2024.");
        }

        public void ConfigureFlightData()
        {
            AddDefinition("PLANE LATITUDE", "degrees");
            AddDefinition("PLANE LONGITUDE", "degrees");
            AddDefinition("PLANE ALTITUDE", "feet");
            AddDefinition("GROUND VELOCITY", "knots");
            AddDefinition("AIRSPEED INDICATED", "knots");
            AddDefinition("PLANE HEADING DEGREES TRUE", "degrees");
            AddDefinition("VERTICAL SPEED", "feet per minute");
            AddDefinition("SIM ON GROUND", "bool");
        }

        public void RequestFlightData()
        {
            var result = _requestData(
                _connection,
                FlightDataRequest,
                FlightDataDefinition,
                UserAircraft,
                PeriodSecond,
                0,
                0,
                0,
                0);
            ThrowIfFailed(result, "Unable to request flight data.");
        }

        public void Dispatch(Action<FlightSample> onSample, Action onDisconnected)
        {
            _onSample = onSample;
            _onDisconnected = onDisconnected;
            _dispatchFailure = null;
            _dispatchCallback ??= ReceiveDispatch;
            var result = _callDispatch(_connection, _dispatchCallback, nint.Zero);
            ThrowIfFailed(result, "Unable to receive flight data.");
            if (_dispatchFailure is not null)
            {
                throw new InvalidOperationException("MSFS returned invalid flight data.", _dispatchFailure);
            }
        }

        public void Close()
        {
            if (_connection == nint.Zero)
            {
                return;
            }

            _ = _close(_connection);
            _connection = nint.Zero;
        }

        public void Dispose()
        {
            Close();
            NativeLibrary.Free(_library);
        }

        private void AddDefinition(string name, string units)
        {
            var result = _addToDataDefinition(
                _connection,
                FlightDataDefinition,
                name,
                units,
                Float64DataType,
                0,
                uint.MaxValue);
            ThrowIfFailed(result, "Unable to define flight data.");
        }

        private void ReceiveDispatch(nint data, uint dataSize, nint context)
        {
            _ = context;
            if (data == nint.Zero || dataSize < 12)
            {
                return;
            }

            var receiveId = unchecked((uint)Marshal.ReadInt32(data, 8));
            if (receiveId == ReceiveIdQuit)
            {
                _onDisconnected?.Invoke();
                return;
            }

            if (receiveId != ReceiveIdSimObjectData
                || dataSize < ReceiveDataOffset + (FlightDataValueCount * sizeof(double))
                || unchecked((uint)Marshal.ReadInt32(data, ReceiveRequestIdOffset)) != FlightDataRequest
                || Marshal.ReadInt32(data, ReceiveDefineCountOffset) != FlightDataValueCount)
            {
                return;
            }

            Span<double> values = stackalloc double[FlightDataValueCount];
            for (var index = 0; index < values.Length; index++)
            {
                values[index] = BitConverter.Int64BitsToDouble(
                    Marshal.ReadInt64(data, ReceiveDataOffset + (index * sizeof(double))));
            }

            try
            {
                var sample = FlightSample.Create(
                    0,
                    DateTimeOffset.UtcNow,
                    values[0],
                    values[1],
                    values[2],
                    values[3],
                    values[4],
                    values[5],
                    values[6],
                    values[7] != 0);
                _onSample?.Invoke(sample);
            }
            catch (Exception exception)
            {
                _dispatchFailure = exception;
            }
        }

        private T GetExport<T>(string name)
            where T : Delegate =>
            Marshal.GetDelegateForFunctionPointer<T>(NativeLibrary.GetExport(_library, name));

        private static void ThrowIfFailed(int result, string message)
        {
            if (result < 0)
            {
                throw new InvalidOperationException(message);
            }
        }

        [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private delegate int OpenDelegate(
            out nint connection,
            [MarshalAs(UnmanagedType.LPStr)] string name,
            nint windowHandle,
            uint userEvent,
            nint eventHandle,
            uint configIndex);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int CloseDelegate(nint connection);

        [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private delegate int AddToDataDefinitionDelegate(
            nint connection,
            uint definitionId,
            [MarshalAs(UnmanagedType.LPStr)] string datumName,
            [MarshalAs(UnmanagedType.LPStr)] string unitsName,
            uint dataType,
            float epsilon,
            uint datumId);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int RequestDataDelegate(
            nint connection,
            uint requestId,
            uint definitionId,
            uint objectId,
            uint period,
            uint flags,
            uint origin,
            uint interval,
            uint limit);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate int CallDispatchDelegate(
            nint connection,
            DispatchDelegate callback,
            nint context);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        private delegate void DispatchDelegate(nint data, uint dataSize, nint context);
    }
}
