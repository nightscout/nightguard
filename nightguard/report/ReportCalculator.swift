import Foundation

enum ReportCalculator {
    static func calculate(_ data: ReportDataset, request: ReportRequest) -> ReportAnalysis {
        let sensors = normalizedReadings(data.readings, request: request)
        let values = sensors.map(\.value)
        let distribution = classify(values, low: request.low, high: request.high)
        let standard = classify(values, low: 70, high: 180)
        let mean = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        let sd = mean.map { center in sqrt(values.reduce(0) { $0 + pow($1 - center, 2) } / Double(values.count)) }
        let meters = data.readings.filter(\.isMeter)
        let days = request.days.map { dayStart -> ReportDay in
            let dayEnd = request.calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let dayReadings = (sensors + meters).filter { $0.date >= dayStart && $0.date < dayEnd }.sorted { $0.date < $1.date }
            let daySensors = dayReadings.filter { !$0.isMeter }
            let events = normalizedTreatments(data.treatments.filter { $0.date >= dayStart && $0.date < dayEnd })
            let carbs = events.reduce(0) { $0 + $1.carbs }
            let bolus = events.reduce(0) { $0 + $1.insulin }
            let basalSeries = basalSeriesForDay(dayStart, end: dayEnd, profiles: data.profiles, treatments: data.treatments) ?? []
            let profileBasal = basalSeries.isEmpty ? nil : basalSeries.reduce(0) { $0 + $1.profileRate * $1.end.timeIntervalSince($1.date) / 3600 }
            let basal = basalSeries.isEmpty ? nil : basalSeries.reduce(0) { $0 + $1.deliveredRate * $1.end.timeIntervalSince($1.date) / 3600 }
            return ReportDay(date: dayStart, readings: dayReadings, treatments: events,
                             distribution: classify(daySensors.map(\.value), low: request.low, high: request.high),
                             carbs: carbs, bolus: bolus, basalSeries: basalSeries, basal: basal, profileBasal: profileBasal,
                             mean: daySensors.isEmpty ? nil : daySensors.reduce(0) { $0 + $1.value } / Double(daySensors.count),
                             targetSeries: targetSeriesForDay(dayStart, end: dayEnd, profiles: data.profiles, treatments: data.treatments))
        }

        // Nightscout Reporter computes GVI from consecutive five-minute samples.
        // Resampling first prevents one-minute sensors from inflating the result.
        let samples = sensors
        var path = 0.0
        var pairs = 0
        var pathGlucose = samples.first?.value ?? 0
        for index in samples.indices.dropFirst() {
            let interval = samples[index].date.timeIntervalSince(samples[index - 1].date)
            if interval > 0 && interval <= 6 * 60 {
                path += hypot(5, samples[index].value - samples[index - 1].value)
                pairs += 1
                pathGlucose += samples[index].value
            }
        }
        let gvi: Double?
        if pairs > 0, let first = samples.first, let last = samples.last {
            gvi = path / hypot(Double(pairs * 5), last.value - first.value)
        } else { gvi = nil }
        let pgs = gvi.flatMap { gvi -> Double? in
            guard pairs > 0, standard.count > 0 else { return nil }
            return gvi * (pathGlucose / Double(pairs)) * (1 - Double(standard.inRange) / Double(standard.count))
        }
        let gri: Double?
        if values.isEmpty { gri = nil } else {
            let fraction = 100 / Double(values.count)
            gri = fraction * (3 * Double(values.filter { $0 < 54 }.count) +
                              2.4 * Double(values.filter { $0 >= 54 && $0 < 70 }.count) +
                              0.8 * Double(values.filter { $0 >= 180 && $0 < 250 }.count) +
                              1.6 * Double(values.filter { $0 > 250 }.count))
        }
        // CGP uses the reporter's clinical analysis range, independently of the
        // wider low/high alert bounds configured in Nightguard.
        let cgpLow = ReportRequest.targetLow
        let cgpHigh = ReportRequest.targetHigh
        let tor = values.isEmpty ? nil : 1440 * Double(values.filter { $0 < cgpLow || $0 > cgpHigh }.count) / Double(values.count)
        let intensity = cgpIntensity(samples, low: cgpLow, high: cgpHigh, request: request)
        let variation = mean.flatMap { $0 > 0 ? (sd ?? 0) / $0 * 100 : nil }
        let cgpValues = [tor, variation, intensity.0, intensity.1, mean]
        let pgr: Double?
        if cgpValues.allSatisfy({ $0 != nil }) {
            let radii = zip(cgpValues, [0, 1, 2, 3, 4]).map { scaleCGP($0.0!, axis: $0.1) }
            let healthy = cgpReference.enumerated().map { scaleCGP($0.element, axis: $0.offset) }
            pgr = polygonArea(radii) / polygonArea(healthy)
        } else { pgr = nil }
        var counts: [String: Int] = [:]
        for treatment in data.treatments where treatment.date >= request.start && treatment.date < request.end {
            counts[treatment.kind.lowercased(), default: 0] += 1
        }
        // Reporter includes the change in the lookback day that established the
        // reservoir and cannula in use at the start of the selected period.
        for kind in ["insulin change", "site change"] {
            if data.treatments.contains(where: { $0.kind.lowercased() == kind && $0.date < request.start }) {
                counts[kind, default: 0] += 1
            }
        }
        return ReportAnalysis(days: days, readings: sensors, distribution: distribution,
                              standardDistribution: standard, min: values.min(), max: values.max(), mean: mean, sd: sd,
                              gvi: gvi, pgs: pgs, gri: gri, tor: tor, hypoIntensity: intensity.0,
                              hyperIntensity: intensity.1, pgr: pgr, profiles: data.profiles, changeCounts: counts)
    }

    static func classify(_ values: [Double], low: Double, high: Double) -> ReportDistribution {
        ReportDistribution(low: values.filter { $0 < low }.count,
                           inRange: values.filter { $0 >= low && $0 < high }.count,
                           high: values.filter { $0 >= high }.count)
    }

    static func percentiles(_ readings: [ReportGlucose], calendar: Calendar) -> [(Int, [Double])] {
        var bins: [Int: [Double]] = [:]
        for entry in readings where !entry.isMeter {
            let components = calendar.dateComponents([.hour, .minute], from: entry.date)
            let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            bins[(minute / 5) * 5, default: []].append(entry.value)
        }
        return bins.keys.sorted().compactMap { minute in
            guard let values = bins[minute], !values.isEmpty else { return nil }
            let sorted = values.sorted()
            return (minute, [10.0, 25, 50, 75, 90].map { percentile(sorted, $0) })
        }
    }

    // Clear each duplicated field independently: a wizard can contain valid carbs
    // alongside a bolus that was already recorded by the pump.
    static func normalizedTreatments(_ events: [ReportTreatment]) -> [ReportTreatment] {
        events.map { event in
            var result = event
            for field in [\ReportTreatment.carbs, \ReportTreatment.insulin] {
                let value = event[keyPath: field]
                let duplicated = event.kind.lowercased() == "bolus wizard" && events.contains { other in
                    other.kind.lowercased() != "bolus wizard" &&
                    abs(other.date.timeIntervalSince(event.date)) <= 120 &&
                    abs(other[keyPath: field] - value) < 0.01
                }
                result[keyPath: field] = value.isFinite && value > 0 && !duplicated ? value : 0
            }
            return result
        }.sorted { $0.date < $1.date }
    }

    static func annotations(_ events: [ReportTreatment], field: KeyPath<ReportTreatment, Double>) -> [ReportAnnotation] {
        var groups: [ReportAnnotation] = []
        for event in events.sorted(by: { $0.date < $1.date }) where event[keyPath: field] > 0 {
            if let last = groups.last, event.date.timeIntervalSince(last.date) < 3600 {
                groups[groups.count - 1].value += event[keyPath: field]
                groups[groups.count - 1].count += 1
            } else {
                groups.append(ReportAnnotation(date: event.date, value: event[keyPath: field], count: 1))
            }
        }
        return groups
    }

    static func targetSeriesForDay(_ start: Date, end: Date, profiles: [ReportProfile], treatments: [ReportTreatment]) -> [ReportTargetPoint] {
        let events = treatments.filter {
            $0.date < end && ["temporary target", "profile switch"].contains($0.kind.lowercased())
        }.sorted { $0.date < $1.date }
        var boundaries: Set<Date> = [start, end]
        var cursor = start
        while cursor < end { boundaries.insert(cursor); cursor = cursor.addingTimeInterval(60) }
        for profile in profiles where profile.effectiveAt > start && profile.effectiveAt < end {
            boundaries.insert(profile.effectiveAt)
        }
        for event in events {
            if event.date > start { boundaries.insert(event.date) }
            let expiry = event.date.addingTimeInterval(event.duration * 60)
            if expiry > start && expiry < end { boundaries.insert(expiry) }
        }
        let times = boundaries.sorted()
        var result: [ReportTargetPoint] = []
        var eventIndex = 0
        var temporary: ReportTreatment?
        var switchName: String?
        for index in times.indices.dropLast() {
            let date = times[index]
            while eventIndex < events.count && events[eventIndex].date <= date {
                let event = events[eventIndex]
                if event.kind.lowercased() == "temporary target" { temporary = event }
                else { switchName = event.profileName }
                eventIndex += 1
            }
            let profile = activeProfile(at: date, profiles: profiles, switchName: switchName)
            var low = profile.flatMap { $0.value($0.targetLow, at: date) }
            var high = profile.flatMap { $0.value($0.targetHigh, at: date) }
            if let temp = temporary, temp.duration > 0,
               temp.date.addingTimeInterval(temp.duration * 60) > date,
               let bottom = temp.targetLow, let top = temp.targetHigh,
               bottom.isFinite, top.isFinite, bottom > 0, top >= bottom {
                low = bottom; high = top
            }
            guard let bottom = low, let top = high, bottom.isFinite, top.isFinite,
                  bottom > 0, top >= bottom else { continue }
            if let last = result.last, last.end == date, last.low == bottom, last.high == top {
                result[result.count - 1] = ReportTargetPoint(date: last.date, end: times[index + 1], low: bottom, high: top)
            } else {
                result.append(ReportTargetPoint(date: date, end: times[index + 1], low: bottom, high: top))
            }
        }
        return result
    }

    private static func percentile(_ sorted: [Double], _ percent: Double) -> Double {
        let position = percent / 100 * Double(sorted.count - 1)
        let lower = Int(position)
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }

    // Reporter uses minute-aligned, interpolated five-minute values (not bucket averages).
    // Preserve gaps of 16 minutes or more and never extrapolate beyond observed data.
    static func normalizedReadings(_ readings: [ReportGlucose], request: ReportRequest) -> [ReportGlucose] {
        let raw = readings.filter { !$0.isMeter && $0.value.isFinite && $0.value > 10 }
            .sorted { $0.date < $1.date }
        guard let first = raw.first, let last = raw.last else { return [] }
        func minuteDate(_ date: Date) -> Date {
            Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60)
        }
        var result: [ReportGlucose] = []
        var index = 0
        var target = request.start
        let firstMinute = minuteDate(first.date)
        if target < firstMinute {
            if firstMinute.timeIntervalSince(target) < 16 * 60 {
                result.append(ReportGlucose(date: target, value: first.value, isMeter: false))
            }
            target = target.addingTimeInterval(ceil(firstMinute.timeIntervalSince(target) / 300) * 300)
        }
        while target < request.end && target <= minuteDate(last.date) {
            while index + 1 < raw.count && minuteDate(raw[index + 1].date) <= target { index += 1 }
            let previous = raw[index]
            let previousDate = minuteDate(previous.date)
            if previousDate == target {
                result.append(ReportGlucose(date: target, value: previous.value, isMeter: false))
            } else if index + 1 < raw.count {
                let next = raw[index + 1]
                let nextDate = minuteDate(next.date)
                let interval = nextDate.timeIntervalSince(previousDate)
                if previousDate < target && interval > 0 && interval < 16 * 60 {
                    let fraction = target.timeIntervalSince(previousDate) / interval
                    let value = previous.value + floor((next.value - previous.value) * fraction)
                    result.append(ReportGlucose(date: target, value: value, isMeter: false))
                }
            }
            target = target.addingTimeInterval(300)
        }
        return result
    }

    static func basalSeriesForDay(_ start: Date, end: Date, profiles: [ReportProfile], treatments: [ReportTreatment]) -> [ReportBasalPoint]? {
        guard !profiles.isEmpty else { return nil }
        // Nightscout Reporter starts its daily basal profile from the profile's
        // midnight schedule and applies that day's temp basal events. A temp
        // started the previous evening is therefore not carried into the day.
        let events = treatments.filter { $0.date >= start && $0.date < end }.sorted { $0.date < $1.date }
        // Integrate on exact event boundaries. A five-minute sampling grid can miss
        // short suspensions, cancellations and rate changes and distort daily totals.
        var boundaries: Set<Date> = [start, end]
        for event in events where event.kind.lowercased() == "temp basal" || event.kind.lowercased() == "profile switch" || event.kind.lowercased() == "pump suspend" || event.kind.lowercased() == "pump resume" {
            if event.date > start && event.date < end { boundaries.insert(event.date) }
            if event.kind.lowercased() == "temp basal" {
                let expiry = event.date.addingTimeInterval(event.duration * 60)
                if expiry > start && expiry < end { boundaries.insert(expiry) }
            }
        }
        for profile in profiles {
            if profile.effectiveAt > start && profile.effectiveAt < end { boundaries.insert(profile.effectiveAt) }
        }
        // Minute boundaries include all profile schedule changes and DST transitions.
        var minute = start
        while minute < end { boundaries.insert(minute); minute = minute.addingTimeInterval(60) }
        let sorted = boundaries.sorted()
        var series: [ReportBasalPoint] = []
        var eventIndex = 0
        var latestTemp: ReportTreatment?
        var switchName: String?
        var suspended = false
        for index in sorted.indices.dropLast() {
            let cursor = sorted[index], next = sorted[index + 1]
            while eventIndex < events.count && events[eventIndex].date <= cursor {
                let event = events[eventIndex]
                switch event.kind.lowercased() {
                case "temp basal": latestTemp = event
                case "profile switch": switchName = event.profileName
                case "pump suspend": suspended = true
                case "pump resume": suspended = false
                default: break
                }
                eventIndex += 1
            }
            guard let profile = activeProfile(at: cursor, profiles: profiles, switchName: switchName),
                  let base = profile.value(profile.basal, at: cursor) else { return nil }
            var rate = base
            // Only the most recent temp is eligible. A cancellation must not revive
            // an earlier overlapping temp, even when that earlier duration remains.
            if let temp = latestTemp,
               temp.duration > 0, temp.date.addingTimeInterval(temp.duration * 60) > cursor {
                if let percent = temp.percent { rate = base * (1 + percent / 100) }
                else if let absolute = temp.rate { rate = absolute }
            }
            if suspended { rate = 0 }
            series.append(ReportBasalPoint(date: cursor, end: next, profileName: profile.name,
                                           profileRate: max(0, base), deliveredRate: max(0, rate)))
        }
        return series
    }

    private static func activeProfile(at date: Date, profiles: [ReportProfile], switchName: String?) -> ReportProfile? {
        guard let latestStart = profiles.last(where: { $0.effectiveAt <= date })?.effectiveAt else { return nil }
        let current = profiles.filter { $0.effectiveAt == latestStart }
        if let switchName = switchName, let switched = current.first(where: { $0.name == switchName }) { return switched }
        return current.first(where: { $0.isDefault }) ?? current.first
    }

    private static func cgpIntensity(_ samples: [ReportGlucose], low: Double, high: Double, request: ReportRequest) -> (Double?, Double?) {
        guard !samples.isEmpty, !request.days.isEmpty else { return (nil, nil) }
        var hypo = 0.0, hyper = 0.0
        for day in request.days {
            let end = request.calendar.date(byAdding: .day, value: 1, to: day)!
            let daily = samples.filter { $0.date >= day && $0.date < end }
            let lows = daily.filter { $0.value <= low }
            let highs = daily.filter { $0.value >= high }
            hypo += hypot(lows.reduce(0) { $0 + (low - $1.value) * 5 }, Double(lows.count * 5)) / 1000
            hyper += hypot(highs.reduce(0) { $0 + $1.value * 5 }, Double(highs.count * 5)) / 1000
        }
        return (hypo / Double(request.days.count), hyper / Double(request.days.count))
    }

    static let cgpReference = [0.0, 16.7, 0.0, 0.0, 90.0]

    static func scaleCGP(_ value: Double, axis: Int) -> Double {
        switch axis {
        case 0: return pow(max(0, value) * 0.00614, 1.581) + 14
        case 1: return max(0, value - 17) * 0.92 + 14
        case 2: return exp(max(0, value) * 0.57) + 13
        case 3: return pow(max(0, value) * 0.115, 1.51) + 14
        default: return pow(max(0, value - 90) * 0.0217, 2.63) + 14
        }
    }

    private static func polygonArea(_ radii: [Double]) -> Double {
        guard radii.count == 5 else { return 0 }
        return (0..<5).reduce(0) { $0 + radii[$1] * radii[($1 + 1) % 5] * sin(2 * .pi / 5) / 2 }
    }
}
