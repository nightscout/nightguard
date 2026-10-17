import Foundation

enum ReportPeriod: Int, CaseIterable, Identifiable {
    case day = 1, week = 7, month = 30, threeMonths = 90

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .day: return NSLocalizedString("1 day", comment: "Report period")
        case .week: return NSLocalizedString("1 week", comment: "Report period")
        case .month: return NSLocalizedString("1 month", comment: "Report period")
        case .threeMonths: return NSLocalizedString("3 months", comment: "Report period")
        }
    }
}

struct ReportSettings: Codable {
    var name = ""
    var birthDate: Date?
    var diabetesSince = ""
    var insulin = ""
    var period = ReportPeriod.week.rawValue

    static func load() -> ReportSettings {
        guard let data = UserDefaults.standard.data(forKey: "report.settings"),
              let settings = try? JSONDecoder().decode(ReportSettings.self, from: data) else { return ReportSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "report.settings")
        }
    }
}

struct ReportRequest {
    let settings: ReportSettings
    let calendar: Calendar
    let start: Date
    let end: Date
    let low: Double
    let high: Double
    let unit: Units
    let locale: Locale
    static let targetLow = 80.0
    static let targetHigh = 180.0
    static let mmolFactor = 18.0182

    init(settings: ReportSettings, timeZone: TimeZone = .current, now: Date = Date(), unit: Units? = nil, locale: Locale = .current) {
        self.settings = settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        self.end = today
        self.start = calendar.date(byAdding: .day, value: -(ReportPeriod(rawValue: settings.period) ?? .week).rawValue, to: today)!
        self.low = Self.targetLow
        self.high = Self.targetHigh
        self.unit = unit ?? UserDefaultsRepository.units.value
        self.locale = locale
    }

    var days: [Date] {
        let count = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func dateText(_ date: Date, format: String = "dd.MM.yyyy") -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    var rangeText: String {
        "\(dateText(start)) – \(dateText(calendar.date(byAdding: .day, value: -1, to: end)!))"
    }

    func displayValue(_ value: Double) -> Double { unit == .mmol ? value / Self.mmolFactor : value }

    var glucoseUnit: String { unit == .mmol ? "mmol/L" : "mg/dL" }
    func displayGlucose(_ value: Double) -> String {
        ReportFormatting.number(displayValue(value), digits: unit == .mmol ? 1 : 0, locale: locale)
    }
}

struct ReportGlucose {
    let date: Date
    let value: Double
    let isMeter: Bool
}

struct ReportTreatment {
    let date: Date
    let kind: String
    var carbs: Double
    var insulin: Double
    let duration: Double
    let rate: Double?
    let percent: Double?
    let profileName: String?
    var isSMB = false
    var targetLow: Double?
    var targetHigh: Double?
}

struct ReportSchedulePoint {
    let minutes: Int
    let value: Double
}

struct ReportProfile {
    let name: String
    let isDefault: Bool
    let effectiveAt: Date
    let timeZone: TimeZone
    let dia: Double?
    let carbsPerHour: Double?
    let basal: [ReportSchedulePoint]
    let carbRatio: [ReportSchedulePoint]
    let sensitivity: [ReportSchedulePoint]
    let targetLow: [ReportSchedulePoint]
    let targetHigh: [ReportSchedulePoint]

    func value(_ schedule: [ReportSchedulePoint], at date: Date) -> Double? {
        guard !schedule.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return schedule.last(where: { $0.minutes <= minute })?.value ?? schedule.last?.value
    }
}

struct ReportDataset {
    let readings: [ReportGlucose]
    let treatments: [ReportTreatment]
    let profiles: [ReportProfile]
}

struct ReportDistribution {
    let low: Int
    let inRange: Int
    let high: Int
    var count: Int { low + inRange + high }
    enum Band: Int { case low, inRange, high }

    // Largest remainders preserve a total of 100% without altering the counts.
    func percent(_ band: Band) -> String {
        guard count > 0 else { return "–" }
        let exact = [low, inRange, high].map { 100 * Double($0) / Double(count) }
        var rounded = exact.map { Int(floor($0)) }
        let order = exact.indices.sorted {
            let lhs = exact[$0] - Double(rounded[$0]), rhs = exact[$1] - Double(rounded[$1])
            return lhs == rhs ? $0 < $1 : lhs > rhs
        }
        for index in order.prefix(100 - rounded.reduce(0, +)) { rounded[index] += 1 }
        return "\(rounded[band.rawValue])%"
    }
}

struct ReportDay {
    let date: Date
    let readings: [ReportGlucose]
    let treatments: [ReportTreatment]
    let distribution: ReportDistribution
    let carbs: Double
    let bolus: Double
    let basalSeries: [ReportBasalPoint]
    let basal: Double?
    let profileBasal: Double?
    let mean: Double?
    var targetSeries: [ReportTargetPoint] = []
    var totalInsulin: Double? { basal.map { $0 + bolus } }
}

struct ReportBasalPoint {
    let date: Date
    let end: Date
    let profileName: String
    let profileRate: Double
    let deliveredRate: Double
}

struct ReportAnalysis {
    let days: [ReportDay]
    let readings: [ReportGlucose]
    let distribution: ReportDistribution
    let standardDistribution: ReportDistribution
    let min: Double?
    let max: Double?
    let mean: Double?
    let sd: Double?
    let gvi: Double?
    let pgs: Double?
    let gri: Double?
    let tor: Double?
    let hypoIntensity: Double?
    let hyperIntensity: Double?
    let pgr: Double?
    let profiles: [ReportProfile]
    let changeCounts: [String: Int]
}

struct ReportTargetPoint {
    let date: Date
    let end: Date
    let low: Double
    let high: Double
}

struct ReportAnnotation {
    let date: Date
    var value: Double
    var count: Int
}

enum ReportFormatting {
    static var insulinUnit: String { NSLocalizedString("Report insulin unit", comment: "Insulin unit in PDF") }

    static func number(_ value: Double?, digits: Int, locale: Locale = .current) -> String {
        guard let value = value, value.isFinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfUp
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? "–"
    }
}
