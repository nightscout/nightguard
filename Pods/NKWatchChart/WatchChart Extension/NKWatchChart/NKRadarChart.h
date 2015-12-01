//
//  NKRadarChart.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define MAXCIRCLE 30

typedef NS_ENUM(NSUInteger, NKRadarChartLabelStyle) {
    NKRadarChartLabelStyleHorizontal = 0,
    NKRadarChartLabelStyleHidden,
};

@interface NKRadarChart : NSObject

@property (nonatomic) UIColor *chartBackgroundColor;
/** Array of `RadarChartDataItem` objects, one for each corner. */
@property (nonatomic) NSArray *chartData;
/** The unit of this chart ,default is 1 */
@property (nonatomic) CGFloat valueDivider;
/** The maximum for the range of values to display on the chart */
@property (nonatomic) CGFloat maxValue;
/** Default is gray. */
@property (nonatomic) UIColor *webColor;
/** Default is green , with an alpha of 0.7 */
@property (nonatomic) UIColor *plotColor;
/** Default is black */
@property (nonatomic) UIColor *fontColor;
/** Default is orange */
@property (nonatomic) UIColor *graduationColor;
/** Default is 15 */
@property (nonatomic) CGFloat fontSize;
/** Controls the labels display style that around chart */
@property (nonatomic, assign) NKRadarChartLabelStyle labelStyle;
/** is show graduation on the chart ,default is NO. */
@property (nonatomic, assign) BOOL isShowGraduation;

-(id)initWithFrame:(CGRect)frame  items:(NSArray *)items valueDivider:(CGFloat)unitValue;
/**
 *Draws the chart in an animated fashion.
 */
-(UIImage *)drawImage;

@end
