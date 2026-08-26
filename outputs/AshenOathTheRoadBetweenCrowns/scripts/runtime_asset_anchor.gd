extends Node

## Runtime asset anchor retained for scene compatibility. Runtime character
## code loads the shared animation library on first use, so this node must not
## preload that multi-megabyte resource during browser boot.
