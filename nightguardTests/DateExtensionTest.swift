//
//  DateExtensionTest.swift
//  nightguardTests
//
//  Created by Jörg Schömer on 04.12.23.
//

import XCTest
import Foundation

final class DateExtensionTest: XCTestCase {
    
    func testCEST() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CEST"),
            year: 2023,
            month: 6,
            day: 7,
            hour: 2,
            minute: 0,
            second: 0
        ).date!
        
        // when
        let mills = Double(testDate.toUTCMillis())!
        
        // then
        // recreate date from mills
        // Returns a `Date` initialized relative to 00:00:00 UTC on 1 January 1970 by a given number of seconds.
        let millsDate = Date(timeIntervalSince1970: mills / 1000.0)
        XCTAssertEqual(millsDate.formatted(Date.ISO8601FormatStyle()), "2023-06-07T00:00:00Z")
    }
    
    func testCET() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CET"),
            year: 2023,
            month: 12,
            day: 4,
            hour: 19,
            minute: 10,
            second: 0
        ).date!
        
        // when
        let mills = Double(testDate.toUTCMillis())!
        
        // then
        // recreate date from mills
        // Returns a `Date` initialized relative to 00:00:00 UTC on 1 January 1970 by a given number of seconds.
        let millsDate = Date(timeIntervalSince1970: mills / 1000.0)
        XCTAssertEqual(millsDate.formatted(Date.ISO8601FormatStyle()), "2023-12-04T18:10:00Z")
    }
    
    func testTimeIntervalSince1970CET() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CET"),
            year: 2023,
            month: 12,
            day: 4,
            hour: 19,
            minute: 10,
            second: 0
        ).date!
        
        // when
        /**
         The interval between the date object and 00:00:00 UTC on 1 January 1970.
         
         This property's value is negative if the date object is earlier than 00:00:00 UTC on 1 January 1970.
         */
        let millisSince1970UTC: Int64 = Int64((testDate.timeIntervalSince1970 * 1000.0).rounded())
        
        // then
        let utcDate = Date(timeIntervalSince1970: (Double(millisSince1970UTC) / 1000.0))
        XCTAssertEqual(utcDate.formatted(Date.ISO8601FormatStyle()), "2023-12-04T18:10:00Z")
    }
    
    func testTimeIntervalSince1970CEST() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CEST"),
            year: 2023,
            month: 06,
            day: 7,
            hour: 2,
            minute: 0,
            second: 0
        ).date!
        
        // when
        /**
         The interval between the date object and 00:00:00 UTC on 1 January 1970.
         
         This property's value is negative if the date object is earlier than 00:00:00 UTC on 1 January 1970.
         */
        let millisSince1970UTC: Int64 = Int64((testDate.timeIntervalSince1970 * 1000.0).rounded())
        
        // then
        let utcDate = Date(timeIntervalSince1970: (Double(millisSince1970UTC) / 1000.0))
        XCTAssertEqual(utcDate.formatted(Date.ISO8601FormatStyle()), "2023-06-07T00:00:00Z")
    }
    
    func testConvertToIsoDateTime() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CEST"),
            year: 2023,
            month: 06,
            day: 7,
            hour: 2,
            minute: 0,
            second: 0
        ).date!
        
        // when
        let dateString = testDate.convertToIsoDateTime()
        
        //then
        XCTAssertEqual(dateString, "2023-06-07T00:00:00Z")
    }
    
    func testConvertToIsoDate() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CEST"),
            year: 2023,
            month: 06,
            day: 7,
            hour: 2,
            minute: 0,
            second: 0
        ).date!

        // when
        let dateString = testDate.convertToIsoDate()
        
        // then
        XCTAssertEqual(dateString, "2023-06-07")
    }
    
    func testToUTCMillis() throws {
        // given
        let testDate = DateComponents(
            calendar: .current,
            timeZone: TimeZone.init(identifier: "CEST"),
            year: 2023,
            month: 06,
            day: 7,
            hour: 2,
            minute: 0,
            second: 0
        ).date!

        // when
        let millisString = testDate.toUTCMillis()

        // then
        XCTAssertEqual(millisString, "1686096000000")
    }
}
