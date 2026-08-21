//
//  NightscoutCacheService.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 06.11.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let nightscoutDataRefreshRequested = Notification.Name("NightscoutDataRefreshRequested")
}

// This is a facade in front of the nightscout service. It is used to reduce the
// amount of turnarounds to the real backend to a minimum.
class NightscoutCacheService: NSObject {
    
    static let singleton = NightscoutCacheService()
    
    let serialQueue = DispatchQueue(label: "de.my-wan.dhe.nightscoutCacheServiceSerialQueue")
    
    var isEmpty: Bool {
        return yesterdaysBgData.isEmpty && todaysBgData.isEmpty
    }
    
    fileprivate var todaysBgData : [BloodSugar] = []
    fileprivate var yesterdaysBgData : [BloodSugar] = []
    fileprivate var yesterdaysBgDataRaw : [BloodSugar] = []
    fileprivate var yesterdaysDayOfTheYear : Int? = nil
    fileprivate var currentNightscoutData : NightscoutData = NightscoutData.init()

    // Keep the last hour of the previous day available while the new day starts.
    // This prevents the no-data alarm from seeing an empty history immediately
    // after midnight.
    fileprivate let dayTransitionGracePeriod: TimeInterval = 60 * 60
    
    fileprivate var cannulaAge : Date? = nil
    fileprivate var sensorAge : Date? = nil
    fileprivate var pumpBattery : Int? = nil
    
    fileprivate var newDataReceived : Bool = false
    fileprivate let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    
    // housekeeping of pending requests
    fileprivate var todaysBgDataTasks: [NightscoutTask] = []
    fileprivate var yesterdaysBgDataTasks: [NightscoutTask] = []
    fileprivate var currentNightscoutDataTasks: [NightscoutTask] = []
    fileprivate var temporaryTargetData: TemporaryTargetData = TemporaryTargetData()
    
    // are there any running "todays bg data" requests?
    var hasTodaysBgDataPendingRequests: Bool {
        serialQueue.sync {
            return todaysBgDataTasks.contains(where: { $0.nightscoutIsRunning })
        }
    }

    // are there any running "yesterdays bg data" requests?
    var hasYesterdaysBgDataPendingRequests: Bool {
        serialQueue.sync {
            return yesterdaysBgDataTasks.contains(where: { $0.nightscoutIsRunning })
        }
    }

    // are there any running "current nightscout data" requests?
    var hasCurrentNightscoutDataPendingRequests: Bool {
        serialQueue.sync {
            return currentNightscoutDataTasks.contains(where: { $0.nightscoutIsRunning })
        }
    }

    // During background updates, this value is modified from the ExtensionDelegate
    func updateCurrentNightscoutData(newNightscoutData : NightscoutData) {
        
        // synchronize here to prevent concurrent modifications when doing background
        // upates
        serialQueue.sync {
            currentNightscoutData = newNightscoutData
            NightscoutDataRepository.singleton.storeCurrentNightscoutData(newNightscoutData)
        }
    }
    
    func resetCache() {
        serialQueue.sync {
            todaysBgData = []
            yesterdaysBgData = []
            yesterdaysBgDataRaw = []
            yesterdaysDayOfTheYear = nil
            currentNightscoutData = NightscoutData()
        }
        NightscoutEntriesStream.shared.resetAll()
        NightscoutDataRepository.singleton.clearAll()
    }

    /// Clears the in-memory and persisted values for today without touching
    /// yesterday's history, then lets the active view model fetch fresh data.
    func resetTodaysData() {
        let tasksToCancel = serialQueue.sync { () -> [NightscoutTask] in
            let tasks = todaysBgDataTasks + currentNightscoutDataTasks
            todaysBgDataTasks.removeAll()
            currentNightscoutDataTasks.removeAll()
            todaysBgData = []
            currentNightscoutData = NightscoutData()
            temporaryTargetData = TemporaryTargetData()
            newDataReceived = true
            return tasks
        }

        tasksToCancel.forEach { $0.cancel() }
        NightscoutEntriesStream.shared.resetTodaysData()
        NightscoutDataRepository.singleton.clearTodaysData()
        AppLogger.singleton.info("NightscoutCacheService: cleared today's local data; requesting a fresh server reload", category: .nightscout)
    }
    
    func getCannulaChangeTime() -> Date {
        
        NightscoutService.singleton.readLastTreatementEventTimestamp(eventType: .cannulaChange, daysToGoBackInTime: 5, resultHandler: { (cannulaChangeTime: Date) in
            let oldDate = NightscoutDataRepository.singleton.loadCannulaChangeTime()
            if abs(cannulaChangeTime.timeIntervalSince(oldDate)) > 1 {
                NightscoutDataRepository.singleton.storeCannulaChangeTime(cannulaChangeTime: cannulaChangeTime)
                AlarmNotificationService.singleton.scheduleCannulaNotification(changeDate: cannulaChangeTime)
            }
        })
        
        return NightscoutDataRepository.singleton.loadCannulaChangeTime()
    }
    
    func getSensorChangeTime() -> Date {
        NightscoutService.singleton.readLastTreatementEventTimestamp(eventType: .sensorStart, daysToGoBackInTime: 14, resultHandler: { (sensorChangeTime: Date) in
            let oldDate = NightscoutDataRepository.singleton.loadSensorChangeTime()
            if abs(sensorChangeTime.timeIntervalSince(oldDate)) > 1 {
                NightscoutDataRepository.singleton.storeSensorChangeTime(sensorChangeTime: sensorChangeTime)
                AlarmNotificationService.singleton.scheduleSensorNotification(changeDate: sensorChangeTime)
            }
        })
        return NightscoutDataRepository.singleton.loadSensorChangeTime()
    }
    
    func getPumpBatteryChangeTime() ->  Date {
        NightscoutService.singleton.readLastTreatementEventTimestamp(eventType: .pumpBatteryChange, daysToGoBackInTime: 40, resultHandler: { (batteryChangeTime: Date) in
            let oldDate = NightscoutDataRepository.singleton.loadBatteryChangeTime()
            if abs(batteryChangeTime.timeIntervalSince(oldDate)) > 1 {
                NightscoutDataRepository.singleton.storeBatteryChangeTime(batteryChangeTime: batteryChangeTime)
                AlarmNotificationService.singleton.scheduleBatteryNotification(changeDate: batteryChangeTime)
            }
        })
        
        return NightscoutDataRepository.singleton.loadBatteryChangeTime()
    }
    
    func getDeviceStatusData(_ resultHandler : @escaping (DeviceStatusData) -> Void) -> DeviceStatusData {
        NightscoutSyncCoordinator.shared.refreshDeviceStatus { deviceStatusData in
            NightscoutDataRepository.singleton.storeDeviceStatusData(deviceStatusData: deviceStatusData)
            resultHandler(deviceStatusData)
        }
        
        return NightscoutDataRepository.singleton.loadDeviceStatusData()
    }
    
    func getCurrentNightscoutData() -> NightscoutData {
        
        return currentNightscoutData
    }
    
    func getTemporaryTargetData(_ completion: @escaping (TemporaryTargetData) -> Void) {
        
        let temporaryTargetData = NightscoutDataRepository.singleton.loadTemporaryTargetData()
        // Load new Targets after 5 minutes only:
        if temporaryTargetData.isUpToDate() {
            completion(temporaryTargetData)
            return
        }
        
        NightscoutService.singleton.readLastTemporaryTarget(daysToGoBackInTime: 1, resultHandler:  { (temporaryTargetData: TemporaryTargetData?) in
            
                if let temporaryTargetData = temporaryTargetData {
                    NightscoutDataRepository.singleton.storeTemporaryTargetData(temporaryTargetData: temporaryTargetData)
                    completion(temporaryTargetData)
                }
            })
    }
    
    func getTodaysBgData() -> [BloodSugar] {
        return todaysBgData
    }
    
    func getYesterdaysBgData() -> [BloodSugar] {
        return yesterdaysBgData
    }
    
    func getYesterdaysBgDataRaw() -> [BloodSugar] {
        return yesterdaysBgDataRaw
    }
    
    // Returns true, if the size of one array changed
    func valuesChanged() -> Bool {
        
        if newDataReceived {
            newDataReceived = false;
            return true
        }
        
        return false
    }
    
    func loadCurrentNightscoutData(forceRefresh: Bool, _ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>?) -> Void) -> NightscoutData {
    
        serialQueue.sync {
            currentNightscoutData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
            checkIfRefreshIsNeeded(resultHandler, forceRefresh: forceRefresh)
        }
        
        return currentNightscoutData
    }
    
    func loadCurrentNightscoutData(_ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>?) -> Void) -> NightscoutData {
        
        return loadCurrentNightscoutData(forceRefresh: false, resultHandler)
    }
    
    // Reads the blood glucose data from today
    func loadTodaysData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>?) -> Void)
        -> [BloodSugar] {

        let shouldRefresh = serialQueue.sync { () -> Bool in
            todaysBgData = removeYesterdaysEntries(bgValues: todaysBgData)
            return todaysBgData.isEmpty || currentNightscoutData.isOlderThanYMinutes()
                || currentNightscoutWasFetchedInBackground(todaysBgData: todaysBgData)
        }

        guard shouldRefresh else {
            resultHandler(nil)
            return serialQueue.sync { todaysBgData }
        }

        let task = NightscoutEntriesStream.shared.refresh { [weak self] result in
            guard let self else { return }
            switch result {
            case .data:
                let calendar = Calendar.current
                let today = TimeService.getToday()
                let dayStart = calendar.startOfDay(for: today)
                let from = calendar.date(byAdding: .hour, value: -1, to: dayStart) ?? dayStart
                let to = calendar.startOfDay(for: TimeService.getTomorrow())
                let values = NightscoutEntriesStream.shared.bloodSugars(from: from, to: to)
                self.serialQueue.sync {
                    self.newDataReceived = true
                    self.todaysBgData = values
                    NightscoutDataRepository.singleton.storeTodaysBgData(values)
                }
                resultHandler(.data(values))
            case .error(let error):
                resultHandler(.error(error))
            }
        }

        if let task {
            serialQueue.sync {
                todaysBgDataTasks.removeAll(where: { !$0.nightscoutIsRunning })
                todaysBgDataTasks.append(task)
            }
        } else {
            resultHandler(nil)
        }

        return serialQueue.sync { todaysBgData }
    }
    
    fileprivate func currentNightscoutWasFetchedInBackground(todaysBgData : [BloodSugar]) -> Bool {
        
        // consider also the case when the current nightscout data is newer than newest 
        // "todays data" (are out of sync because probably the ns data was obtained 
        // while the app was in background)
        return currentNightscoutData.time.doubleValue > (todaysBgData.last?.timestamp ?? 0)
    }
    
    func removeYesterdaysEntries(bgValues: [BloodSugar], currentDate: Date = TimeService.getToday()) -> [BloodSugar] {
        let calendar = Calendar.current
        let startOfCurrentDay = calendar.startOfDay(for: currentDate)
        let startOfTransitionWindow = calendar.date(
            byAdding: .second,
            value: -Int(dayTransitionGracePeriod),
            to: startOfCurrentDay
        ) ?? startOfCurrentDay
        let startOfTransitionWindowTimestamp = startOfTransitionWindow.timeIntervalSince1970 * 1000

        return bgValues.filter { bgValue in
            bgValue.timestamp >= startOfTransitionWindowTimestamp
        }
    }
    
    // Reads the blood glucose data from yesterday
    func loadYesterdaysData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>?) -> Void)
        -> [BloodSugar] {

        if yesterdaysBgData.count == 0 {
            yesterdaysBgData = NightscoutDataRepository.singleton.loadYesterdaysBgData()
            yesterdaysDayOfTheYear = NightscoutDataRepository.singleton.loadYesterdaysDayOfTheYear()
        }
        
        if yesterdaysBgDataRaw.count == 0 {
            yesterdaysBgDataRaw = NightscoutDataRepository.singleton.loadYesterdaysBgDataRaw()
        }
        
        let shouldRefresh = yesterdaysBgData.isEmpty || yesterdaysValuesAreOutdated()
        guard shouldRefresh else {
            resultHandler(nil)
            return yesterdaysBgData
        }

        let task = NightscoutEntriesStream.shared.refresh { [weak self] result in
            guard let self else { return }
            switch result {
            case .data:
                let calendar = Calendar.current
                let yesterday = TimeService.getYesterday()
                let start = calendar.startOfDay(for: yesterday)
                let end = calendar.startOfDay(for: TimeService.getToday())
                let rawValues = NightscoutEntriesStream.shared.bloodSugars(from: start, to: end)
                self.newDataReceived = true
                self.yesterdaysBgDataRaw = rawValues
                NightscoutDataRepository.singleton.storeYesterdaysBgDataRaw(rawValues)
                self.yesterdaysBgData = self.transformToCurrentDay(yesterdaysValues: rawValues)
                NightscoutDataRepository.singleton.storeYesterdaysBgData(self.yesterdaysBgData)
                if let day = calendar.ordinality(of: .day, in: .year, for: yesterday) {
                    self.yesterdaysDayOfTheYear = day
                    NightscoutDataRepository.singleton.storeYesterdaysDayOfTheYear(yesterdaysDayOfTheYear: day)
                }
                resultHandler(.data(self.yesterdaysBgData))
            case .error(let error):
                resultHandler(.error(error))
            }
        }
        if let task {
            serialQueue.sync {
                yesterdaysBgDataTasks.removeAll(where: { !$0.nightscoutIsRunning })
                yesterdaysBgDataTasks.append(task)
            }
        } else {
            resultHandler(nil)
        }

        return yesterdaysBgData
    }
    
    // check if the stored yesterdaysvalues are from a day before
    fileprivate func yesterdaysValuesAreOutdated() -> Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return false
        }
        guard let newYesterdayDayOfTheYear = Calendar.current.ordinality(of: .day, in: .year, for: yesterday) else {
            return false
        }
        
        return newYesterdayDayOfTheYear != yesterdaysDayOfTheYear
    }
    
    fileprivate func transformToCurrentDay(yesterdaysValues : [BloodSugar]) -> [BloodSugar] {
        var transformedValues : [BloodSugar] = []
        for yesterdaysValue in yesterdaysValues {
            let transformedValue = BloodSugar.init(value: yesterdaysValue.value, timestamp: yesterdaysValue.timestamp + self.ONE_DAY_IN_MICROSECONDS, isMeteredBloodGlucoseValue: yesterdaysValue.isMeteredBloodGlucoseValue, arrow: yesterdaysValue.arrow)
            transformedValues.append(transformedValue)
        }
        
        return transformedValues
    }
    
    fileprivate func checkIfRefreshIsNeeded(_ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>?) -> Void, forceRefresh: Bool = false) {
        
        guard forceRefresh || currentNightscoutData.isOlderThanYMinutes() else {
            resultHandler(nil)
            return
        }
        
        if let task = NightscoutEntriesStream.shared.refresh(force: forceRefresh, completion: { [weak self] (result: NightscoutRequestResult<[NightscoutEntryRecord]>) in
            guard let self else { return }
            switch result {
            case .data(let records):
                NightscoutService.singleton.makeCurrentData(from: records) { currentResult in
                    if case .data(let newNightscoutData) = currentResult {
                        self.serialQueue.sync {
                            self.currentNightscoutData = newNightscoutData
                        }
                        NightscoutDataRepository.singleton.storeCurrentNightscoutData(newNightscoutData)
                    }
                    resultHandler(currentResult)
                }
            case .error(let error):
                resultHandler(.error(error))
            }
        }) {
            // cleanup (delete not running tasks) and add the current started one
            currentNightscoutDataTasks.removeAll(where: { !$0.nightscoutIsRunning })
            currentNightscoutDataTasks.append(task)
        } else {
            resultHandler(nil)
        }
    }
}


// HACK for updating the today's data from Test Cases; the problem is that
// from tests the NightscoutDataRepository.loadTodaysBgData will fail unarchiving the [BloodSugar]
// data, even if stored correctly...
extension NightscoutCacheService {
    func updateTodaysBgDataForTesting(_ data: [BloodSugar]) {
        self.todaysBgData = data
    }
}

/// One cache-coalesced stream for all glucose entries used by the app.
///
/// Nightscout's v3 generic collection applies its configured server-side
/// result limit. We keep the returned head locally for two days and derive
/// current values, charts and meter readings from that same snapshot.
final class NightscoutEntriesStream {
    static let shared = NightscoutEntriesStream()

    private let queue = DispatchQueue(label: "de.my-wan.dhe.nightscoutEntriesStreamSerialQueue")
    private let retention: TimeInterval = 48 * 60 * 60
    private let refreshInterval: TimeInterval = 5 * 60
    private var records: [NightscoutEntryRecord] = []
    private var loaded = false
    private var syncInFlight = false
    private var activeNetworkTask: NightscoutTask?
    private var generation = 0
    private var lastSyncAt: Date?
    private var pending: [(NightscoutRequestResult<[NightscoutEntryRecord]>) -> Void] = []

    func snapshot() -> [NightscoutEntryRecord] {
        queue.sync {
            loadIfNeededLocked()
            return records
        }
    }

    @discardableResult
    func refresh(
        force: Bool = false,
        completion: @escaping (NightscoutRequestResult<[NightscoutEntryRecord]>) -> Void
    ) -> NightscoutTask? {
        let callerTask = NightscoutRequestTask()
        var shouldStart = false
        var requestGeneration = 0
        var immediateResult: NightscoutRequestResult<[NightscoutEntryRecord]>?

        queue.sync {
            loadIfNeededLocked()
            if !force,
               !records.isEmpty,
               let lastSyncAt,
               Date().timeIntervalSince(lastSyncAt) < refreshInterval {
                immediateResult = .data(records)
            } else {
                pending.append { result in
                    callerTask.finish()
                    dispatchOnMain { completion(result) }
                }
                if !syncInFlight {
                    syncInFlight = true
                    shouldStart = true
                    requestGeneration = generation
                }
            }
        }

        if let immediateResult {
            callerTask.finish()
            dispatchOnMain { completion(immediateResult) }
            return callerTask
        }

        if shouldStart {
            let refreshGeneration = requestGeneration
            let networkTask = NightscoutService.singleton.readEntriesHead { [weak self] result in
                self?.finishRefresh(result, generation: refreshGeneration)
            }
            if let networkTask {
                queue.sync { activeNetworkTask = networkTask }
                callerTask.add(networkTask)
            } else {
                finishRefresh(.error(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)), generation: refreshGeneration)
            }
        }

        return callerTask
    }

    func bloodSugars(from start: Date, to end: Date) -> [BloodSugar] {
        let fromMillis = start.timeIntervalSince1970 * 1000
        let toMillis = end.timeIntervalSince1970 * 1000
        return snapshot()
            .filter { $0.dateMillis >= fromMillis && $0.dateMillis < toMillis }
            .compactMap(\.bloodSugar)
            .sorted { $0.timestamp < $1.timestamp }
    }

    func resetTodaysData() {
        queue.sync {
            generation += 1
            activeNetworkTask?.cancel()
            activeNetworkTask = nil
            syncInFlight = false
            pending.removeAll()
            loadIfNeededLocked()
            let startOfToday = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000
            let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970 + 24 * 60 * 60
            let tomorrowMillis = startOfTomorrow * 1000
            records.removeAll { $0.dateMillis >= startOfToday && $0.dateMillis < tomorrowMillis }
            NightscoutDataRepository.singleton.storeNightscoutEntries(records)
            lastSyncAt = nil
        }
        AppLogger.singleton.info("NightscoutEntriesStream: removed current-day entries; next refresh is forced", category: .nightscout)
    }

    func resetAll() {
        queue.sync {
            generation += 1
            activeNetworkTask?.cancel()
            activeNetworkTask = nil
            records = []
            loaded = true
            lastSyncAt = nil
            syncInFlight = false
            pending.removeAll()
        }
    }

    private func loadIfNeededLocked() {
        guard !loaded else { return }
        loaded = true
        records = NightscoutDataRepository.singleton.loadNightscoutEntries()
        if records.isEmpty {
            // Migrate the old split caches once. This keeps the first stream
            // refresh useful even when the app is upgraded with no network.
            let today = NightscoutDataRepository.singleton.loadTodaysBgData().map {
                legacyRecord(from: $0)
            }
            let yesterday = NightscoutDataRepository.singleton.loadYesterdaysBgDataRaw().map {
                legacyRecord(from: $0)
            }
            records = today + yesterday
            if !records.isEmpty {
                records = deduplicated(records)
                NightscoutDataRepository.singleton.storeNightscoutEntries(records)
                AppLogger.singleton.info("NightscoutEntriesStream: migrated \(records.count) legacy glucose value(s) into the raw cache", category: .nightscout)
            }
        }
        records = prune(records)
    }

    private func legacyRecord(from bloodSugar: BloodSugar) -> NightscoutEntryRecord {
        let type = bloodSugar.isMeteredBloodGlucoseValue ? "mbg" : "sgv"
        return NightscoutEntryRecord(
            storageKey: "legacy:\(type):\(Int(bloodSugar.timestamp))",
            dateMillis: bloodSugar.timestamp,
            type: type,
            sgv: bloodSugar.isMeteredBloodGlucoseValue ? nil : Double(bloodSugar.value),
            mbg: bloodSugar.isMeteredBloodGlucoseValue ? Double(bloodSugar.value) : nil,
            direction: bloodSugar.arrow
        )
    }

    private func finishRefresh(_ result: NightscoutRequestResult<[NightscoutEntryRecord]>, generation requestGeneration: Int) {
        var callbacks: [(NightscoutRequestResult<[NightscoutEntryRecord]>) -> Void] = []
        var deliveredResult = result
        queue.sync {
            guard requestGeneration == generation else { return }
            syncInFlight = false
            activeNetworkTask = nil
            callbacks = pending
            pending.removeAll()

            if case .data(let incoming) = result {
                let before = records.count
                records = deduplicated(records + incoming)
                records = prune(records)
                lastSyncAt = Date()
                NightscoutDataRepository.singleton.storeNightscoutEntries(records)
                let addedOrUpdated = max(0, records.count - before)
                let oldest = records.map(\.dateMillis).min().map { Date(timeIntervalSince1970: $0 / 1000).description } ?? "-"
                let newest = records.map(\.dateMillis).max().map { Date(timeIntervalSince1970: $0 / 1000).description } ?? "-"
                AppLogger.singleton.info(
                    "NightscoutEntriesStream: merged source=head incoming=\(incoming.count) stored=\(records.count) addedOrUpdated=\(addedOrUpdated) oldest=\(oldest) newest=\(newest)",
                    category: .nightscout
                )
                deliveredResult = .data(records)
            } else if case .error(let error) = result {
                AppLogger.singleton.error(
                    "NightscoutEntriesStream: refresh failed; retaining \(records.count) cached entry/entries: \(error.localizedDescription)",
                    category: .nightscout
                )
            }
        }

        callbacks.forEach { callback in
            dispatchOnMain { callback(deliveredResult) }
        }
    }

    private func deduplicated(_ values: [NightscoutEntryRecord]) -> [NightscoutEntryRecord] {
        var byKey: [String: NightscoutEntryRecord] = [:]
        values.forEach { byKey[$0.storageKey] = $0 }
        return byKey.values.sorted { $0.dateMillis < $1.dateMillis }
    }

    private func prune(_ values: [NightscoutEntryRecord]) -> [NightscoutEntryRecord] {
        let cutoff = (Date().timeIntervalSince1970 - retention) * 1000
        return deduplicated(values.filter { $0.dateMillis >= cutoff })
    }
}

/// Coalesces the remaining non-entry refreshes. Treatments and device status
/// stay separate models, but a foreground/background cycle no longer starts
/// duplicate requests when both consumers ask for the same data concurrently.
final class NightscoutSyncCoordinator {
    static let shared = NightscoutSyncCoordinator()

    private let queue = DispatchQueue(label: "de.my-wan.dhe.nightscoutSyncCoordinatorSerialQueue")
    private var treatmentsInFlight = false
    private var treatmentCompletions: [([[String: Any]]) -> Void] = []
    private var deviceStatusInFlight = false
    private var deviceStatusCompletions: [(DeviceStatusData) -> Void] = []

    /// Starts the regular synchronized cycle. Entries remain the shared raw
    /// stream; treatments are fetched into their existing dedicated model.
    /// Both requests are coalesced independently when foreground and
    /// background consumers overlap.
    func refreshEntriesAndTreatments(force: Bool) {
        _ = NightscoutEntriesStream.shared.refresh(force: force) { result in
            if case .error(let error) = result {
                AppLogger.singleton.warning("NightscoutSyncCoordinator: entries cycle retained local data after error: \(error.localizedDescription)", category: .nightscout)
            }
        }
        _ = refreshTreatments { treatments in
            #if MAIN_APP
            TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: treatments)
            #endif
        }
    }

    @discardableResult
    func refreshTreatments(_ completion: @escaping ([[String: Any]]) -> Void) -> NightscoutTask? {
        let callerTask = NightscoutRequestTask()
        var shouldStart = false
        queue.sync {
            treatmentCompletions.append { values in
                callerTask.finish()
                dispatchOnMain { completion(values) }
            }
            if !treatmentsInFlight {
                treatmentsInFlight = true
                shouldStart = true
            }
        }

        if shouldStart {
            let task = NightscoutService.singleton.readLatestTreatements { [weak self] values in
                guard let self else { return }
                var completions: [([[String: Any]]) -> Void] = []
                self.queue.sync {
                    self.treatmentsInFlight = false
                    completions = self.treatmentCompletions
                    self.treatmentCompletions.removeAll()
                }
                AppLogger.singleton.info("NightscoutSyncCoordinator: treatments refresh completed count=\(values.count)", category: .nightscout)
                completions.forEach { $0(values) }
            }
            if let task { callerTask.add(task) }
        }
        return callerTask
    }

    @discardableResult
    func refreshDeviceStatus(_ completion: @escaping (DeviceStatusData) -> Void) -> NightscoutTask? {
        let callerTask = NightscoutRequestTask()
        var shouldStart = false
        queue.sync {
            deviceStatusCompletions.append { value in
                callerTask.finish()
                dispatchOnMain { completion(value) }
            }
            if !deviceStatusInFlight {
                deviceStatusInFlight = true
                shouldStart = true
            }
        }

        if shouldStart {
            let task = NightscoutService.singleton.readDeviceStatus { [weak self] value in
                guard let self else { return }
                var completions: [(DeviceStatusData) -> Void] = []
                self.queue.sync {
                    self.deviceStatusInFlight = false
                    completions = self.deviceStatusCompletions
                    self.deviceStatusCompletions.removeAll()
                }
                AppLogger.singleton.info("NightscoutSyncCoordinator: device status refresh completed", category: .nightscout)
                completions.forEach { $0(value) }
            }
            if let task { callerTask.add(task) }
        }
        return callerTask
    }
}
