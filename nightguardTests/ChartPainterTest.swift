//
//  ChartPainterTest.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 01.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class ChartPainterTest: XCTestCase {

    let chartPainter : ChartPainter = ChartPainter(canvasWidth: 165, canvasHeight: 125)

    func testStatisticsNormalizationKeepsAscendingV3ValuesChronological() {
        let calendar = statisticsTestCalendar()
        let values = [
            statisticsReading(value: 100, year: 2026, month: 9, day: 11, hour: 8, minute: 0, calendar: calendar),
            statisticsReading(value: 110, year: 2026, month: 9, day: 11, hour: 9, minute: 0, calendar: calendar)
        ]

        let normalized = StatisticsRepository.normalizeForChart(values, calendar: calendar)

        XCTAssertEqual(normalized.map(\.value), [100, 110])
        XCTAssertLessThan(normalized[0].timestamp, normalized[1].timestamp)
        assertStatisticsReferenceDay(normalized, calendar: calendar)
    }

    func testStatisticsNormalizationSortsDescendingV1ValuesChronologically() {
        let calendar = statisticsTestCalendar()
        let metered = statisticsReading(
            value: 110,
            year: 2026,
            month: 9,
            day: 10,
            hour: 9,
            minute: 0,
            isMetered: true,
            calendar: calendar
        )
        let values = [
            metered,
            statisticsReading(value: 100, year: 2026, month: 9, day: 10, hour: 8, minute: 0, calendar: calendar)
        ]

        let normalized = StatisticsRepository.normalizeForChart(values, calendar: calendar)

        XCTAssertEqual(normalized.map(\.value), [100, 110])
        XCTAssertTrue(normalized[1].isMeteredBloodGlucoseValue)
        assertStatisticsReferenceDay(normalized, calendar: calendar)
    }

    func testStatisticsDayLoadingTrackerRejectsDuplicateRequestsUntilFinished() {
        var tracker = StatisticsDayLoadingTracker()

        XCTAssertTrue(tracker.beginLoading(0))
        XCTAssertFalse(tracker.beginLoading(0))
        XCTAssertTrue(tracker.beginLoading(1))

        tracker.finishLoading(0, succeeded: true)

        XCTAssertTrue(tracker.beginLoading(0))
        XCTAssertEqual(tracker.loadingDays, [0, 1])
    }

    func testStatisticsDayLoadingTrackerWaitsForExplicitRetryAfterFailure() {
        var tracker = StatisticsDayLoadingTracker()

        XCTAssertTrue(tracker.beginLoading(0))
        tracker.finishLoading(0, succeeded: false)

        XCTAssertFalse(tracker.beginLoading(0))
        XCTAssertEqual(tracker.failedDays, [0])

        tracker.allowRetry(0)

        XCTAssertTrue(tracker.beginLoading(0))
    }

    func testXMinAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 10000, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.minimumXValue, 10000)
    }
   
    func testMaxYDisplayValueGetsRecognized() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 150, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.maximumYValue, 150)
    }
    
    func testStretchedValueShouldBeStretchedToCanvasMinAndMaxWidth() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue : 20000, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)

        XCTAssertEqual(Int(chartPainter.stretchedXValue(10000)), 0)
        XCTAssertEqual(Int(chartPainter.stretchedXValue(20000)), chartPainter.canvasWidth)
    }
    
    func testXMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 20000, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.maximumXValue, 20000)
    }

    func testFuturePredictionsExtendXRangeWithoutChangingYRange() {
        let now = Date()
        let measured = BloodSugar(value: 100, timestamp: now.addingTimeInterval(-300).timeIntervalSince1970 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")
        let prediction = BloodSugar(value: 300, timestamp: now.addingTimeInterval(300).timeIntervalSince1970 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")

        chartPainter.adjustMinMaxXYCoordinates([[measured, prediction]], maxYDisplayValue: 350, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)

        XCTAssertEqual(chartPainter.maximumYValue, 180)
        XCTAssertEqual(chartPainter.maximumXValue, prediction.timestamp)
    }

    func testLatestPredictionIsReturnedAsDisplayPosition() {
        let now = Date()
        let measured = BloodSugar(value: 100, timestamp: now.addingTimeInterval(-300).timeIntervalSince1970 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")
        let prediction = BloodSugar(value: 120, timestamp: now.addingTimeInterval(300).timeIntervalSince1970 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")
        let painter = ChartPainter(canvasWidth: 600, canvasHeight: 200)

        let (_, displayPosition) = painter.drawImage([[measured, prediction], []], maxBgValue: 350, upperBoundNiceValue: 180, lowerBoundNiceValue: 80, displayDaysLegend: false, showYesterdaysBGValues: false, useContrastfulColors: false)

        XCTAssertEqual(displayPosition, painter.canvasWidth)
    }
    
    func testYMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 220, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 220, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.maximumYValue, 220)
    }
    
    func testYValue0IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 0, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 250, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(0)), 171)
    }
    
    func testYValue200IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 200, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 240, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(200)), 0)
    }
    
    func testYValue300IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 300, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 350, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(300)), 0)
    }
    
    func testYValue40IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 40, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 200, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(40)), chartPainter.canvasHeight - 30)
    }
    
    func testStretchedValue160ShouldBeStretchedToCanvasHeight() {
        XCTAssertEqual(Int(chartPainter.stretchedYValue(160 + chartPainter.minimumYValue)), chartPainter.canvasHeight - 30)
    }
    
    func testHalfHoursBetweenADayShiftAreCalculatedCorrectly() {

        let today = Date()
        let tomorrow = (Calendar.current as NSCalendar).date(
            byAdding: .day,
            value: 1,
            to: today,
            options: NSCalendar.Options(rawValue: 0))
            
        let minTimestamp : Double = today.timeIntervalSince1970 * 1000
        let maxTimestamp : Double = (tomorrow?.timeIntervalSince1970)! * 1000
        
        let hours = chartPainter.determineHoursBetween(minTimestamp, maxTimestamp: maxTimestamp)
        
        XCTAssertEqual(24, hours.count)
    }

    func testChartSelectionChoosesNearestBloodSugar() {
        let firstTimestamp = Date().addingTimeInterval(-600).timeIntervalSince1970 * 1000
        let secondTimestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let first = BloodSugar(value: 100, timestamp: firstTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let second = BloodSugar(value: 140, timestamp: secondTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: false)

        scene.paintChart([[first, second], []], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.activateSelection(atSceneX: 0)

        XCTAssertEqual(scene.selectedBloodSugar?.timestamp, firstTimestamp)

        // The two plotted points are at x=0 and x=600. x=300 is exactly
        // halfway between them, so either point is a valid nearest match.
        scene.moveSelection(toSceneX: 500)
        XCTAssertEqual(scene.selectedBloodSugar?.timestamp, secondTimestamp)
        scene.deactivateSelection()
    }

    func testChartAutoScrollPolicyWaitsTenSecondsAfterLastInteraction() {
        let start = Date(timeIntervalSince1970: 1_000)
        var policy = ChartAutoScrollPolicy(inactivityInterval: 10)

        XCTAssertEqual(policy.remainingDelay(at: start), 0)

        policy.recordInteraction(at: start)
        XCTAssertEqual(policy.remainingDelay(at: start), 10)
        XCTAssertEqual(policy.remainingDelay(at: start.addingTimeInterval(9)), 1)
        XCTAssertEqual(policy.remainingDelay(at: start.addingTimeInterval(10)), 0)
    }

    func testChartAutoScrollPolicyRestartsDelayForEveryInteraction() {
        let start = Date(timeIntervalSince1970: 1_000)
        var policy = ChartAutoScrollPolicy(inactivityInterval: 10)

        policy.recordInteraction(at: start)
        policy.recordInteraction(at: start.addingTimeInterval(8))

        XCTAssertEqual(policy.remainingDelay(at: start.addingTimeInterval(10)), 8)
        XCTAssertEqual(policy.remainingDelay(at: start.addingTimeInterval(18)), 0)

        policy.reset()
        XCTAssertEqual(policy.remainingDelay(at: start.addingTimeInterval(18)), 0)
    }

    func testChartCanMoveToLatestValueWithoutRepainting() {
        let firstTimestamp = Date().addingTimeInterval(-600).timeIntervalSince1970 * 1000
        let secondTimestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let first = BloodSugar(value: 100, timestamp: firstTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let second = BloodSugar(value: 140, timestamp: secondTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: false)

        scene.paintChart([[first, second], []], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.chartNode.position = CGPoint(x: -100, y: 0)
        scene.moveToLatestValue(animated: false)

        XCTAssertEqual(scene.chartNode.position.x, scene.latestXPosition ?? .nan)
        XCTAssertNotEqual(scene.chartNode.position.x, -100)
    }

    func testLatestPositionSurvivesARepaintThatCancelsTheCurrentAnimation() {
        let firstTimestamp = Date().addingTimeInterval(-600).timeIntervalSince1970 * 1000
        let secondTimestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let first = BloodSugar(value: 100, timestamp: firstTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let second = BloodSugar(value: 140, timestamp: secondTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: false)
        let days = [[first, second], []]

        scene.paintChart(days, newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: true, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.paintChart(days, newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.moveToLatestValue(animated: false)

        XCTAssertEqual(scene.chartNode.position.x, scene.latestXPosition ?? .nan)
    }

    func testChartSelectionIncludesTreatmentsNearSelectedBloodSugar() {
        let timestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let glucose = BloodSugar(value: 120, timestamp: timestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let treatment = MealBolusTreatment(id: "selection-test", timestamp: timestamp + 60 * 1000, carbs: 30, insulin: 2)
        let previousTreatments = TreatmentsStream.singleton.treatments
        TreatmentsStream.singleton.restoreTreatments([treatment])
        defer { TreatmentsStream.singleton.restoreTreatments(previousTreatments) }

        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: false)
        scene.paintChart([[glucose, BloodSugar(value: 130, timestamp: timestamp + 300 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")], []], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.activateSelection(atSceneX: 0)

        XCTAssertEqual(scene.selectedTreatments.count, 1)
        XCTAssertTrue(scene.selectedTreatments.first is MealBolusTreatment)
    }

    func testDelayedTreatmentChangesStreamAfterGlucoseCouldAlreadyBePainted() {
        let previousTreatments = TreatmentsStream.singleton.treatments
        TreatmentsStream.singleton.resetForReload()
        defer { TreatmentsStream.singleton.restoreTreatments(previousTreatments) }

        let timestamp = Date().timeIntervalSince1970 * 1000
        let changed = TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: [[
            "_id": "delayed-meal",
            "eventType": "Meal Bolus",
            "mills": timestamp,
            "carbs": 42,
            "insulin": 3.5
        ]])

        XCTAssertTrue(changed)
        XCTAssertEqual(TreatmentsStream.singleton.treatments.count, 1)
        let meal = TreatmentsStream.singleton.treatments.first as? MealBolusTreatment
        XCTAssertEqual(meal?.timestamp, timestamp)
        XCTAssertEqual(meal?.carbs, 42)
        XCTAssertEqual(meal?.insulin, 3.5)
    }

    func testIdenticalTreatmentResponseDoesNotCreateDuplicateOrReportChange() {
        let previousTreatments = TreatmentsStream.singleton.treatments
        TreatmentsStream.singleton.resetForReload()
        defer { TreatmentsStream.singleton.restoreTreatments(previousTreatments) }

        let treatment: [String: Any] = [
            "identifier": "same-carb",
            "eventType": "Carb Correction",
            "mills": Date().timeIntervalSince1970 * 1000,
            "carbs": 20
        ]

        XCTAssertTrue(TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: [treatment]))
        XCTAssertFalse(TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: [treatment]))
        XCTAssertEqual(TreatmentsStream.singleton.treatments.count, 1)
    }

    func testExistingTreatmentIsReplacedWhenServerCompletesItsValues() {
        let previousTreatments = TreatmentsStream.singleton.treatments
        TreatmentsStream.singleton.resetForReload()
        defer { TreatmentsStream.singleton.restoreTreatments(previousTreatments) }

        let timestamp = Date().timeIntervalSince1970 * 1000
        let initial: [String: Any] = [
            "_id": "completed-meal",
            "eventType": "Meal Bolus",
            "mills": timestamp,
            "carbs": 0,
            "insulin": 2.0
        ]
        let completed: [String: Any] = [
            "_id": "completed-meal",
            "eventType": "Meal Bolus",
            "mills": timestamp,
            "carbs": 35,
            "insulin": 2.0
        ]

        XCTAssertTrue(TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: [initial]))
        XCTAssertTrue(TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: [completed]))
        XCTAssertEqual(TreatmentsStream.singleton.treatments.count, 1)
        XCTAssertEqual((TreatmentsStream.singleton.treatments.first as? MealBolusTreatment)?.carbs, 35)
    }

    func testRestoredTreatmentIsIndexedAndNotAddedAgain() {
        let previousTreatments = TreatmentsStream.singleton.treatments
        defer { TreatmentsStream.singleton.restoreTreatments(previousTreatments) }

        let timestamp = Date().timeIntervalSince1970 * 1000
        TreatmentsStream.singleton.restoreTreatments([
            MealBolusTreatment(id: "persisted-meal", timestamp: timestamp, carbs: 30, insulin: 2.5)
        ])

        let changed = TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: [[
            "_id": "persisted-meal",
            "eventType": "Meal Bolus",
            "mills": timestamp,
            "carbs": 30,
            "insulin": 2.5
        ]])

        XCTAssertFalse(changed)
        XCTAssertEqual(TreatmentsStream.singleton.treatments.count, 1)
    }

    func testChartSelectionIgnoresPreviousDayValues() {
        let currentTimestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let previousDayTimestamp = Date().addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970 * 1000
        let current = BloodSugar(value: 120, timestamp: currentTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let previousDay = BloodSugar(value: 220, timestamp: previousDayTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: true)

        scene.paintChart([[current], [previousDay, BloodSugar(value: 230, timestamp: previousDayTimestamp + 300 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")]], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: true)
        scene.activateSelection(atSceneX: 0)

        XCTAssertEqual(scene.selectedBloodSugar?.timestamp, currentTimestamp)
    }

    private func statisticsTestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func statisticsReading(
        value: Float,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        isMetered: Bool = false,
        calendar: Calendar
    ) -> BloodSugar {
        let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
        return BloodSugar(
            value: value,
            timestamp: date.timeIntervalSince1970 * 1000,
            isMeteredBloodGlucoseValue: isMetered,
            arrow: "-"
        )
    }

    private func assertStatisticsReferenceDay(
        _ readings: [BloodSugar],
        calendar: Calendar,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for reading in readings {
            let components = calendar.dateComponents(
                [.year, .month, .day],
                from: Date(timeIntervalSince1970: reading.timestamp / 1000)
            )
            XCTAssertEqual(components.year, 1971, file: file, line: line)
            XCTAssertEqual(components.month, 1, file: file, line: line)
            XCTAssertEqual(components.day, 1, file: file, line: line)
        }
    }
}
