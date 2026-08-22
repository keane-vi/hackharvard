//
//  VitalsAPI.swift
//  hackharvard
//
//  Talks to the FastAPI backend's /v1/process endpoint (see contracts/process-api.md).
//

import Foundation

struct VitalsQuality: Decodable {
    let hr: String
    let prv: String
    let rr: String
    let spo2: String
}

struct VitalsMeta: Decodable {
    let duration_s: Double?
    let fs: Double?
    let disclaimer: String
}

struct VitalsResponse: Decodable, Identifiable {
    let id = UUID()
    let hr_bpm: Double?
    let prv_sdnn_ms: Double?
    let prv_rmssd_ms: Double?
    let rr_brpm: Double?
    let spo2_pct: Double?
    let quality: VitalsQuality
    let meta: VitalsMeta
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case hr_bpm, prv_sdnn_ms, prv_rmssd_ms, rr_brpm, spo2_pct, quality, meta, error
    }
}

struct VitalsAPIError: Decodable, Error {
    let error: String
    let message: String
}

enum VitalsAPI {
    // Local Windows backend. Phone and this PC must be on the same Wi-Fi.
    // Render is not used. Update the IP if `ipconfig` changes.
    static var baseURL = URL(string: "http://172.20.10.6:8000")!

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    static func process(videoAt fileURL: URL) async throws -> VitalsResponse {
        let healthURL = baseURL.appendingPathComponent("health")
        _ = try? await session.data(from: healthURL)

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/process"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let videoData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw (try? JSONDecoder().decode(VitalsAPIError.self, from: data))
                ?? VitalsAPIError(error: "processing_failed", message: "The server returned an unexpected error.")
        }

        return try JSONDecoder().decode(VitalsResponse.self, from: data)
    }
}
