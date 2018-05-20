/*
 *  BXBootImageView.m
 *  BootXChanger
 *
 *  Created by Zydeco on 2007-11-03.
 *  Copyright 2007-2010 namedfork.net. All rights reserved.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "BXBootImageView.h"
#import "DBApplication.h"

@implementation BXBootImageView

//- (void)setImage:(NSImage *)newImage {
//    if (newImage == nil) {
//        [(DBApplication*)NSApp showDefaultImage:self];
//        return;
//    }
//
//    [super setImage:newImage];
//}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    /*------------------------------------------------------
     method that should handle the drop data
     --------------------------------------------------------*/
    if ([sender draggingSource] != self) {
        NSURL* fileURL;
        
        //set the image using the best representation we can get from the pasteboard
        if([NSImage canInitWithPasteboard:[sender draggingPasteboard]]) {
            NSImage *newImage = [[NSImage alloc] initWithPasteboard:[sender draggingPasteboard]];
            [self setImage:newImage];
            
            //            NSRect selfFrame = self.frame;
            //            selfFrame.size = newImage.size;
            //            selfFrame.origin = CGPointMake(0, 0);
            //            self.frame = selfFrame;
            //            self.superview.frame = self.frame;
            //            [newImage release];
        }
        
        //if the drag comes from a file, set the window title to the filename
        fileURL = [NSURL URLFromPasteboard:[sender draggingPasteboard]];
        self.path = fileURL.path;
//        [[self window] setTitle: fileURL!=NULL ? [fileURL lastPathComponent] : @"(no name)"];
//        if ([self.delegate respondsToSelector:@selector(dropComplete:)]) {
//            [self.delegate dropComplete:[fileURL path]];
//        }
    }
    
    return YES;
}

@end
