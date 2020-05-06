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
#import "MF_sidebarButton.h"

@interface DBApplication : NSApplication {
    // Application views
    IBOutlet NSWindow               *mainWindow;
    IBOutlet NSView                 *tabMain;
    IBOutlet NSView                 *tabBootColor;
    IBOutlet NSView                 *tabBootImage;
    IBOutlet NSView                 *tabBootOptions;
    IBOutlet NSView                 *tabLoginScreen;
    IBOutlet NSView                 *tabLockScreen;
    IBOutlet NSView                 *tabMacForge;
    
    // MacForge view
    IBOutlet NSTextView             *mfWarningText;
    
    // About view
    IBOutlet NSTextField            *appName;
    IBOutlet NSTextField            *appVersion;
    IBOutlet NSTextField            *appCopyright;
    IBOutlet NSTextView             *changeLog;
    IBOutlet NSImageView            *aboutGif;
    
    // Boot options
    IBOutlet NSButton               *bootAuto;
    IBOutlet NSButton               *bootAudio;
    IBOutlet NSButton               *bootSafe;
    IBOutlet NSButton               *bootVerbose;
    IBOutlet NSButton               *bootCamshell;
    IBOutlet NSButton               *bootSingle;
    
    // Boot Color
    IBOutlet NSColorWell            *bootColorView;
    IBOutlet NSSegmentedControl     *bootColorControl;
    IBOutlet AYProgressIndicator    *bootColorIndicator;
    IBOutlet NSImageView            *bootColorApple;
    IBOutlet NSProgressIndicator    *bootColorProgress;
    NSColor                         *bootCustomColor;
    
    // Boot Image
	IBOutlet BXBootImageView        *bootImageView;
    IBOutlet NSColorWell            *bgColorWell;

    // Login screen
    IBOutlet BXBootImageView        *loginImageView;
    IBOutlet NSImageView            *loginUserIcon;
    
    // Lock screen
    IBOutlet BXBootImageView        *lockImageView;
    IBOutlet NSButton               *lockTextCustomSize;
    IBOutlet NSButton               *lockTextCustomText;
    IBOutlet NSSlider               *lockTextSlider;
    IBOutlet NSTextField            *lockTextText;
    IBOutlet NSImageView            *lockUserIcon;
    
    // ?
    IBOutlet NSButton               *sellogin;
    IBOutlet NSButton               *selboot;
    IBOutlet NSButton               *sellock;

    NSUInteger                      *hashVal;
    
    NSUInteger osx_ver;
	AuthorizationRef	auth;
    NSURL *lockImagePath;
}

// Windows
@property IBOutlet NSWindow             *windowPreferences;

// Preferences
@property IBOutlet NSSegmentedControl   *preferencesTabController;
@property IBOutlet NSView               *preferencesGeneral;
@property IBOutlet NSView               *preferencesAbout;
@property IBOutlet NSView               *preferencesData;

// Top sidebar items
@property IBOutlet MF_sidebarButton     *sidebarBootColor;
@property IBOutlet MF_sidebarButton     *sidebarBootImage;
@property IBOutlet MF_sidebarButton     *sidebarBootOptions;
@property IBOutlet MF_sidebarButton     *sidebarLoginScreen;
@property IBOutlet MF_sidebarButton     *sidebarLockScreen;

// Bottom sidebar items
@property IBOutlet MF_sidebarButton     *sidebarDiscord;
@property IBOutlet MF_sidebarButton     *sidebarApplyAll;

@property IBOutlet NSButton *feedbackButton;
@property IBOutlet NSButton *reportButton;
@property IBOutlet NSButton *donateButton;

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
