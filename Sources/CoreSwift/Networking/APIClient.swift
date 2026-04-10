import Foundation

public enum APIError: Error, Sendable {
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case networkError(Error)
}

public struct APIClient: Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func post<T: Decodable & Sendable, U: Encodable & Sendable>(
        path: String,
        body: U
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.networkError(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                URLError(.badServerResponse)
            )
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
