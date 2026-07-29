mod bridge;

use tauri::Manager;

pub fn run() {
    tauri::Builder::default()
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
