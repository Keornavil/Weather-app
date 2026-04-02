import Foundation

// MARK: - Domain Models
struct WeatherData {
    let city: String
    let timezoneID: String
    let localTime: Date
    let current: CurrentWeather
    let hourly: [HourlyWeather]
    let daily: [DailyWeather]
}

struct CurrentWeather {
    let temperatureCelsius: Double
    let feelsLikeCelsius: Double
    let condition: String
}

struct HourlyWeather {
    let time: Date
    let temperatureCelsius: Double
    let condition: String
}

struct DailyWeather {
    let date: Date
    let minTemperatureCelsius: Double
    let maxTemperatureCelsius: Double
    let condition: String
    let hourly: [HourlyWeather]
}

// MARK: - Query
enum WeatherQuery {
    case city(String)
    case coordinates(latitude: Double, longitude: Double)

    // MARK: - Derived Values
    var qValue: String {
        switch self {
        case let .city(name):
            return name
        case let .coordinates(latitude, longitude):
            return "\(latitude),\(longitude)"
        }
    }
}
