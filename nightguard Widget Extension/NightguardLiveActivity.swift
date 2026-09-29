//
//  NightguardLiveActivity.swift
//  nightguard Widget Extension
//
//  Created by Gemini CLI.
//

import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct NightguardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightguardActivityAttributes.self) { context in
            // Prefer the familiar side-by-side layout. Measure the complete
            // readout so long values cannot steal the chart's minimum width.
            ViewThatFits(in: .horizontal) {
                lockScreenRow(for: context.state, compact: false)
                lockScreenRow(for: context.state, compact: true)
                VStack(alignment: .leading, spacing: 6) {
                    lockScreenReadout(for: context.state, compact: true)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    lockScreenChart(for: context.state, height: 54)
                }
            }
            .padding()
            .activityBackgroundTint(nil)

        } dynamicIsland: { context in
            DynamicIsland {
                // Use the full width below the camera for the value and chart.
                // Each candidate declares its required width; narrow displays
                // can choose smaller type or put the chart on a second row.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ViewThatFits(in: .horizontal) {
                            expandedRow(for: context.state, compact: false)
                            expandedRow(for: context.state, compact: true)
                            VStack(alignment: .leading, spacing: 6) {
                                expandedReadout(for: context.state, compact: true)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                expandedChart(for: context.state)
                            }
                        }
                        HStack(spacing: 8) {
                            if !context.state.iob.isEmpty {
                                Text("IOB: \(context.state.iob)")
                            }

                            if !context.state.iob.isEmpty && !context.state.cob.isEmpty {
                                Text("•")
                                    .foregroundColor(.secondary.opacity(0.65))
                            }

                            if !context.state.cob.isEmpty {
                                Text("COB: \(context.state.cob)")
                            }

                            Spacer(minLength: 8)

                            HStack(spacing: 3) {
                                Text(context.state.date, style: .relative)
                                Text("ago")
                            }
                            .monospacedDigit()
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Text(context.state.sgv)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.trendArrow)
                    Text(context.state.delta)
                }
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            } minimal: {
                Text(context.state.sgv)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            }
            .widgetURL(URL(string: "nightguard://open"))
            .keylineTint(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
        }
    }

    private func lockScreenRow(for state: NightguardActivityAttributes.ContentState, compact: Bool) -> some View {
        HStack(spacing: 12) {
            lockScreenReadout(for: state, compact: compact)
                .fixedSize(horizontal: true, vertical: false)
            lockScreenChart(for: state)
        }
    }

    private func lockScreenReadout(for state: NightguardActivityAttributes.ContentState, compact: Bool) -> some View {
        HStack(spacing: 8) {
            Text(state.sgv)
                .font(.system(size: compact ? 36 : 50, weight: .bold))
                .foregroundColor(.primary)
                .layoutPriority(1)

            VStack(alignment: .leading) {
                HStack {
                    Text(state.trendArrow)
                        .font(compact ? .system(size: 23) : .title)
                    Text(state.delta)
                        .font(compact ? .system(size: 17) : .title3)
                        .foregroundColor(.secondary)
                }
                Text(state.date, style: .time)
                    .font(compact ? .system(size: 12) : .caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func lockScreenChart(for state: NightguardActivityAttributes.ContentState, height: CGFloat = 64) -> some View {
        if !state.glucoseSamples.isEmpty {
            GlucoseSparkline(
                samples: state.glucoseSamples,
                lowerTarget: state.lowerTarget,
                upperTarget: state.upperTarget,
                lineColor: glucoseColor(for: state)
            )
            .frame(minWidth: 100, maxWidth: .infinity)
            .frame(height: height)
        }
    }

    private func expandedRow(for state: NightguardActivityAttributes.ContentState, compact: Bool) -> some View {
        HStack(spacing: 12) {
            expandedReadout(for: state, compact: compact)
                .fixedSize(horizontal: true, vertical: false)
            expandedChart(for: state)
        }
    }

    private func expandedReadout(for state: NightguardActivityAttributes.ContentState, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(state.sgv)
                .font(.system(size: compact ? 36 : 52, weight: .bold, design: .rounded))
                .layoutPriority(1)
            Text(state.delta)
                .font(.system(size: compact ? 19 : 25, weight: .semibold, design: .rounded))
            Text(state.trendArrow)
                .font(.system(size: compact ? 23 : 30, weight: .medium))
        }
        .foregroundColor(glucoseColor(for: state))
    }

    @ViewBuilder
    private func expandedChart(for state: NightguardActivityAttributes.ContentState) -> some View {
        if !state.glucoseSamples.isEmpty {
            GlucoseSparkline(
                samples: state.glucoseSamples,
                lowerTarget: state.lowerTarget,
                upperTarget: state.upperTarget,
                lineColor: glucoseColor(for: state)
            )
            .frame(minWidth: 120, maxWidth: .infinity)
            .frame(height: 54)
        }
    }

    private func glucoseColor(for state: NightguardActivityAttributes.ContentState) -> Color {
        Color(
            red: state.sgvColorRed,
            green: state.sgvColorGreen,
            blue: state.sgvColorBlue
        )
    }
}

@available(iOS 16.1, *)
private struct GlucoseSparkline: View {
    private let displayedDuration: TimeInterval = 60 * 60 * 1000
    private let maximumContinuousGap: TimeInterval = 15 * 60 * 1000

    let samples: [NightguardActivityAttributes.GlucoseSample]
    let lowerTarget: Double
    let upperTarget: Double
    let lineColor: Color

    var body: some View {
        GeometryReader { geometry in
            let yAxisWidth: CGFloat = 24
            let plotRect = CGRect(
                x: yAxisWidth + 4,
                y: 6,
                width: max(geometry.size.width - yAxisWidth - 7, 1),
                height: max(geometry.size.height - 12, 1)
            )

            ZStack {
                targetBandPath(in: plotRect)
                    .fill(Color.primary.opacity(0.08))

                glucosePath(in: plotRect)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                ForEach(orderedSamples.indices, id: \.self) { index in
                    let sample = orderedSamples[index]
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                        .position(point(for: sample, in: plotRect))
                }

                if let sampleValueBounds {
                    Text(axisLabel(for: sampleValueBounds.upperBound))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .position(
                            x: yAxisWidth / 2,
                            y: yPosition(for: sampleValueBounds.upperBound, in: plotRect)
                        )

                    if sampleValueBounds.lowerBound != sampleValueBounds.upperBound {
                        Text(axisLabel(for: sampleValueBounds.lowerBound))
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .position(
                                x: yAxisWidth / 2,
                                y: yPosition(for: sampleValueBounds.lowerBound, in: plotRect)
                            )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var orderedSamples: [NightguardActivityAttributes.GlucoseSample] {
        samples.sorted { $0.timestamp < $1.timestamp }
    }

    private var valueRange: ClosedRange<Double> {
        guard let minimum = orderedSamples.map(\.value).min(),
              let maximum = orderedSamples.map(\.value).max() else {
            let normalizedLowerTarget = min(lowerTarget, upperTarget)
            let normalizedUpperTarget = max(lowerTarget, upperTarget)
            return normalizedLowerTarget...normalizedUpperTarget
        }

        if minimum == maximum {
            return (minimum - 1)...(maximum + 1)
        }
        return minimum...maximum
    }

    private var sampleValueBounds: ClosedRange<Double>? {
        guard let minimum = orderedSamples.map(\.value).min(),
              let maximum = orderedSamples.map(\.value).max() else {
            return nil
        }
        return minimum...maximum
    }

    private var timeRange: ClosedRange<TimeInterval> {
        let latestTimestamp = orderedSamples.last?.timestamp ?? 0
        return (latestTimestamp - displayedDuration)...latestTimestamp
    }

    private func point(
        for sample: NightguardActivityAttributes.GlucoseSample,
        in rect: CGRect
    ) -> CGPoint {
        let timeSpan = max(timeRange.upperBound - timeRange.lowerBound, 1)
        let valueSpan = max(valueRange.upperBound - valueRange.lowerBound, 1)
        let relativeX = ((sample.timestamp - timeRange.lowerBound) / timeSpan).clamped(to: 0...1)
        let relativeY = ((sample.value - valueRange.lowerBound) / valueSpan).clamped(to: 0...1)

        return CGPoint(
            x: rect.minX + rect.width * relativeX,
            y: rect.maxY - rect.height * relativeY
        )
    }

    private func yPosition(for value: Double, in rect: CGRect) -> CGFloat {
        let valueSpan = max(valueRange.upperBound - valueRange.lowerBound, 1)
        let relativeY = ((value - valueRange.lowerBound) / valueSpan).clamped(to: 0...1)
        return rect.maxY - rect.height * relativeY
    }

    private func axisLabel(for value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func glucosePath(in rect: CGRect) -> Path {
        Path { path in
            var previousSample: NightguardActivityAttributes.GlucoseSample?

            for sample in orderedSamples {
                let samplePoint = point(for: sample, in: rect)
                if let previousSample,
                   sample.timestamp - previousSample.timestamp <= maximumContinuousGap {
                    path.addLine(to: samplePoint)
                } else {
                    path.move(to: samplePoint)
                }
                previousSample = sample
            }
        }
    }

    private func targetBandPath(in rect: CGRect) -> Path {
        let normalizedLowerTarget = min(lowerTarget, upperTarget)
        let normalizedUpperTarget = max(lowerTarget, upperTarget)
        let lowerPoint = point(
            for: NightguardActivityAttributes.GlucoseSample(
                value: normalizedLowerTarget,
                timestamp: timeRange.lowerBound
            ),
            in: rect
        )
        let upperPoint = point(
            for: NightguardActivityAttributes.GlucoseSample(
                value: normalizedUpperTarget,
                timestamp: timeRange.lowerBound
            ),
            in: rect
        )

        return Path(
            CGRect(
                x: rect.minX,
                y: upperPoint.y,
                width: rect.width,
                height: max(lowerPoint.y - upperPoint.y, 0)
            )
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
