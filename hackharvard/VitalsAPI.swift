//
//  VitalsAPI.swift
//  hackharvard
//
//  Talks to the FastAPI backend's /v1/process endpoint (see contracts/process-api.md).
//

import Foundation
import AVFoundation

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
        let uploadURL = try await prepareVideoForUpload(at: fileURL)
        defer {
            if uploadURL != fileURL {
                try? FileManager.default.removeItem(at: uploadURL)
            }
        }

        let healthURL = baseURL.appendingPathComponent("health")
        _ = try? await session.data(from: healthURL)

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/process"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let videoData = try Data(contentsOf: uploadURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"prepared-video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
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

    private static func prepareVideoForUpload(at sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVC1920x1080) else {
            return sourceURL
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("prepared-\(UUID().uuidString).mp4")
        exporter.shouldOptimizeForNetworkUse = true

        // The async export API owns the operation's concurrency and surfaces
        // failures directly, avoiding the deprecated callback/status access.
        try await exporter.export(to: outputURL, as: .mp4)

        return outputURL
    }
}
