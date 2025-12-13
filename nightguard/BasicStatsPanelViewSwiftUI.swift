//
//  BasicStatsPanelViewSwiftUI.swift
//  nightguard
//
//  SwiftUI version of BasicStatsPanelView
//  Replaces the XIB-based BasicStatsPanelView with a pure SwiftUI implementation
//

import SwiftUI

/// SwiftUI version of the BasicStatsPanelView
/// Displays 4 circular stats views: A1c, Glucose Distribution, Readings Stats, and Period Selector
struct BasicStatsPanelViewSwiftUI: View {
    @State private var model: BasicStats?
    @State private var currentPeriod: BasicStats.Period = .last24h
    @State private var updateTrigger: UUID = UUID()

    var body: some View {
        HStack(spacing: 8) {
            // A1c View - displays A1c, IFCC A1c, average glucose, std deviation, coefficient of variation
            A1cViewRepresentable(model: model)
                .aspectRatio(1, contentMode: .fit)

            // Glucose Distribution View - displays in range, low, high percentages with pie chart
            GlucoseDistributionViewRepresentable(model: model)
                .aspectRatio(1, contentMode: .fit)

            // Readings Stats View - displays readings count and percentage
            ReadingsStatsViewRepresentable(model: model)
                .aspectRatio(1, contentMode: .fit)

            // Period Selector View - allows switching between time periods
            StatsPeriodSelectorViewRepresentable(
                model: model,
                onPeriodChange: { period in
                    currentPeriod = period
                    model = BasicStats(period: period)
                }
            )
            .aspectRatio(1, contentMode: .fit)

            Spacer()
        }
        .onAppear {
            updateModel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NightscoutDataUpdated"))) { _ in
            updateModel()
        }
    }

    /// Update the model with the most recent data if needed
    func updateModel() {
        if let currentModel = model, currentModel.isUpToDate {
            // Model is already up to date
            return
        }

        // Recreate the model with fresh data
        model = BasicStats(period: model?.period ?? currentPeriod)
        updateTrigger = UUID()
    }
}

// MARK: - UIViewRepresentable Wrappers

/// SwiftUI wrapper for A1cView
struct A1cViewRepresentable: UIViewRepresentable {
    let model: BasicStats?

    func makeUIView(context: Context) -> A1cView {
        let view = A1cView()
        return view
    }

    func updateUIView(_ uiView: A1cView, context: Context) {
        uiView.model = model
    }
}

/// SwiftUI wrapper for GlucoseDistributionView
struct GlucoseDistributionViewRepresentable: UIViewRepresentable {
    let model: BasicStats?

    func makeUIView(context: Context) -> GlucoseDistributionView {
        let view = GlucoseDistributionView()
        return view
    }

    func updateUIView(_ uiView: GlucoseDistributionView, context: Context) {
        uiView.model = model
    }
}

/// SwiftUI wrapper for ReadingsStatsView
struct ReadingsStatsViewRepresentable: UIViewRepresentable {
    let model: BasicStats?

    func makeUIView(context: Context) -> ReadingsStatsView {
        let view = ReadingsStatsView()
        return view
    }

    func updateUIView(_ uiView: ReadingsStatsView, context: Context) {
        uiView.model = model
    }
}

/// SwiftUI wrapper for StatsPeriodSelectorView
struct StatsPeriodSelectorViewRepresentable: UIViewRepresentable {
    let model: BasicStats?
    let onPeriodChange: (BasicStats.Period) -> Void

    func makeUIView(context: Context) -> StatsPeriodSelectorView {
        let view = StatsPeriodSelectorView()
        view.onPeriodChangeRequest = { period in
            onPeriodChange(period)
        }
        return view
    }

    func updateUIView(_ uiView: StatsPeriodSelectorView, context: Context) {
        uiView.model = model
    }
}

#Preview {
    BasicStatsPanelViewSwiftUI()
        .frame(height: 80)
        .background(Color.black)
}
