//
//  BXApplication.h
//  BootXChanger
//
//  Created by Zydeco on 2010-05-20.
//  Copyright 2010 namedfork.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

@interface BXApplication : NSApplication {
	IBOutlet NSImageView *imageView;
	IBOutlet NSColorWell *bgColorWell;
    IBOutlet NSColorWell *bootColorWell;
//    IBOutlet NSPopUpButton *currentBGColor;
	AuthorizationRef	auth;
}

- (NSColor*)currentBackgroundColor;
- (NSImage*)currentBootImage;
- (NSColor*)currentBootColor;
- (NSImage*)defaultBootImage;
- (NSColor*)defaultBootColor;
- (IBAction)showDefaultImage:(id)sender;
- (IBAction)showCurrentImage:(id)sender;
- (IBAction)saveBootImage:(id)sender;
- (BOOL)installBootImage:(NSImage*)img withBackgroundColor:(NSColor*)bgColor error:(NSError**)err;
- (BOOL)authorize;
- (void)deauthorize;
@end
