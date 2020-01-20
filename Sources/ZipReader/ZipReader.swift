import CShims
import CMinizip
import Foundation

public enum ZipReaderError: Error {
    case minizipError(Int)
    case fileDoesNotExist
    case invalidFileInfo
    case invalidPath
    case openFailed(Int)
    case readError

    public var errorDescription: String? {
        switch self {
        case .minizipError (let code):
            return "Minizip error \(code)"
        case .fileDoesNotExist:
            return "File does not exist in archive"
        case .invalidFileInfo:
            return "Invalid file_info returned from mz_zip_reader_entry_get_info"
        case .invalidPath:
            return "Cannot read path from zip info"
        case .openFailed (let code):
            return "mz_zip_reader_entry_open failed: \(code)"
        case .readError:
            return "Zip file read failed"
       }
    }
}

public struct ZippedFile {
    public let metadata: ZipMetadata
    public let data: Data
}

extension ZippedFile: CustomStringConvertible {

    public var description: String {
        return String(describing: metadata)
    }
}

public struct ZipMetadata {
    public let path: String
    public let size: Int64
    public let compressedSize: Int64
    public let crc32: UInt32
    public let compressionMethod: CompressionMethod

    var ratio: Double {
        return Double(compressedSize) / Double(size)
    }
}

extension ZipMetadata: CustomStringConvertible {

    public var description: String {
        return "\(path): \(size) bytes / \(compressedSize) packed (\(ratio)) CRC32: \(String(crc32, radix: 16, uppercase: false))"
    }
}

public enum CompressionMethod: UInt16 {
    case store = 0
    case deflate = 8
    case bzip2 = 12
    case lzma = 14
    case aes = 99
    case unknown = 1000
}

public class ZipReader {

    private var _zipReader: UnsafeMutableRawPointer?

    /*
    Returns the number of files in the archive, or the negative error code on error.

    - Returns: 'Int' object.
    */
    var fileCount: Int {
        var count: UInt64 = 0
        let result = mz_zip_get_number_entry(_zipReader, &count)
        if result != MZ_OK {
            mz_zip_reader_delete(&_zipReader)
            return Int(result)
        }
        return Int(count)
    }

    public init (url: URL, inMemory: Bool = false) throws {

        let result: Int32
        print(url.path)
        mz_zip_reader_create(&_zipReader)
        if inMemory {
            result = mz_zip_reader_open_file_in_memory(_zipReader, url.path)
        } else {
            result = mz_zip_reader_open_file(_zipReader, url.path)
        }
        if result != MZ_OK
        {
            mz_zip_reader_delete(&_zipReader)
            throw ZipReaderError.minizipError(Int(result))
        }
    }

    public func file(path: String, caseSensitive: Bool = false) throws -> ZippedFile {
        var result = mz_zip_reader_locate_entry(_zipReader, path, caseSensitive ? UInt8(0) : UInt8(1))

        if result != MZ_OK {
            if result == MZ_END_OF_LIST {
                throw ZipReaderError.minizipError(Int(result))
            } else {
                throw ZipReaderError.fileDoesNotExist
            }
        }
        let metadata = try currentItemMetadata()
        var buffer = [UInt8](repeating: 0, count: Int(metadata.size))

        result = mz_zip_reader_entry_open(_zipReader)
        if result != MZ_OK {
            throw ZipReaderError.openFailed(Int(result))
        }
        defer {
            mz_zip_reader_entry_close(_zipReader)
        }
        let readCount = mz_zip_reader_entry_read(_zipReader, &buffer, Int32(metadata.size))
        if readCount != metadata.size {
            throw ZipReaderError.readError
        }
        let crc32 = buffer.crc32
        if metadata.crc32 != crc32 {
            throw ZipReaderError.readError
        }
        return ZippedFile(metadata: metadata, data: Data(buffer))
    }

    private func currentItemMetadata () throws -> ZipMetadata {
        var fileInfoPointer: UnsafeMutablePointer<mz_zip_file>? = nil

        let result = mz_zip_reader_entry_get_info(_zipReader, &fileInfoPointer)
        if result != MZ_OK {
            throw ZipReaderError.minizipError(Int(result))
        }
        guard let info = fileInfoPointer?.pointee else {
            throw ZipReaderError.invalidFileInfo
        }
        let compressionMethod = CompressionMethod(rawValue: info.compression_method) ?? .unknown

        guard let path = String(cString: info.filename, encoding: .utf8) else {
            throw ZipReaderError.invalidPath
        }
        let metadata = ZipMetadata(
            path: path,
            size: info.uncompressed_size,
            compressedSize: info.compressed_size,
            crc32: info.crc,
            compressionMethod: compressionMethod
        )
        return metadata
    }

    public func listArchive () -> Bool {
        return list_zip_archive(_zipReader) == MZ_OK
    }

    deinit {
        mz_zip_reader_delete(&_zipReader)
    }
}

fileprivate var table: [UInt32] = {
    (0...255).map { i -> UInt32 in
        (0..<8).reduce(UInt32(i), { c, _ in
            (c % 2 == 0) ? (c >> 1) : (0xEDB88320 ^ (c >> 1))
        })
    }
}()

public extension Array where Element == UInt8 {

    var crc32: UInt32 {
        return ~(self.reduce(~UInt32(0), { crc, byte in
            (crc >> 8) ^ table[(Int(crc) ^ Int(byte)) & 0xFF]
        }))
    }
}
