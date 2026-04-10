import XCTest
@testable import CoreSwift
import Foundation

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Models

private struct EchoRequest: Codable, Sendable {
    let message: String
}

private struct EchoResponse: Codable, Sendable {
    let reply: String
}

// MARK: - Tests

final class APIClientTests: XCTestCase {

    private var session: URLSession!
    private var client: APIClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = APIClient(baseURL: URL(string: "https://api.example.com")!)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testPostEncodesRequestBody() async throws {
        MockURLProtocol.requestHandler = { request in
            // Verify the request body was encoded correctly
            let body = try JSONDecoder().decode(EchoRequest.self, from: request.httpBody ?? Data())
            XCTAssertEqual(body.message, "hello")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let responseData = try JSONEncoder().encode(EchoResponse(reply: "world"))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }

        let _: EchoResponse = try await client.post(path: "/echo", body: EchoRequest(message: "hello"))
        print("✓ testPostEncodesRequestBody")
    }

    func testPostDecodesSuccessfulResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let responseData = try JSONEncoder().encode(EchoResponse(reply: "pong"))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }

        let result: EchoResponse = try await client.post(path: "/ping", body: EchoRequest(message: "ping"))
        XCTAssertEqual(result.reply, "pong")
        print("✓ testPostDecodesSuccessfulResponse")
    }

    func testPostThrowsHTTPErrorForNon2xx() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 422,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = "Unprocessable Entity".data(using: .utf8)!
            return (response, body)
        }

        do {
            let _: EchoResponse = try await client.post(path: "/fail", body: EchoRequest(message: "bad"))
            XCTFail("Expected APIError.httpError to be thrown")
        } catch let error as APIError {
            if case .httpError(let statusCode, let body) = error {
                XCTAssertEqual(statusCode, 422)
                XCTAssertEqual(body, "Unprocessable Entity")
            } else {
                XCTFail("Expected httpError but got \(error)")
            }
        }
        print("✓ testPostThrowsHTTPErrorForNon2xx")
    }
}
