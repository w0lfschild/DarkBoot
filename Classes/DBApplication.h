//
//  BXApplication.h
//  BootXChanger
//
//  Created by Wolfgang Baird on 11/23/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import "AYProgressIndicator.h"
#import "BXBootImageView.h"

@interface DBApplication : NSApplication {
    // Tab bar items
    IBOutlet NSButton *viewBootColor;
    IBOutlet NSButton *viewBootImage;
    IBOutlet NSButton *viewBootOptions;
    IBOutlet NSButton *viewLoginScreen;
    IBOutlet NSButton *viewLockScreen;
    
    IBOutlet NSButton *viewAbout;
    IBOutlet NSButton *viewPreferences;
    
    IBOutlet NSButton *applyButton;
    IBOutlet NSButton *adButton;
    IBOutlet NSButton *feedbackButton;
    IBOutlet NSButton *reportButton;
    IBOutlet NSButton *donateButton;
    
    
    // Application views
    IBOutlet NSView *tabMain;
    
    IBOutlet NSView *tabBootColor;
    IBOutlet NSView *tabBootImage;
    IBOutlet NSView *tabBootOptions;

    IBOutlet NSView *tabLoginScreen;
    IBOutlet NSView *tabLockScreen;
    
    IBOutlet NSView *tabAbout;
    IBOutlet NSView *tabPreferences;
    
    
    // About view
    IBOutlet NSTextField *appName;
    IBOutlet NSTextField *appVersion;
    IBOutlet NSTextField *appCopyright;
    IBOutlet NSButton *gitButton;
    IBOutlet NSButton *sourceButton;
    IBOutlet NSButton *emailButton;
    IBOutlet NSButton *webButton;
    IBOutlet NSButton *showCredits;
    IBOutlet NSButton *showChanges;
    IBOutlet NSButton *showEULA;
    IBOutlet NSTextView *changeLog;
    
    
    // Other items
    IBOutlet NSWindow *mainWindow;
    IBOutlet AYProgressIndicator *bootColorIndicator;
    IBOutlet NSImageView *bootColorApple;
    IBOutlet NSColorWell *bootColorView;
	IBOutlet BXBootImageView *bootImageView;
    IBOutlet BXBootImageView *loginImageView;
    IBOutlet BXBootImageView *lockImageView;
	IBOutlet NSColorWell *bgColorWell;
    IBOutlet NSColorWell *bootColorWell;
    
    IBOutlet NSButton *lockTextCustomSize;
    IBOutlet NSButton *lockTextCustomText;
    IBOutlet NSSlider *lockTextSlider;
    IBOutlet NSTextField *lockTextText;
    
    IBOutlet NSButton *curlogin;
    IBOutlet NSButton *deflogin;
    IBOutlet NSButton *sellogin;
    
    IBOutlet NSButton *curboot;
    IBOutlet NSButton *defboot;
    IBOutlet NSButton *selboot;
    
    IBOutlet NSButton *sellock;

    
    IBOutlet NSButton *applyChanges;
    IBOutlet NSButton *defColor;
    IBOutlet NSButton *blkColor;
    IBOutlet NSButton *gryColor;
    IBOutlet NSButton *clrColor;
    
	AuthorizationRef	auth;
    
    NSURL *lockImagePath;
}

// ADs URL
@property (readwrite, nonatomic) NSString* adURL;
@property (readwrite, nonatomic) NSArray* adArray;
@property (readwrite, nonatomic) NSInteger lastAD;

//- (IBAction)setupBXPlist:(id)sender;
- (NSColor*)currentBackgroundColor;

- (NSImage*)currentBootImage;
- (NSColor*)currentBootColor;

- (NSImage*)defaultBootImage;
- (NSColor*)defaultBootColor;

- (IBAction)showDefaultImage:(id)sender;
- (IBAction)showCurrentImage:(id)sender;

//- (IBAction)saveBootImage:(id)sender;
- (IBAction)removeBXPlist:(id)sender;

- (BOOL)installBootImage:(NSImage*)img withBackgroundColor:(NSColor*)bgColor error:(NSError**)err;

- (void)dirCheck:(NSString *)directory;
- (NSImage*)imageFromCGImageRef:(CGImageRef)image;
- (BOOL)authorize;
- (void)deauthorize;

@end
