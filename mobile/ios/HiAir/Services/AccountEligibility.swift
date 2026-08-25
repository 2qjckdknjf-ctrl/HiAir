import Foundation

enum AccountEligibility {
    static let minimumAgeYears = 13

    static var youngestAllowedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -minimumAgeYears, to: Date()) ?? Date()
    }

    static func isEligible(dateOfBirth: Date, now: Date = Date()) -> Bool {
        let years = Calendar.current.dateComponents([.year], from: dateOfBirth, to: now).year ?? 0
        return years >= minimumAgeYears
    }
}
