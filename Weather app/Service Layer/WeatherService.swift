import Foundation

// MARK: - Localization
fileprivate func localizedStringRU(_ key: String) -> String {
    guard let path = Bundle.main.path(forResource: "ru", ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return key
    }
    return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
}

// MARK: - Protocol
@MainActor
protocol WeatherServiceProtocol {
    func request<T: Decodable>(endpoint: WeatherEndpoint, as type: T.Type) async throws -> T
}

// MARK: - Service
final class WeatherService: WeatherServiceProtocol {

    // MARK: - Dependencies
    private let networkService: NetworkServiceWithAsyncProtocol
    private let apiKey = "fa8b3df74d4042b9aa7135114252304"

    // MARK: - Init
    init(networkService: NetworkServiceWithAsyncProtocol) {
        self.networkService = networkService
    }

    // MARK: - Public
    func request<T: Decodable>(endpoint: WeatherEndpoint, as type: T.Type) async throws -> T {
        guard let url = makeURL(for: endpoint) else {
            throw WeatherServiceError.invalidURL
        }

        do {
            return try await networkService.fetchData(url: url)
        } catch let networkError as NetworkServiceError {
            switch networkError {
            case .invalidResponse:
                throw WeatherServiceError.invalidResponse
            case let .httpStatus(status):
                throw WeatherServiceError.httpStatus(status)
            }
        } catch {
            throw error
        }
    }
}

// MARK: - URL Factory
private extension WeatherService {
    func makeURL(for endpoint: WeatherEndpoint) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.weatherapi.com"
        components.path = "/v1/\(endpoint.path)"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: endpoint.query.qValue),
            URLQueryItem(name: "lang", value: "ru")
        ]

        if let days = endpoint.days {
            queryItems.append(URLQueryItem(name: "days", value: String(days)))
        }

        components.queryItems = queryItems
        return components.url
    }
}

// MARK: - Endpoint
enum WeatherEndpoint {
    case current(query: WeatherQuery)
    case forecast(query: WeatherQuery, days: Int)

    var path: String {
        switch self {
        case .current:
            return "current.json"
        case .forecast:
            return "forecast.json"
        }
    }

    var query: WeatherQuery {
        switch self {
        case let .current(query):
            return query
        case let .forecast(query, _):
            return query
        }
    }

    var days: Int? {
        switch self {
        case .current:
            return nil
        case let .forecast(_, days):
            return days
        }
    }
}

// MARK: - Errors
enum WeatherServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return localizedStringRU("error.invalid_url")
        case .invalidResponse:
            return localizedStringRU("error.invalid_response")
        case let .httpStatus(status):
            return String(format: localizedStringRU("error.http_status"), status)
        }
    }
}

// MARK: - DTO
struct CurrentResponse: Decodable, Sendable {
    let location: LocationDTO
    let current: CurrentDTO
}

struct ForecastResponse: Decodable, Sendable {
    let forecast: ForecastDTO
}

struct LocationDTO: Decodable, Sendable {
    let name: String
    let tzID: String
    let localtimeEpoch: Int

    enum CodingKeys: String, CodingKey {
        case name
        case tzID = "tz_id"
        case localtimeEpoch = "localtime_epoch"
    }
}

struct CurrentDTO: Decodable, Sendable {
    let lastUpdatedEpoch: Int
    let tempC: Double
    let feelsLikeC: Double
    let condition: ConditionDTO

    enum CodingKeys: String, CodingKey {
        case lastUpdatedEpoch = "last_updated_epoch"
        case tempC = "temp_c"
        case feelsLikeC = "feelslike_c"
        case condition
    }
}

struct ForecastDTO: Decodable, Sendable {
    let forecastday: [ForecastDayDTO]
}

struct ForecastDayDTO: Decodable, Sendable {
    let dateEpoch: Int
    let day: DayDTO
    let hour: [HourDTO]

    enum CodingKeys: String, CodingKey {
        case dateEpoch = "date_epoch"
        case day
        case hour
    }
}

struct DayDTO: Decodable, Sendable {
    let maxTempC: Double
    let minTempC: Double
    let condition: ConditionDTO

    enum CodingKeys: String, CodingKey {
        case maxTempC = "maxtemp_c"
        case minTempC = "mintemp_c"
        case condition
    }
}

struct HourDTO: Decodable, Sendable {
    let timeEpoch: Int
    let tempC: Double
    let condition: ConditionDTO

    enum CodingKeys: String, CodingKey {
        case timeEpoch = "time_epoch"
        case tempC = "temp_c"
        case condition
    }
}

struct ConditionDTO: Decodable, Sendable {
    let text: String
}
