//
//  NKCircleChart.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM (NSUInteger, NKChartFormatType) {
    NKChartFormatTypePercent,
    NKChartFormatTypeDollar,
    NKChartFormatTypeNone
};

#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

@interface NKCircleChart : NSObject

- (id)initWithFrame:(CGRect)frame
              total:(NSNumber *)total
            current:(NSNumber *)current
          clockwise:(BOOL)clockwise;

- (id)initWithFrame:(CGRect)frame
              total:(NSNumber *)total
            current:(NSNumber *)current
          clockwise:(BOOL)clockwise
             shadow:(BOOL)hasBackgroundShadow
        shadowColor:(UIColor *)backgroundShadowColor;

- (id)initWithFrame:(CGRect)frame
              total:(NSNumber *)total
            current:(NSNumber *)current
          clockwise:(BOOL)clockwise
             shadow:(BOOL)hasBackgroundShadow
        shadowColor:(UIColor *)backgroundShadowColor
displayCountingLabel:(BOOL)displayCountingLabel;

- (id)initWithFrame:(CGRect)frame
              total:(NSNumber *)total
            current:(NSNumber *)current
          clockwise:(BOOL)clockwise
             shadow:(BOOL)hasBackgroundShadow
        shadowColor:(UIColor *)backgroundShadowColor
displayCountingLabel:(BOOL)displayCountingLabel
  overrideLineWidth:(NSNumber *)overrideLineWidth;

@property (nonatomic) UIColor *chartBackgroundColor;
@property (nonatomic) UIColor *strokeColor;
@property (nonatomic) UIColor *strokeColorGradientStart;
@property (nonatomic) NSNumber *total;
@property (nonatomic) NSNumber *current;
@property (nonatomic) NSNumber *lineWidth;
@property (nonatomic) NKChartFormatType chartType;
@property (nonatomic) BOOL clockwise;
@property (nonatomic) BOOL hasBackgroundShadow;
@property (nonatomic) UIColor *backgroundShadowColor;
@property (nonatomic) BOOL displayCountingLabel;

- (UIImage *)drawImage;

@end

