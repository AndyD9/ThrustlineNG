use std::{
    io::{self, Write},
    net::{Ipv4Addr, TcpListener},
    path::PathBuf,
    process::{Child, Command, Stdio},
    sync::Mutex,
};

pub struct BridgeSupervisor {
    child: Mutex<Option<Child>>,
}

impl BridgeSupervisor {
    pub fn start() -> Result<Self, Box<dyn std::error::Error>> {
        let port = reserve_loopback_port()?;
        let token = generate_instance_token()
            .map_err(|error| io::Error::other(format!("OS random source failed: {error}")))?;
        let executable = bridge_executable()?;
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
        })
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

fn bridge_executable() -> io::Result<PathBuf> {
    if cfg!(debug_assertions)
        && let Some(path) = std::env::var_os("THRUSTLINE_BRIDGE_PATH")
    {
        return Ok(PathBuf::from(path));
    }

    let mut path = std::env::current_exe()?;
    path.set_file_name("Thrustline.Bridge.exe");
    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::{generate_instance_token, reserve_loopback_port};

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
}
