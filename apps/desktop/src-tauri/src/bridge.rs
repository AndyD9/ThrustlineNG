use std::{
    io::{self, Write},
    net::{Ipv4Addr, TcpListener},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::Mutex,
};

use crate::flight_summary::{self, ArmedFlightSummary, FlightSummary, FlightSummaryFailure};

pub struct BridgeSupervisor {
    child: Mutex<Option<Child>>,
    // The local contract coordinates never leave this process: the WebView
    // only ever sees the validated summary returned by `read_flight_summary`.
    port: u16,
    token: String,
    // The measurement attachment: which dispatch the armed generation
    // measures. Kept in-process only — the bridge stays free of any business
    // identity, and the WebView never sees the generation itself.
    attachment: Mutex<Option<Attachment>>,
}

struct Attachment {
    dispatch_id: String,
    generation: u64,
}

impl BridgeSupervisor {
    pub fn start(resource_directory: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let port = reserve_loopback_port()?;
        let token = generate_instance_token()
            .map_err(|error| io::Error::other(format!("OS random source failed: {error}")))?;
        let executable = bridge_executable(resource_directory);
        let mut child = Command::new(executable)
            .args(["--port", &port.to_string()])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()?;
        let mut input = child
            .stdin
            .take()
            .ok_or_else(|| io::Error::other("bridge stdin pipe is unavailable"))?;
        input.write_all(token.as_bytes())?;
        input.write_all(b"\n")?;
        drop(input);

        Ok(Self {
            child: Mutex::new(Some(child)),
            port,
            token,
            attachment: Mutex::new(None),
        })
    }

    pub fn read_flight_summary(&self) -> Result<FlightSummary, FlightSummaryFailure> {
        let reading = flight_summary::read(self.port, &self.token)?;
        let attached_dispatch_id = self.attachment.lock().ok().and_then(|guard| {
            guard.as_ref().and_then(|attachment| {
                (attachment.generation == reading.generation)
                    .then(|| attachment.dispatch_id.clone())
            })
        });
        Ok(FlightSummary::from_reading(reading, attached_dispatch_id))
    }

    /// Arms a fresh measurement for one dispatch: the bridge is rearmed under
    /// a new generation, then the attachment is recorded in-process. The
    /// dispatch identifier is the only WebView input and is validated before
    /// anything else happens.
    pub fn arm_flight_summary(
        &self,
        dispatch_id: &str,
    ) -> Result<ArmedFlightSummary, FlightSummaryFailure> {
        if !flight_summary::is_canonical_dispatch_id(dispatch_id) {
            return Err(FlightSummaryFailure::Rejected);
        }

        let generation = flight_summary::rearm(self.port, &self.token)?;
        let Ok(mut guard) = self.attachment.lock() else {
            return Err(FlightSummaryFailure::Unavailable);
        };
        *guard = Some(Attachment {
            dispatch_id: dispatch_id.to_owned(),
            generation,
        });
        Ok(ArmedFlightSummary::new(dispatch_id.to_owned()))
    }

    pub fn stop(&self) {
        let Ok(mut guard) = self.child.lock() else {
            return;
        };
        if let Some(mut child) = guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

impl Drop for BridgeSupervisor {
    fn drop(&mut self) {
        self.stop();
    }
}

fn reserve_loopback_port() -> io::Result<u16> {
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0))?;
    let port = listener.local_addr()?.port();
    if port < 49152 {
        return Err(io::Error::new(
            io::ErrorKind::AddrNotAvailable,
            "Windows did not allocate a dynamic port",
        ));
    }
    Ok(port)
}

fn generate_instance_token() -> Result<String, getrandom::Error> {
    let mut bytes = [0_u8; 32];
    getrandom::fill(&mut bytes)?;
    Ok(bytes.iter().map(|byte| format!("{byte:02x}")).collect())
}

fn bridge_executable(resource_directory: &Path) -> PathBuf {
    #[cfg(debug_assertions)]
    if let Some(path) = std::env::var_os("THRUSTLINE_BRIDGE_PATH") {
        return PathBuf::from(path);
    }

    installed_bridge_executable(resource_directory)
}

fn installed_bridge_executable(resource_directory: &Path) -> PathBuf {
    resource_directory
        .join("bridge")
        .join("Thrustline.Bridge.exe")
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use super::{generate_instance_token, installed_bridge_executable, reserve_loopback_port};

    #[test]
    fn instance_tokens_are_random_hex_values() {
        let first = generate_instance_token().expect("first token");
        let second = generate_instance_token().expect("second token");
        assert_eq!(first.len(), 64);
        assert!(first.chars().all(|character| character.is_ascii_hexdigit()));
        assert_ne!(first, second);
    }

    #[test]
    fn selected_port_is_dynamic() {
        assert!(reserve_loopback_port().expect("dynamic port") >= 49152);
    }

    #[test]
    fn installed_bridge_is_resolved_from_the_resource_directory() {
        let resource_directory = Path::new(r"C:\Program Files\Thrustline");
        let executable = installed_bridge_executable(resource_directory);
        assert_eq!(
            executable,
            resource_directory
                .join("bridge")
                .join("Thrustline.Bridge.exe")
        );
    }
}
