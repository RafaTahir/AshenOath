# Godot Web export template

The production and Web QA presets use the single-threaded release template in `outputs/AshenOathTheRoadBetweenCrowns/tools/templates/`. Godot ignores this directory when importing game content. The editor and native checks use the standard 4.6.3 executable.

Build from Godot's 4.6.3-stable tag, object `7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3`, commit `35e80b3a8822a9df9be390814b62f44c0a9c69e8`. Apply the four patches in this directory to a clean checkout. The build patch compiles GLES3 storage files separately because combining them in one C++ translation unit makes the two Texture classes ambiguous. Use Emscripten 4.0.11 and SCons 4.11.1.

```sh
git apply "$patch_dir/godot-4.6.3-load-token.patch" "$patch_dir/godot-4.6.3-web-program-lifetime.patch" "$patch_dir/godot-4.6.3-web-build-storage.patch" "$patch_dir/godot-4.6.3-web-download.patch"
scons -j3 platform=web target=template_release threads=no scu_build=yes scu_limit=5 optimize=size lto=none debug_symbols=no use_closure_compiler=no
```

Use the resulting `godot.web.template_release.wasm32.nothreads.zip` as `tools/templates/web_nothreads_release.zip`. The Web renderer links a program on its first real bind, using the requested material, lighting and pass specialization. A successful link releases its vertex and fragment shader objects. The linked program remains owned by its material version. The Web build submits both shader stages before checking the link. If the link fails it retrieves the stage logs and generated sources as well as the program log.

The Web shell's existing buffer-ownership packaging requires readable public engine glue. The release command applies that change to the exported JavaScript and generates content-addressed engine URLs. The complete package and cold browser measurements are recorded in the narrative implementation ledger.

This game's single engine consumes the WebAssembly fetch directly. The general engine API retains cloning for clients that reuse a download. The progress stream reads a chunk when the consumer requests it and forwards errors and cancellation.

Template ZIP SHA-256 is 02de5d9ae4f6d5de4eeb6fe33215a5fb1c26b9871c1732ee3d61383461808718. The ZIP contains 9,171,456 bytes.
