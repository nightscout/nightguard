//
//  WatchStatsView.swift
//  nightguard WatchKit App
//

import SwiftUI
import Combine

struct WatchStatsView: View {
    @State private var model = BasicStats(period: .last24h)
    @State private var currentPeriod: BasicStats.Period = .last24h
    @State private var a1cPageIndex = 0
    @State private var distributionPageIndex = 0
    @State private var readingsPageIndex = 0

    private let timer = Timer.publish(every: 15, on: .current, in: .common).autoconnect()
    private let refreshDataOnAppBecameActiveNotification = NotificationCenter.default.publisher(for: .refreshDataOnAppBecameActive)

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var isProAvailable: Bool {
        UserDefaultsRepository.watchProAccessAvailable.value
    }

    private var a1cPages: [WatchStatsPage] {
        [
            WatchStatsPage(
                title: NSLocalizedString("A1c", comment: "Watch stats A1c title"),
                primaryText: model.formattedA1c ?? "--",
                secondaryText: model.formattedAverageGlucose ?? "--",
                ringStyle: .solid(color: a1cColor)
            ),
            WatchStatsPage(
                title: NSLocalizedString("IFCC A1c", comment: "Watch stats IFCC A1c title"),
                primaryText: (model.formattedIFCCA1c ?? "--").replacingOccurrences(of: " ", with: "\n"),
                secondaryText: "",
                ringStyle: .solid(color: a1cColor)
            ),
            WatchStatsPage(
                title: NSLocalizedString("Average", comment: "Watch stats average title"),
                primaryText: (model.formattedAverageGlucose ?? "--").replacingOccurrences(of: " ", with: "\n"),
                secondaryText: "",
                ringStyle: .solid(color: a1cColor)
            ),
            WatchStatsPage(
                title: NSLocalizedString("Std Deviation", comment: "Watch stats standard deviation title"),
                primaryText: model.formattedStandardDeviation ?? "--",
                secondaryText: "",
                ringStyle: .solid(color: variationColor)
            ),
            WatchStatsPage(
                title: NSLocalizedString("Coefficient of Variation", comment: "Watch stats coefficient of variation title"),
                primaryText: model.formattedCoefficientOfVariation ?? "--",
                secondaryText: "",
                ringStyle: .solid(color: variationColor)
            )
        ]
    }

    private var distributionPages: [WatchStatsPage] {
        let low = max(0, Double(model.lowValuesPercentage))
        let inRange = max(0, Double(model.inRangeValuesPercentage))
        let high = max(0, Double(model.highValuesPercentage))

        let segments = [
            WatchRingSegment(fraction: low, color: Color(UIColor.nightguardRed()), isHighlighted: false),
            WatchRingSegment(fraction: inRange, color: Color(UIColor.nightguardGreen()), isHighlighted: false),
            WatchRingSegment(fraction: high, color: Color(UIColor.nightguardYellow()), isHighlighted: false)
        ]

        return [
            WatchStatsPage(
                title: NSLocalizedString("In Range", comment: "Watch stats in range title"),
                primaryText: model.formattedInRangeValuesPercentage ?? "--",
                secondaryText: glucoseDistributionDetail,
                ringStyle: .segmented(segments: highlightedSegments(base: segments, highlightedIndex: 1))
            ),
            WatchStatsPage(
                title: NSLocalizedString("Low", comment: "Watch stats low title"),
                primaryText: model.formattedLowValuesPercentage ?? "--",
                secondaryText: durationText(fromReadingsCount: model.lowValuesCount),
                ringStyle: .segmented(segments: highlightedSegments(base: segments, highlightedIndex: 0))
            ),
            WatchStatsPage(
                title: NSLocalizedString("High", comment: "Watch stats high title"),
                primaryText: model.formattedHighValuesPercentage ?? "--",
                secondaryText: durationText(fromReadingsCount: model.highValuesCount),
                ringStyle: .segmented(segments: highlightedSegments(base: segments, highlightedIndex: 2))
            ),
            WatchStatsPage(
                title: NSLocalizedString("In Range", comment: "Watch stats in range title"),
                primaryText: model.formattedInRangeValuesPercentage ?? "--",
                secondaryText: glucoseDistributionDetail,
                ringStyle: .segmented(segments: highlightedSegments(base: segments, highlightedIndex: nil))
            )
        ]
    }

    private var readingsPages: [WatchStatsPage] {
        let validFraction = max(0, Double(model.readingsPercentage - model.invalidValuesPercentage))
        let invalidFraction = max(0, Double(model.invalidValuesPercentage))

        var pages = [
            WatchStatsPage(
                title: NSLocalizedString("Readings", comment: "Watch stats readings title"),
                primaryText: "\(Float(model.readingsCount).cleanValue)/\(model.readingsMaximumCount)",
                secondaryText: model.formattedReadingsPercentage ?? "--",
                ringStyle: .segmented(segments: readingsSegments(validFraction: validFraction, invalidFraction: invalidFraction, highlightInvalid: false))
            ),
            WatchStatsPage(
                title: NSLocalizedString("Readings %", comment: "Watch stats readings percentage title"),
                primaryText: model.formattedReadingsPercentage ?? "--",
                secondaryText: "\(Float(model.readingsCount).cleanValue)/\(model.readingsMaximumCount)",
                ringStyle: .segmented(segments: readingsSegments(validFraction: validFraction, invalidFraction: invalidFraction, highlightInvalid: false))
            )
        ]

        if model.invalidValuesCount > 0 {
            pages.append(
                WatchStatsPage(
                    title: NSLocalizedString("Invalid readings", comment: "Watch stats invalid readings title"),
                    primaryText: "\(model.invalidValuesCount)",
                    secondaryText: durationText(fromReadingsCount: model.invalidValuesCount),
                    ringStyle: .segmented(segments: readingsSegments(validFraction: validFraction, invalidFraction: invalidFraction, highlightInvalid: true))
                )
            )
        }

        return pages
    }

    private var periodPage: WatchStatsPage {
        WatchStatsPage(
            title: NSLocalizedString("Stats Period", comment: "Watch stats period title"),
            primaryText: model.period.description,
            secondaryText: NSLocalizedString("Tap to change", comment: "Watch stats period change hint"),
            ringStyle: .solid(color: .nightguardAccent)
        )
    }

    var body: some View {
        Group {
            if isProAvailable {
                statsGrid
            } else {
                lockedView
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            refreshStats()
        }
        .onReceive(timer) { _ in
            refreshStats()
        }
        .onReceive(refreshDataOnAppBecameActiveNotification) { _ in
            refreshStats()
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            let a1cPage = page(at: a1cPageIndex, in: a1cPages)
            let distributionPage = page(at: distributionPageIndex, in: distributionPages)
            let readingsPage = page(at: readingsPageIndex, in: readingsPages)

            WatchStatsCircleCard(page: a1cPage, action: advanceA1cPage)
            WatchStatsCircleCard(page: distributionPage, action: advanceDistributionPage)
            WatchStatsCircleCard(page: readingsPage, action: advanceReadingsPage)
            WatchStatsCircleCard(page: periodPage, action: cyclePeriod)
        }
    }

    private var lockedView: some View {
        Button(action: requestProPromotion) {
            VStack(spacing: 10) {
                Image(systemName: "lock.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.nightguardAccent)

                Text(NSLocalizedString("Watch Statistics", comment: "Watch locked stats title"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("Unlock Pro to see the four main stats on your Apple Watch.", comment: "Watch locked stats description"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("Subscribe on iPhone", comment: "Watch locked stats CTA button"))
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.nightguardAccent)
                    .cornerRadius(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var glucoseDistributionDetail: String {
        let low = model.formattedLowValuesPercentage ?? "--"
        let high = model.formattedHighValuesPercentage ?? "--"
        return "L \(low) H \(high)"
    }

    private var a1cColor: Color {
        guard !model.a1c.isNaN else {
            return .nightguardAccent
        }

        return watchRedYellowGreen(for: Double(model.a1c), bestValue: 5.5, worstValue: 8.5)
    }

    private var variationColor: Color {
        guard !model.coefficientOfVariation.isNaN else {
            return .nightguardAccent
        }

        return watchRedYellowGreen(for: Double(model.coefficientOfVariation), bestValue: 0.3, worstValue: 0.5)
    }

    private func refreshStats() {
        model = BasicStats(period: currentPeriod)
    }

    private func cyclePeriod() {
        let periods: [BasicStats.Period] = [.last24h, .last8h, .today, .yesterday, .todayAndYesterday]
        let currentIndex = periods.firstIndex(of: currentPeriod) ?? 0
        currentPeriod = periods[(currentIndex + 1) % periods.count]
        refreshStats()
    }

    private func advanceA1cPage() {
        guard !a1cPages.isEmpty else { return }
        a1cPageIndex = (a1cPageIndex + 1) % a1cPages.count
    }

    private func advanceDistributionPage() {
        guard !distributionPages.isEmpty else { return }
        distributionPageIndex = (distributionPageIndex + 1) % distributionPages.count
    }

    private func advanceReadingsPage() {
        guard !readingsPages.isEmpty else { return }
        readingsPageIndex = (readingsPageIndex + 1) % readingsPages.count
    }

    private func requestProPromotion() {
        ShowProPromotionMessage().send()
    }

    private func page(at index: Int, in pages: [WatchStatsPage]) -> WatchStatsPage {
        guard !pages.isEmpty else {
            return WatchStatsPage(
                title: "",
                primaryText: "--",
                secondaryText: "",
                ringStyle: .solid(color: .gray)
            )
        }

        return pages[min(index, pages.count - 1)]
    }

    private func durationText(fromReadingsCount readingsCount: Int) -> String {
        guard readingsCount > 0 else {
            return ""
        }

        let totalMinutes = readingsCount * 5
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    private func highlightedSegments(base: [WatchRingSegment], highlightedIndex: Int?) -> [WatchRingSegment] {
        base.enumerated().map { index, segment in
            WatchRingSegment(
                fraction: segment.fraction,
                color: segment.color,
                isHighlighted: highlightedIndex == nil ? true : highlightedIndex == index
            )
        }
    }

    private func readingsSegments(validFraction: Double, invalidFraction: Double, highlightInvalid: Bool) -> [WatchRingSegment] {
        var segments = [
            WatchRingSegment(
                fraction: validFraction,
                color: .white,
                isHighlighted: !highlightInvalid
            )
        ]

        if invalidFraction > 0 {
            segments.append(
                WatchRingSegment(
                    fraction: invalidFraction,
                    color: Color(UIColor.nightguardRed()),
                    isHighlighted: highlightInvalid
                )
            )
        }

        return segments
    }

    private func watchRedYellowGreen(for value: Double, bestValue: Double, worstValue: Double) -> Color {
        let power: Double

        if bestValue < worstValue {
            power = max(min((worstValue - value) / (worstValue - bestValue), 1), 0)
        } else {
            power = max(min((bestValue - value) / (bestValue - worstValue), 1), 0)
        }

        if power > 0.75 {
            return Color(UIColor.nightguardGreen())
        }
        if power > 0.4 {
            return Color(UIColor.nightguardYellow())
        }
        if power > 0.3 {
            return Color(UIColor.nightguardOrange())
        }
        return Color(UIColor.nightguardRed())
    }
}

private struct WatchStatsPage {
    let title: String
    let primaryText: String
    let secondaryText: String
    let ringStyle: WatchRingStyle
}

private enum WatchRingStyle {
    case solid(color: Color)
    case segmented(segments: [WatchRingSegment])
}

private struct WatchRingSegment {
    let fraction: Double
    let color: Color
    let isHighlighted: Bool
}

private struct WatchStatsCircleCard: View {
    let page: WatchStatsPage
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    circleContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                circleContent
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var circleContent: some View {
        ZStack {
            WatchStatsRingView(style: page.ringStyle)

            VStack(spacing: 2) {
                Text(page.title)
                    .font(.system(size: 9, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.primaryText)
                    .font(.system(size: 12, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !page.secondaryText.isEmpty {
                    Text(page.secondaryText)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
        }
    }
}

private struct WatchStatsRingView: View {
    let style: WatchRingStyle

    var body: some View {
        GeometryReader { geometry in
            let lineWidth = max(4, geometry.size.width * 0.08)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)

                switch style {
                case .solid(let color):
                    Circle()
                        .fill(color.opacity(0.12))
                    Circle()
                        .stroke(color.opacity(0.95), lineWidth: lineWidth)

                case .segmented(let segments):
                    ForEach(Array(segmentRanges(for: segments).enumerated()), id: \.offset) { _, range in
                        if range.end > range.start {
                            WatchRingArc(startFraction: range.start, endFraction: range.end)
                                .stroke(
                                    range.segment.color.opacity(range.segment.isHighlighted ? 1.0 : 0.5),
                                    style: StrokeStyle(
                                        lineWidth: range.segment.isHighlighted ? lineWidth + 1 : lineWidth - 0.5,
                                        lineCap: .butt
                                    )
                                )
                        }
                    }
                }
            }
        }
    }

    private func segmentRanges(for segments: [WatchRingSegment]) -> [(start: Double, end: Double, segment: WatchRingSegment)] {
        let positiveSegments = segments.filter { $0.fraction > 0 }
        let total = positiveSegments.reduce(0.0) { $0 + $1.fraction }
        guard total > 0 else {
            return []
        }

        let gap = positiveSegments.count > 1 ? 0.012 : 0
        var current = 0.0

        return positiveSegments.map { segment in
            let normalized = total > 1 ? min(max(segment.fraction / total, 0), 1) : min(max(segment.fraction, 0), 1)
            let start = current + gap / 2
            let end = min(current + normalized - gap / 2, 1)
            current += normalized
            return (start: max(0, start), end: max(start, end), segment: segment)
        }
    }
}

private struct WatchRingArc: Shape {
    let startFraction: Double
    let endFraction: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle.degrees(startFraction * 360 - 90)
        let endAngle = Angle.degrees(endFraction * 360 - 90)

        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}
