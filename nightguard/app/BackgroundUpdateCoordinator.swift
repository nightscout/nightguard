//
//  BackgroundUpdateCoordinator.swift
//  nightguard
//

import Foundation
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

enum BackgroundUpdateTrigger: String {
    case bgTask = "BGTask"
    case silentPush = "SilentPush"
}

struct BackgroundUpdateResult {
    let success: Bool
    let hasNewData: Bool
    let message: String
}

final class BackgroundUpdateCoordinator {
    static let shared = BackgroundUpdateCoordinator()

    private let completionLock = NSLock()
    private var isRunning = false

    private init() {}

    func run(trigger: BackgroundUpdateTrigger, completion: @escaping (BackgroundUpdateResult) -> Void) {
        completionLock.lock()
        guard !isRunning else {
            completionLock.unlock()
            completion(BackgroundUpdateResult(success: true, hasNewData: false, message: "Background update already running"))
            return
        }
        isRunning = true
        completionLock.unlock()

        AppLogger.singleton.debug("\(trigger.rawValue) background update started", category: .backgroundUpdates)

        let _ = NightscoutCacheService.singleton.loadCurrentNightscoutData(forceRefresh: true) { [weak self] result in
            guard let self = self else { return }

            func finish(_ result: BackgroundUpdateResult) {
                self.completionLock.lock()
                self.isRunning = false
                self.completionLock.unlock()
                AppLogger.singleton.debug(
                    "\(trigger.rawValue) background update finished success=\(result.success), hasNewData=\(result.hasNewData), message=\(result.message)",
                    category: .backgroundUpdates
                )
                completion(result)
            }

            guard let result = result else {
                finish(BackgroundUpdateResult(success: true, hasNewData: false, message: "No Nightscout result"))
                return
            }

            switch result {
            case .error(let error):
                AppLogger.singleton.error("\(trigger.rawValue) background update failed: \(error)", category: .backgroundUpdates)
                finish(BackgroundUpdateResult(success: false, hasNewData: false, message: "Nightscout error"))
            case .data(let nightscoutData):
                AppLogger.singleton.debug(
                    "\(trigger.rawValue) fetched Nightscout data: SGV=\(nightscoutData.sgv), timestamp=\(nightscoutData.time)",
                    category: .backgroundUpdates
                )

                AlarmNotificationService.singleton.notifyIfAlarmActivated(nightscoutData)
                WatchService.singleton.sendToWatchCurrentNightwatchData()

                let storedHistoryValues = NightscoutDataRepository.singleton.loadTodaysBgData()
                NightscoutService.singleton.readTodaysChartData(oldValues: storedHistoryValues) { historyResult in
                    let snapshot: NightguardDisplaySnapshot
                    switch historyResult {
                    case .data(let bloodSugarValues):
                        let historyValues = NightguardDisplaySnapshot.historyValues(
                            bloodSugarValues,
                            including: nightscoutData
                        )
                        NightscoutDataRepository.singleton.storeTodaysBgData(historyValues)
                        snapshot = NightscoutDataRepository.singleton.storeLatestDisplaySnapshot(
                            from: nightscoutData,
                            previousValues: historyValues
                        )
                    case .error(let error):
                        AppLogger.singleton.warning(
                            "\(trigger.rawValue) failed to fetch widget history values: \(error.localizedDescription)",
                            category: .backgroundUpdates
                        )
                        let historyValues = NightguardDisplaySnapshot.historyValues(
                            storedHistoryValues,
                            including: nightscoutData
                        )
                        NightscoutDataRepository.singleton.storeTodaysBgData(historyValues)
                        snapshot = NightscoutDataRepository.singleton.storeLatestDisplaySnapshot(
                            from: nightscoutData,
                            previousValues: historyValues
                        )
                    }

                    AppLogger.singleton.debug(
                        "\(trigger.rawValue) stored display snapshot: SGV=\(snapshot.sgv), timestamp=\(snapshot.timestamp), values=\(snapshot.lastBGValues.count)",
                        category: .backgroundUpdates
                    )

                    Task {
                        if #available(iOS 16.1, *) {
                            let updateResult = await LiveActivityManager.shared.updateExistingActivities(with: nightscoutData)
                            let logMessage = "\(trigger.rawValue) Live Activity update result: activities=\(updateResult.activityCount), updated=\(updateResult.updatedActivityCount), message=\(updateResult.message)"
                            if updateResult.didUpdateAnyActivity {
                                AppLogger.singleton.info(logMessage, category: .backgroundUpdates)
                            } else {
                                AppLogger.singleton.warning(logMessage, category: .backgroundUpdates)
                            }
                        }

                        self.reloadWidgetTimelines(trigger: trigger)

                        let deviceStatusData: DeviceStatusData = await withCheckedContinuation { continuation in
                            let _ = NightscoutCacheService.singleton.getDeviceStatusData { deviceStatusData in
                                continuation.resume(returning: deviceStatusData)
                            }
                        }

                        AppLogger.singleton.debug(
                            "\(trigger.rawValue) received device status: reservoir=\(deviceStatusData.reservoirUnits)",
                            category: .backgroundUpdates
                        )
                        AlarmNotificationService.singleton.notifyIfReservoirCritical(deviceStatusData.reservoirUnits)

                        if trigger == .bgTask {
                            try? await Task.sleep(nanoseconds: 4_000_000_000)
                        }

                        finish(BackgroundUpdateResult(success: true, hasNewData: true, message: "Nightscout data processed"))
                    }
                }
            }
        }
    }

    private func reloadWidgetTimelines(trigger: BackgroundUpdateTrigger) {
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            let widgetKinds = [
                "org.duckdns.dhe.nightguard.NightguardDefaultWidgets",
                "org.duckdns.dhe.nightguard.NightguardTimestampWidgets",
                "org.duckdns.dhe.nightguard.NightguardGaugeWidgets"
            ]

            for widgetKind in widgetKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
                AppLogger.singleton.debug("\(trigger.rawValue) requested widget timeline reload: \(widgetKind)", category: .backgroundUpdates)
            }
        }
        #endif
    }
}
