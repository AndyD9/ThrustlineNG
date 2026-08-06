use std::{
    io::{self, Read, Write},
    net::{Ipv4Addr, SocketAddr, TcpStream},
    time::Duration,
};

use serde::Serialize;

const SUMMARY_PATH: &str = "/api/v1/flight-summary";
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

/// The only shape that crosses the WebView boundary: three closed keys,
/// never the token, the port nor any trace path.
#[derive(Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FlightSummary {
    contract_version: &'static str,
    state: FlightSummaryState,
    block_minutes: Option<u32>,
}

/// Closed failure categories: no dynamic content can leak through an error.
#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum FlightSummaryFailure {
    Unavailable,
    InvalidResponse,
}

pub(crate) fn read(port: u16, token: &str) -> Result<FlightSummary, FlightSummaryFailure> {
    let raw = request(port, token).map_err(|_| FlightSummaryFailure::Unavailable)?;
    let body = successful_body(&raw)?;
    validate(body)
}

fn request(port: u16, token: &str) -> io::Result<Vec<u8>> {
    let address = SocketAddr::from((Ipv4Addr::LOCALHOST, port));
    let mut stream = TcpStream::connect_timeout(&address, CONNECT_TIMEOUT)?;
    stream.set_read_timeout(Some(IO_TIMEOUT))?;
    stream.set_write_timeout(Some(IO_TIMEOUT))?;

    // HTTP/1.0 keeps the exchange close-delimited: no keep-alive, no chunking.
    write!(
        stream,
        "GET {SUMMARY_PATH} HTTP/1.0\r\nHost: 127.0.0.1:{port}\r\nAccept: application/json\r\n{TOKEN_HEADER}: {token}\r\nConnection: close\r\n\r\n"
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

fn successful_body(raw: &[u8]) -> Result<&[u8], FlightSummaryFailure> {
    let head_end = raw
        .windows(4)
        .position(|window| window == b"\r\n\r\n")
        .ok_or(FlightSummaryFailure::InvalidResponse)?;
    let head =
        str::from_utf8(&raw[..head_end]).map_err(|_| FlightSummaryFailure::InvalidResponse)?;
    let status_line = head
        .lines()
        .next()
        .ok_or(FlightSummaryFailure::InvalidResponse)?;
    let mut parts = status_line.split_ascii_whitespace();
    let version = parts.next().ok_or(FlightSummaryFailure::InvalidResponse)?;
    let status = parts.next().ok_or(FlightSummaryFailure::InvalidResponse)?;
    if !version.starts_with("HTTP/1.") {
        return Err(FlightSummaryFailure::InvalidResponse);
    }
    if status != "200" {
        return Err(FlightSummaryFailure::Unavailable);
    }
    Ok(&raw[head_end + 4..])
}

fn validate(body: &[u8]) -> Result<FlightSummary, FlightSummaryFailure> {
    let value: serde_json::Value =
        serde_json::from_slice(body).map_err(|_| FlightSummaryFailure::InvalidResponse)?;
    let object = value
        .as_object()
        .ok_or(FlightSummaryFailure::InvalidResponse)?;

    let mut keys: Vec<&str> = object.keys().map(String::as_str).collect();
    keys.sort_unstable();
    if keys != ["blockMinutes", "contractVersion", "state"] {
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

    // J1 semantics are closed: only a completed trace carries a block time.
    let coherent = match state {
        FlightSummaryState::Completed => block_minutes.is_some(),
        _ => block_minutes.is_none(),
    };
    if !coherent {
        return Err(FlightSummaryFailure::InvalidResponse);
    }

    Ok(FlightSummary {
        contract_version: CONTRACT_VERSION,
        state,
        block_minutes,
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
        FlightSummary, FlightSummaryFailure, FlightSummaryState, read, successful_body, validate,
    };

    fn summary(state: FlightSummaryState, block_minutes: Option<u32>) -> FlightSummary {
        FlightSummary {
            contract_version: "1",
            state,
            block_minutes,
        }
    }

    #[test]
    fn a_completed_summary_is_accepted() {
        let body = br#"{"contractVersion":"1","state":"completed","blockMinutes":42}"#;
        assert_eq!(
            validate(body),
            Ok(summary(FlightSummaryState::Completed, Some(42)))
        );
    }

    #[test]
    fn every_non_completed_state_requires_a_null_block_time() {
        for state in ["idle", "running", "incomplete"] {
            let body =
                format!(r#"{{"contractVersion":"1","state":"{state}","blockMinutes":null}}"#);
            assert!(validate(body.as_bytes()).is_ok(), "state {state}");
            let body = format!(r#"{{"contractVersion":"1","state":"{state}","blockMinutes":5}}"#);
            assert_eq!(
                validate(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "state {state} must not carry a block time"
            );
        }
    }

    #[test]
    fn a_completed_summary_without_block_time_is_rejected() {
        let body = br#"{"contractVersion":"1","state":"completed","blockMinutes":null}"#;
        assert_eq!(validate(body), Err(FlightSummaryFailure::InvalidResponse));
    }

    #[test]
    fn unknown_or_missing_keys_are_rejected() {
        for body in [
            r#"{"contractVersion":"1","state":"idle","blockMinutes":null,"tracePath":"C:\\x"}"#,
            r#"{"contractVersion":"1","state":"idle"}"#,
            r#"{"contractVersion":"1","state":"idle","blockMinutes":null,"token":"a"}"#,
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
        let body = br#"{"contractVersion":"2","state":"idle","blockMinutes":null}"#;
        assert_eq!(validate(body), Err(FlightSummaryFailure::InvalidResponse));
    }

    #[test]
    fn out_of_range_block_times_are_rejected() {
        for minutes in ["0", "-1", "1.5", "2147483648", r#""1""#] {
            let body = format!(
                r#"{{"contractVersion":"1","state":"completed","blockMinutes":{minutes}}}"#
            );
            assert_eq!(
                validate(body.as_bytes()),
                Err(FlightSummaryFailure::InvalidResponse),
                "minutes {minutes}"
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
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"contractVersion\":\"1\",\"state\":\"completed\",\"blockMinutes\":7}",
        );

        let summary = read(port, token).expect("summary");
        let request = handle.join().expect("request");

        assert!(request.contains(&format!("X-Thrustline-Instance: {token}")));
        let crossing = serde_json::to_string(&summary).expect("serialize");
        assert_eq!(
            crossing,
            r#"{"contractVersion":"1","state":"completed","blockMinutes":7}"#
        );
        assert!(!crossing.contains(token));
        assert!(!crossing.contains(&port.to_string()));
    }

    #[test]
    fn a_forged_summary_with_extra_keys_never_crosses() {
        let (port, handle) = serve_once(
            "HTTP/1.1 200 OK\r\n\r\n{\"contractVersion\":\"1\",\"state\":\"completed\",\"blockMinutes\":7,\"tracePath\":\"C:\\\\trace.json\"}",
        );
        assert_eq!(
            read(port, "token"),
            Err(FlightSummaryFailure::InvalidResponse)
        );
        handle.join().expect("request");
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
    }
}
