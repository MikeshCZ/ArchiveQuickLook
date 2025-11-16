<a href="https://www.buymeacoffee.com/michalsara" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-red.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

# ArchiveQuickLook

A macOS QuickLook extension that enables quick preview of archive file contents directly in Finder.

## Overview

ArchiveQuickLook adds native QuickLook support for compressed archive files on macOS. When you press the Space bar on an archive file in Finder, you can instantly see the list of files contained within, including their sizes, compressed sizes, and modification dates—all without extracting the archive.

## Supported Formats

- **ZIP** (`.zip`)
- **TAR** (`.tar`, `.tar.gz`, `.tgz`, `.tar.xz`, `.txz`)
- **GZIP** (`.gz`)
- **XZ** (`.xz`)

## Features

- 📦 **Quick Preview**: View archive contents directly in Finder's QuickLook
- 📊 **Detailed Information**: See file names, sizes, compressed sizes, and modification dates
- 📁 **Folder Recognition**: Directories are clearly marked with folder icons
- ⚡ **Native Implementation**: Pure Swift implementation for optimal performance
- 🔒 **Secure**: No extraction required—view contents safely and quickly

## Installation

1. Download and install ArchiveQuickLook.app
2. Open the application at least once to activate the QuickLook extension
3. The extension is now active system-wide
4. In Finder, select any supported archive file and press Space to preview

> **Note**: You may need to grant the extension permission in System Settings > Privacy & Security > Extensions > Quick Look

## Technical Details

The extension uses:
- Native Swift implementation for ZIP archive parsing
- Foundation's compression framework for GZIP and XZ decompression
- Custom TAR format parser for TAR archives
- NSTableView for displaying archive contents in a clean, familiar interface

## Requirements

- macOS (compatible with systems supporting QuickLook extensions)
- No external dependencies required

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## Privacy

ArchiveQuickLook operates entirely on your local machine. No data is sent to external servers, and no archive contents are stored or transmitted.

## 🧑‍💻 Author

- [More about the author](https://www.michalsara.cz)

## ☕ If you like this repository, you can **[buy me a coffee](https://www.buymeacoffee.com/michalsara)**. Thanks!
