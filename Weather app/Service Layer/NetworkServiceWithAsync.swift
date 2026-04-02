import Foundation

// MARK: - Protocol
@MainActor
protocol NetworkServiceWithAsyncProtocol {
    func fetchData<T: Decodable>(url: URL) async throws -> T
}

// MARK: - Service
final class NetworkServiceWithAsync: NetworkServiceWithAsyncProtocol {

    // MARK: - Dependencies
    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init
    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    // MARK: - Public
    func fetchData<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response: response)
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Validation
private extension NetworkServiceWithAsync {
    func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkServiceError.httpStatus(httpResponse.statusCode)
        }
    }
}

// MARK: - Errors
enum NetworkServiceError: Error {
    case invalidResponse
    case httpStatus(Int)
}
