//
//  PreviewViewController.swift
//  ArchivePreview
//
//  Created by Michal Šára on 16.11.2025.
//

import Cocoa
import Quartz
import UniformTypeIdentifiers
import Compression

class PreviewViewController: NSViewController, QLPreviewingController {

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var archiveEntries: [ArchiveEntry] = []

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
        setupUI()
    }

    override var acceptsFirstResponder: Bool {
        return false
    }

    private func setupUI() {
        // Vytvoření scroll view
        scrollView = NSScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder

        tableView = NSTableView(frame: scrollView.bounds)
        tableView.autoresizingMask = [.width, .height]
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self

        // DŮLEŽITÉ: Zakázat interakci pro QuickLook extension
        tableView.allowsColumnSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false

        // Sloupec pro název souboru
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = String(localized: "column.name")
        nameColumn.width = 300
        nameColumn.minWidth = 150
        tableView.addTableColumn(nameColumn)

        // Sloupec pro velikost
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = String(localized: "column.size")
        sizeColumn.width = 100
        sizeColumn.minWidth = 80
        tableView.addTableColumn(sizeColumn)

        // Sloupec pro komprimovanou velikost
        let compressedSizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("compressedSize"))
        compressedSizeColumn.title = String(localized: "column.compressedSize")
        compressedSizeColumn.width = 100
        compressedSizeColumn.minWidth = 80
        tableView.addTableColumn(compressedSizeColumn)

        // Sloupec pro datum
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = String(localized: "column.modificationDate")
        dateColumn.width = 150
        dateColumn.minWidth = 120
        tableView.addTableColumn(dateColumn)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        NSLog("ArchivePreview: preparePreviewOfFile called for \(url.path)")

        do {
            // Načtení obsahu archivu
            archiveEntries = try await loadArchiveContents(from: url)

            NSLog("ArchivePreview: Loaded \(archiveEntries.count) entries")
            for entry in archiveEntries {
                NSLog("  - \(entry.name) (\(entry.size) bytes)")
            }

            // Aktualizace UI v hlavním vlákně
            await MainActor.run {
                NSLog("ArchivePreview: Reloading table with \(self.archiveEntries.count) entries")
                tableView.reloadData()
            }
        } catch {
            NSLog("ArchivePreview: Error loading archive: \(error)")
            throw error
        }
    }

    private func loadArchiveContents(from url: URL) async throws -> [ArchiveEntry] {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "zip":
            return try await loadZipArchive(from: url)
        case "tar", "gz", "tgz", "xz", "txz":
            return try await loadTarArchive(from: url)
        default:
            throw NSError(domain: "ArchivePreview", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "error.unsupportedFormat")])
        }
    }

    private func loadZipArchive(from url: URL) async throws -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []

        guard let archive = Archive(url: url, accessMode: .read) else {
            throw NSError(domain: "ArchivePreview", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "error.cannotOpenZip")])
        }

        for entry in archive {
            let archiveEntry = ArchiveEntry(
                name: entry.path,
                size: Int64(entry.uncompressedSize),
                compressedSize: Int64(entry.compressedSize),
                modificationDate: entry.fileAttributes[.modificationDate] as? Date,
                isDirectory: entry.type == .directory
            )
            entries.append(archiveEntry)
        }

        return entries.sorted { $0.name < $1.name }
    }

    private func loadTarArchive(from url: URL) async throws -> [ArchiveEntry] {
        NSLog("Loading TAR archive from \(url.path)")

        // Dekomprese pokud je potřeba
        let data: Data
        let ext = url.pathExtension.lowercased()

        if ext == "gz" || ext == "tgz" {
            // GZIP komprese
            NSLog("Decompressing GZIP...")
            data = try decompressGzip(url: url)
        } else if ext == "xz" || ext == "txz" {
            // XZ komprese
            NSLog("Decompressing XZ/LZMA...")
            data = try decompressXz(url: url)
        } else {
            // Nekomprimovaný TAR
            data = try Data(contentsOf: url)
        }

        return try parseTarData(data)
    }

    private func decompressGzip(url: URL) throws -> Data {
        let compressedData = try Data(contentsOf: url)

        // Zlib může dekomprimovat GZIP
        if let decompressed = try? (compressedData as NSData).decompressed(using: .zlib) as Data {
            return decompressed
        }

        // Pokud selže, zkusíme manuální GZIP dekomprese
        // GZIP má hlavičku, kterou musíme přeskočit
        var offset = 0

        // Kontrola GZIP magic number (0x1f 0x8b)
        guard compressedData.count > 10,
              compressedData[0] == 0x1f,
              compressedData[1] == 0x8b else {
            throw NSError(domain: "ArchivePreview", code: 4,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "error.invalidGzip")])
        }

        // Přeskočit GZIP hlavičku (10 bytů + případné extra fieldy)
        offset = 10
        let flags = compressedData[3]

        // FEXTRA
        if (flags & 0x04) != 0 {
            let xlen = Int(compressedData[offset]) | (Int(compressedData[offset + 1]) << 8)
            offset += 2 + xlen
        }

        // FNAME
        if (flags & 0x08) != 0 {
            while offset < compressedData.count && compressedData[offset] != 0 {
                offset += 1
            }
            offset += 1
        }

        // FCOMMENT
        if (flags & 0x10) != 0 {
            while offset < compressedData.count && compressedData[offset] != 0 {
                offset += 1
            }
            offset += 1
        }

        // FHCRC
        if (flags & 0x02) != 0 {
            offset += 2
        }

        // Zbytek je komprimovaná data (zlib formát)
        let zlibData = compressedData[offset..<compressedData.count - 8] // -8 pro CRC a velikost na konci
        return try (zlibData as NSData).decompressed(using: .zlib) as Data
    }

    private func decompressXz(url: URL) throws -> Data {
        let compressedData = try Data(contentsOf: url)
        return try (compressedData as NSData).decompressed(using: .lzma) as Data
    }

    private func parseTarData(_ data: Data) throws -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var offset = 0

        NSLog("TAR: Parsing \(data.count) bytes")

        while offset + 512 <= data.count {
            // TAR hlavička je 512 bytů
            let headerData = data[offset..<offset + 512]

            // Kontrola, zda není konec (dva prázdné bloky)
            if headerData.allSatisfy({ $0 == 0 }) {
                break
            }

            // Přečíst název souboru (0-99)
            guard let fileName = readTarString(from: headerData, offset: 0, length: 100),
                  !fileName.isEmpty else {
                offset += 512
                continue
            }

            // Přečíst velikost (124-135, osmičková soustava)
            let sizeString = readTarString(from: headerData, offset: 124, length: 12) ?? ""
            let size = Int64(sizeString.trimmingCharacters(in: .whitespaces), radix: 8) ?? 0

            // Přečíst čas modifikace (136-147, osmičková soustava, Unix timestamp)
            let mtimeString = readTarString(from: headerData, offset: 136, length: 12) ?? ""
            let mtime = Int64(mtimeString.trimmingCharacters(in: .whitespaces), radix: 8) ?? 0
            let modificationDate = mtime > 0 ? Date(timeIntervalSince1970: TimeInterval(mtime)) : nil

            // Přečíst typ (156)
            let typeFlag = headerData[156]
            let isDirectory = (typeFlag == 0x35) || fileName.hasSuffix("/") // '5' = directory

            // Pokud je prefix (345-499), spojit s názvem
            var fullName = fileName
            if let prefix = readTarString(from: headerData, offset: 345, length: 155), !prefix.isEmpty {
                fullName = prefix + "/" + fileName
            }

            NSLog("TAR: Found entry: \(fullName) (\(size) bytes)")

            entries.append(ArchiveEntry(
                name: fullName,
                size: size,
                compressedSize: nil,
                modificationDate: modificationDate,
                isDirectory: isDirectory
            ))

            // Přejít na další záznam
            // TAR data jsou zarovnaná na 512 bytů
            offset += 512
            if size > 0 {
                let dataBlocks = (size + 511) / 512
                offset += Int(dataBlocks * 512)
            }
        }

        NSLog("TAR: Parsed \(entries.count) entries")
        return entries.sorted { $0.name < $1.name }
    }

    private func readTarString(from data: Data, offset: Int, length: Int) -> String? {
        guard offset + length <= data.count else { return nil }

        let slice = data[offset..<offset + length]
        // Najít první nulový byte (konec C stringu)
        if let nullIndex = slice.firstIndex(of: 0) {
            let stringData = data[offset..<nullIndex]
            return String(data: stringData, encoding: .utf8)
        } else {
            return String(data: slice, encoding: .utf8)
        }
    }

}

// MARK: - NSTableViewDataSource
extension PreviewViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return archiveEntries.count
    }
}

// MARK: - NSTableViewDelegate
extension PreviewViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = archiveEntries[row]
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        let cellView = NSTextField(labelWithString: "")
        cellView.lineBreakMode = .byTruncatingTail
        cellView.cell?.truncatesLastVisibleLine = true

        // DŮLEŽITÉ: Zakázat editaci pro QuickLook extension
        cellView.isEditable = false
        cellView.isSelectable = false
        cellView.isBezeled = false
        cellView.drawsBackground = false

        switch identifier.rawValue {
        case "name":
            let icon = entry.isDirectory ? "📁 " : "📄 "
            cellView.stringValue = icon + entry.name
        case "size":
            cellView.stringValue = formatFileSize(entry.size)
        case "compressedSize":
            if let compressedSize = entry.compressedSize {
                cellView.stringValue = formatFileSize(compressedSize)
            } else {
                cellView.stringValue = "-"
            }
        case "date":
            if let date = entry.modificationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                cellView.stringValue = formatter.string(from: date)
            } else {
                cellView.stringValue = "-"
            }
        default:
            cellView.stringValue = ""
        }

        return cellView
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - ArchiveEntry
struct ArchiveEntry {
    let name: String
    let size: Int64
    let compressedSize: Int64?
    let modificationDate: Date?
    let isDirectory: Bool
}

// MARK: - Simple ZIP Archive Reader
// Nativní Swift implementace pro čtení ZIP archivů
struct Archive {
    let url: URL
    let accessMode: AccessMode

    enum AccessMode {
        case read
    }

    init?(url: URL, accessMode: AccessMode) {
        self.url = url
        self.accessMode = accessMode
    }

    var entries: [Entry] {
        do {
            NSLog("Archive: Reading ZIP from \(url.path)")

            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            // Najít End of Central Directory Record (EOCD)
            let eocd = try findEndOfCentralDirectory(fileHandle: fileHandle)
            NSLog("Archive: Found EOCD at offset \(eocd.centralDirectoryOffset)")

            // Přečíst Central Directory
            try fileHandle.seek(toOffset: eocd.centralDirectoryOffset)
            let centralDirectoryData = try fileHandle.read(upToCount: Int(eocd.centralDirectorySize)) ?? Data()

            // Parsovat záznamy z Central Directory
            let result = try parseCentralDirectory(data: centralDirectoryData, entryCount: eocd.entryCount)
            NSLog("Archive: Parsed \(result.count) entries")
            return result
        } catch {
            NSLog("Archive: Error reading ZIP: \(error)")
            return []
        }
    }

    private func findEndOfCentralDirectory(fileHandle: FileHandle) throws -> (centralDirectoryOffset: UInt64, centralDirectorySize: UInt64, entryCount: UInt16) {
        // EOCD signature: 0x06054b50
        // Hledáme od konce souboru
        try fileHandle.seekToEnd()
        let fileSize = try fileHandle.offset()

        // EOCD je minimálně 22 bytů, max comment size je 65535
        let searchStart: UInt64
        if fileSize > 65557 {
            searchStart = fileSize - 65557
        } else {
            searchStart = 0
        }

        try fileHandle.seek(toOffset: searchStart)
        let searchData = try fileHandle.readToEnd() ?? Data()

        // Hledáme EOCD signature
        let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        var eocdOffset: Int = -1

        for i in stride(from: searchData.count - 22, through: 0, by: -1) {
            if searchData.count >= i + 4 &&
               searchData[i] == signature[0] &&
               searchData[i+1] == signature[1] &&
               searchData[i+2] == signature[2] &&
               searchData[i+3] == signature[3] {
                eocdOffset = i
                break
            }
        }

        guard eocdOffset >= 0 else {
            throw NSError(domain: "Archive", code: 1, userInfo: [NSLocalizedDescriptionKey: "EOCD not found"])
        }

        let eocdData = searchData[eocdOffset...]

        // Parsovat EOCD
        let entryCount = eocdData.readUInt16(at: 10)
        let centralDirectorySize = UInt64(eocdData.readUInt32(at: 12))
        let centralDirectoryOffset = UInt64(eocdData.readUInt32(at: 16))

        return (centralDirectoryOffset, centralDirectorySize, entryCount)
    }

    private func parseCentralDirectory(data: Data, entryCount: UInt16) throws -> [Entry] {
        var entries: [Entry] = []
        var offset = 0

        for _ in 0..<entryCount {
            // Central Directory Header signature: 0x02014b50
            guard offset + 46 <= data.count else { break }

            let signature = data.readUInt32(at: offset)
            guard signature == 0x02014b50 else { break }

            let compressedSize = UInt64(data.readUInt32(at: offset + 20))
            let uncompressedSize = UInt64(data.readUInt32(at: offset + 24))
            let fileNameLength = Int(data.readUInt16(at: offset + 28))
            let extraFieldLength = Int(data.readUInt16(at: offset + 30))
            let fileCommentLength = Int(data.readUInt16(at: offset + 32))

            let modTime = data.readUInt16(at: offset + 12)
            let modDate = data.readUInt16(at: offset + 14)

            // Přečíst název souboru
            guard offset + 46 + fileNameLength <= data.count else { break }
            let fileNameData = data[offset + 46..<offset + 46 + fileNameLength]
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""

            // Konvertovat DOS datum/čas na Date
            let date = dosDateTimeToDate(date: modDate, time: modTime)
            var fileAttributes: [FileAttributeKey: Any] = [:]
            if let date = date {
                fileAttributes[.modificationDate] = date
            }

            let isDirectory = fileName.hasSuffix("/")

            entries.append(Entry(
                path: fileName,
                uncompressedSize: uncompressedSize,
                compressedSize: compressedSize,
                type: isDirectory ? .directory : .file,
                fileAttributes: fileAttributes
            ))

            offset += 46 + fileNameLength + extraFieldLength + fileCommentLength
        }

        return entries
    }

    private func dosDateTimeToDate(date: UInt16, time: UInt16) -> Date? {
        let year = Int((date >> 9) & 0x7F) + 1980
        let month = Int((date >> 5) & 0x0F)
        let day = Int(date & 0x1F)

        let hour = Int((time >> 11) & 0x1F)
        let minute = Int((time >> 5) & 0x3F)
        let second = Int((time & 0x1F) * 2)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        return Calendar.current.date(from: components)
    }

    struct Entry {
        let path: String
        let uncompressedSize: UInt64
        let compressedSize: UInt64
        let type: EntryType
        let fileAttributes: [FileAttributeKey: Any]

        enum EntryType {
            case file
            case directory
        }
    }
}

extension Archive: Sequence {
    func makeIterator() -> IndexingIterator<[Entry]> {
        return entries.makeIterator()
    }
}

// MARK: - Data Extensions for ZIP parsing
extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset >= 0 && offset + 2 <= count else { return 0 }
        let idx = startIndex.advanced(by: offset)
        // Little-endian byte order (ZIP standard)
        let byte0 = UInt16(self[idx])
        let byte1 = UInt16(self[idx + 1])
        return byte0 | (byte1 << 8)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset >= 0 && offset + 4 <= count else { return 0 }
        let idx = startIndex.advanced(by: offset)
        // Little-endian byte order (ZIP standard)
        let byte0 = UInt32(self[idx])
        let byte1 = UInt32(self[idx + 1])
        let byte2 = UInt32(self[idx + 2])
        let byte3 = UInt32(self[idx + 3])
        return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
    }
}
