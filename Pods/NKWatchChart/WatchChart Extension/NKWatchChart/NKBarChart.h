//
//  NKBarChart.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/6/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WatchKit/WatchKit.h>

#define kXLabelMargin 8
#define kYLabelMargin 8
#define kYLabelHeight 8
#define kXLabelHeight 8

typedef NSString *(^NKYLabelFormatter)(CGFloat yLabelValue);

@interface NKBarChart : NSObject

- (id)initWithFrame:(CGRect)frame;
- (UIImage *)drawImage;

@property (nonatomic) BOOL showLabel;
@property (nonatomic) UIColor *labelTextColor;
@property (nonatomic) UIFont *labelFont;
@property (nonatomic) CGFloat labelMarginTop;

@property (nonatomic) NSArray *xLabels;
@property (nonatomic) NSInteger xLabelSkip;

@property (nonatomic) NSArray *yLabels;
@property (nonatomic) NSArray *yValues;
/** How many labels on the y-axis to skip in between displaying labels. */
@property (nonatomic) NSInteger yLabelSum;
/** Formats the ylabel text. */
@property (copy) NKYLabelFormatter yLabelFormatter;

/** Prefix to y label values, none if unset. */
@property (nonatomic) NSString *yLabelPrefix;

/** Suffix to y label values, none if unset. */
@property (nonatomic) NSString *yLabelSuffix;

/** The maximum for the range of values to display on the y-axis. */
@property (nonatomic) CGFloat yMaxValue;

/** The minimum for the range of values to display on the y-axis. */
@property (nonatomic) CGFloat yMinValue;

/** Changes chart margin. */
@property (nonatomic) CGFloat yChartLabelWidth;

@property (nonatomic) UIColor *chartBackgroundColor;
@property (nonatomic) UIColor *barBackgroundColor;
@property (nonatomic) UIColor *barColor;

@property (nonatomic) CGFloat chartMargin;

/** Corner radius for all bars in the chart. */
@property (nonatomic) CGFloat barRadius;

/** Width of all bars in the chart. */
@property (nonatomic) CGFloat barWidth;

/** Controls whether the chart border line should be displayed. */
@property (nonatomic) BOOL showChartBorder;

@property (nonatomic) UIColor *chartBorderColor;

@property (nonatomic) UIColor *strokeColor;
@property (nonatomic) NSArray *strokeColors;

@end
