mod bridge;
mod flight_summary;

use tauri::Manager;

// The two IPC commands of the shell. `flight_summary` is read-only and takes
// no guest-supplied parameter; `flight_summary_arm` accepts exactly one
// canonical dispatch identifier. Only validated closed shapes cross the
// boundary — never the token, the port nor the measurement generation.
#[tauri::command]
async fn flight_summary(
    app: tauri::AppHandle,
) -> Result<flight_summary::FlightSummary, flight_summary::FlightSummaryFailure> {
    tauri::async_runtime::spawn_blocking(move || {
        app.state::<bridge::BridgeSupervisor>()
            .read_flight_summary()
    })
    .await
    .map_err(|_| flight_summary::FlightSummaryFailure::Unavailable)?
}

#[tauri::command]
async fn flight_summary_arm(
    app: tauri::AppHandle,
    dispatch_id: String,
) -> Result<flight_summary::ArmedFlightSummary, flight_summary::FlightSummaryFailure> {
    tauri::async_runtime::spawn_blocking(move || {
        app.state::<bridge::BridgeSupervisor>()
            .arm_flight_summary(&dispatch_id)
    })
    .await
    .map_err(|_| flight_summary::FlightSummaryFailure::Unavailable)?
}

pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![flight_summary, flight_summary_arm])
        .setup(|app| {
            let resource_directory = app.path().resource_dir()?;
            let supervisor = bridge::BridgeSupervisor::start(&resource_directory)?;
            app.manage(supervisor);
            Ok(())
        })
        .on_window_event(|window, event| {
            if matches!(event, tauri::WindowEvent::Destroyed)
                && let Some(supervisor) = window.try_state::<bridge::BridgeSupervisor>()
            {
                supervisor.stop();
            }
        })
        .run(tauri::generate_context!())
        .expect("failed to start the Thrustline shell; verify WebView2 Evergreen is installed");
}
