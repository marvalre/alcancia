import Foundation

/// Escritor ZIP mínimo para paquetes OOXML. Los archivos se almacenan sin
/// compresión para mantener la implementación auditable y sin dependencias.
struct ZIPArchiveWriter {
    private struct File {
        let name: String
        let data: Data
        let crc32: UInt32
        let offset: UInt32
    }

    private var files: [File] = []
    private var payload = Data()

    mutating func addFile(named name: String, data: Data) {
        let nameData = Data(name.utf8)
        let offset = UInt32(payload.count)
        let checksum = crc32(data)
        appendUInt32(0x0403_4B50, to: &payload)
        appendUInt16(20, to: &payload)
        appendUInt16(0, to: &payload)
        appendUInt16(0, to: &payload)
        appendUInt16(0, to: &payload)
        appendUInt16(0, to: &payload)
        appendUInt32(checksum, to: &payload)
        appendUInt32(UInt32(data.count), to: &payload)
        appendUInt32(UInt32(data.count), to: &payload)
        appendUInt16(UInt16(nameData.count), to: &payload)
        appendUInt16(0, to: &payload)
        payload.append(nameData)
        payload.append(data)
        files.append(File(name: name, data: data, crc32: checksum, offset: offset))
    }

    mutating func makeData() -> Data {
        let centralDirectoryOffset = UInt32(payload.count)
        for file in files {
            let nameData = Data(file.name.utf8)
            appendUInt32(0x0201_4B50, to: &payload)
            appendUInt16(20, to: &payload)
            appendUInt16(20, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt32(file.crc32, to: &payload)
            appendUInt32(UInt32(file.data.count), to: &payload)
            appendUInt32(UInt32(file.data.count), to: &payload)
            appendUInt16(UInt16(nameData.count), to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt16(0, to: &payload)
            appendUInt32(0, to: &payload)
            appendUInt32(file.offset, to: &payload)
            payload.append(nameData)
        }
        let centralDirectorySize = UInt32(payload.count) - centralDirectoryOffset
        appendUInt32(0x0605_4B50, to: &payload)
        appendUInt16(0, to: &payload)
        appendUInt16(0, to: &payload)
        appendUInt16(UInt16(files.count), to: &payload)
        appendUInt16(UInt16(files.count), to: &payload)
        appendUInt32(centralDirectorySize, to: &payload)
        appendUInt32(centralDirectoryOffset, to: &payload)
        appendUInt16(0, to: &payload)
        return payload
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1 == 1) ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        let littleEndian = value.littleEndian
        withUnsafeBytes(of: littleEndian) { data.append(contentsOf: $0) }
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        let littleEndian = value.littleEndian
        withUnsafeBytes(of: littleEndian) { data.append(contentsOf: $0) }
    }
}
