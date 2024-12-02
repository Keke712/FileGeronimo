# File Geronimo

A fast, keyboard-driven file explorer built with GTK4 and GtkLayerShell for Linux.

## Features

- Grid and list view modes
- Keyboard shortcuts for quick navigation
- Drag and drop support
- File operations (copy, cut, paste, delete)
- Thumbnail generation for images
- File monitoring for automatic updates
- Undo support for file operations
- Tab completion for paths

## Dependencies

- gtk4
- libgtk-layer-shell
- vala
- meson
- ninja

## Installation

### Build from source

1. Clone the repository:
    `$ git clone https://github.com/Keke712/fgeronimo.git`

2. Setup with meson:
    `$ sudo meson setup build`

3. Install with meson:
    `$ sudo meson install -C build`

4. Launch
    `$ fgeronimo`