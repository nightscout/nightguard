//
//  NKLineChart.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/7/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import "NKLineChart.h"
#import "NKLineChartData.h"
#import "NKLineChartDataItem.h"
#import "NKColor.h"

@interface NKLineChart ()

@property (nonatomic) CGRect frame;
@property (nonatomic) NSMutableArray *chartLineArray;

// Array of line path, one for each line.
@property (nonatomic) NSMutableArray *chartPath;

// Array of point path, one for each line
@property (nonatomic) NSMutableArray *pointPath;

// Array of start and end points of each line path, one for each line
@property (nonatomic) NSMutableArray *endPointsOfPath;

@property (nonatomic) NSMutableArray *pathPoints;
@property (nonatomic) CGFloat chartCavanHeight;
@property (nonatomic) CGFloat chartCavanWidth;

// display grade
@property (nonatomic) NSMutableArray *gradeStringPaths;

@end

@implementation NKLineChart

- (instancetype) initWithFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
        _frame = frame;
        [self setupDefaultValues];
    }
    
    return self;
}

- (void)setupDefaultValues
{
    // Initialization code
    _chartLineArray       = [NSMutableArray new];
    _showLabel            = YES;
    _pathPoints           = [[NSMutableArray alloc] init];
    _endPointsOfPath      = [[NSMutableArray alloc] init];
    
    _yFixedValueMin       = -FLT_MAX;
    _yFixedValueMax       = -FLT_MAX;
    _yLabelNum            = 5.0;
    _yLabelHeight         = 8;
    
    _chartMargin = 18;
    _chartCavanWidth = _frame.size.width - _chartMargin * 2;
    _chartCavanHeight = _frame.size.height - _chartMargin * 2;
    
    // Coordinate Axis Default Values
    _showCoordinateAxis = NO;
    _axisColor = [UIColor colorWithRed:0.4f green:0.4f blue:0.4f alpha:1.f];
    _axisWidth = 1.f;
}

#pragma mark - Draw Chart

- (UIImage *)drawImage
{
    CGFloat scale = [WKInterfaceDevice currentDevice].screenScale;
    
    UIGraphicsBeginImageContextWithOptions(_frame.size, false, scale);
    
    if (_chartBackgroundColor) {
        UIBezierPath *chartRect = [UIBezierPath bezierPathWithRect:_frame];
        [_chartBackgroundColor setFill];
        [chartRect fill];
    }
    
    if (self.isShowCoordinateAxis)
    {
        [self drawCoordinate];
    }
    
    [self drawYLabels];
    [self drawXLabels];
    [self drawLines];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)drawCoordinate
{
    CGFloat yAxisOffset = 5.f;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, _axisWidth);
    CGContextSetStrokeColorWithColor(ctx, [_axisColor CGColor]);
    
    CGFloat xAxisEndPointX = CGRectGetWidth(_frame) - _chartMargin/2;
    CGFloat yAxisCorssPointY = _chartMargin + _chartCavanHeight;
    
    // draw coordinate axis
    CGContextMoveToPoint(ctx, _chartMargin + yAxisOffset, 0);
    CGContextAddLineToPoint(ctx, _chartMargin + yAxisOffset, yAxisCorssPointY);
    CGContextAddLineToPoint(ctx, xAxisEndPointX, yAxisCorssPointY);
    CGContextStrokePath(ctx);
    
    // draw y axis arrow
    CGContextMoveToPoint(ctx, _chartMargin + yAxisOffset - 3, 3);
    CGContextAddLineToPoint(ctx, _chartMargin + yAxisOffset, 0);
    CGContextAddLineToPoint(ctx, _chartMargin + yAxisOffset + 3, 3);
    CGContextStrokePath(ctx);
    
    // draw x axis arrow
    CGContextMoveToPoint(ctx, xAxisEndPointX - 3, yAxisCorssPointY - 3);
    CGContextAddLineToPoint(ctx, xAxisEndPointX, yAxisCorssPointY);
    CGContextAddLineToPoint(ctx, xAxisEndPointX - 3, yAxisCorssPointY + 3);
    CGContextStrokePath(ctx);
    
    if (_showLabel)
    {
        _xLabelWidth = (_chartCavanWidth - yAxisOffset) / [_xLabels count];
        // draw x axis separator
        CGPoint point;
        for (NSUInteger i = 0; i < [_xLabels count]; i++) {
            point = CGPointMake(2 * _chartMargin +  (i * _xLabelWidth), _chartMargin + _chartCavanHeight);
            CGContextMoveToPoint(ctx, point.x, point.y - 2);
            CGContextAddLineToPoint(ctx, point.x, point.y);
            CGContextStrokePath(ctx);
        }
        
        // draw y axis separator
        if (_showLabel) {
            _yLabelHeight = _chartCavanHeight / [_yLabels count];
        } else {
            _yLabelHeight = (_frame.size.height) / [_yLabels count];
        }
        
        _yLabelNum = _yLabels.count - 1;
        CGFloat yStepHeight = _chartCavanHeight / _yLabelNum;
        for (NSUInteger i = 0; i < [_xLabels count]; i++)
        {
            point = CGPointMake(_chartMargin + yAxisOffset, (_chartCavanHeight - i * yStepHeight + _yLabelHeight / 2));
            CGContextMoveToPoint(ctx, point.x, point.y);
            CGContextAddLineToPoint(ctx, point.x + 2, point.y);
            CGContextStrokePath(ctx);
        }
        
        UIFont *font = [UIFont systemFontOfSize:10];
        
        // draw y unit
        if ([_yUnit length]) {
            CGFloat height = [NKLineChart sizeOfString:_yUnit withWidth:30.f font:font].height;
            CGRect drawRect = CGRectMake(_chartMargin + 10 + 5, 0, 30.f, height);
            [self drawTextInContext:ctx text:_yUnit inRect:drawRect font:font];
        }
        
        // draw x unit
        if ([_xUnit length]) {
            CGFloat height = [NKLineChart sizeOfString:_xUnit withWidth:30.f font:font].height;
            CGRect drawRect = CGRectMake(CGRectGetWidth(_frame) - _chartMargin - 10, _chartMargin + _chartCavanHeight - 2*height, 30.f, height);
            [self drawTextInContext:ctx text:_xUnit inRect:drawRect font:font];
        }
        
    }
    
}

- (void) drawXLabels
{
    if (_showLabel) {
        _xLabelWidth = _chartCavanWidth / [_xLabels count];
    } else {
        _xLabelWidth = (_frame.size.width) / [_xLabels count];
    }
    
    NSMutableDictionary *attributesDictionary = [NSMutableDictionary dictionary];
    if (_xLabelFont)
    {
        [attributesDictionary setObject:_xLabelFont forKey:NSFontAttributeName];
    }
    if (_xLabelColor)
    {
        
        [attributesDictionary setObject:_xLabelColor forKey:NSForegroundColorAttributeName];
    }

    NSMutableParagraphStyle *priceParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    priceParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    priceParagraphStyle.alignment = NSTextAlignmentCenter;
    [attributesDictionary setObject:priceParagraphStyle forKey:NSParagraphStyleAttributeName];
    
    NSString *labelText;
    
    if (_showLabel) {
        
        for (int index = 0; index < _xLabels.count; index++) {
            labelText = _xLabels[index];
            
            NSInteger x = 2 * _chartMargin +  (index * _xLabelWidth) - (_xLabelWidth / 2);
            NSInteger y = _chartMargin + _chartCavanHeight;
            
            CGRect labelRect = CGRectMake(x, y, (NSInteger)_xLabelWidth, (NSInteger)_chartMargin);
            [labelText drawInRect:labelRect
                   withAttributes:attributesDictionary];
        }
    }
    
}

- (void) drawYLabels
{
    [self prepareYLabelsWithData:_chartData];
    //_showGenYLabels = NO;
    _yLabelNum = _yLabels.count - 1;
    
    if (_showLabel) {
        _yLabelHeight = _chartCavanHeight / [_yLabels count];
    } else {
        _yLabelHeight = (_frame.size.height) / [_yLabels count];
    }
    
    CGFloat yStep = (_yValueMax - _yValueMin) / _yLabelNum;
    CGFloat yStepHeight = _chartCavanHeight / _yLabelNum;
    
    NSMutableDictionary *attributesDictionary = [NSMutableDictionary dictionary];
    if (_yLabelFont)
    {
        [attributesDictionary setObject:_yLabelFont forKey:NSFontAttributeName];
    }
    if (_yLabelColor)
    {
        
        [attributesDictionary setObject:_yLabelColor forKey:NSForegroundColorAttributeName];
    }
    
    NSMutableParagraphStyle *priceParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    priceParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    priceParagraphStyle.alignment = NSTextAlignmentCenter;
    [attributesDictionary setObject:priceParagraphStyle forKey:NSParagraphStyleAttributeName];
    
    if (yStep == 0.0)
    {
        CGRect minLabelRect = CGRectMake(0.0, (NSInteger)_chartCavanHeight, (NSInteger)_chartMargin, (NSInteger)_yLabelHeight);
        NSString *minLabelText = [self formatYLabel:0.0];
        [minLabelText drawInRect:minLabelRect
                  withAttributes:attributesDictionary];
        
        CGRect midLabelRect = CGRectMake(0.0, (NSInteger)(_chartCavanHeight / 2), (NSInteger)_chartMargin, (NSInteger)_yLabelHeight);
        NSString *midLabelText = [self formatYLabel:_yValueMax];
        [midLabelText drawInRect:midLabelRect
                  withAttributes:attributesDictionary];
        
        CGRect maxLabelRect =CGRectMake(0.0, 0.0, (NSInteger)_chartMargin, (NSInteger)_yLabelHeight);
        NSString *maxLabelText = [self formatYLabel:_yValueMax * 2];
        [maxLabelText drawInRect:maxLabelRect
                  withAttributes:attributesDictionary];
        
        
    } else {
        
        NSInteger index = 0;
        NSInteger num = _yLabelNum + 1;
        
        while (num > 0)
        {
            CGRect labelRect = CGRectMake(0.0, (NSInteger)(_chartCavanHeight - index * yStepHeight)+(_yLabelHeight / 4), (NSInteger)_chartMargin, (NSInteger)_yLabelHeight);
            NSString *text = [self formatYLabel:_yValueMin + (yStep * index)];
            [text drawInRect:labelRect
              withAttributes:attributesDictionary];
            index += 1;
            num -= 1;
        }
        
    }
}

- (void)drawLines
{
    _chartPath = [[NSMutableArray alloc] init];
    _pointPath = [[NSMutableArray alloc] init];
    _gradeStringPaths = [NSMutableArray array];
    
    [self calculateChartPath:_chartPath andPointsPath:_pointPath andPathKeyPoints:_pathPoints andPathStartEndPoints:_endPointsOfPath];
    
    // Draw each line
    for (NSUInteger lineIndex = 0; lineIndex < _chartData.count; lineIndex++)
    {
        NKLineChartData *chartData = _chartData[lineIndex];
        
        UIBezierPath *chartLinePath = [_chartPath objectAtIndex:lineIndex];
        UIBezierPath *pointPath = [_pointPath objectAtIndex:lineIndex];
        
        if (chartData.color) {
            [[chartData.color colorWithAlphaComponent:chartData.alpha] setStroke];
            
        } else {
            [NKGreen setStroke];
            
        }
        
        [chartLinePath stroke];
        [pointPath stroke];
    }
}

- (void)calculateChartPath:(NSMutableArray *)chartPath andPointsPath:(NSMutableArray *)pointsPath andPathKeyPoints:(NSMutableArray *)pathPoints andPathStartEndPoints:(NSMutableArray *)pointsOfPath
{
    
    // Draw each line
    for (NSUInteger lineIndex = 0; lineIndex < _chartData.count; lineIndex++) {
        NKLineChartData *chartData = _chartData[lineIndex];
        
        CGFloat yValue;
        CGFloat innerGrade;
        
        UIBezierPath *progressline = [UIBezierPath bezierPath];
        
        UIBezierPath *pointPath = [UIBezierPath bezierPath];
        
        
        [chartPath insertObject:progressline atIndex:lineIndex];
        [pointsPath insertObject:pointPath atIndex:lineIndex];
        
        
        NSMutableArray* gradePathArray = [NSMutableArray array];
        [_gradeStringPaths addObject:gradePathArray];
        
        if (!_showLabel) {
            _chartCavanHeight = _frame.size.height - 2 * _yLabelHeight;
            _chartCavanWidth = _frame.size.width;
            _chartMargin = chartData.inflexionPointWidth;
            _xLabelWidth = (_chartCavanWidth / ([_xLabels count] - 1));
        }
        
        NSMutableArray *linePointsArray = [[NSMutableArray alloc] init];
        NSMutableArray *lineStartEndPointsArray = [[NSMutableArray alloc] init];
        int last_x = 0;
        int last_y = 0;
        CGFloat inflexionWidth = chartData.inflexionPointWidth;
        
        for (NSUInteger i = 0; i < chartData.itemCount; i++) {
            
            yValue = chartData.getData(i).y;
            
            if (!(_yValueMax - _yValueMin)) {
                innerGrade = 0.5;
            } else {
                innerGrade = (yValue - _yValueMin) / (_yValueMax - _yValueMin);
            }
            
            CGFloat offSetX = (_chartCavanWidth) / (chartData.itemCount);
            
            int x = 2 * _chartMargin +  (i * offSetX);
            int y = _chartCavanHeight - (innerGrade * _chartCavanHeight) + (_yLabelHeight / 2);
            
            // Circular point
            if (chartData.inflexionPointStyle == NKLineChartPointStyleCircle) {
                
                CGRect circleRect = CGRectMake(x - inflexionWidth / 2, y - inflexionWidth / 2, inflexionWidth, inflexionWidth);
                CGPoint circleCenter = CGPointMake(circleRect.origin.x + (circleRect.size.width / 2), circleRect.origin.y + (circleRect.size.height / 2));
                
                [pointPath moveToPoint:CGPointMake(circleCenter.x + (inflexionWidth / 2), circleCenter.y)];
                [pointPath addArcWithCenter:circleCenter radius:inflexionWidth / 2 startAngle:0 endAngle:2 * M_PI clockwise:YES];
                
                if ( i != 0 ) {
                    
                    // calculate the point for line
                    float distance = sqrt(pow(x - last_x, 2) + pow(y - last_y, 2) );
                    float last_x1 = last_x + (inflexionWidth / 2) / distance * (x - last_x);
                    float last_y1 = last_y + (inflexionWidth / 2) / distance * (y - last_y);
                    float x1 = x - (inflexionWidth / 2) / distance * (x - last_x);
                    float y1 = y - (inflexionWidth / 2) / distance * (y - last_y);
                    
                    [progressline moveToPoint:CGPointMake(last_x1, last_y1)];
                    [progressline addLineToPoint:CGPointMake(x1, y1)];
                    
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(last_x1, last_y1)]];
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(x1, y1)]];
                }
                
                last_x = x;
                last_y = y;
            }
            // Square point
            else if (chartData.inflexionPointStyle == NKLineChartPointStyleSquare) {
                
                CGRect squareRect = CGRectMake(x - inflexionWidth / 2, y - inflexionWidth / 2, inflexionWidth, inflexionWidth);
                CGPoint squareCenter = CGPointMake(squareRect.origin.x + (squareRect.size.width / 2), squareRect.origin.y + (squareRect.size.height / 2));
                
                [pointPath moveToPoint:CGPointMake(squareCenter.x - (inflexionWidth / 2), squareCenter.y - (inflexionWidth / 2))];
                [pointPath addLineToPoint:CGPointMake(squareCenter.x + (inflexionWidth / 2), squareCenter.y - (inflexionWidth / 2))];
                [pointPath addLineToPoint:CGPointMake(squareCenter.x + (inflexionWidth / 2), squareCenter.y + (inflexionWidth / 2))];
                [pointPath addLineToPoint:CGPointMake(squareCenter.x - (inflexionWidth / 2), squareCenter.y + (inflexionWidth / 2))];
                [pointPath closePath];
                
                if ( i != 0 ) {
                    
                    // calculate the point for line
                    float distance = sqrt(pow(x - last_x, 2) + pow(y - last_y, 2) );
                    float last_x1 = last_x + (inflexionWidth / 2);
                    float last_y1 = last_y + (inflexionWidth / 2) / distance * (y - last_y);
                    float x1 = x - (inflexionWidth / 2);
                    float y1 = y - (inflexionWidth / 2) / distance * (y - last_y);
                    
                    [progressline moveToPoint:CGPointMake(last_x1, last_y1)];
                    [progressline addLineToPoint:CGPointMake(x1, y1)];
                    
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(last_x1, last_y1)]];
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(x1, y1)]];
                }
                
                last_x = x;
                last_y = y;
            }
            // Triangle point
            else if (chartData.inflexionPointStyle == NKLineChartPointStyleTriangle) {
                
                CGRect squareRect = CGRectMake(x - inflexionWidth / 2, y - inflexionWidth / 2, inflexionWidth, inflexionWidth);
                
                CGPoint startPoint = CGPointMake(squareRect.origin.x,squareRect.origin.y + squareRect.size.height);
                CGPoint endPoint = CGPointMake(squareRect.origin.x + (squareRect.size.width / 2) , squareRect.origin.y);
                CGPoint middlePoint = CGPointMake(squareRect.origin.x + (squareRect.size.width) , squareRect.origin.y + squareRect.size.height);
                
                [pointPath moveToPoint:startPoint];
                [pointPath addLineToPoint:middlePoint];
                [pointPath addLineToPoint:endPoint];
                [pointPath closePath];
                
                if ( i != 0 ) {
                    // calculate the point for triangle
                    float distance = sqrt(pow(x - last_x, 2) + pow(y - last_y, 2) ) * 1.4 ;
                    float last_x1 = last_x + (inflexionWidth / 2) / distance * (x - last_x);
                    float last_y1 = last_y + (inflexionWidth / 2) / distance * (y - last_y);
                    float x1 = x - (inflexionWidth / 2) / distance * (x - last_x);
                    float y1 = y - (inflexionWidth / 2) / distance * (y - last_y);
                    
                    [progressline moveToPoint:CGPointMake(last_x1, last_y1)];
                    [progressline addLineToPoint:CGPointMake(x1, y1)];
                    
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(last_x1, last_y1)]];
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(x1, y1)]];
                }
                
                last_x = x;
                last_y = y;
                
            } else {
                
                if ( i != 0 ) {
                    [progressline addLineToPoint:CGPointMake(x, y)];
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
                }
                
                [progressline moveToPoint:CGPointMake(x, y)];
                if(i != chartData.itemCount - 1){
                    [lineStartEndPointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
                }
            }
            
            [linePointsArray addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
        }
        
        [pathPoints addObject:[linePointsArray copy]];
        [pointsOfPath addObject:[lineStartEndPointsArray copy]];
    }
}

#pragma mark - tools

+ (CGSize)sizeOfString:(NSString *)text withWidth:(float)width font:(UIFont *)font
{
    NSInteger ch;
    CGSize size = CGSizeMake(width, MAXFLOAT);
    
    NSDictionary *tdic = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    size = [text boundingRectWithSize:size
                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                           attributes:tdic
                              context:nil].size;
    
    ch = size.height;
    
    return size;
}

-(void)prepareYLabelsWithData:(NSArray *)data
{
    CGFloat yMax = 0.0f;
    CGFloat yMin = MAXFLOAT;
    NSMutableArray *yLabelsArray = [NSMutableArray new];
    
    for (NKLineChartData *chartData in data) {
        // create as many chart line layers as there are data-lines
        
        for (NSUInteger i = 0; i < chartData.itemCount; i++) {
            CGFloat yValue = chartData.getData(i).y;
            [yLabelsArray addObject:[NSString stringWithFormat:@"%2f", yValue]];
            yMax = fmaxf(yMax, yValue);
            yMin = fminf(yMin, yValue);
        }
    }
    
    
    // Min value for Y label
    if (yMax < 5) {
        yMax = 5.0f;
    }
    
    if (yMin < 0) {
        yMin = 0.0f;
    }
    
    _yValueMin = (_yFixedValueMin > -FLT_MAX) ? _yFixedValueMin : yMin ;
    _yValueMax = (_yFixedValueMax > -FLT_MAX) ? _yFixedValueMax : yMax + yMax / 10.0;
}


- (void)drawTextInContext:(CGContextRef )ctx text:(NSString *)text inRect:(CGRect)rect font:(UIFont *)font
{
    NSMutableParagraphStyle *priceParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    priceParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    priceParagraphStyle.alignment = NSTextAlignmentLeft;
    
    [text drawInRect:rect
      withAttributes:@{ NSParagraphStyleAttributeName:priceParagraphStyle, NSFontAttributeName:font, NSForegroundColorAttributeName:[UIColor whiteColor]}];
}

- (NSString*) formatYLabel:(double)value{
    
    if (_yLabelBlockFormatter)
    {
        return _yLabelBlockFormatter(value);
    }
    else
    {
        if (!_thousandsSeparator) {
            NSString *format = _yLabelFormat ? : @"%1f";
            return [NSString stringWithFormat:format,value];
        }
        
        NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior: NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle: NSNumberFormatterDecimalStyle];
        return [numberFormatter stringFromNumber: [NSNumber numberWithDouble:value]];
    }
}

@end
