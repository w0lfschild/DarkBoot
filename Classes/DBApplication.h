//
//  BXApplication.h
//  BootXChanger
//
//  Created by Wolfgang Baird on 11/23/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

@interface DBApplication : NSApplication {
    // Tab bar items
    IBOutlet NSButton *viewBootColor;
    IBOutlet NSButton *viewBootImage;
    IBOutlet NSButton *viewLoginImage;
    
    IBOutlet NSButton *viewAbout;
    IBOutlet NSButton *viewPreferences;
    
    IBOutlet NSButton *reportButton;
    IBOutlet NSButton *donateButton;
    
    
    // Application views
    IBOutlet NSView *tabMain;
    
    IBOutlet NSView *tabBootColor;
    IBOutlet NSView *tabBootImage;
    IBOutlet NSView *tabLoginImage;
    
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
	IBOutlet NSImageView *bootImageView;
    IBOutlet NSImageView *loginImageView;
	IBOutlet NSColorWell *bgColorWell;
    IBOutlet NSColorWell *bootColorWell;
    
    IBOutlet NSButton *curlogin;
    IBOutlet NSButton *deflogin;
    IBOutlet NSButton *sellogin;
    
    IBOutlet NSButton *curboot;
    IBOutlet NSButton *defboot;
    IBOutlet NSButton *selboot;
    
    IBOutlet NSButton *applyChanges;
    IBOutlet NSButton *defColor;
    IBOutlet NSButton *blkColor;
    IBOutlet NSButton *gryColor;
    IBOutlet NSButton *clrColor;
    
	AuthorizationRef	auth;
}

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

- (BOOL)authorize;
- (void)deauthorize;
@end
