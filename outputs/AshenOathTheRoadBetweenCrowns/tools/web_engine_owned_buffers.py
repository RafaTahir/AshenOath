"""Opt-in ownership transfer for verified, immutable Godot Web pack buffers.

This changes only the exported JavaScript glue, not the engine WASM. Normal
copyToFS callers retain copy semantics. Unknown glue must fail packaging rather
than silently advertise an ownership capability that it cannot provide.
"""

from __future__ import annotations

MARKER = "Engine.prototype['supportsOwnedPackBuffers'] = true;"
MAIN_PACK_MARKER = "Engine.prototype['supportsOwnedMainPackBuffer'] = true;"
BUFFER_REPLACEMENTS = (
    ("copy_to_fs:function(path,buffer){", "copy_to_fs:function(path,buffer,takeOwnership){"),
    ("FS.writeFile(path,new Uint8Array(buffer))",
     "FS.writeFile(path,new Uint8Array(buffer),{canOwn:takeOwnership===true})"),
    ("copyToFS: function (path, buffer) {", "copyToFS: function (path, buffer, takeOwnership) {"),
    ("this.rtenv['copyToFS'](path, buffer);",
     "this.rtenv['copyToFS'](path, buffer, takeOwnership === true);"),
    ("Engine.prototype['copyToFS'] = Engine.prototype.copyToFS;",
     "Engine.prototype['copyToFS'] = Engine.prototype.copyToFS;\n\t\t" + MARKER),
)
MAIN_PACK_REPLACEMENTS = (
    ("me.preloadedFiles.push({\n\t\t\t\t\tpath: destPath || pathOrBuffer,\n\t\t\t\t\tbuffer: buf,\n\t\t\t\t});",
     "me.preloadedFiles.push({\n\t\t\t\t\tpath: destPath || pathOrBuffer,\n\t\t\t\t\tbuffer: buf,\n\t\t\t\t\tashenPrivateNetworkBuffer: true,\n\t\t\t\t});"),
    ("me.rtenv['copyToFS'](file.path, file.buffer);",
     "me.rtenv['copyToFS'](file.path, file.buffer, file.ashenPrivateNetworkBuffer === true && "
     "file.path === (me.config.mainPack || `${me.config.executable}.pck`));"),
    (MARKER, MARKER + "\n\t\t" + MAIN_PACK_MARKER),
)
REPLACEMENTS = BUFFER_REPLACEMENTS + MAIN_PACK_REPLACEMENTS


def _apply_boundary(source, marker, replacements):
    if marker in source:
        if all(source.count(replacement) == 1 for _, replacement in replacements):
            return source
        raise ValueError("Incomplete verified-pack ownership glue")
    for expected, _ in replacements:
        if source.count(expected) != 1:
            raise ValueError(f"Unsupported Godot Web ownership boundary: {expected}")
    for expected, replacement in replacements:
        source = source.replace(expected, replacement, 1)
    return source


def enable_owned_pack_buffers(payload: bytes) -> bytes:
    source = payload.decode("utf-8")
    source = _apply_boundary(source, MARKER, BUFFER_REPLACEMENTS)
    # Only URL-fetched buffers are private to the preloader. Caller-provided
    # ArrayBuffers/views remain untagged, even when their path is the main PCK.
    # Transferring that one game-owned PCK avoids a transient full MEMFS copy;
    # start() still clears every preload record before callMain as stock does.
    source = _apply_boundary(source, MAIN_PACK_MARKER, MAIN_PACK_REPLACEMENTS)
    return source.encode("utf-8")
