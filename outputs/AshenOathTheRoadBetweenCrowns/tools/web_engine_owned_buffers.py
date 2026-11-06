"""Opt-in ownership transfer for verified, immutable Godot Web pack buffers.

This changes only the exported JavaScript glue, not the engine WASM. Normal
copyToFS callers retain copy semantics. Unknown glue must fail packaging rather
than silently advertise an ownership capability that it cannot provide.
"""

from __future__ import annotations

MARKER = "Engine.prototype['supportsOwnedPackBuffers'] = true;"
REPLACEMENTS = (
    ("copy_to_fs:function(path,buffer){", "copy_to_fs:function(path,buffer,takeOwnership){"),
    ("FS.writeFile(path,new Uint8Array(buffer))",
     "FS.writeFile(path,new Uint8Array(buffer),{canOwn:takeOwnership===true})"),
    ("copyToFS: function (path, buffer) {", "copyToFS: function (path, buffer, takeOwnership) {"),
    ("this.rtenv['copyToFS'](path, buffer);",
     "this.rtenv['copyToFS'](path, buffer, takeOwnership === true);"),
    ("Engine.prototype['copyToFS'] = Engine.prototype.copyToFS;",
     "Engine.prototype['copyToFS'] = Engine.prototype.copyToFS;\n\t\t" + MARKER),
)


def enable_owned_pack_buffers(payload: bytes) -> bytes:
    source = payload.decode("utf-8")
    if MARKER in source:
        if all(source.count(replacement) == 1 for _, replacement in REPLACEMENTS):
            return payload
        raise ValueError("Incomplete verified-pack ownership glue")
    for expected, _ in REPLACEMENTS:
        if source.count(expected) != 1:
            raise ValueError(f"Unsupported Godot Web ownership boundary: {expected}")
    for expected, replacement in REPLACEMENTS:
        source = source.replace(expected, replacement, 1)
    return source.encode("utf-8")
