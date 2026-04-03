import Foundation
import Combine
import CoreLocation

// MARK: - Localization
fileprivate func localizedStringRU(_ key: String) -> String {
    guard let path = Bundle.main.path(forResource: "ru", ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return key
    }
    return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
}

// MARK: - View State
enum MainViewState {
    case idle
    case loading
    case loaded(MainViewContent)
    case error(String)
}

// MARK: - View Data
struct MainViewContent {
    let cityTitle: String
    let localTimeText: String
    let temperatureText: String
    let conditionText: String
    let feelsLikeText: String
    let hourlyItems: [HourlyItemViewData]
    let dailyItems: [DailyItemViewData]
}

struct HourlyItemViewData {
    let timeText: String
    let temperatureText: String
    let conditionText: String
    let isCurrent: Bool
}

struct DailyItemViewData {
    let dayText: String
    let minMaxText: String
    let conditionText: String
    let hourlyItems: [DayHourlyItemViewData]
}

struct DayHourlyItemViewData {
    let timeText: String
    let temperatureText: String
    let conditionText: String
    let isCurrent: Bool
}

// MARK: - Protocol
@MainActor
protocol MainViewModelProtocol: AnyObject {
    var statePublisher: AnyPublisher<MainViewState, Never> { get }
    func loadWeather()
}

// MARK: - ViewModel
@MainActor
final class MainViewModel: MainViewModelProtocol {

    // MARK: - State
    @Published private var state: MainViewState = .idle
    var statePublisher: AnyPublisher<MainViewState, Never> { $state.eraseToAnyPublisher() }

    // MARK: - Dependencies
    private let repository: WeatherRepositoryProtocol
    private let locationService: LocationServiceProtocol

    // MARK: - Combine
    private var currentRequest: AnyCancellable?

    // MARK: - Init
    init(
        repository: WeatherRepositoryProtocol,
        locationService: LocationServiceProtocol
    ) {
        self.repository = repository
        self.locationService = locationService
    }

    // MARK: - Public
    func loadWeather() {
        state = .loading
        currentRequest?.cancel()

        currentRequest = locationService.requestLocation()
            .setFailureType(to: Error.self)
            .timeout(.seconds(4), scheduler: RunLoop.main, customError: { MainViewModelError.locationTimeout })
            .prefix(1)
            .flatMap { [repository] coordinate -> AnyPublisher<WeatherData, Error> in
                let query: WeatherQuery
                if let coordinate {
                    query = .coordinates(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                } else {
                    query = .city(Self.fallbackCityQuery)
                }
                return repository.fetchWeather(for: query)
            }
            .map { Self.mapToContent($0) }
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case let .failure(error) = completion {
                    self.state = .error(error.localizedDescription)
                }
            } receiveValue: { [weak self] content in
                self?.state = .loaded(content)
            }
    }
}

private enum MainViewModelError: Error {
    case locationTimeout
}

extension MainViewModelError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .locationTimeout:
            return localizedStringRU("error.location_timeout")
        }
    }
}

// MARK: - Mapping
private extension MainViewModel {
    static var fallbackCityQuery: String {
        let value = localizedStringRU("weather.fallback_city_query").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Moscow" : value
    }

    nonisolated private static func mapToContent(_ weather: WeatherData) -> MainViewContent {
        let tz = TimeZone(identifier: weather.timezoneID) ?? .current

        let localTimeFormatter = DateFormatter()
        localTimeFormatter.timeZone = tz
        localTimeFormatter.locale = Locale(identifier: "ru_RU")
        localTimeFormatter.dateStyle = .none
        localTimeFormatter.timeStyle = .short

        let hourFormatter = DateFormatter()
        hourFormatter.timeZone = tz
        hourFormatter.locale = Locale(identifier: "ru_RU")
        hourFormatter.dateFormat = "HH:mm"

        let dayFormatter = DateFormatter()
        dayFormatter.timeZone = tz
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "EEE, d MMM"

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let currentHourDate = calendar.date(
            bySettingHour: calendar.component(.hour, from: weather.localTime),
            minute: 0,
            second: 0,
            of: weather.localTime
        ) ?? weather.localTime
        let todayStart = calendar.startOfDay(for: weather.localTime)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        var didShowTomorrowMarker = false

        let hourlyItems = weather.hourly.enumerated().map { index, hourly -> HourlyItemViewData in
            let baseTime = hourFormatter.string(from: hourly.time)
            let isTomorrow = calendar.isDate(hourly.time, inSameDayAs: tomorrowStart)
            let timeText: String

            if isTomorrow && !didShowTomorrowMarker {
                didShowTomorrowMarker = true
                timeText = "\(localizedStringRU("weather.tomorrow"))\n\(baseTime)"
            } else {
                timeText = baseTime
            }

            return HourlyItemViewData(
                timeText: timeText,
                temperatureText: "\(Int(round(hourly.temperatureCelsius)))°",
                conditionText: hourly.condition,
                isCurrent: index == 0
            )
        }

        let dailyItems = weather.daily.map {
            DailyItemViewData(
                dayText: dayFormatter.string(from: $0.date),
                minMaxText: "\(Int(round($0.minTemperatureCelsius)))° / \(Int(round($0.maxTemperatureCelsius)))°",
                conditionText: $0.condition,
                hourlyItems: $0.hourly.map { hour in
                    DayHourlyItemViewData(
                        timeText: hourFormatter.string(from: hour.time),
                        temperatureText: "\(Int(round(hour.temperatureCelsius)))°",
                        conditionText: hour.condition,
                        isCurrent: calendar.isDate(hour.time, equalTo: currentHourDate, toGranularity: .hour)
                    )
                }
            )
        }

        return MainViewContent(
            cityTitle: weather.city,
            localTimeText: String(
                format: localizedStringRU("weather.local_time"),
                localTimeFormatter.string(from: weather.localTime)
            ),
            temperatureText: "\(Int(round(weather.current.temperatureCelsius)))°C",
            conditionText: weather.current.condition,
            feelsLikeText: String(
                format: localizedStringRU("weather.feels_like"),
                Int(round(weather.current.feelsLikeCelsius))
            ),
            hourlyItems: hourlyItems,
            dailyItems: dailyItems
        )
    }
}
