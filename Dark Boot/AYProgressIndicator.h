//
//  AYProgressIndicator.h
//  AYProgressBar
//
//  Created by Alexander Yakubchyk on 09.12.13.
//  Copyright (c) 2013 Alexander Yakubchyk. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AYProgressIndicator : NSProgressIndicator

@property (copy) NSColor *progressColor;
@property (copy) NSColor *emptyColor;

- (id)initWithFrame:(NSRect)frameRect
      progressColor:(NSColor*)progressColor
         emptyColor:(NSColor*)emptyColor
           minValue:(double)minValue
           maxValue:(double)maxValue
       currentValue:(double)currentValue;

@end
