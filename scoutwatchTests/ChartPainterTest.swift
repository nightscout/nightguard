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

    func testXMinAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 100, timestamp: 10000), BloodSugar.init(value: 200, timestamp: 20000)])
        XCTAssertEqual(chartPainter.minimumXValue, 10000)
    }
    
    func testStretchedValueShouldBeStretchedToCanvasMinAndMaxWidth() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 100, timestamp: 10000), BloodSugar.init(value: 200, timestamp: 20000)])
        
        XCTAssertEqual(Int(chartPainter.stretchedXValue(10000)), 0)
        XCTAssertEqual(Int(chartPainter.stretchedXValue(20000)), chartPainter.canvasWidth)
    }
    
    func testXMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 100, timestamp: 10000), BloodSugar.init(value: 200, timestamp: 20000)])
        XCTAssertEqual(chartPainter.maximumXValue, 20000)
    }
    
    func testYMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 220, timestamp: 0)])
        XCTAssertEqual(chartPainter.maximumYValue, 220)
    }
    
    func testYValue0IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 0, timestamp: 0)])
        XCTAssertEqual(Int(chartPainter.calcYValue(0)), chartPainter.canvasHeight)
    }
    
    func testYValue200IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 200, timestamp: 0)])
        XCTAssertEqual(Int(chartPainter.calcYValue(200)), 0)
    }
    
    func testYValue300IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 300, timestamp: 0)])
        XCTAssertEqual(Int(chartPainter.calcYValue(300)), 0)
    }
    
    func testYValue40IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([BloodSugar.init(value: 40, timestamp: 0)])
        XCTAssertEqual(Int(chartPainter.calcYValue(40)), chartPainter.canvasHeight)
    }
    
    func testStretchedValue160ShouldBeStretchedToCanvasHeight() {
        XCTAssertEqual(Int(chartPainter.stretchedYValue(160 + chartPainter.minimumYValue)), chartPainter.canvasHeight)
    }
}
