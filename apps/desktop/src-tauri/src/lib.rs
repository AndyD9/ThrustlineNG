pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("failed to start the Thrustline shell; verify WebView2 Evergreen is installed");
}
