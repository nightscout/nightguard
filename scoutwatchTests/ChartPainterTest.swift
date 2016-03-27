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

    func testYMinAdjustementIsWorking() {
        chartPainter.adjustMinMaxYCoordinates([0])
        XCTAssertEqual(chartPainter.minimumYValue, 0)
    }
    
    func testYMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxYCoordinates([220])
        XCTAssertEqual(chartPainter.maximumYValue, 220)
    }
    
    func testYValue0IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxYCoordinates([0])
        XCTAssertEqual(Int(chartPainter.calcYValue(0)), chartPainter.canvasHeight)
    }
    
    func testYValue200IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxYCoordinates([200])
        XCTAssertEqual(Int(chartPainter.calcYValue(200)), 0)
    }
    
    func testYValue300IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxYCoordinates([300])
        XCTAssertEqual(Int(chartPainter.calcYValue(300)), 0)
    }
    
    func testYValue40IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxYCoordinates([40])
        XCTAssertEqual(Int(chartPainter.calcYValue(40)), chartPainter.canvasHeight)
    }
    
    func testStretchedValue160ShouldBeStretchedToCanvasHeight() {
        XCTAssertEqual(Int(chartPainter.stretchedYValue(160 + chartPainter.minimumYValue)), chartPainter.canvasHeight)
    }
    
    func testXValue0OutOf2ShouldBe0AtCanvas() {
        XCTAssertEqual(Int(chartPainter.calcXValue(0, xValuesCount: 2)), 0)
    }
    
    func testXValue1OutOf2ShouldBeAtTheVeryRightAtTheCanvas() {
        XCTAssertEqual(Int(chartPainter.calcXValue(1, xValuesCount: 2)), chartPainter.canvasWidth)
    }
}
