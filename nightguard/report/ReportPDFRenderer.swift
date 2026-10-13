import UIKit

final class ReportPDFRenderer {
    private let portrait = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let landscape = CGRect(x: 0, y: 0, width: 842, height: 595)
    private let green = UIColor(red: 0.04, green: 0.50, blue: 0.12, alpha: 1)
    private let blue = UIColor(red: 0.04, green: 0.31, blue: 0.83, alpha: 1)
    private let orange = UIColor(red: 0.95, green: 0.57, blue: 0.17, alpha: 1)

    private var locale = Locale.current
    private var continuation: (() -> Void)?
    private var insulinUnit: String { ReportFormatting.insulinUnit }

    func render(request: ReportRequest, analysis: ReportAnalysis) throws -> URL {
        locale = request.locale
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "Nightguard Report \(request.rangeText)",
                               kCGPDFContextCreator as String: "Nightguard"]
        let renderer = UIGraphicsPDFRenderer(bounds: portrait, format: format)
        let data = renderer.pdfData { pdf in
            summary(pdf, request: request, analysis: analysis)
            profiles(pdf, request: request, analysis: analysis)
            percentilePage(pdf, request: request, analysis: analysis)
            dailyPages(pdf, request: request, analysis: analysis)
            pentagonPage(pdf, request: request, analysis: analysis)
            comparisonPages(pdf, request: request, analysis: analysis)
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NightguardReport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let first = request.dateText(request.start, format: "yyyy-MM-dd")
        let last = request.dateText(request.end.addingTimeInterval(-1), format: "yyyy-MM-dd")
        let url = folder.appendingPathComponent("Nightguard-Report-\(first)-to-\(last).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func page(_ pdf: UIGraphicsPDFRendererContext, title: String, request: ReportRequest, landscape isLandscape: Bool = false) -> CGRect {
        let bounds = isLandscape ? landscape : portrait
        pdf.beginPage(withBounds: bounds, pageInfo: [:])
        let titleWidth = (title as NSString).size(withAttributes: [.font: UIFont.boldSystemFont(ofSize: 26)]).width
        let titleSize = min(26, 26 * (bounds.width - 64) / max(1, titleWidth))
        text(title, x: 32, y: 22, width: bounds.width - 64, size: titleSize, color: green, bold: true)
        text(request.rangeText, x: 32, y: 58, width: bounds.width - 64, size: 10, color: .darkGray)
        line(x1: 32, y1: 74, x2: bounds.width - 32, y2: 74, color: green, width: 2)
        line(x1: 32, y1: bounds.height - 39, x2: bounds.width - 32, y2: bounds.height - 39, color: green)
        text("Nightguard • \(request.settings.name)", x: 32, y: bounds.height - 31, width: bounds.width - 64, size: 8, color: .gray)
        text(NSLocalizedString("All information is provided without warranty. Not for medical decisions.", comment: "PDF disclaimer"),
             x: 32, y: bounds.height - 19, width: bounds.width - 64, size: 7, color: .gray)
        return bounds
    }

    private func summary(_ pdf: UIGraphicsPDFRendererContext, request: ReportRequest, analysis: ReportAnalysis) {
        _ = page(pdf, title: NSLocalizedString("Report summary", comment: "PDF section"), request: request)
        continuation = { [self] in
            _ = page(pdf, title: NSLocalizedString("Report summary", comment: "PDF section"), request: request)
        }
        defer { continuation = nil }
        var y: CGFloat = 92
        if !request.settings.name.isEmpty { row(NSLocalizedString("Name", comment: "Report"), request.settings.name, y: &y) }
        if let birth = request.settings.birthDate { row(NSLocalizedString("Date of birth", comment: "Report"), request.dateText(birth), y: &y) }
        if !request.settings.diabetesSince.isEmpty { row(NSLocalizedString("Diabetes since", comment: "Report"), request.settings.diabetesSince, y: &y) }
        if !request.settings.insulin.isEmpty { row(NSLocalizedString("Insulin", comment: "Report"), request.settings.insulin, y: &y) }
        section(NSLocalizedString("Data coverage", comment: "Report"), y: &y)
        row(NSLocalizedString("Report days", comment: "Report"), "\(analysis.days.count)", y: &y)
        row(NSLocalizedString("Glucose readings", comment: "Report"), "\(analysis.readings.count)", y: &y)
        if !analysis.readings.isEmpty {
            row(NSLocalizedString("Average measurement interval", comment: "Report"),
                "\(number(request.end.timeIntervalSince(request.start) / 60 / Double(analysis.readings.count), 1)) min", y: &y)
        }
        let changeLabels = [("Insulin Change", NSLocalizedString("Reservoir changes", comment: "Report")),
                            ("Site Change", NSLocalizedString("Cannula changes", comment: "Report")),
                            ("Sensor Change", NSLocalizedString("Sensor changes", comment: "Report"))]
        for item in changeLabels {
            let count = analysis.changeCounts[item.0.lowercased(), default: 0] +
                (item.0 == "Sensor Change" ? analysis.changeCounts["sensor start", default: 0] : 0)
            row(item.1, "\(count)", y: &y)
        }
        section(NSLocalizedString("Report target range", comment: "Report"), y: &y)
        distributionRows(analysis.distribution, low: request.low, high: request.high, request: request, y: &y)
        section(NSLocalizedString("Standard range", comment: "Report"), y: &y)
        distributionRows(analysis.standardDistribution, low: 70, high: 180, request: request, y: &y)
        section(NSLocalizedString("Glucose and risk", comment: "Report"), y: &y)
        row(NSLocalizedString("Minimum / maximum", comment: "Report"), "\(glucose(analysis.min, request)) / \(glucose(analysis.max, request)) \(request.glucoseUnit)", y: &y)
        row(NSLocalizedString("Mean / standard deviation", comment: "Report"), "\(glucose(analysis.mean, request)) / \(number(analysis.sd.map { request.unit == .mmol ? $0 / ReportRequest.mmolFactor : $0 }, 1)) \(request.glucoseUnit)", y: &y)
        row(NSLocalizedString("Estimated HbA1c", comment: "Report"), a1c(analysis.mean), y: &y)
        row("GVI", "\(number(analysis.gvi, 2))  \(gviDescription(analysis.gvi))", y: &y)
        row("PGS", "\(number(analysis.pgs, 2))  \(pgsDescription(analysis.pgs))", y: &y)
        row("GRI", "\(number(analysis.gri, 0))  \(griDescription(analysis.gri))", y: &y)
        section(NSLocalizedString("Treatment per day", comment: "Report"), y: &y)
        let count = Double(max(analysis.days.count, 1))
        let averageCarbs = analysis.days.reduce(0) { $0 + $1.carbs } / count
        let averageBolus = analysis.days.reduce(0) { $0 + $1.bolus } / count
        row(NSLocalizedString("Carbohydrates / bolus", comment: "Report"), "\(number(averageCarbs, 1)) g (\(number(averageCarbs / 12, 1)) BE) / \(number(averageBolus, 1)) \(insulinUnit)", y: &y)
        let basals = analysis.days.compactMap(\.basal)
        let averageBasal = basals.reduce(0, +) / count
        let totalInsulin = averageBasal + averageBolus
        row(NSLocalizedString("Basal / total insulin", comment: "Report"), basals.count == analysis.days.count ? "\(number(averageBasal, 1)) / \(number(totalInsulin, 1)) \(insulinUnit)" : "–", y: &y)
        if basals.count == analysis.days.count && totalInsulin > 0 {
            row(NSLocalizedString("Bolus / basal share", comment: "Report"), "\(number(averageBolus / totalInsulin * 100, 1))% / \(number(averageBasal / totalInsulin * 100, 1))%", y: &y)
        }
        text(NSLocalizedString("Basal insulin is reconstructed from Nightscout profiles and events where available.", comment: "Report caveat"), x: 38, y: y + 14, width: 510, size: 9, color: .darkGray)
    }

    private func profiles(_ pdf: UIGraphicsPDFRendererContext, request: ReportRequest, analysis: ReportAnalysis) {
        let usedNames = Set(analysis.days.flatMap { $0.basalSeries.map(\.profileName) })
        let previousStart = analysis.profiles.filter { $0.effectiveAt < request.start }.map(\.effectiveAt).max()
        let relevant = analysis.profiles.filter { $0.effectiveAt < request.end && usedNames.contains($0.name) && $0.effectiveAt >= request.start } +
            analysis.profiles.filter { $0.effectiveAt == previousStart && usedNames.contains($0.name) }
        if relevant.isEmpty {
            _ = page(pdf, title: NSLocalizedString("Therapy profile", comment: "PDF section"), request: request, landscape: true)
            text(NSLocalizedString("No Nightscout profile available for this period.", comment: "Report"), x: 38, y: 112, width: 740, size: 13)
            return
        }
        for profile in relevant.sorted(by: { $0.effectiveAt < $1.effectiveAt }) {
            let targetMinutes = Set(profile.targetLow.map(\.minutes) + profile.targetHigh.map(\.minutes)).sorted()
            let schedules = [profile.carbRatio, profile.sensitivity, profile.basal]
            let count = max(targetMinutes.count, schedules.map(\.count).max() ?? 0)
            for offset in stride(from: 0, to: max(1, count), by: 24) {
                _ = page(pdf, title: NSLocalizedString("Therapy profile", comment: "PDF section"), request: request, landscape: true)
                text("\(profile.name) • \(request.dateText(profile.effectiveAt, format: "dd.MM.yyyy HH:mm")) • \(profile.timeZone.identifier)", x: 38, y: 94, width: 760, size: 12, bold: true)
                text("DIA: \(number(profile.dia, 1)) h    \(NSLocalizedString("Carbohydrate absorption", comment: "Report")): \(number(profile.carbsPerHour, 0)) g/h", x: 38, y: 116, width: 760, size: 10)
                let titles = ["ICR (g/\(insulinUnit))", "ISF (\(request.glucoseUnit)/\(insulinUnit))", "\(NSLocalizedString("Basal", comment: "Report")) (\(insulinUnit)/h)", "\(NSLocalizedString("Target", comment: "Report")) (\(request.glucoseUnit))"]
                for column in 0..<4 {
                    let x = CGFloat(38 + column * 194)
                    text(titles[column], x: x, y: 146, width: 184, size: 10, color: green, bold: true)
                    let minutes = column == 3 ? targetMinutes : schedules[column].map(\.minutes)
                    if minutes.isEmpty { text("–", x: x, y: 180, width: 184, size: 9) }
                    for index in minutes.indices.dropFirst(offset).prefix(24) {
                        let minute = minutes[index]
                        let end = index + 1 < minutes.count ? minutes[index + 1] : 1440
                        let value: String
                        if column == 3 {
                            let low = scheduleValue(profile.targetLow, minute: minute)
                            let high = scheduleValue(profile.targetHigh, minute: minute)
                            value = "\(glucose(low, request))–\(glucose(high, request))"
                        } else {
                            let raw = schedules[column][index].value
                            value = column == 1 ? request.displayGlucose(raw) : number(raw, column == 2 ? 2 : 1)
                        }
                        text("\(clockText(minute))–\(clockText(end))   \(value)", x: x, y: 180 + CGFloat(index - offset) * 15, width: 184, size: 9)
                    }
                    if column < 3 {
                        let total = scheduleTotal(schedules[column])
                        let summary = column == 2 ? "\(number(total, 1)) \(insulinUnit)/24h" :
                            "Ø \(column == 1 ? glucose(total.map { $0 / 24 }, request) : number(total.map { $0 / 24 }, 1))"
                        text(summary, x: x, y: 162, width: 184, size: 9, color: blue)
                    }
                }
            }
        }
    }

    private func clockText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    private func scheduleValue(_ schedule: [ReportSchedulePoint], minute: Int) -> Double? {
        schedule.last(where: { $0.minutes <= minute })?.value ?? schedule.last?.value
    }

    private func percentilePage(_ pdf: UIGraphicsPDFRendererContext, request: ReportRequest, analysis: ReportAnalysis) {
        _ = page(pdf, title: NSLocalizedString("Glucose percentiles", comment: "PDF section"), request: request, landscape: true)
        let plot = CGRect(x: 68, y: 112, width: 708, height: 330)
        let bins = ReportCalculator.percentiles(analysis.readings, calendar: request.calendar)
        let maximum = glucoseMaximum(bins.flatMap { $0.1 }.max() ?? 0, request: request, compact: false)
        drawRange(plot, low: request.low, high: request.high, maxValue: maximum, request: request)
        guard bins.count > 1, let ctx = UIGraphicsGetCurrentContext() else {
            text(NSLocalizedString("Insufficient glucose data", comment: "Report"), x: 72, y: 240, width: 600, size: 15)
            return
        }
        for (lower, upper, alpha) in [(0, 4, 0.17), (1, 3, 0.30)] {
            let path = UIBezierPath()
            for (index, bin) in bins.enumerated() {
                let p = CGPoint(x: plot.minX + CGFloat(bin.0) / 1440 * plot.width, y: glucoseY(bin.1[lower], plot: plot, max: maximum))
                index == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            for bin in bins.reversed() {
                path.addLine(to: CGPoint(x: plot.minX + CGFloat(bin.0) / 1440 * plot.width, y: glucoseY(bin.1[upper], plot: plot, max: maximum)))
            }
            path.close()
            ctx.setFillColor(blue.withAlphaComponent(alpha).cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
        let median = UIBezierPath()
        for (index, bin) in bins.enumerated() {
            let p = CGPoint(x: plot.minX + CGFloat(bin.0) / 1440 * plot.width, y: glucoseY(bin.1[2], plot: plot, max: maximum))
            index == 0 ? median.move(to: p) : median.addLine(to: p)
        }
        blue.setStroke(); median.lineWidth = 1.4; median.stroke()
        legend("10–90%", color: blue.withAlphaComponent(0.17), x: 68, y: 468)
        legend("25–75%", color: blue.withAlphaComponent(0.30), x: 218, y: 468)
        legend(NSLocalizedString("Median", comment: "Report"), color: blue, x: 368, y: 468)
        legend("\(NSLocalizedString("Report target range", comment: "Report")): \(request.displayGlucose(request.low))–\(request.displayGlucose(request.high)) \(request.glucoseUnit)", color: green.withAlphaComponent(0.17), x: 68, y: 494, width: 650)
    }

    private func dailyPages(_ pdf: UIGraphicsPDFRendererContext, request: ReportRequest, analysis: ReportAnalysis) {
        // Dense days get taller charts so event labels remain readable.
        let dense = analysis.days.contains { day in
            let plot = CGRect(x: 0, y: 0, width: 221, height: 0)
            let carbs = annotationLayout(ReportCalculator.annotations(day.treatments, field: \.carbs), unit: "g", digits: 0, plot: plot, request: request)
            let bolus = annotationLayout(ReportCalculator.annotations(day.treatments.filter { !$0.isSMB }, field: \.insulin), unit: insulinUnit, digits: 1, plot: plot, request: request)
            return annotationRowCount(carbs) + annotationRowCount(bolus) > 2
        }
        let perPage = dense ? 4 : 8
        let rowHeight: CGFloat = dense ? 342 : 171
        for offset in stride(from: 0, to: analysis.days.count, by: perPage) {
            _ = page(pdf, title: NSLocalizedString("Daily charts", comment: "PDF section"), request: request)
            text(NSLocalizedString("Report daily legend", comment: "PDF event symbols and colors"), x: 32, y: 778, width: 530, size: 6, color: .darkGray, height: 24)
            for (index, day) in analysis.days[offset..<min(offset + perPage, analysis.days.count)].enumerated() {
                let rect = CGRect(x: 32 + CGFloat(index % 2) * 267, y: 91 + CGFloat(index / 2) * rowHeight,
                                  width: 255, height: rowHeight - 5)
                dailyChart(day, rect: rect, request: request)
            }
        }
    }

    private func dailyChart(_ day: ReportDay, rect: CGRect, request: ReportRequest) {
        line(x1: rect.minX, y1: rect.maxY, x2: rect.maxX, y2: rect.maxY, color: green)
        text(request.dateText(day.date, format: "EEE, dd.MM.yyyy"), x: rect.minX, y: rect.minY, width: rect.width, size: 10, color: green, bold: true)
        let extra = rect.height - 166
        var plot = CGRect(x: rect.minX + 27, y: rect.minY + 39, width: rect.width - 34, height: 59 + extra)
        let carbs = annotationLayout(ReportCalculator.annotations(day.treatments, field: \.carbs), unit: "g", digits: 0, plot: plot, request: request)
        let bolus = annotationLayout(ReportCalculator.annotations(day.treatments.filter { !$0.isSMB }, field: \.insulin), unit: insulinUnit, digits: 1, plot: plot, request: request)
        let annotationHeight = CGFloat(annotationRowCount(carbs) + annotationRowCount(bolus)) * 11
        plot.origin.y += max(0, annotationHeight - 22)
        plot.size.height -= max(0, annotationHeight - 22)
        let maximum = glucoseMaximum(max(day.readings.map(\.value).max() ?? 0, day.targetSeries.map { ($0.low + $0.high) / 2 }.max() ?? 0), request: request, compact: true)
        drawRange(plot, low: request.low, high: request.high, maxValue: maximum, request: request, compact: true)
        let readings = day.readings.filter { !$0.isMeter }
        if readings.isEmpty {
            text(NSLocalizedString("No glucose data", comment: "Report"), x: plot.minX + 15, y: plot.midY - 7, width: 180, size: 9)
        } else {
            let path = UIBezierPath()
            var previous: ReportGlucose?
            for reading in readings {
                let components = request.calendar.dateComponents([.hour, .minute], from: reading.date)
                let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                let point = CGPoint(x: plot.minX + CGFloat(minute) / 1440 * plot.width,
                                    y: glucoseY(reading.value, plot: plot, max: maximum))
                if let last = previous, reading.date.timeIntervalSince(last.date) <= 15 * 60 { path.addLine(to: point) }
                else { path.move(to: point) }
                previous = reading
            }
            blue.setStroke(); path.lineWidth = 1; path.stroke()
        }
        // Target schedules remain in mg/dL; only axis labels change with units.
        var previousTarget: ReportTargetPoint?
        for target in day.targetSeries {
            let x = timeX(target.date, plot: plot, request: request)
            let end = target.end == request.calendar.date(byAdding: .day, value: 1, to: day.date) ? plot.maxX : timeX(target.end, plot: plot, request: request)
            let y = glucoseY((target.low + target.high) / 2, plot: plot, max: maximum)
            if let previous = previousTarget, previous.end == target.date {
                let previousY = glucoseY((previous.low + previous.high) / 2, plot: plot, max: maximum)
                line(x1: x, y1: previousY, x2: x, y2: y, color: .systemPurple, width: 0.7)
            }
            line(x1: x, y1: y, x2: end, y2: y, color: .systemPurple, width: 0.7)
            previousTarget = target
        }
        annotationLabels(carbs, plot: plot, y: rect.minY + 13, color: orange, request: request)
        annotationLabels(bolus, plot: plot, y: rect.minY + 13 + CGFloat(annotationRowCount(carbs)) * 11, color: blue, request: request)
        for event in day.treatments where event.isSMB && event.insulin > 0 {
            let x = timeX(event.date, plot: plot, request: request)
            let nearest = readings.min { abs($0.date.timeIntervalSince(event.date)) < abs($1.date.timeIntervalSince(event.date)) }
            let value = nearest.flatMap { abs($0.date.timeIntervalSince(event.date)) <= 15 * 60 ? $0.value : nil }
            let y = value.map { glucoseY($0, plot: plot, max: maximum) } ?? plot.maxY - 3
            let marker = UIBezierPath()
            marker.move(to: CGPoint(x: x, y: y + 2))
            marker.addLine(to: CGPoint(x: x - 2, y: y - 2))
            marker.addLine(to: CGPoint(x: x + 2, y: y - 2))
            marker.close(); blue.setFill(); marker.fill()
        }
        for event in day.treatments {
            let symbol: String
            switch event.kind.lowercased() {
            case "sensor change", "sensor start": symbol = "S"
            case "site change": symbol = "K"
            case "insulin change": symbol = "R"
            default: continue
            }
            let x = timeX(event.date, plot: plot, request: request)
            let lane: CGFloat = symbol == "S" ? 0 : symbol == "K" ? 1 : 2
            text(symbol, x: min(plot.maxX - 5, x), y: plot.maxY - 8 - lane * 7, width: 6, size: 5, bold: true)
        }
        for reading in day.readings where reading.isMeter {
            let x = timeX(reading.date, plot: plot, request: request)
            let y = glucoseY(reading.value, plot: plot, max: maximum)
            UIColor.systemRed.setFill()
            UIBezierPath(ovalIn: CGRect(x: x - 1.7, y: y - 1.7, width: 3.4, height: 3.4)).fill()
        }
        if !day.basalSeries.isEmpty {
            let maxRate = max(1, day.basalSeries.map { max($0.profileRate, $0.deliveredRate) }.max() ?? 1)
            for (keyPath, color) in [(\.profileRate, UIColor.systemTeal), (\.deliveredRate, UIColor.systemBlue)] as [(KeyPath<ReportBasalPoint, Double>, UIColor)] {
                let basalPath = UIBezierPath()
                for (index, sample) in day.basalSeries.enumerated() {
                    let y = rect.minY + 122 + extra - CGFloat(sample[keyPath: keyPath] / maxRate) * 12
                    let point = CGPoint(x: timeX(sample.date, plot: plot, request: request), y: y)
                    index == 0 ? basalPath.move(to: point) : basalPath.addLine(to: point)
                    let endX = sample.end == day.basalSeries.last?.end ? plot.maxX : timeX(sample.end, plot: plot, request: request)
                    basalPath.addLine(to: CGPoint(x: endX, y: y))
                }
                color.setStroke(); basalPath.lineWidth = 1; basalPath.stroke()
            }
        }
        let meanText = "\(NSLocalizedString("Mean", comment: "Report")) \(glucose(day.mean, request)) \(request.glucoseUnit)"
        text("\(meanText)  •  \(NSLocalizedString("Carbs", comment: "Report")) \(number(day.carbs, 0)) g  •  HbA1c \(a1c(day.mean))", x: rect.minX, y: rect.minY + 126 + extra, width: rect.width, size: 7.5)
        text("\(NSLocalizedString("Bolus", comment: "Report")) \(number(day.bolus, 1)) \(insulinUnit)  •  \(NSLocalizedString("Basal", comment: "Report")) \(number(day.basal, 1)) \(insulinUnit)  •  TDD \(number(day.totalInsulin, 1)) \(insulinUnit)", x: rect.minX, y: rect.minY + 140 + extra, width: rect.width, size: 8)
        text("\(NSLocalizedString("Profile basal", comment: "Report")) \(number(day.profileBasal, 1)) \(insulinUnit) • \(NSLocalizedString("Basal", comment: "Report")) \(number(day.totalInsulin.flatMap { $0 > 0 ? (day.basal ?? 0) / $0 * 100 : nil }, 0))%", x: rect.minX, y: rect.minY + 153 + extra, width: rect.width, size: 7, color: .darkGray)
    }

    private func pentagonPage(_ pdf: UIGraphicsPDFRendererContext, request: ReportRequest, analysis: ReportAnalysis) {
        _ = page(pdf, title: "CGP • Comprehensive Glucose Pentagon", request: request)
        let center = CGPoint(x: 296, y: 316)
        let radius: CGFloat = 180
        func polygon(_ values: [Double], color: UIColor) {
            let path = UIBezierPath()
            for (index, value) in values.enumerated() {
                let angle = Double(index) * 2 * Double.pi / 5 - Double.pi / 2
                let point = CGPoint(x: center.x + radius * CGFloat(value) * CGFloat(cos(angle)),
                                    y: center.y + radius * CGFloat(value) * CGFloat(sin(angle)))
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.close(); color.withAlphaComponent(0.45).setFill(); path.fill()
            color.setStroke(); path.lineWidth = 1; path.stroke()
        }
        let values = [analysis.tor, analysis.sd.flatMap { sd in analysis.mean.flatMap { $0 > 0 ? sd / $0 * 100 : nil } },
                      analysis.hypoIntensity, analysis.hyperIntensity, analysis.mean]
        let tickValues: [[Double]] = [
            [0, 300, 720, 1080, 1440],
            [16.7, 30, 40, 50, 60, 70, 80],
            [0, 3, 4, 5, 6, 7.2],
            [0, 20, 40, 60, 80, 100, 130],
            [130, 190, 220, 250, 280, 310]
        ]
        for index in 0..<5 {
            let angle = Double(index) * 2 * Double.pi / 5 - Double.pi / 2
            let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            let normal = CGPoint(x: -direction.y, y: direction.x)
            line(x1: center.x, y1: center.y,
                 x2: center.x + radius * direction.x, y2: center.y + radius * direction.y, color: .lightGray)
            for value in tickValues[index] {
                let distance = radius * CGFloat(ReportCalculator.scaleCGP(cgpClamped(value, axis: index), axis: index) / 76)
                let point = CGPoint(x: center.x + direction.x * distance, y: center.y + direction.y * distance)
                line(x1: point.x - normal.x * 3, y1: point.y - normal.y * 3,
                     x2: point.x + normal.x * 3, y2: point.y + normal.y * 3, color: .black, width: 0.8)
                let digits = request.unit == .mmol && index >= 2 ? (index == 2 ? 2 : 1) : (value.rounded() == value ? 0 : 1)
                let label = number(index >= 2 ? request.displayValue(value) : value, digits)
                let width: CGFloat = index == 0 ? 28 : 22
                let labelPoint = CGPoint(x: point.x + normal.x * (index == 0 ? 20 : 12),
                                         y: point.y + normal.y * 12)
                text(label, x: labelPoint.x - width / 2, y: labelPoint.y - 3, width: width, size: 5.5)
            }
        }
        polygon(ReportCalculator.cgpReference.enumerated().map { ReportCalculator.scaleCGP($0.element, axis: $0.offset) / 76 }, color: green)
        if values.allSatisfy({ $0 != nil }) {
            polygon(values.enumerated().map { ReportCalculator.scaleCGP(cgpClamped($0.element!, axis: $0.offset), axis: $0.offset) / 76 }, color: orange)
        }
        text(NSLocalizedString("CGP ToR axis", comment: "CGP axis label"), x: 251, y: 104, width: 90, size: 9, bold: true)
        text(NSLocalizedString("CGP CV axis", comment: "CGP axis label"), x: 462, y: 224, width: 90, size: 9, bold: true)
        text("\(NSLocalizedString("HYPO intensity", comment: "CGP")) [\(request.glucoseUnit) × min²]", x: 376, y: 488, width: 150, size: 8, bold: true)
        text("\(NSLocalizedString("HYPER intensity", comment: "CGP")) [\(request.glucoseUnit) × min²]", x: 69, y: 488, width: 160, size: 8, bold: true)
        text("\(NSLocalizedString("Mean glucose", comment: "Report")) [\(request.glucoseUnit)]", x: 40, y: 224, width: 145, size: 9, bold: true)
        var y: CGFloat = 535
        row("ToR / CV", "\(number(analysis.tor, 0)) \(NSLocalizedString("min/day", comment: "Report unit")) / \(number(values[1], 0))%", y: &y)
        row("HYPO / HYPER (\(request.glucoseUnit) × min²)", "\(number(analysis.hypoIntensity.map(request.displayValue), 1)) / \(number(analysis.hyperIntensity.map(request.displayValue), 1))", y: &y)
        row(NSLocalizedString("Mean", comment: "Report"), "\(glucose(analysis.mean, request)) \(request.glucoseUnit)", y: &y)
        row("PGR", number(analysis.pgr, 1), y: &y)
        text(NSLocalizedString("Green: reference range • Orange: selected period", comment: "CGP legend"), x: 38, y: 638, width: 510, size: 9)
        text(String(format: NSLocalizedString("CGP limits: %@–%@ %@. ToR: minutes outside this range; CV: glucose variation; HYPO/HYPER: intensity beyond the limits.", comment: "CGP explanation"), request.displayGlucose(request.low), request.displayGlucose(request.high), request.glucoseUnit), x: 38, y: 658, width: 510, size: 9)
        text(NSLocalizedString("PGR is a research metric; its prediction of long-term complications has not been established.", comment: "Report caveat"), x: 38, y: 686, width: 510, size: 9)
        text("Vigersky et al., Journal of Diabetes Science and Technology 12(1), 2018. doi:10.1177/1932296817718561", x: 38, y: 724, width: 510, size: 8, color: .gray)
    }

    private func comparisonPages(_ pdf: UIGraphicsPDFRendererContext, request: ReportRequest, analysis: ReportAnalysis) {
        for offset in stride(from: 0, to: analysis.days.count, by: 15) {
            _ = page(pdf, title: NSLocalizedString("Period comparison", comment: "PDF section"), request: request, landscape: true)
            let slice = Array(analysis.days[offset..<min(offset + 15, analysis.days.count)])
            let bar = CGFloat(720) / CGFloat(slice.count)
            let insulinMax = max(10, ceil((slice.compactMap(\.totalInsulin).max() ?? 0) / 10) * 10)
            let carbMax = max(50, ceil((slice.map(\.carbs).max() ?? 0) / 50) * 50)
            for (bottom, maximum, unit) in [(CGFloat(220), 100.0, "%"), (CGFloat(355), insulinMax, insulinUnit), (CGFloat(485), carbMax, "g")] {
                for fraction in [0.0, 0.5, 1.0] {
                    let y = bottom - CGFloat(fraction) * 90
                    line(x1: 64, y1: y, x2: 786, y2: y, color: .lightGray, width: 0.4)
                    text("\(number(maximum * fraction, 0))\(unit)", x: 26, y: y - 4, width: 36, size: 7)
                }
            }
            for (index, day) in slice.enumerated() {
                let x = 66 + CGFloat(index) * bar
                let width = bar - 8
                let distribution = day.distribution
                if distribution.count > 0 {
                    let low = CGFloat(distribution.low) / CGFloat(distribution.count) * 90
                    let normal = CGFloat(distribution.inRange) / CGFloat(distribution.count) * 90
                    fill(CGRect(x: x, y: 220 - low, width: width, height: low), .systemRed)
                    fill(CGRect(x: x, y: 220 - low - normal, width: width, height: normal), .systemGreen)
                    fill(CGRect(x: x, y: 130, width: width, height: 90 - low - normal), .systemYellow)
                    text(distribution.percent(.inRange), x: x, y: 117, width: width, size: 8)
                } else {
                    text("–", x: x, y: 177, width: width, size: 12, color: .gray)
                }
                if let total = day.totalInsulin {
                    let height = CGFloat(total / insulinMax) * 90
                    fill(CGRect(x: x, y: 355 - height, width: width, height: height), blue)
                    if let basal = day.basal {
                        let basalHeight = CGFloat(basal / insulinMax) * 90
                        fill(CGRect(x: x, y: 355 - basalHeight, width: width, height: basalHeight), .systemTeal)
                    }
                    text("\(number(total, 1)) / \(number(day.basal, 1))", x: x, y: 355 - height - 12, width: width, size: 7)
                } else { text("–", x: x, y: 305, width: width, size: 12, color: .gray) }
                let height = CGFloat(day.carbs / carbMax) * 90
                fill(CGRect(x: x, y: 485 - height, width: width, height: height), orange)
                text(number(day.carbs, 0), x: x, y: 485 - height - 12, width: width, size: 8)
                for y in [CGFloat(224), 359, 489] {
                    text(request.dateText(day.date, format: "dd.MM"), x: x, y: y, width: width, size: 7)
                }
            }
            text("\(NSLocalizedString("Glucose range", comment: "Report")) • \(request.displayGlucose(request.low))–\(request.displayGlucose(request.high)) \(request.glucoseUnit)", x: 64, y: 88, width: 680, size: 10, bold: true)
            text(NSLocalizedString("Total insulin / basal (U)", comment: "Report"), x: 64, y: 244, width: 680, size: 10, bold: true)
            text(NSLocalizedString("Carbohydrates (g)", comment: "Report"), x: 64, y: 376, width: 680, size: 10, bold: true)
            text(NSLocalizedString("Red: low • Green: in range • Yellow: high", comment: "Report"), x: 64, y: 519, width: 700, size: 9)
        }
    }

    private func distributionRows(_ distribution: ReportDistribution, low: Double, high: Double, request: ReportRequest, y: inout CGFloat) {
        row("< \(request.displayGlucose(low)) \(request.glucoseUnit)", "\(distribution.percent(.low))  •  \(distribution.low)", y: &y)
        row("\(request.displayGlucose(low))–\(request.displayGlucose(high)) \(request.glucoseUnit)", "\(distribution.percent(.inRange))  •  \(distribution.inRange)", y: &y)
        row("≥ \(request.displayGlucose(high)) \(request.glucoseUnit)", "\(distribution.percent(.high))  •  \(distribution.high)", y: &y)
    }

    private func section(_ title: String, y: inout CGFloat) {
        if y + 80 > 770, let next = continuation { next(); y = 92 }
        y += 8
        text(title, x: 38, y: y, width: 510, size: 11, color: green, bold: true)
        y += 24
    }

    private func row(_ label: String, _ value: String, y: inout CGFloat) {
        let height = max(textHeight(label, width: 275, size: 10), textHeight(value, width: 230, size: 10))
        if y + height > 755, let next = continuation { next(); y = 92 }
        text(label, x: 42, y: y, width: 275, size: 10, height: height)
        text(value, x: 321, y: y, width: 230, size: 10, color: blue, height: height)
        y += max(19, height + 6)
    }

    private func glucoseMaximum(_ value: Double, request: ReportRequest, compact: Bool) -> Double {
        let step = request.unit == .mmol ? (compact ? 2.0 : 1.0) * ReportRequest.mmolFactor : (compact ? 100.0 : 50.0)
        return ceil(max(value, request.high) / step) * step
    }

    private func legend(_ label: String, color: UIColor, x: CGFloat, y: CGFloat, width: CGFloat = 145) {
        fill(CGRect(x: x, y: y + 2, width: 14, height: 8), color)
        text(label, x: x + 20, y: y, width: width - 20, size: 9)
    }

    private struct AnnotationLabel {
        let date: Date
        let text: String
        let x: CGFloat
        let width: CGFloat
        let row: Int
    }

    private func annotationRowCount(_ labels: [AnnotationLabel]) -> Int { (labels.map(\.row).max() ?? 0) + 1 }

    private func annotationLayout(_ groups: [ReportAnnotation], unit: String, digits: Int,
                                  plot: CGRect, request: ReportRequest) -> [AnnotationLabel] {
        var edges: [CGFloat] = []
        return groups.map { group in
            let value = "\(number(group.value, digits)) \(unit)"
            let label = group.count > 1 ? "[\(value)]" : value
            let width = (label as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 5.5)]).width + 3
            let desired = min(plot.maxX - width, max(plot.minX, timeX(group.date, plot: plot, request: request) - width / 2))
            let row = edges.firstIndex(where: { max($0, desired) + width <= plot.maxX }) ?? edges.count
            if row == edges.count { edges.append(plot.minX) }
            let x = max(edges[row], desired)
            edges[row] = x + width
            return AnnotationLabel(date: group.date, text: label, x: x, width: width, row: row)
        }
    }

    private func annotationLabels(_ labels: [AnnotationLabel], plot: CGRect, y: CGFloat,
                                  color: UIColor, request: ReportRequest) {
        for label in labels {
            let eventX = timeX(label.date, plot: plot, request: request)
            let labelY = y + CGFloat(label.row) * 11
            text(label.text, x: label.x, y: labelY, width: label.width, size: 5.5, color: color)
            line(x1: eventX, y1: plot.minY, x2: eventX, y2: plot.minY + 6, color: color, width: 0.7)
            line(x1: label.x + label.width / 2, y1: labelY + 7,
                 x2: eventX, y2: plot.minY, color: color.withAlphaComponent(0.4), width: 0.3)
        }
    }

    private func scheduleTotal(_ schedule: [ReportSchedulePoint]) -> Double? {
        guard !schedule.isEmpty else { return nil }
        let ordered = schedule.sorted { $0.minutes < $1.minutes }
        return ordered.enumerated().reduce((ordered.last?.value ?? 0) * Double(ordered.first?.minutes ?? 0) / 60) { total, item in
            let end = item.offset + 1 < ordered.count ? ordered[item.offset + 1].minutes : 1440
            return total + item.element.value * Double(max(0, end - item.element.minutes)) / 60
        }
    }

    private func timeX(_ date: Date, plot: CGRect, request: ReportRequest) -> CGFloat {
        let components = request.calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        return plot.minX + CGFloat(seconds / 86400) * plot.width
    }

    private func drawRange(_ rect: CGRect, low: Double, high: Double, maxValue: Double, request: ReportRequest, compact: Bool = false) {
        let top = glucoseY(high, plot: rect, max: maxValue)
        let bottom = glucoseY(low, plot: rect, max: maxValue)
        fill(CGRect(x: rect.minX, y: top, width: rect.width, height: bottom - top), green.withAlphaComponent(0.17))
        let step = request.unit == .mmol ? (compact ? 2.0 : 1.0) * ReportRequest.mmolFactor : (compact ? 100.0 : 50.0)
        for value in stride(from: 0.0, through: maxValue, by: step) {
            let y = glucoseY(value, plot: rect, max: maxValue)
            line(x1: rect.minX, y1: y, x2: rect.maxX, y2: y, color: .lightGray, width: 0.3)
            text(request.displayGlucose(value), x: rect.minX - 27, y: y - 4, width: 25, size: compact ? 6 : 8, color: .darkGray)
        }
        text(request.glucoseUnit, x: rect.minX, y: rect.minY - 10, width: 65, size: compact ? 6 : 8, color: .darkGray)
        for hour in stride(from: 0, through: 24, by: compact ? 6 : 2) {
            let x = rect.minX + CGFloat(hour) / 24 * rect.width
            line(x1: x, y1: rect.minY, x2: x, y2: rect.maxY, color: .lightGray, width: 0.3)
            text("\(hour)", x: x - 4, y: rect.maxY + 3, width: 22, size: compact ? 6 : 8)
        }
    }

    private func glucoseY(_ value: Double, plot: CGRect, max: Double) -> CGFloat {
        plot.maxY - CGFloat(Swift.min(Swift.max(value, 0), max) / max) * plot.height
    }

    private func cgpClamped(_ value: Double, axis: Int) -> Double {
        let limits: [(Double, Double)] = [(0, 1440), (16.7, 80), (0, 7.2), (0, 130), (130, 310)]
        let range = limits[axis]
        return min(range.1, max(range.0, value))
    }

    private func glucose(_ value: Double?, _ request: ReportRequest) -> String { value.map { request.displayGlucose($0) } ?? "–" }
    private func number(_ value: Double?, _ digits: Int) -> String { ReportFormatting.number(value, digits: digits, locale: locale) }
    private func a1c(_ mean: Double?) -> String { mean.map { number(($0 + 46.7) / 28.7, 1) + "%" } ?? "–" }

    private func gviDescription(_ value: Double?) -> String {
        guard let value = value else { return "" }
        if value < 1 { return "" }
        if value <= 1.2 { return NSLocalizedString("very good", comment: "Report quality") }
        if value <= 1.5 { return NSLocalizedString("good", comment: "Report quality") }
        return NSLocalizedString("poor", comment: "Report quality")
    }

    private func pgsDescription(_ value: Double?) -> String {
        guard let value = value else { return "" }
        if value < 35 { return NSLocalizedString("excellent", comment: "Report quality") }
        if value <= 100 { return NSLocalizedString("good", comment: "Report quality") }
        if value <= 150 { return NSLocalizedString("poor", comment: "Report quality") }
        return NSLocalizedString("very poor", comment: "Report quality")
    }

    private func griDescription(_ value: Double?) -> String {
        guard let value = value else { return "" }
        let zone = value <= 20 ? "A" : value <= 40 ? "B" : value <= 60 ? "C" : value <= 80 ? "D" : "E"
        return "\(NSLocalizedString("Zone", comment: "GRI zone")) \(zone)"
    }

    private func textHeight(_ value: String, width: CGFloat, size: CGFloat) -> CGFloat {
        ceil((value as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
              options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: size)], context: nil).height)
    }

    private func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, color: UIColor = .black, bold: Bool = false, height: CGFloat? = nil) {
        (value as NSString).draw(in: CGRect(x: x, y: y, width: width, height: height ?? size * 2.5),
                                 withAttributes: [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .foregroundColor: color])
    }

    private func line(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, color: UIColor, width: CGFloat = 0.8) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(color.cgColor); context.setLineWidth(width)
        context.move(to: CGPoint(x: x1, y: y1)); context.addLine(to: CGPoint(x: x2, y: y2)); context.strokePath()
    }

    private func fill(_ rect: CGRect, _ color: UIColor) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(color.cgColor); context.fill(rect)
    }
}
