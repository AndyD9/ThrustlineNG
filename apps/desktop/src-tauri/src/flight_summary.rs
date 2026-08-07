use std::{
    io::{self, Read, Write},
    net::{Ipv4Addr, SocketAddr, TcpStream},
    time::Duration,
};

use serde::Serialize;

const SUMMARY_PATH: &str = "/api/v1/flight-summary";
const REARM_PATH: &str = "/api/v1/flight-summary/rearm";
const TOKEN_HEADER: &str = "X-Thrustline-Instance";
const CONTRACT_VERSION: &str = "1";
const RESPONSE_LIMIT_BYTES: usize = 16 * 1024;
const CONNECT_TIMEOUT: Duration = Duration::from_secs(1);
const IO_TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum FlightSummaryState {
    Idle,
    Running,
    Completed,
    Incomplete,
}

/// What the bridge reports on its local contract. The generation is a local
/// integer that never crosses the WebView boundary: it only serves the
/// in-process attachment kept by the supervisor.
#[derive(Debug, PartialEq)]
pub(crate) struct BridgeSummaryReading {
    pub(crate) state: FlightSummaryState,
    pub(crate) block_minutes: Option<u32>,
    pub(crate) generation: u64,
}

/// The only summary shape that crosses the WebView boundary: four closed
/// keys — never the token, the port, the generation nor any trace path.
#[derive(Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FlightSummary {
    contract_version: &'static str,
    state: FlightSummaryState,
    block_minutes: Option<u32>,
    attached_dispatch_id: Option<String>,
}

impl FlightSummary {
    pub(crate) fn from_reading(
        reading: BridgeSummaryReading,
        attached_dispatch_id: Option<String>,
    ) -> Self {
        Self {
            contract_version: CONTRACT_VERSION,
            state: reading.state,
            block_minutes: reading.block_minutes,
            attached_dispatch_id,
        }
    }
}

/// The only armed shape that crosses the WebView boundary.
#[derive(Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ArmedFlightSummary {
    contract_version: &'static str,
    dispatch_id: String,
}

impl ArmedFlightSummary {
    pub(crate) fn new(dispatch_id: String) -> Self {
        Self {
            contract_version: CONTRACT_VERSION,
            dispatch_id,
        }
    }
}

/// Closed failure categories: no dynamic content can leak through an error.
#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum FlightSummaryFailure {
    Unavailable,
    InvalidResponse,
    Rejected,
}

pub(crate) fn read(port: u16, token: &str) -> Result<BridgeSummaryReading, FlightSummaryFailure> {
    let raw =
        request(port, token, "GET", SUMMARY_PATH).map_err(|_| FlightSummaryFailure::Unavailable)?;
    let body = successful_body(&raw)?;
    validate(body)
}

/// Opens a fresh measurement session on the bridge and returns its new
/// generation. A bridge refusing mid-measure reads as `Rejected`.
pub(crate) fn rearm(port: u16, token: &str) -> Result<u64, FlightSummaryFailure> {
    let raw =
        request(port, token, "POST", REARM_PATH).map_err(|_| FlightSummaryFailure::Unavailable)?;
    let body = match successful_body(&raw) {
        Ok(body) => body,
        Err(FlightSummaryFailure::Unavailable) if status_code(&raw) == Some(409) => {
            return Err(FlightSummaryFailure::Rejected);
        }
        Err(failure) => return Err(failure),
    };
    validate_rearm(body)
}

fn request(port: u16, token: &str, method: &str, path: &str) -> io::Result<Vec<u8>> {
    let address = SocketAddr::from((Ipv4Addr::LOCALHOST, port));
    let mut stream = TcpStream::connect_timeout(&address, CONNECT_TIMEOUT)?;
    stream.set_read_timeout(Some(IO_TIMEOUT))?;
    stream.set_write_timeout(Some(IO_TIMEOUT))?;

    // HTTP/1.0 keeps the exchange close-delimited: no keep-alive, no chunking.
    write!(
        stream,
        "{method} {path} HTTP/1.0\r\nHost: 127.0.0.1:{port}\r\nAccept: application/json\r\nContent-Length: 0\r\n{TOKEN_HEADER}: {token}\r\nConnection: close\r\n\r\n"
    )?;
    stream.flush()?;

    let mut raw = Vec::new();
    let mut chunk = [0_u8; 2_048];
    loop {
        let count = stream.read(&mut chunk)?;
        if count == 0 {
            return Ok(raw);
        }
        if raw.len() + count > RESPONSE_LIMIT_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "bridge response exceeds the size limit",
            ));
        }
        raw.extend_from_slice(&chunk[..count]);
    }
}

fn status_code(raw: &[u8]) -> Option<u16> {
    let head_end = raw.windows(4).position(|window| window == b"\r\n\r\n")?;
    let head = str::from_utf8(&raw[..head_end]).ok()?;
    let status_line = head.lines().next()?;
    let mut parts = status_line.split_ascii_whitespace();
    let version = parts.next()?;
    if !version.starts_with("HTTP/1.") {
        return None;
    }
    parts.next()?.parse().ok()
}

fn successful_body(raw: &[u8]) -> Result<&[u8], FlightSummaryFailure> {
    let head_end = raw
        .windows(4)
        .position(|window| window == b"\r\n\r\n")
        .ok_or(FlightSummaryFailure::InvalidResponse)?;
    match status_code(raw) {
        Some(200) => Ok(&raw[head_end + 4..]),
        Some(_) => Err(FlightSummaryFailure::Unavailable),
        None => Err(FlightSummaryFailure::InvalidResponse),
    }
}

fn validate(body: &[u8]) -> Result<BridgeSummaryReading, FlightSummaryFailure> {
    let value: serde_json::Value =
        serde_json::from_slice(body).map_err(|_| FlightSummaryFailure::InvalidResponse)?;
    let object = value
        .as_object()
        .ok_or(FlightSummaryFailure::InvalidResponse)?;

    let mut keys: Vec<&str> = object.keys().map(String::as_str).collect();
    keys.sort_unstable();
    if keys != ["blockMinutes", "contractVersion", "generation", "state"] {
        return Err(FlightSummaryFailure::InvalidResponse);
    }
    if object
        .get("contractVersion")
        .and_then(|entry| entry.as_str())
        != Some(CONTRACT_VERSION)
    {
        return Err(FlightSummaryFailure::InvalidResponse);
    }

    let state = match object.get("state").and_then(|entry| entry.as_str()) {
        Some("idle") => FlightSummaryState::Idle,
        Some("running") => FlightSummaryState::Running,
        Some("completed") => FlightSummaryState::Completed,
        Some("incomplete") => FlightSummaryState::Incomplete,
        _ => return Err(FlightSummaryFailure::InvalidResponse),
    };

    let block_minutes = match object.get("blockMinutes") {
        Some(serde_json::Value::Null) => None,
        Some(entry) => Some(
            entry
                .as_u64()
                .filter(|&minutes| (1..=i32::MAX as u64).contains(&minutes))
                .ok_or(FlightSummaryFailure::InvalidResponse)? as u32,
        ),
        None => return Err(FlightSummaryFailure::InvalidResponse),
    };

    let generation = parse_generation(object.get("generation"))?;

    // J1 semantics are closed: only a completed trace carries a block time.
    let coherent = match state {
        FlightSummaryState::Completed => block_minutes.is_some(),
        _ => block_minutes.is_none(),
    };
    if !coherent {
        return Err(FlightSummaryFailure::InvalidResponse);
    }

    Ok(BridgeSummaryReading {
        state,
        block_minutes,
        generation,
    })
}

fn validate_rearm(body: &[u8]) -> Result<u64, FlightSummaryFailure> {
    let value: serde_json::Value =
        serde_json::from_slice(body).map_err(|_| FlightSummaryFailure::InvalidResponse)?;
    let object = value
        .as_object()
        .ok_or(FlightSummaryFailure::InvalidResponse)?;

    let mut keys: Vec<&str> = object.keys().map(String::as_str).collect();
    keys.sort_unstable();
    if keys != ["contractVersion", "generation"] {
        return Err(FlightSummaryFailure::InvalidResponse);
    }
    if object
        .get("contractVersion")
        .and_then(|entry| entry.as_str())
        != Some(CONTRACT_VERSION)
    {
        return Err(FlightSummaryFailure::InvalidResponse);
    }

    parse_generation(object.get("generation"))
}

fn parse_generation(entry: Option<&serde_json::Value>) -> Result<u64, FlightSummaryFailure> {
    entry
        .and_then(|value| value.as_u64())
        .filter(|&generation| generation >= 1)
        .ok_or(FlightSummaryFailure::InvalidResponse)
}

/// A canonical lowercase UUID, the only dispatch identity accepted from the
/// WebView before anything reaches the bridge supervisor state.
pub(crate) fn is_canonical_dispatch_id(candidate: &str) -> bool {
    let bytes = candidate.as_bytes();
    if bytes.len() != 36 {
        return false;
    }
    bytes.iter().enumerate().all(|(index, &byte)| {
        if matches!(index, 8 | 13 | 18 | 23) {
            byte == b'-'
        } else {
            byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)
        }
    })
}

#[cfg(test)]
mod tests {
    use std::{
        io::{Read, Write},
        net::TcpListener,
        thread,
    };

    use super::{
        ArmedFlightSummary, BridgeSummaryReading, FlightSummary, FlightSummaryFailure,
        FlightSummaryState, is_canonical_dispatch_id, read, rearm, successful_body, validate,
        validate_rearm,
    };

    fn reading(
        state: FlightSummaryState,
        block_minutes: Option<u32>,
        generation: u64,
    ) -> BridgeSummaryReading {
        BridgeSummaryReading {
            state,
            block_minutes,
            generation,
        }
    }

    #[test]
    fn a_completed_summary_is_accepted_with_its_generation() {
        let body =
            br#"{"contractVersion":"1","state":"completed","blockMinutes":42,"generation":3}"#;
        assert_eq!(
            validate(body),
            Ok(reading(FlightSummaryState::Completed, Some(42), 3))
        );
    }

    #[test]
    fn every_non_completed_state_requires_a_null_block_time() {
        for state in ["idle", "running", "incomplete"] {
            let body = format!(
                r#"{{"contractVersion":"1","state":"{state}","blockMinutes":null,"generation":1}}"#
            );
            assert!(validate(body.as_bytes()).is_ok(), "state {state}");
            let body = format!(
                r#"{{"contractVersion":"1","state":"{state}","blockMinutes":5,"generation":1}}"#
            );
            assert_eq!(
                validate(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "state {state} must not carry a block time"
            );
        }
    }

    #[test]
    fn a_completed_summary_without_block_time_is_rejected() {
        let body =
            br#"{"contractVersion":"1","state":"completed","blockMinutes":null,"generation":1}"#;
        assert_eq!(validate(body), Err(FlightSummaryFailure::InvalidResponse));
    }

    #[test]
    fn unknown_missing_or_legacy_keys_are_rejected() {
        for body in [
            // The F0004 shape without a generation is no longer acceptable.
            r#"{"contractVersion":"1","state":"idle","blockMinutes":null}"#,
            r#"{"contractVersion":"1","state":"idle","blockMinutes":null,"generation":1,"tracePath":"C:\\x"}"#,
            r#"{"contractVersion":"1","state":"idle","generation":1}"#,
            r#"{"contractVersion":"1","state":"idle","blockMinutes":null,"generation":1,"token":"a"}"#,
            r#"[]"#,
            r#""idle""#,
        ] {
            assert_eq!(
                validate(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "body {body}"
            );
        }
    }

    #[test]
    fn foreign_contract_versions_are_rejected() {
        let body = br#"{"contractVersion":"2","state":"idle","blockMinutes":null,"generation":1}"#;
        assert_eq!(validate(body), Err(FlightSummaryFailure::InvalidResponse));
    }

    #[test]
    fn out_of_range_block_times_are_rejected() {
        for minutes in ["0", "-1", "1.5", "2147483648", r#""1""#] {
            let body = format!(
                r#"{{"contractVersion":"1","state":"completed","blockMinutes":{minutes},"generation":1}}"#
            );
            assert_eq!(
                validate(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "minutes {minutes}"
            );
        }
    }

    #[test]
    fn out_of_range_generations_are_rejected() {
        for generation in ["0", "-1", "1.5", r#""1""#, "null"] {
            let body = format!(
                r#"{{"contractVersion":"1","state":"idle","blockMinutes":null,"generation":{generation}}}"#
            );
            assert_eq!(
                validate(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "generation {generation}"
            );
        }
    }

    #[test]
    fn a_rearm_acknowledgement_is_validated_strictly() {
        assert_eq!(
            validate_rearm(br#"{"contractVersion":"1","generation":2}"#),
            Ok(2)
        );
        for body in [
            r#"{"contractVersion":"1"}"#,
            r#"{"contractVersion":"1","generation":0}"#,
            r#"{"contractVersion":"2","generation":2}"#,
            r#"{"contractVersion":"1","generation":2,"token":"a"}"#,
            r#"[]"#,
        ] {
            assert_eq!(
                validate_rearm(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "body {body}"
            );
        }
    }

    #[test]
    fn canonical_dispatch_identifiers_are_the_only_accepted_shape() {
        assert!(is_canonical_dispatch_id(
            "94abcdef-0000-4000-8000-000000000004"
        ));
        for candidate in [
            "",
            "not-a-uuid",
            "94ABCDEF-0000-4000-8000-000000000004",
            "94abcdef-0000-4000-8000-00000000000",
            "94abcdef-0000-4000-8000-0000000000045",
            "94abcdef+0000-4000-8000-000000000004",
            " 94abcdef-0000-4000-8000-000000000004",
        ] {
            assert!(
                !is_canonical_dispatch_id(candidate),
                "candidate {candidate}"
            );
        }
    }

    #[test]
    fn a_non_200_status_reads_as_unavailable() {
        let raw = b"HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\n\r\n";
        assert_eq!(
            successful_body(raw).unwrap_err(),
            FlightSummaryFailure::Unavailable
        );
    }

    #[test]
    fn a_malformed_response_reads_as_invalid() {
        assert_eq!(
            successful_body(b"not http at all"),
            Err(FlightSummaryFailure::InvalidResponse)
        );
    }

    #[test]
    fn a_closed_port_reads_as_unavailable() {
        let port = {
            let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
            listener.local_addr().expect("address").port()
        };
        assert_eq!(read(port, "token"), Err(FlightSummaryFailure::Unavailable));
        assert_eq!(rearm(port, "token"), Err(FlightSummaryFailure::Unavailable));
    }

    fn serve_once(response: &'static str) -> (u16, thread::JoinHandle<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
        let port = listener.local_addr().expect("address").port();
        let handle = thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("accept");
            let mut received = Vec::new();
            let mut chunk = [0_u8; 1_024];
            while !received.windows(4).any(|window| window == b"\r\n\r\n") {
                let count = stream.read(&mut chunk).expect("read request");
                received.extend_from_slice(&chunk[..count]);
            }
            stream.write_all(response.as_bytes()).expect("write");
            String::from_utf8(received).expect("utf8 request")
        });
        (port, handle)
    }

    #[test]
    fn the_token_authenticates_the_request_but_never_crosses_into_the_result() {
        let token = "feedfacefeedfacefeedfacefeedfacefeedfacefeedfacefeedfacefeedface";
        let (port, handle) = serve_once(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"contractVersion\":\"1\",\"state\":\"completed\",\"blockMinutes\":7,\"generation\":2}",
        );

        let reading = read(port, token).expect("summary");
        let request = handle.join().expect("request");

        assert!(request.contains(&format!("X-Thrustline-Instance: {token}")));
        let crossing = serde_json::to_string(&FlightSummary::from_reading(
            reading,
            Some("94abcdef-0000-4000-8000-000000000004".to_owned()),
        ))
        .expect("serialize");
        assert_eq!(
            crossing,
            r#"{"contractVersion":"1","state":"completed","blockMinutes":7,"attachedDispatchId":"94abcdef-0000-4000-8000-000000000004"}"#
        );
        assert!(!crossing.contains(token));
        assert!(!crossing.contains(&port.to_string()));
        assert!(!crossing.contains("generation"));
    }

    #[test]
    fn a_rearm_refusal_reads_as_rejected() {
        let (port, handle) = serve_once(
            "HTTP/1.1 409 Conflict\r\nContent-Type: application/json\r\n\r\n{\"contractVersion\":\"1\",\"generation\":1}",
        );
        assert_eq!(rearm(port, "token"), Err(FlightSummaryFailure::Rejected));
        let request = handle.join().expect("request");
        assert!(request.starts_with("POST /api/v1/flight-summary/rearm HTTP/1.0"));
    }

    #[test]
    fn a_rearm_acknowledgement_carries_the_new_generation() {
        let (port, handle) = serve_once(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"contractVersion\":\"1\",\"generation\":5}",
        );
        assert_eq!(rearm(port, "token"), Ok(5));
        handle.join().expect("request");
    }

    #[test]
    fn a_forged_summary_with_extra_keys_never_crosses() {
        let (port, handle) = serve_once(
            "HTTP/1.1 200 OK\r\n\r\n{\"contractVersion\":\"1\",\"state\":\"completed\",\"blockMinutes\":7,\"generation\":1,\"tracePath\":\"C:\\\\trace.json\"}",
        );
        assert_eq!(
            read(port, "token"),
            Err(FlightSummaryFailure::InvalidResponse)
        );
        handle.join().expect("request");
    }

    #[test]
    fn armed_acknowledgements_expose_only_the_dispatch_identity() {
        let armed = ArmedFlightSummary::new("94abcdef-0000-4000-8000-000000000004".to_owned());
        assert_eq!(
            serde_json::to_string(&armed).expect("serialize"),
            r#"{"contractVersion":"1","dispatchId":"94abcdef-0000-4000-8000-000000000004"}"#
        );
    }

    #[test]
    fn failures_serialize_to_fixed_categories_only() {
        assert_eq!(
            serde_json::to_string(&FlightSummaryFailure::Unavailable).expect("serialize"),
            r#""unavailable""#
        );
        assert_eq!(
            serde_json::to_string(&FlightSummaryFailure::InvalidResponse).expect("serialize"),
            r#""invalid-response""#
        );
        assert_eq!(
            serde_json::to_string(&FlightSummaryFailure::Rejected).expect("serialize"),
            r#""rejected""#
        );
    }
}
