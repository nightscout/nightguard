//
//  BloodSugarArrayTest.swift
//  nightguardTests
//
//  Created by Florian Preknya on 1/13/19.
//  Copyright © 2019 private. All rights reserved.
//

import XCTest

extension Array where Element: BloodSugar {
    
    // Creates blood sugar array from an array of values, with a timespan of 5 minutes between them, starting from current time back (last reading offset specifies the distance in seconds of the last reading)
    init(values: [Float], lastReadingOffset: TimeInterval = 120) {

        let now = Date()
        let readings: [Element] = (0..<values.count).map { index in
            let readingTimeOffset = -lastReadingOffset - TimeInterval((values.count - index - 1) * 60 * 5)
            let readingTime = now.addingTimeInterval(readingTimeOffset)
            return Element(value: values[index], timestamp: Double(readingTime.timeIntervalSince1970 * 1000), isMeteredBloodGlucoseValue: false, arrow: "-")
        }

        self = readings
    }
}

class BloodSugarArrayTest: XCTestCase {
    
    let bgValues: [Float] = [
        99, 102, 112, 119, 130, 128, 122, 109, 97, 77, 65, 64
    ]
    
    let ascendingBgValues: [Float] = [
        130, 138, 143, 150
    ]
    
    let withoutTrendBgValues: [Float] = [
        130, 128, 127, 129
    ]
    
    var readings: [BloodSugar] {
        return [BloodSugar](values: bgValues)
    }
    
    func readings(for values: [Float]) -> [BloodSugar] {
        return [BloodSugar](values: values)
    }
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // IMPORTANT: test bg values are in mg/dl
        UserDefaultsRepository.units.value = .mgdl
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK:- generic array extension: prefix / suffix
    func testPrefix1() {
        
        // get first 5 readings that are below 110 mg/dl
        let lessThan110Values = readings.prefix(5, where: { $0.value < 110 })
        XCTAssertEqual(lessThan110Values.count, 5)
        XCTAssertEqual(lessThan110Values[0].value, 99)
        XCTAssertEqual(lessThan110Values[1].value, 102)
        XCTAssertEqual(lessThan110Values[2].value, 109)
        XCTAssertEqual(lessThan110Values[3].value, 97)
        XCTAssertEqual(lessThan110Values[4].value, 77)
    }
    
    func testPrefix2() {

        // get first 5 readings that are between 70-100 mg/dl
        let between70And100Values = readings.prefix(5, where: { (70...100).contains($0.value) })
        XCTAssertEqual(between70And100Values.count, 3, "Should be ONLY 3 values")
        XCTAssertEqual(between70And100Values[0].value, 99)
        XCTAssertEqual(between70And100Values[1].value, 97)
        XCTAssertEqual(between70And100Values[2].value, 77)
    }
    
    func testSuffix() {
        
        // get last 3 readings taken in the last 20 minutes that are above 70 mg/dl
        let last20MinutesTimestamp = Double(Date().addingTimeInterval(-20 * 60).timeIntervalSince1970 * 1000)
        let above70ValuesInLatest20Minutes = readings.suffix(3, where: { $0.timestamp > last20MinutesTimestamp && $0.value > 70 })
        print(above70ValuesInLatest20Minutes)
        XCTAssertEqual(above70ValuesInLatest20Minutes.count, 2, "Should be ONLY 2 values")
        XCTAssertEqual(above70ValuesInLatest20Minutes[0].value, 97)
        XCTAssertEqual(above70ValuesInLatest20Minutes[1].value, 77)
    }
    
    // MARK:- BloodSugar array extension properties & methods
    func testDeltasForEmptyArray() {
        let emptyArray: [BloodSugar] = []
        XCTAssertEqual(emptyArray.deltas, [])
    }
    
    func testDeltasForArrayWithOneElement() {
        let oneElementArray: [BloodSugar] = [readings.first!]
        XCTAssertEqual(oneElementArray.deltas, [])
    }
    
    func testDeltasForArrayWithTwoElement() {
        let twoElementsArray: [BloodSugar] = [readings[0], readings[1]]
        XCTAssertEqual(twoElementsArray.deltas, [3])
    }

    func testDeltasForArrayWithManyElements() {
        
        var calculatedDeltas: [Float] = []
        for index in 1..<readings.count {
            calculatedDeltas.append(readings[index].value - readings[index - 1].value)
        }
        
        let deltas = readings.deltas
        XCTAssertEqual(calculatedDeltas.count, deltas.count)
        for index in 0..<deltas.count {
            XCTAssertEqual(calculatedDeltas[index], deltas[index])
        }
    }
    
    func testTrend() {
        XCTAssertEqual(readings(for: ascendingBgValues).trend, BloodSugarTrend.ascending)
        XCTAssertEqual(readings(for: ascendingBgValues.reversed()).trend, BloodSugarTrend.descending)
        XCTAssertEqual(readings(for: withoutTrendBgValues).trend, BloodSugarTrend.unknown)
    }
    
    func testLastXMinutes() {
        
        let readings = self.readings
        
        // no readings in last 2 minutes
        XCTAssertEqual(readings.lastXMinutes(0).count, 0)
        XCTAssertEqual(readings.lastXMinutes(1).count, 0)

        // last 5 minutes should contain the last reading
        let last5MinutesReadings = readings.lastXMinutes(5)
        XCTAssertEqual(last5MinutesReadings.count, 1)
        XCTAssertEqual(last5MinutesReadings[0], readings.last!)
        
        // last 10 minutes should contain 2 readings
        let last10MinutesReadings = readings.lastXMinutes(10)
        XCTAssertEqual(last10MinutesReadings.count, 2)
        XCTAssertEqual(last10MinutesReadings[0], readings[readings.count - 2])
        XCTAssertEqual(last10MinutesReadings[1], readings[readings.count - 1])
        
        // last 20 minutes should contain 4 readings
        let last20MinutesReadings = readings.lastXMinutes(20)
        XCTAssertEqual(last20MinutesReadings.count, 4)
        XCTAssertEqual(last20MinutesReadings[0], readings[readings.count - 4])
        XCTAssertEqual(last20MinutesReadings[1], readings[readings.count - 3])
        XCTAssertEqual(last20MinutesReadings[2], readings[readings.count - 2])
        XCTAssertEqual(last20MinutesReadings[3], readings[readings.count - 1])
    }
    
    func testLastConsecutive() {
        
        var readings = self.readings
        
        var lastConsecutive3Readings = readings.lastConsecutive(3) ?? []
        XCTAssertEqual(lastConsecutive3Readings.count, 3)
        XCTAssertEqual(lastConsecutive3Readings[0], readings[readings.count - 3])
        XCTAssertEqual(lastConsecutive3Readings[1], readings[readings.count - 2])
        XCTAssertEqual(lastConsecutive3Readings[2], readings[readings.count - 1])
        
        // supposing that we missed the latest value
        readings.removeLast()
        
        // the same tests should pass
        lastConsecutive3Readings = readings.lastConsecutive(3) ?? []
        XCTAssertEqual(lastConsecutive3Readings.count, 3)
        XCTAssertEqual(lastConsecutive3Readings[0], readings[readings.count - 3])
        XCTAssertEqual(lastConsecutive3Readings[1], readings[readings.count - 2])
        XCTAssertEqual(lastConsecutive3Readings[2], readings[readings.count - 1])

        // supposing that we missed the previous value also (2 missed values!)
        readings.removeLast()
        
        // no consecutive values are returned in this case, as we tolerate only one missed value!
        lastConsecutive3Readings = readings.lastConsecutive(3) ?? []
        XCTAssertEqual(lastConsecutive3Readings.count, 0)
        
        // ...BUT if we accept two missed values, the tests should pass again!
        lastConsecutive3Readings = readings.lastConsecutive(3, maxMissedReadings: 2) ?? []
        XCTAssertEqual(lastConsecutive3Readings.count, 3)
        XCTAssertEqual(lastConsecutive3Readings[0], readings[readings.count - 3])
        XCTAssertEqual(lastConsecutive3Readings[1], readings[readings.count - 2])
        XCTAssertEqual(lastConsecutive3Readings[2], readings[readings.count - 1])
    }
}
