//
//  NKRadarChart.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import "NKRadarChart.h"
#import "NKRadarChartDataItem.h"
#import "NKColor.h"

@interface NKRadarChart()

@property (nonatomic) CGRect frame;
@property (nonatomic) CGFloat centerX;
@property (nonatomic) CGFloat centerY;
@property (nonatomic) NSMutableArray *pointsToWebArrayArray;
@property (nonatomic) NSMutableArray *pointsToPlotArray;
@property (nonatomic) CGFloat lengthUnit;

@end

@implementation NKRadarChart

- (id)initWithFrame:(CGRect)frame items:(NSArray *)items valueDivider:(CGFloat)unitValue {
    self=[super init];
    if (self) {
        
        _frame = frame;
        if ([items count]< 3)//At least three corners of A polygon ,If the count of items is less than 3 will add 3 default values
        {
            NSLog( @"At least three items!");
            NSArray *defaultArray = @[[NKRadarChartDataItem dataItemWithValue:0 description:@"Default"],
                                      [NKRadarChartDataItem dataItemWithValue:0 description:@"Default"],
                                      [NKRadarChartDataItem dataItemWithValue:0 description:@"Default"],
                                      ];
            defaultArray = [defaultArray arrayByAddingObjectsFromArray:items];
            _chartData = [NSArray arrayWithArray:defaultArray];
        }else{
            _chartData = [NSArray arrayWithArray:items];
        }
        _valueDivider = unitValue;
        _maxValue = 1;
        _webColor = [UIColor grayColor];
        _plotColor = [UIColor colorWithRed:.4 green:.8 blue:.4 alpha:.7];
        _fontColor = [UIColor blackColor];
        _graduationColor = [UIColor orangeColor];
        _fontSize = 8;
        _labelStyle = NKRadarChartLabelStyleHorizontal;
        _isShowGraduation = NO;
        
        //Private iVar
        _centerX = _frame.size.width/2;
        _centerY = _frame.size.height/2;
        _pointsToWebArrayArray = [NSMutableArray array];
        _pointsToPlotArray = [NSMutableArray array];
        _lengthUnit = 0;
    }
    return self;
}

#pragma mark - main

- (UIImage *)drawImage
{
    
    CGFloat scale = [WKInterfaceDevice currentDevice].screenScale;
    UIGraphicsBeginImageContextWithOptions(_frame.size, false, scale);
    
    if (_chartBackgroundColor) {
        UIBezierPath *chartRect = [UIBezierPath bezierPathWithRect:_frame];
        [_chartBackgroundColor setFill];
        [chartRect fill];
    }

    [self calculateChartPoints];
    
    // Drawing backgound
    int section = 0;
    //circles
    for(NSArray *pointArray in _pointsToWebArrayArray){
        //plot backgound
        CGContextRef graphContext = UIGraphicsGetCurrentContext();
        CGContextBeginPath(graphContext);
        CGPoint beginPoint = [[pointArray objectAtIndex:0] CGPointValue];
        CGContextMoveToPoint(graphContext, beginPoint.x, beginPoint.y);
        for(NSValue* pointValue in pointArray){
            CGPoint point = [pointValue CGPointValue];
            CGContextAddLineToPoint(graphContext, point.x, point.y);
        }
        CGContextAddLineToPoint(graphContext, beginPoint.x, beginPoint.y);
        CGContextSetStrokeColorWithColor(graphContext, _webColor.CGColor);
        CGContextStrokePath(graphContext);
        
    }
    //cuts
    NSArray *largestPointArray = [_pointsToWebArrayArray lastObject];
    for (NSValue *pointValue in largestPointArray){
        section++;
        if (section==1&&_isShowGraduation)continue;
        
        CGContextRef graphContext = UIGraphicsGetCurrentContext();
        CGContextBeginPath(graphContext);
        CGContextMoveToPoint(graphContext, _centerX, _centerY);
        CGPoint point = [pointValue CGPointValue];
        CGContextAddLineToPoint(graphContext, point.x, point.y);
        CGContextSetStrokeColorWithColor(graphContext, _webColor.CGColor);
        CGContextStrokePath(graphContext);
    }
    
    //Draw plot
    UIBezierPath *plotline = [UIBezierPath bezierPath];
    CGPoint beginPoint = [[_pointsToPlotArray objectAtIndex:0] CGPointValue];
    [plotline moveToPoint:CGPointMake(beginPoint.x, beginPoint.y)];
    for(NSValue *pointValue in _pointsToPlotArray){
        CGPoint point = [pointValue CGPointValue];
        [plotline addLineToPoint:CGPointMake(point.x ,point.y)];
        
    }
    [plotline setLineWidth:1];
    [plotline setLineCapStyle:kCGLineCapButt];
    [plotline setLineJoinStyle:kCGLineJoinMiter];
    [plotline closePath];
    [_plotColor setFill];
    [plotline fill];
    
    if (_isShowGraduation) {
        [self showGraduation];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)calculateChartPoints {
    [_pointsToPlotArray removeAllObjects];
    [_pointsToWebArrayArray removeAllObjects];
    
    //init Descriptions , Values and Angles.
    NSMutableArray *descriptions = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    NSMutableArray *angles = [NSMutableArray array];
    for (int i=0;i<_chartData.count;i++) {
        NKRadarChartDataItem *item = (NKRadarChartDataItem *)[_chartData objectAtIndex:i];
        [descriptions addObject:item.textDescription];
        [values addObject:[NSNumber numberWithFloat:item.value]];
        CGFloat angleValue = (float)i/(float)[_chartData count]*2*M_PI;
        [angles addObject:[NSNumber numberWithFloat:angleValue]];
    }
    
    //calculate all the lengths
    _maxValue = [self getMaxValueFromArray:values];
    CGFloat margin = 0;
    if (_labelStyle==NKRadarChartLabelStyleHorizontal) {
        margin = [self getMaxWidthLabelFromArray:descriptions withFontSize:_fontSize];
    }
    CGFloat maxLength = ceil(MIN(_centerX, _centerY) - margin);
    int plotCircles = (_maxValue/_valueDivider);
    if (plotCircles > MAXCIRCLE) {
        NSLog(@"Circle number is higher than max");
        plotCircles = MAXCIRCLE;
        _valueDivider = _maxValue/plotCircles;
    }
    _lengthUnit = maxLength/plotCircles;
    NSArray *lengthArray = [self getLengthArrayWithCircleNum:(int)plotCircles];
    
    //get all the points and plot
    for (NSNumber *lengthNumber in lengthArray) {
        CGFloat length = [lengthNumber floatValue];
        [_pointsToWebArrayArray addObject:[self getWebPointWithLength:length angleArray:angles]];
    }
    int section = 0;
    for (id value in values) {
        CGFloat valueFloat = [value floatValue];
        if (valueFloat>_maxValue) {
            NSString *reason = [NSString stringWithFormat:@"Value number is higher than max -value: %f - maxValue: %f",valueFloat,_maxValue];
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
            return;
        }
        
        CGFloat length = valueFloat/_maxValue*maxLength;
        CGFloat angle = [[angles objectAtIndex:section] floatValue];
        CGFloat x = _centerX +length*cos(angle);
        CGFloat y = _centerY +length*sin(angle);
        NSValue* point = [NSValue valueWithCGPoint:CGPointMake(x, y)];
        [_pointsToPlotArray addObject:point];
        section++;
    }
    //set the labels
    [self drawLabelWithMaxLength:maxLength labelArray:descriptions angleArray:angles];
    
}

#pragma helpers

- (void)drawLabelWithMaxLength:(CGFloat)maxLength labelArray:(NSArray *)labelArray angleArray:(NSArray *)angleArray
{
    int section = 0;
    CGFloat labelLength = maxLength + maxLength/10;
    
    for (NSString *labelString in labelArray) {
        CGFloat angle = [[angleArray objectAtIndex:section] floatValue];
        CGFloat x = _centerX + labelLength *cos(angle);
        CGFloat y = _centerY + labelLength *sin(angle);
        
        // label.backgroundColor = [UIColor clearColor];
        UIFont *font = [UIFont systemFontOfSize:_fontSize];
        CGSize detailSize = [labelString sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:_fontSize]}];
        CGRect frame = CGRectZero;
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:font forKey:NSFontAttributeName];
        [attributes setObject:NKGreen forKey:NSForegroundColorAttributeName];
        
        NSMutableParagraphStyle *paragraphStyle =NSMutableParagraphStyle.new;
        switch (_labelStyle) {
            case NKRadarChartLabelStyleHorizontal:
                if (x<_centerX) {
                    frame = CGRectMake(x-detailSize.width, y-detailSize.height/2, detailSize.width, detailSize.height);
                    paragraphStyle.alignment = NSTextAlignmentRight;
                    [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                    [labelString drawInRect:frame withAttributes:attributes];
                    
                }else{
                    frame = CGRectMake(x, y-detailSize.height/2, detailSize.width , detailSize.height);
                    paragraphStyle.alignment = NSTextAlignmentLeft;
                    [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                    [labelString drawInRect:frame withAttributes:attributes];
                    
                }
                break;
            case NKRadarChartLabelStyleHidden:
                break;
            default:
                break;
        }
        
        section ++;
    }
    
}

- (void)showGraduation
{
    int section = 0;
    for (NSArray *pointsArray in _pointsToWebArrayArray) {
        section++;
        CGPoint labelPoint = [[pointsArray objectAtIndex:0] CGPointValue];
        CGRect graduationRect = CGRectMake(labelPoint.x-_lengthUnit, labelPoint.y-_lengthUnit*5/8, _lengthUnit*5/8, _lengthUnit);
        CGFloat fontSize;
        if (ceil(_lengthUnit-1) < 1) {
            fontSize = 1.0;
        } else {
            fontSize = ceil(_lengthUnit-1);
        }
        UIFont *font = [UIFont systemFontOfSize:fontSize];
        UIColor *textColor = [UIColor orangeColor];
        NSString *text = [NSString stringWithFormat:@"%.0f",_valueDivider*section];
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:font forKey:NSFontAttributeName];
        [attributes setObject:textColor forKey:NSForegroundColorAttributeName];
        
        [text drawInRect:graduationRect withAttributes:attributes];
    }
 
 }

- (NSArray *)getWebPointWithLength:(CGFloat)length angleArray:(NSArray *)angleArray {
    NSMutableArray *pointArray = [NSMutableArray array];
    for (NSNumber *angleNumber in angleArray) {
        CGFloat angle = [angleNumber floatValue];
        CGFloat x = _centerX + length*cos(angle);
        CGFloat y = _centerY + length*sin(angle);
        [pointArray addObject:[NSValue valueWithCGPoint:CGPointMake(x,y)]];
    }
    return pointArray;
    
}

- (NSArray *)getLengthArrayWithCircleNum:(int)plotCircles {
    NSMutableArray *lengthArray = [NSMutableArray array];
    CGFloat length = 0;
    for (int i = 0; i < plotCircles; i++) {
        length += _lengthUnit;
        [lengthArray addObject:[NSNumber numberWithFloat:length]];
    }
    return lengthArray;
}

- (CGFloat)getMaxWidthLabelFromArray:(NSArray *)keyArray withFontSize:(CGFloat)size {
    CGFloat maxWidth = 0;
    for (NSString *str in keyArray) {
        CGSize detailSize = [str sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:_fontSize]}];
        maxWidth = MAX(maxWidth, detailSize.width);
    }
    return maxWidth;
}

- (CGFloat)getMaxValueFromArray:(NSArray *)valueArray {
    CGFloat max = _maxValue;
    for (NSNumber *valueNum in valueArray) {
        CGFloat valueFloat = [valueNum floatValue];
        max = MAX(valueFloat, max);
    }
    return ceil(max);
}

@end