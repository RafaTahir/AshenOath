# Publishing Ashen Oath Online

The browser build is a normal static Godot Web export. Build it with `Export_Web_Build.bat`, then deploy the contents of `../AshenOath_Web_Slim`.

## Vercel, Netlify, or Cloudflare Pages

1. Run `Export_Web_Build.bat`.
2. Create a static site/project.
3. Upload or point the site root at `AshenOath_Web_Slim`.
4. Confirm `index.html` is at the deployment root.
5. Do not rename the generated `.wasm`, `.pck`, `.js`, or `.png` files.

This project uses the single-threaded Web export preset for first release, so special COOP/COEP headers are not required. If thread support is enabled later, add:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

## itch.io

1. Run `Export_Web_Build.bat`.
2. Zip the contents of `AshenOath_Web_Slim`, not the parent folder.
3. Upload as an HTML game.
4. Use a 1280x720 viewport or responsive fullscreen embed.
5. Publish only the Web build for this release.

## Browser Notes

Chrome, Edge, and Firefox are the primary browser targets. Safari and mobile browser support should be treated as experimental until directly tested. The first splash screen intentionally requires a click so browsers allow audio and mouse capture.
