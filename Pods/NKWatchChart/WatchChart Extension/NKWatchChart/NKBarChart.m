//
//  NKBarChart.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/6/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import "NKBarChart.h"
#import "NKColor.h"

@interface NKBarChart ()

@property (nonatomic) CGRect frame;

- (UIColor *)barColorAtIndex:(NSUInteger)index;

@property (nonatomic) CGFloat xLabelWidth;
@property (nonatomic) float yValueMax;

@end

@implementation NKBarChart

- (id)initWithFrame:(CGRect)frame
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
    _showLabel           = YES;
    _labelTextColor      = NKGreen;
    _labelFont           = [UIFont systemFontOfSize:8.0f];
    _chartMargin         = 12.0;
    _labelMarginTop      = 0;
    _yLabelSum           = 4;
    _xLabelSkip          = 1;
    
    _yLabelFormatter = ^(CGFloat yValue){
        return [NSString stringWithFormat:@"%1.f",yValue];
    };
    
    _yChartLabelWidth    = 10;
    _barRadius           = 2.0;
    _showChartBorder     = NO;
    _chartBorderColor    = NKLightGrey;
    _barBackgroundColor = NKLightGrey;

}

- (void)drawXLabels
{
    _xLabelWidth = (_frame.size.width - _chartMargin * 2) / [_xLabels count];
    int labelAddCount = 0;
    for (int index = 0; index < _xLabels.count; index++) {
        labelAddCount += 1;
        
        if (labelAddCount == _xLabelSkip) {
            NSString *labelText = [_xLabels[index] description];
            
            NSMutableParagraphStyle *priceParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            priceParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
            priceParagraphStyle.alignment = NSTextAlignmentLeft;
            
            NSMutableDictionary *attributesDictionary = [NSMutableDictionary dictionary];
            [attributesDictionary setObject:_labelFont forKey:NSFontAttributeName];
            [attributesDictionary setObject:_labelTextColor forKey:NSForegroundColorAttributeName];
            [attributesDictionary setObject:priceParagraphStyle forKey:NSParagraphStyleAttributeName];
            
            CGFloat labelXPosition = (index *  _xLabelWidth + _chartMargin + _xLabelWidth /2.0 );
            
            CGRect labelRect = CGRectMake(labelXPosition,
                                          _frame.size.height - kXLabelHeight - _chartMargin + _labelMarginTop,
                                          _xLabelWidth,
                                          kXLabelHeight);
            [labelText drawInRect:labelRect withAttributes:attributesDictionary];
            
            labelAddCount = 0;
            
        }
    }
    
}

- (void)drawYLabels
{
    [self processYMaxValue];
    
    float sectionHeight = (_frame.size.height - _chartMargin * 2 - kXLabelHeight) / _yLabelSum;
    for (int i = 0; i <= _yLabelSum; i++)
    {
        
        CGRect frame = (CGRect){0, sectionHeight * i + _chartMargin - kYLabelHeight/2.0, _yChartLabelWidth, kYLabelHeight};
        
        NSMutableString *yLabelText;
        if (_yLabels)
        {
            float yAsixValue = [_yLabels[_yLabels.count - i - 1] floatValue];
            yLabelText = [_yLabelFormatter(yAsixValue) mutableCopy];
        } else
        {
            yLabelText = [_yLabelFormatter((float)_yValueMax * ( (_yLabelSum - i) / (float)_yLabelSum )) mutableCopy];
        }
        
        if (_yLabelPrefix)
        {
            yLabelText = [NSMutableString stringWithFormat:@"%@%@", _yLabelPrefix, yLabelText];
        }
        if (_yLabelSuffix)
        {
            yLabelText = [NSMutableString stringWithFormat:@"%@%@", yLabelText, _yLabelSuffix];
        }
        
        NSMutableParagraphStyle *priceParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        priceParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        priceParagraphStyle.alignment = NSTextAlignmentRight;
        
        NSMutableDictionary *attributesDictionary = [NSMutableDictionary dictionary];
        [attributesDictionary setObject:_labelFont forKey:NSFontAttributeName];
        [attributesDictionary setObject:_labelTextColor forKey:NSForegroundColorAttributeName];
        [attributesDictionary setObject:priceParagraphStyle forKey:NSParagraphStyleAttributeName];
        
        [yLabelText drawInRect:frame withAttributes:attributesDictionary];
        
    }
    
}

- (void)drawBorderLines
{
    //Add chart border bottom line
    UIBezierPath *bottomLineLine = [UIBezierPath bezierPath];
    [bottomLineLine moveToPoint:CGPointMake(_chartMargin, _frame.size.height - kXLabelHeight - _chartMargin)];
    [bottomLineLine addLineToPoint:CGPointMake(_frame.size.width - _chartMargin,  _frame.size.height - kXLabelHeight - _chartMargin)];
    [bottomLineLine setLineWidth:1.0];
    [bottomLineLine setLineCapStyle:kCGLineCapSquare];
    [_chartBorderColor setStroke];
    [bottomLineLine stroke];

    //Add left Chart Line
    UIBezierPath *leftLine = [UIBezierPath bezierPath];
    [leftLine moveToPoint:CGPointMake(_chartMargin, self.frame.size.height - kXLabelHeight - _chartMargin)];
    [leftLine addLineToPoint:CGPointMake(_chartMargin,  _chartMargin)];
    [leftLine setLineWidth:1.0];
    [leftLine setLineCapStyle:kCGLineCapSquare];
    [_chartBorderColor setStroke];
    [leftLine stroke];
}

- (UIImage *)drawImage
{
    CGFloat scale = [WKInterfaceDevice currentDevice].screenScale;
    UIGraphicsBeginImageContextWithOptions(_frame.size, false, scale);
    
    if (_chartBackgroundColor) {
        UIBezierPath *chartRect = [UIBezierPath bezierPathWithRect:_frame];
        [_chartBackgroundColor setFill];
        [chartRect fill];
    }
    
    if (_showLabel)
    {
        
        [self drawXLabels];
        [self drawYLabels];
        
    } else {
        [self processYMaxValue];
    }
    
    if (_showChartBorder)
    {
        [self drawBorderLines];
    }
    // draw bars
    CGFloat chartCavanHeight = self.frame.size.height - _chartMargin * 2 - kXLabelHeight;
    NSInteger index = 0;
    
    for (NSNumber *valueString in _yValues)
    {
        CGFloat barWidth;
        CGFloat barHeight;
        CGFloat barXPosition;
        CGFloat barYPosition;
        
        UIColor *barBackgroundColor;
        UIColor *barColor;
        
        if (_barWidth) {
            barWidth = _barWidth;
            barXPosition = index *  _xLabelWidth + _chartMargin + _xLabelWidth /2.0 - _barWidth /2.0;
        }else{
            barXPosition = index *  _xLabelWidth + _chartMargin + _xLabelWidth * 0.25;
            if (_showLabel) {
                barWidth = _xLabelWidth * 0.5;
                
            }
            else {
                barWidth = _xLabelWidth * 0.6;
                
            }
        }// if _barWidth
        
        barYPosition = _frame.size.height - chartCavanHeight - kXLabelHeight - _chartMargin;
        barHeight = chartCavanHeight;
        
        CGRect barBackgroundRect = CGRectMake(barXPosition, barYPosition, barWidth, barHeight);
        barBackgroundColor = _barBackgroundColor;
        UIBezierPath* barBackgroundRectPath = [UIBezierPath
                                               bezierPathWithRoundedRect: barBackgroundRect
                                               cornerRadius: 2];
        [barBackgroundColor setFill];
        [barBackgroundRectPath fill];
        
        if (self.strokeColor) {
            barColor = self.strokeColor;
        }else{
            barColor = [self barColorAtIndex:index];
        }
        
        float value = [valueString floatValue];
        float grade =fabsf((float)value / (float)_yValueMax);
        if (isnan(grade)) {
            grade = 0;
        }
        CGRect barRect = CGRectMake(barXPosition, barYPosition + (1-grade)*barHeight, barWidth, grade*barHeight);
        UIBezierPath* barRectPath = [UIBezierPath
                                  bezierPathWithRoundedRect: barRect
                                  cornerRadius: 2];
        [barColor setFill];
        [barRectPath fill];
        
        index += 1;
        
    }

     UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
     UIGraphicsEndImageContext();
     return image;
}

- (void)processYMaxValue {
    NSArray *yAxisValues = _yLabels ? _yLabels : _yValues;
    _yLabelSum = _yLabels ? _yLabels.count - 1 :_yLabelSum;
    if (_yMaxValue) {
        _yValueMax = _yMaxValue;
    } else {
        [self getYValueMax:yAxisValues];
    }
    
    if (_yLabelSum==4) {
        _yLabelSum = yAxisValues.count;
        (_yLabelSum % 2 == 0) ? _yLabelSum : _yLabelSum++;
    }
}

- (void)getYValueMax:(NSArray *)yLabels
{
    CGFloat max = [[yLabels valueForKeyPath:@"@max.floatValue"] floatValue];
    
    //ensure max is even
    _yValueMax = max ;
    
    if (_yValueMax == 0) {
        _yValueMax = _yMinValue;
    }
}


#pragma mark - Class extension methods

- (UIColor *)barColorAtIndex:(NSUInteger)index
{
    if ([self.strokeColors count] == [self.yValues count]) {
        return self.strokeColors[index];
    }
    else {
        return self.strokeColor;
    }
}

@end
