import Foundation

struct CoreEnvelope<T: Decodable>: Decodable {
    let schemaVersion: Int
    let ok: Bool
    let data: T?
    let error: CoreError?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case ok
        case data
        case error
    }
}

struct CoreError: Decodable, Error {
    let code: String
    let message: String
}

struct CapturePayload: Decodable {
    let capture: CaptureRecord
}

struct LookupPayload: Decodable {
    let fileHash: String
    let records: [CaptureRecord]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case fileHash = "file_hash"
        case records
        case count
    }
}

struct SearchPayload: Decodable {
    let query: String
    let backend: String
    let results: [CaptureRecord]
    let count: Int
}

struct CaptureRecord: Decodable {
    let id: String
    let createdAt: Int
    let fileName: String
    let filePathAtCapture: String
    let originTitle: String
    let originURL: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case fileName = "file_name"
        case filePathAtCapture = "file_path_at_capture"
        case originTitle = "origin_title"
        case originURL = "origin_url"
        case note
    }
}
