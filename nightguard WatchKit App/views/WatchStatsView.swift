//
//  WatchStatsView.swift
//  nightguard WatchKit App
//

import SwiftUI
import Combine

struct WatchStatsView: View {
    @State private var model = BasicStats(period: .last24h)
    @State private var currentPeriod: BasicStats.Period = .last24h

    private let timer = Timer.publish(every: 15, on: .current, in: .common).autoconnect()
    private let refreshDataOnAppBecameActiveNotification = NotificationCenter.default.publisher(for: .refreshDataOnAppBecameActive)

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var isProAvailable: Bool {
        UserDefaultsRepository.watchProAccessAvailable.value
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
            WatchStatsCircleCard(
                title: NSLocalizedString("A1c", comment: "Watch stats A1c title"),
                primaryText: model.formattedA1c ?? "--",
                secondaryText: model.formattedAverageGlucose ?? "--",
                accentColor: watchA1cColor,
                action: nil
            )

            WatchStatsCircleCard(
                title: NSLocalizedString("In Range", comment: "Watch stats in range title"),
                primaryText: model.formattedInRangeValuesPercentage ?? "--",
                secondaryText: glucoseDistributionDetail,
                accentColor: .green,
                action: nil
            )

            WatchStatsCircleCard(
                title: NSLocalizedString("Readings", comment: "Watch stats readings title"),
                primaryText: model.formattedReadingsPercentage ?? "--",
                secondaryText: "\(model.readingsCount)/\(model.readingsMaximumCount)",
                accentColor: .white,
                action: nil
            )

            WatchStatsCircleCard(
                title: NSLocalizedString("Stats Period", comment: "Watch stats period title"),
                primaryText: model.period.description,
                secondaryText: NSLocalizedString("Tap to change", comment: "Watch stats period change hint"),
                accentColor: .nightguardAccent,
                action: cyclePeriod
            )
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

                Text(NSLocalizedString("Unlock Pro to see the four main stats on your Apple Watch.", comment: "Watch locked stats description"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("Unlock Pro Version", comment: "Unlock Pro Version Button"))
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
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

    private var watchA1cColor: Color {
        let a1c = model.a1c
        guard !a1c.isNaN else {
            return .nightguardAccent
        }

        if a1c <= 6.5 {
            return .green
        }
        if a1c <= 7.5 {
            return .yellow
        }
        return .red
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

    private func requestProPromotion() {
        ShowProPromotionMessage().send()
    }
}

private struct WatchStatsCircleCard: View {
    let title: String
    let primaryText: String
    let secondaryText: String
    let accentColor: Color
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
            Circle()
                .fill(accentColor.opacity(0.12))

            Circle()
                .stroke(accentColor.opacity(0.9), lineWidth: 4)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(primaryText)
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)

                Text(secondaryText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }
            .padding(8)
        }
    }
}
