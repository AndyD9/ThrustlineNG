use std::{
    io::{self, Write},
    net::{Ipv4Addr, TcpListener},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::Mutex,
};

use crate::flight_summary::{self, FlightSummary, FlightSummaryFailure};

pub struct BridgeSupervisor {
    child: Mutex<Option<Child>>,
    // The local contract coordinates never leave this process: the WebView
    // only ever sees the validated summary returned by `read_flight_summary`.
    port: u16,
    token: String,
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
        })
    }

    pub fn read_flight_summary(&self) -> Result<FlightSummary, FlightSummaryFailure> {
        flight_summary::read(self.port, &self.token)
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
