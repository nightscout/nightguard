//
//  NKLineChart.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/7/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NKLineChart : NSObject

// Background color of the chart
@property (nonatomic) UIColor *chartBackgroundColor;
// Array of `LineChartData` objects, one for each line.
@property (nonatomic) NSArray *chartData;
@property (nonatomic) CGFloat chartMargin;

@property (nonatomic) BOOL showLabel;

@property (nonatomic) NSArray *xLabels;
@property (nonatomic) NSArray *yLabels;
@property (nonatomic) CGFloat xLabelWidth;
@property (nonatomic) UIFont *xLabelFont;
@property (nonatomic) UIColor *xLabelColor;

@property (nonatomic) UIFont *yLabelFont;
@property (nonatomic) UIColor *yLabelColor;
@property (nonatomic) NSInteger yLabelNum;
@property (nonatomic) CGFloat yLabelHeight;

@property (nonatomic) CGFloat yValueMax;
@property (nonatomic) CGFloat yValueMin;
@property (nonatomic) CGFloat yFixedValueMax;
@property (nonatomic) CGFloat yFixedValueMin;

// Controls whether to show the coordinate axis. Default is NO.
@property (nonatomic, getter = isShowCoordinateAxis) BOOL showCoordinateAxis;
@property (nonatomic) UIColor *axisColor;
@property (nonatomic) CGFloat axisWidth;

@property (nonatomic, strong) NSString *xUnit;
@property (nonatomic, strong) NSString *yUnit;

// String formatter for float values in y-axis labels. If not set, defaults to @"%1.f"
@property (nonatomic, strong) NSString *yLabelFormat;

//Block formatter for custom string in y-axis labels. If not set, defaults to yLabelFormat
@property (nonatomic, copy) NSString* (^yLabelBlockFormatter)(CGFloat);

@property (nonatomic) BOOL thousandsSeparator;

- (instancetype) initWithFrame:(CGRect)frame;
- (UIImage *)drawImage;

@end