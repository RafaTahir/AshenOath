R4 tested-code / committed-code binding: PASS

Producer/source commit: 86f8425afa9f7c9cb5256946f0c0dd8461cdf85d
Checkout attribute commit: d40a63095b03e0636cb4c09c5154873cf742dff7
Both project trees: 29a407b48df5e7be7a3e01c10b9c0ba04662b9f4
Only commit-level changed path: .gitattributes; executable/source blobs unchanged.

526/526 bounded runtime inputs match the recorded R4 checkout bytes: 341 executable/shader/text-scene resources, 136 runtime data, 36 root JSON contracts/registries, 1 project configuration, 5 script-adjacent contracts/docs, and 7 separately classified generated metadata files. All 20 protected -text inputs match raw Git blobs. The other 505 transformed entries use Git's actual checkout filtering, never manual newline normalization; 1 binary metadata entry also matches raw bytes.

Git 2.53.0.windows.3; core.autocrlf=true from C:/Program Files/Git/etc/gitconfig; core.eol/core.safecrlf/core.attributesfile unset. Attributes came explicitly from d40a630. The original failed86f receipt is retained: its footprint-view raw blob matched R4, but lacked -text and would change on Windows checkout. The attribute-only followup fixes that guarantee without changing code or builder inputs.

Scope: 13,601,693 bytes of bounded Git code/data/text-resource objects read; no current mutable project/generated files and no large source assets read. Of 6623 recorded inputs, 4022 are tracked. This proof does not claim all6623 are tracked: 321 ignored UID files, 2276 generated remaps and4 baseline-native embedded PNG images have separate R4 cache/extraction proof. Also excluded from this bounded object read are 3435 tracked noncode assets, 51 tracked remaps and10 tracked UID files. Builder-owned resource/pack metadata is validated separately after refresh.

No engine launched; active builder ownership remained with root.
