import Foundation

/// Visit dates are calendar days, not UTC instants. Keep their day intact when
/// encoding a picker selection or displaying a saved date in another time zone.
public enum PostCalendarDate {
    public static func string(from date: Date, timeZone: TimeZone = .current) -> String {
        formatter(timeZone: timeZone).string(from: date)
    }

    public static func date(from string: String, timeZone: TimeZone = .current) -> Date? {
        let formatter = formatter(timeZone: timeZone)
        guard let date = formatter.date(from: string), formatter.string(from: date) == string else { return nil }
        return date
    }

    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
}
