//
//  NKPieChart.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import "NKPieChart.h"
#import "NKPieChartDataItem.h"

@interface NKPieChart()

@property (nonatomic) CGRect frame;

@property (nonatomic) NSArray *items;
@property (nonatomic) NSArray *endPercentages;
@property (nonatomic) CGFloat outerCircleRadius;
@property (nonatomic) CGFloat innerCircleRadius;

@property (nonatomic) NSMutableArray *descriptionLabels;

- (NKPieChartDataItem *)dataItemForIndex:(NSUInteger)index;
- (CGFloat)startPercentageForItemAtIndex:(NSUInteger)index;
- (CGFloat)endPercentageForItemAtIndex:(NSUInteger)index;
- (CGFloat)ratioForItemAtIndex:(NSUInteger)index;

@end

@implementation NKPieChart

-(id)initWithFrame:(CGRect)frame items:(NSArray *)items{
    self = [self init];
    if(self){
        
        _frame = frame;
        _items = [NSArray arrayWithArray:items];
        _outerCircleRadius  = CGRectGetWidth(_frame) / 2;
        _innerCircleRadius  = CGRectGetWidth(_frame) / 6;
        
        _descriptionTextColor = [UIColor whiteColor];
        _descriptionTextFont  = [UIFont systemFontOfSize:10.0];
        
    }
    return self;
    
}

- (UIImage *)drawImage
{
    __block CGFloat currentTotal = 0;
    CGFloat total = [[_items valueForKeyPath:@"@sum.value"] floatValue];
    NSMutableArray *endPercentages = [NSMutableArray new];
    [_items enumerateObjectsUsingBlock:^(NKPieChartDataItem *item, NSUInteger idx, BOOL *stop) {
        if (total == 0){
            [endPercentages addObject:@(1.0 / _items.count * (idx + 1))];
        }else{
            currentTotal += item.value;
            [endPercentages addObject:@(currentTotal / total)];
        }
    }];
    _endPercentages = [endPercentages copy];
    
    CGFloat scale = [WKInterfaceDevice currentDevice].screenScale;
    UIGraphicsBeginImageContextWithOptions(_frame.size, false, scale);
    
    
    if (_chartBackgroundColor) {
        UIBezierPath *chartRect = [UIBezierPath bezierPathWithRect:_frame];
        [_chartBackgroundColor setFill];
        [chartRect fill];
    }
    
    CGPoint center = CGPointMake(CGRectGetMidX(_frame),CGRectGetMidY(_frame));
    NKPieChartDataItem *currentItem;
    for (int i = 0; i < _items.count; i++) {
        currentItem = [self dataItemForIndex:i];
        
        CGFloat startPercnetage = [self startPercentageForItemAtIndex:i];
        CGFloat endPercentage   = [self endPercentageForItemAtIndex:i];
        
        CGFloat startAngle = -M_PI_2 + 2.0 * M_PI * startPercnetage;
        CGFloat endAngle = -M_PI_2 + 2.0 * M_PI * endPercentage;
        
        CGFloat radius = _innerCircleRadius + (_outerCircleRadius - _innerCircleRadius) / 2;
        CGFloat borderWidth = _outerCircleRadius - _innerCircleRadius;
        
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                            radius:radius
                                                        startAngle:startAngle
                                                          endAngle:endAngle
                                                         clockwise:YES];
        path.lineWidth = borderWidth;
        [currentItem.color setStroke];
        [path stroke];
        
        // draw text
        NSString *description;
        
        CGFloat distance = _innerCircleRadius + (_outerCircleRadius - _innerCircleRadius) / 2;
        CGFloat centerPercentage = ([self startPercentageForItemAtIndex:i] + [self endPercentageForItemAtIndex:i])/ 2;
        CGFloat rad = centerPercentage * 2 * M_PI;
        
        NSString *titleText = currentItem.textDescription;
        NSString *titleValue;
        
        if (_showAbsoluteValues) {
            titleValue = [NSString stringWithFormat:@"%.0f",currentItem.value];
        }else{
            titleValue = [NSString stringWithFormat:@"%.0f%%",[self ratioForItemAtIndex:i] * 100];
        }
        if(!titleText || _showOnlyValues){
            description = titleValue;
        }
        else {
            NSString* str = [titleValue stringByAppendingString:[NSString stringWithFormat:@"\n%@",titleText]];
            description = str ;
        }
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:_descriptionTextFont forKey:NSFontAttributeName];
        [attributes setObject:_descriptionTextColor forKey:NSForegroundColorAttributeName];
        
        CGPoint center = CGPointMake(_outerCircleRadius + distance * sin(rad),
                                     _outerCircleRadius - distance * cos(rad));
        
        CGSize size = [description boundingRectWithSize:CGSizeMake( (_outerCircleRadius - _innerCircleRadius),
            (_outerCircleRadius - _innerCircleRadius))
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:attributes
                                                context:nil].size;
        
        [description drawInRect:CGRectMake(center.x - size.width/2, center.y - size.height/2, size.width, size.height) withAttributes:attributes];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (NKPieChartDataItem *)dataItemForIndex:(NSUInteger)index{
    return _items[index];
}

- (CGFloat)startPercentageForItemAtIndex:(NSUInteger)index{
    if(index == 0){
        return 0;
    }
    
    return [_endPercentages[index - 1] floatValue];
}

- (CGFloat)endPercentageForItemAtIndex:(NSUInteger)index{
    return [_endPercentages[index] floatValue];
}

- (CGFloat)ratioForItemAtIndex:(NSUInteger)index{
    return [self endPercentageForItemAtIndex:index] - [self startPercentageForItemAtIndex:index];
}

@end
