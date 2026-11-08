# Vendored XIRASM standard library

This directory holds the subset of the XIRASM 0.3.5 standard library needed to
assemble `src/main.xir`. It is checked in so `tools/xirasm.exe` works offline in
CI without installing the full release.

- `format/` — the executable/object format facade. `src/main.xir` does
  `import("format/format.inc")` and calls `format_pe64(...)` to emit a PE64
  console image.
- `io/` — the Windows console I/O layer. `import("io/windows.inc")` provides
  `io_read_stdin` / `io_write_stdout` and `io_windows64_imports(...)` which adds
  the KERNEL32.DLL imports.

## Resolution order

XIRASM resolves a relative `import`/`include` path as: directory of the
importing source → project `include/` directory → installed `include/`
directory (beside the executable). Because the library lives here, even the
bare `tools/xirasm.exe` resolves `format/format.inc` from this project include
directory.

Project-specific helper includes can be added alongside these folders; they
take precedence over the installed library.

Source: XIRASM 0.3.5 release (Apache-2.0), `include/format/` and `include/io/`.
