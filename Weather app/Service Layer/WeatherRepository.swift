import Foundation
import Combine

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
protocol WeatherRepositoryProtocol {
    func fetchWeather(for query: WeatherQuery) -> AnyPublisher<WeatherData, Error>
}

// MARK: - Repository
@MainActor
final class WeatherRepository: WeatherRepositoryProtocol {

    // MARK: - Dependencies
    private let service: WeatherServiceProtocol

    // MARK: - Init
    init(service: WeatherServiceProtocol) {
        self.service = service
    }

    // MARK: - Public
    func fetchWeather(for query: WeatherQuery) -> AnyPublisher<WeatherData, Error> {
        Future<WeatherData, Error> { [service] promise in
            Task { @MainActor in
                do {
                    let currentResponse: CurrentResponse = try await service.request(
                        endpoint: .current(query: query),
                        as: CurrentResponse.self
                    )
                    let forecastResponse: ForecastResponse = try await service.request(
                        endpoint: .forecast(query: query, days: 3),
                        as: ForecastResponse.self
                    )

                    let weather = try Self.makeDomainModel(
                        current: currentResponse,
                        forecast: forecastResponse
                    )
                    promise(.success(weather))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Mapping
private extension WeatherRepository {
    private static func makeDomainModel(current: CurrentResponse, forecast: ForecastResponse) throws -> WeatherData {
        guard let today = forecast.forecast.forecastday.first else {
            throw WeatherRepositoryError.emptyForecast
        }

        let timezoneID = current.location.tzID
        let nowDate = Date(timeIntervalSince1970: TimeInterval(current.location.localtimeEpoch))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneID) ?? .current
        let currentHourStart = calendar.dateInterval(of: .hour, for: nowDate)?.start ?? nowDate
        let currentHourStartEpoch = Int(currentHourStart.timeIntervalSince1970)

        let todayHours = today.hour
            .filter { $0.timeEpoch >= currentHourStartEpoch }
            .map {
                HourlyWeather(
                    time: Date(timeIntervalSince1970: TimeInterval($0.timeEpoch)),
                    temperatureCelsius: $0.tempC,
                    condition: $0.condition.text
                )
            }

        let tomorrowHours = forecast.forecast.forecastday
            .dropFirst()
            .first?
            .hour
            .map {
                HourlyWeather(
                    time: Date(timeIntervalSince1970: TimeInterval($0.timeEpoch)),
                    temperatureCelsius: $0.tempC,
                    condition: $0.condition.text
                )
            } ?? []

        let daily = forecast.forecast.forecastday.prefix(3).map {
            DailyWeather(
                date: Date(timeIntervalSince1970: TimeInterval($0.dateEpoch)),
                minTemperatureCelsius: $0.day.minTempC,
                maxTemperatureCelsius: $0.day.maxTempC,
                condition: $0.day.condition.text,
                hourly: $0.hour.map { hour in
                    HourlyWeather(
                        time: Date(timeIntervalSince1970: TimeInterval(hour.timeEpoch)),
                        temperatureCelsius: hour.tempC,
                        condition: hour.condition.text
                    )
                }
            )
        }

        return WeatherData(
            city: current.location.name,
            timezoneID: timezoneID,
            localTime: nowDate,
            current: CurrentWeather(
                temperatureCelsius: current.current.tempC,
                feelsLikeCelsius: current.current.feelsLikeC,
                condition: current.current.condition.text
            ),
            hourly: todayHours + tomorrowHours,
            daily: daily
        )
    }
}

// MARK: - Errors
enum WeatherRepositoryError: LocalizedError {
    case emptyForecast

    var errorDescription: String? {
        switch self {
        case .emptyForecast:
            return localizedStringRU("error.empty_forecast")
        }
    }
}
