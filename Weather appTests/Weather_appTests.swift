import Testing
import Combine
import CoreLocation
import UIKit
@testable import Weather_app

struct Weather_appTests {

    @MainActor
    @Test
    func loadWeather_success_emitsLoadedState() async throws {
        let repository = WeatherRepositoryMock()
        repository.result = .success(Self.makeWeatherData())
        let location = LocationServiceMock()
        let coordinator = CoordinatorMock()
        let viewModel = MainViewModel(
            repository: repository,
            locationService: location,
            coordinator: coordinator
        )

        var states: [MainViewState] = []
        let cancellable = viewModel.statePublisher
            .sink { states.append($0) }

        viewModel.loadWeather()
        location.subject.send(CLLocationCoordinate2D(latitude: 55.75, longitude: 37.61))

        let hasLoaded = await Self.waitUntil {
            states.contains { state in
                if case .loaded = state { return true }
                return false
            }
        }

        #expect(hasLoaded)
        #expect(repository.fetchCallCount == 1)
        #expect(states.contains { state in
            if case .loading = state { return true }
            return false
        })

        guard case let .loaded(content)? = states.last(where: {
            if case .loaded = $0 { return true }
            return false
        }) else {
            Issue.record("Ожидалось состояние .loaded")
            return
        }

        #expect(content.cityTitle == "Moscow")
        #expect(content.temperatureText == "12°C")
        #expect(!content.hourlyItems.isEmpty)
        #expect(content.dailyItems.count == 3)

        cancellable.cancel()
    }

    @MainActor
    @Test
    func loadWeather_locationUnavailable_emitsErrorAndSkipsRepository() async throws {
        let repository = WeatherRepositoryMock()
        repository.result = .success(Self.makeWeatherData())
        let location = LocationServiceMock()
        let coordinator = CoordinatorMock()
        let viewModel = MainViewModel(
            repository: repository,
            locationService: location,
            coordinator: coordinator
        )

        var states: [MainViewState] = []
        let cancellable = viewModel.statePublisher
            .sink { states.append($0) }

        viewModel.loadWeather()
        location.subject.send(nil)

        let hasError = await Self.waitUntil {
            states.contains { state in
                if case .error = state { return true }
                return false
            }
        }

        #expect(hasError)
        #expect(repository.fetchCallCount == 0)

        cancellable.cancel()
    }

    @MainActor
    @Test
    func loadWeather_repositoryFailure_emitsErrorState() async throws {
        let repository = WeatherRepositoryMock()
        repository.result = .failure(TestError.network)
        let location = LocationServiceMock()
        let coordinator = CoordinatorMock()
        let viewModel = MainViewModel(
            repository: repository,
            locationService: location,
            coordinator: coordinator
        )

        var states: [MainViewState] = []
        let cancellable = viewModel.statePublisher
            .sink { states.append($0) }

        viewModel.loadWeather()
        location.subject.send(CLLocationCoordinate2D(latitude: 55.75, longitude: 37.61))

        let hasError = await Self.waitUntil {
            states.contains { state in
                if case .error = state { return true }
                return false
            }
        }

        #expect(hasError)
        #expect(repository.fetchCallCount == 1)

        cancellable.cancel()
    }
}

// MARK: - Helpers
private extension Weather_appTests {
    static func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollNanoseconds: UInt64 = 10_000_000,
        condition: @MainActor () -> Bool
    ) async -> Bool {
        var elapsed: UInt64 = 0
        while elapsed < timeoutNanoseconds {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
            elapsed += pollNanoseconds
        }
        return await condition()
    }

    static func makeWeatherData() -> WeatherData {
        let tz = TimeZone(identifier: "Europe/Moscow") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        let localTime = Date(timeIntervalSince1970: 1_780_000_000)
        let todayStart = calendar.startOfDay(for: localTime)

        let hourly: [HourlyWeather] = (0..<6).compactMap { offset in
            guard let date = calendar.date(byAdding: .hour, value: offset, to: localTime) else {
                return nil
            }
            return HourlyWeather(
                time: date,
                temperatureCelsius: 10 + Double(offset),
                condition: "Облачно"
            )
        }

        let daily: [DailyWeather] = (0..<3).compactMap { dayOffset in
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else {
                return nil
            }
            let dayHours: [HourlyWeather] = (0..<24).compactMap { hourOffset in
                guard let hourDate = calendar.date(byAdding: .hour, value: hourOffset, to: dayDate) else {
                    return nil
                }
                return HourlyWeather(
                    time: hourDate,
                    temperatureCelsius: 5 + Double(hourOffset) * 0.2,
                    condition: "Пасмурно"
                )
            }
            return DailyWeather(
                date: dayDate,
                minTemperatureCelsius: 5,
                maxTemperatureCelsius: 15,
                condition: "Пасмурно",
                hourly: dayHours
            )
        }

        return WeatherData(
            city: "Moscow",
            timezoneID: "Europe/Moscow",
            localTime: localTime,
            current: CurrentWeather(
                temperatureCelsius: 12,
                feelsLikeCelsius: 10,
                condition: "Облачно"
            ),
            hourly: hourly,
            daily: daily
        )
    }
}

// MARK: - Mocks
@MainActor
private final class WeatherRepositoryMock: WeatherRepositoryProtocol {
    var fetchCallCount = 0
    var result: Result<WeatherData, Error> = .failure(TestError.network)

    func fetchWeather(for query: WeatherQuery) -> AnyPublisher<WeatherData, Error> {
        fetchCallCount += 1
        return result.publisher.eraseToAnyPublisher()
    }
}

private final class LocationServiceMock: LocationServiceProtocol {
    let subject = PassthroughSubject<CLLocationCoordinate2D?, Never>()

    func requestLocation() -> AnyPublisher<CLLocationCoordinate2D?, Never> {
        subject.eraseToAnyPublisher()
    }
}

@MainActor
private final class CoordinatorMock: CoordinatorProtocol {
    var navigationController: UINavigationController?
    var assemblyBuilder: AssemblyBuilderProtocol?

    func initialMainViewController() {}
}

private enum TestError: Error {
    case network
}
