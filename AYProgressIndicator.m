//
//  AYProgressIndicator.m
//  AYProgressBar
//
//  Created by Alexander Yakubchyk on 09.12.13.
//  Copyright (c) 2013 Alexander Yakubchyk. All rights reserved.
//

#import "AYProgressIndicator.h"


@implementation AYProgressIndicator

- (id)initWithFrame:(NSRect)frameRect
      progressColor:(NSColor*)progressColor
         emptyColor:(NSColor*)emptyColor
           minValue:(double)minValue
           maxValue:(double)maxValue
       currentValue:(double)currentValue
{
    self = [super initWithFrame:frameRect];
    
    if (self)
    {
        self.progressColor = progressColor;
        self.emptyColor    = emptyColor;
        self.minValue      = minValue;
        self.maxValue      = maxValue;
        self.doubleValue   = currentValue;
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	[self setWantsLayer:YES];
    
    // Clear background color
    [[NSColor clearColor] set];
    NSRectFill(dirtyRect);
    
    // Draw progress line
    NSRect activeRect = dirtyRect;
    [self.progressColor set];
    activeRect.size.width = floor(activeRect.size.width * ([self doubleValue] / [self maxValue]));
    NSRectFill(activeRect);
    
    // Draw empty line
    NSRect passiveRect = dirtyRect;
    passiveRect.size.width -= activeRect.size.width;
    passiveRect.origin.x = activeRect.size.width;
    [self.emptyColor set];
    NSRectFill(passiveRect);
}

@end
