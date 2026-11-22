# Release Checklist

- Run `Run_Ashen_Oath_Godot_4_6.bat` and smoke-test the first 10 minutes.
- Run Godot headless launch and `tools/verify_runtime.gd`.
- Run `Export_Web_Build.bat`.
- Verify `../AshenOath_Web/index.html`, `.wasm`, `.pck`, and `.js` exist.
- Serve the web folder locally and confirm the splash screen, audio click, mouse capture, dialogue cursor, Wychwood encounter, and fall recovery.
- Upload the web folder contents to the chosen static host.
- Include license/credits notes from `assets_external/licenses` when publishing publicly.
