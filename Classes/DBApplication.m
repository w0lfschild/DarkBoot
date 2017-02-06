//
//  Created by Wolfgang Baird on 11/23/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

@import LetsMove;

#import "DBApplication.h"
#import <DevMateKit/DevMateKit.h>

#include <sys/stat.h>
#include <unistd.h>

@import AppKit;

static NSString *path_bootImagePlist    = @"/Library/Preferences/SystemConfiguration/com.apple.Boot.plist";
static NSString *path_bootColorPlist    = @"/Library/LaunchDaemons/com.dabrain13.darkboot.plist";
static NSString *path_loginImage        = @"/Library/Caches/com.apple.desktop.admin.png";

static NSString *DBErrorDomain          = @"Dark Boot";

NSArray *tabViewButtons;
NSArray *tabViews;

enum BXErrorCode
{
	BXErrorNone,
	BXErrorCannotGetPNG,
	BXErrorCannotWriteTmpFile,
};

@implementation DBApplication

- (void)awakeFromNib {
	[self showCurrentImage:self];
    [self showCurrentLogin:self];
	[self setDelegate:(id)self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    [DevMateKit sendTrackingReport:nil delegate:nil];
    [DevMateKit setupIssuesController:nil reportingUnhandledIssues:YES];
    
    PFMoveToApplicationsFolderIfNecessary();

    [mainWindow setMovableByWindowBackground:YES];
    
    if ([[NSProcessInfo processInfo] operatingSystemVersion].minorVersion < 10)
    {
        //        _window.centerTrafficLightButtons = false;
        //        _window.showsBaselineSeparator = false;
        //        _window.titleBarHeight = 0.0;
    } else {
        [mainWindow setTitlebarAppearsTransparent:true];
        mainWindow.styleMask |= NSFullSizeContentViewWindowMask;
        NSRect frame = mainWindow.frame;
        frame.size.height += 22;
        [mainWindow setFrame:frame display:true];
    }
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    [appName setStringValue:[infoDict objectForKey:@"CFBundleExecutable"]];
    [appVersion setStringValue:[NSString stringWithFormat:@"Version %@ (%@)",
                                 [infoDict objectForKey:@"CFBundleShortVersionString"],
                                 [infoDict objectForKey:@"CFBundleVersion"]]];
    [appCopyright setStringValue:@"Copyright © 2015 - 2016 Wolfgang Baird"];
    [[changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Changelog" ofType:@"rtf"] documentAttributes:nil]];
    
    Class vibrantClass=NSClassFromString(@"NSVisualEffectView");
    if (vibrantClass) {
        NSVisualEffectView *vibrant=[[vibrantClass alloc] initWithFrame:[[mainWindow contentView] bounds]];
        [vibrant setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [vibrant setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [[mainWindow contentView] addSubview:vibrant positioned:NSWindowBelow relativeTo:nil];
    } else {
        [mainWindow setBackgroundColor:[NSColor whiteColor]];
    }

    [reportButton setAction:@selector(reportIssue)];
    [donateButton setAction:@selector(donate)];
    [emailButton setAction:@selector(sendEmail)];
    [gitButton setAction:@selector(visitGithub)];
    [sourceButton setAction:@selector(visitSource)];
    [webButton setAction:@selector(visitWebsite)];
    
    tabViewButtons = [NSArray arrayWithObjects:viewBootColor, viewBootImage, viewLoginImage, viewAbout, viewPreferences, nil];
    for (NSButton *btn in tabViewButtons) {
        [btn setWantsLayer:YES];
        [btn setTarget:self];
        [btn setAction:@selector(selectView:)];
    }
    
    [donateButton setWantsLayer:YES];
    [reportButton setWantsLayer:YES];
    [feedbackButton setWantsLayer:YES];
    [feedbackButton.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.438f green:0.121f blue:0.199f alpha:0.258f].CGColor];
    [donateButton.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.438f green:0.121f blue:0.199f alpha:0.258f].CGColor];
    [reportButton.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.438f green:0.121f blue:0.199f alpha:0.258f].CGColor];
    
    tabViews = [NSArray arrayWithObjects:tabBootColor, tabBootImage, tabLoginImage, tabAbout, tabPreferences, nil];
    
    [self selectView:viewBootColor];
    

    NSColor *bk = [self currentBackgroundColor];
    if (bk != nil) {
        [bootColorWell setColor:[self currentBackgroundColor]];
        NSString *bgs = [self currentBackgroundString];
        if ([bgs isEqualToString:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%00%00%00"]) {
            [blkColor setState:NSOnState];
        } else if ([bgs isEqualToString:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%99%99%99"]) {
            [gryColor setState:NSOnState];
        } else {
            [clrColor setState:NSOnState];
        }
        [bootColorWell setColor:bk];
    } else {
        [bootColorWell setColor:[NSColor grayColor]];
        [defColor setState:NSOnState];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[self deauthorize];
	return NSTerminateNow;
}

- (NSString *)currentBackgroundString {
    NSString* result = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path_bootColorPlist]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path_bootColorPlist];
        NSArray* args = [dict objectForKey:@"ProgramArguments"];
        result = [args objectAtIndex:1];
    }
    return result;
}

- (NSImage *)currentLoginImage {
    // get image
    NSImage *img = [[NSImage alloc] initWithContentsOfFile:path_loginImage];
    if (img == nil) return [self defaultBootImage];
    return img;
}

- (NSImage *)currentBootImage {
	NSDictionary *bootPlist = [NSDictionary dictionaryWithContentsOfFile:path_bootImagePlist];
	id bootLogoPath = [bootPlist objectForKey:@"Boot Logo"];
	if (bootLogoPath == nil || 
		![bootLogoPath isKindOfClass:[NSString class]] || 
		([bootLogoPath length] == 0)) {
		return [self defaultBootImage];
	}
	// convert to POSIX path
	NSMutableString *pPath = [NSMutableString stringWithString:bootLogoPath];
	[pPath replaceOccurrencesOfString:@"/" withString:@":" options:NSLiteralSearch range:NSMakeRange(0, [pPath length])];
	[pPath replaceOccurrencesOfString:@"\\" withString:@"/" options:NSLiteralSearch range:NSMakeRange(0, [pPath length])];
	if (![pPath hasPrefix:@"/"]) [pPath insertString:@"/" atIndex:0];
	// get image
	NSImage *img = [[NSImage alloc] initWithContentsOfFile:pPath];
	if (img == nil) return [self defaultBootImage];
	return img;
}

- (NSColor *)currentBootColor {
	NSDictionary *bootPlist = [NSDictionary dictionaryWithContentsOfFile:path_bootImagePlist];
	if ([bootPlist objectForKey:@"Background Color"] == nil) return [self defaultBootColor];
	UInt32 colorVal = [[bootPlist objectForKey:@"Background Color"] unsignedIntValue];
	struct {int r,g,b;} color;
	color.r = (colorVal & 0xFF0000) >> 16;
	color.g = (colorVal & 0x00FF00) >> 8;
	color.b = (colorVal & 0x0000FF);
	return [NSColor colorWithDeviceRed:color.r/255.0 green:color.g/255.0 blue:color.b/255.0 alpha:1.0];
}

- (NSImage *)defaultLoginImage {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/sqlite3";
    NSString *dbPath = [NSString stringWithFormat:@"%@/Library/Application Support/Dock/desktoppicture.db", NSHomeDirectory()];
    task.arguments = @[dbPath, @"select * from data"];
    task.standardOutput = pipe;
    [task launch];
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSArray* lines = [grepOutput componentsSeparatedByString: @"\n"];
    NSString *path = @"";
    if ([lines count] > 2)
        path = [lines objectAtIndex:([lines count] - 2)];
    path = [path stringByExpandingTildeInPath];
    return [[NSImage alloc] initWithContentsOfFile:path];;
}

- (NSImage *)defaultBootImage {
	return [NSImage imageNamed:@"default.png"];
}

- (NSColor *)defaultBootColor {
	return [NSColor colorWithDeviceRed:191.0/255.0 green:191.0/255.0 blue:191.0/255.0 alpha:1.0];
}

- (IBAction)showDefaultImage:(id)sender {
	bootImageView.image = [self defaultBootImage];
	bgColorWell.color = [self defaultBootColor];
}

- (IBAction)showCurrentImage:(id)sender {
	bootImageView.image = [self currentBootImage];
	bgColorWell.color = [self currentBootColor];
}

- (IBAction)showDefaultLogin:(id)sender {
    loginImageView.image = [self defaultLoginImage];
}

- (IBAction)showCurrentLogin:(id)sender {
    loginImageView.image = [self currentLoginImage];
}

- (IBAction)saveChanges:(id)sender {
	BOOL success = [self installBootImage:bootImageView.image withBackgroundColor:bgColorWell.color error:NULL];
    [self installLoginImage:loginImageView.image];
    [self setupDarkBoot];
	if (!success) { [self showCurrentImage:self]; }
}

- (NSColor *)currentBackgroundColor {
    NSColor* result = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path_bootColorPlist]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path_bootColorPlist];
        NSArray* args = [dict objectForKey:@"ProgramArguments"];
        if (args.count > 1) {
            NSString* color = [args objectAtIndex:1];
            NSArray* foo = [color componentsSeparatedByString: @"%"];
            long b = strtol([[foo objectAtIndex: 1] UTF8String], NULL, 16); // r
            long g = strtol([[foo objectAtIndex: 2] UTF8String], NULL, 16);
            long r = strtol([[foo objectAtIndex: 3] UTF8String], NULL, 16); // b
            result = [NSColor colorWithDeviceRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
            NSLog(@"r%ld g%ld b%ld", r, g, b);
        }
    }
    return result;
}

- (NSString *)hexStringForColor:(NSColor *)color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat b = components[0]; //r
    CGFloat g = components[1];
    CGFloat r = components[2]; //b
    NSString *hexString=[NSString stringWithFormat:@"%%%02X%%%02X%%%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];
    return hexString;
}

- (void)runAuthorization:(char*)tool :(char**)args {
    FILE *pipe = NULL;
    AuthorizationExecuteWithPrivileges(auth, tool, kAuthorizationFlagDefaults, args, &pipe);
}

- (void)installColorPlist:(NSString*)colorString {
    NSString* BXPlist = [[NSBundle mainBundle] pathForResource:@"com.dabrain13.darkboot" ofType:@"plist"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:BXPlist];
    NSMutableArray* bargs = [dict objectForKey:@"ProgramArguments"];
    [bargs setObject:colorString atIndexedSubscript:1];
    [dict setObject:bargs forKey:@"ProgramArguments"];
    [dict writeToFile:@"/tmp/BXplist.plist" atomically:YES];
    
    char *tool = "/bin/mv";
    char *args0[] = { "-f", "/tmp/BXplist.plist", (char*)[path_bootColorPlist UTF8String], nil };
    [self runAuthorization:tool :args0];
    
    tool = "/usr/sbin/chown";
    char *args1[] = { "root:admin", (char*)[path_bootColorPlist UTF8String], nil };
    [self runAuthorization:tool :args1];
    
    system("launchctl unload /Library/LaunchDaemons/com.dabrain13.darkboot.plist");
    system("launchctl load /Library/LaunchDaemons/com.dabrain13.darkboot.plist");
}

- (void)installLoginImage:(NSImage*)img {
    chflags([path_loginImage UTF8String], 0);
    
    NSData *imageData = [img TIFFRepresentation];
    NSData *loginData = [[self defaultLoginImage] TIFFRepresentation];
    
    if ([imageData isEqualToData:loginData]) {
        [[NSFileManager defaultManager] removeItemAtPath:path_loginImage error:nil];
    } else {
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]];
        NSData *imgData2 = [rep representationUsingType:NSPNGFileType properties:[[NSDictionary alloc] init]];
        [imgData2 writeToFile:path_loginImage atomically: NO];
        chflags([path_loginImage UTF8String], UF_IMMUTABLE);
    }
}

- (BOOL)installBootImage:(NSImage*)img withBackgroundColor:(NSColor*)bgColor error:(NSError**)err {
    // make temporary file
    NSString *tmpPath = nil;
    if (![img isEqual:[self defaultBootImage]]) {
        tmpPath = [NSTemporaryDirectory() stringByAppendingString:@"bootxchanger.XXXXXX"];
        char *tmpPathC = strdup([tmpPath fileSystemRepresentation]);
        mktemp(tmpPathC);
        tmpPath = [NSString stringWithUTF8String:tmpPathC];
        free(tmpPathC);
        
        // draw on background
        NSSize imgSize = [img size];
        NSImage *img2 = [[NSImage alloc] initWithSize:imgSize];
        [img2 lockFocus];
        [bgColor setFill];
        NSRectFill(NSMakeRect(0, 0, imgSize.width, imgSize.height));
        [img drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [img2 unlockFocus];
        
        // get png data
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[img2 TIFFRepresentation]];
        [rep setProperty:NSImageColorSyncProfileData withValue:nil];
        NSData *pngData = [rep representationUsingType:NSPNGFileType properties:[[NSDictionary alloc] init]];
        if (pngData == nil) {
            // could not get PNG representation
            if (err) *err = [NSError errorWithDomain:DBErrorDomain code:BXErrorCannotGetPNG userInfo:nil];
            return NO;
        }
        
        // write to file
        if (![pngData writeToFile:tmpPath atomically:NO]) {
            // could not write temporary file
            if (err) *err = [NSError errorWithDomain:DBErrorDomain code:BXErrorCannotWriteTmpFile userInfo:nil];
            return NO;
        }
    }
    
    // make color string
    bgColor = [bgColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    char colorStr[32];
    int colorInt = ((int)([bgColor redComponent]*255) << 16) | ((int)([bgColor greenComponent]*255) << 8) | ((int)([bgColor blueComponent]*255));
    sprintf(colorStr, "%d", colorInt);
    
    // install
    [self authorize];
    char *toolArgs[3] = {colorStr, (char*)[tmpPath fileSystemRepresentation], NULL};
    NSString *toolPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"InstallBootImage"];
    [self runAuthorization:(char*)[toolPath fileSystemRepresentation] :toolArgs];
//    return (e == errAuthorizationSuccess);
    return true;
}

- (IBAction)removeBXPlist:(id)sener {
    // Run the tool using the authorization reference
    char *tool = "/bin/rm";
    char *args0[] = { "-f", (char)[path_bootColorPlist UTF8String], nil };
    [self runAuthorization:tool :args0];
    system("launchctl unload /Library/LaunchDaemons/com.dabrain13.darkboot.plist");
    [bootColorWell setColor:[NSColor grayColor]];
}

- (IBAction)colorRadioButton:(id)sender {
    //    NSLog(@"%@", sender);
}

- (void)setupDarkBoot {
    if ([defColor state] == NSOnState) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path_bootColorPlist])
            [self removeBXPlist:nil];
    }
    if ([blkColor state] == NSOnState) {
        [self installColorPlist:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%00%00%00"];
    }
    if ([gryColor state] == NSOnState) {
        [self installColorPlist:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%99%99%99"];
    }
    if ([clrColor state] == NSOnState) {
        if ([self currentBackgroundColor] != bootColorWell.color) {
            NSString *bootColor = [self hexStringForColor:bootColorWell.color];
            NSString *bootARG = [NSString stringWithFormat:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%@", bootColor];
            [self installColorPlist:bootARG];
        }
    }
}

- (BOOL)authorize {
	if (auth) return YES;
	NSString				*toolPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"InstallBootImage"];
	AuthorizationFlags		authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
	AuthorizationItem		authItems[] = {kAuthorizationRightExecute, strlen([toolPath fileSystemRepresentation]), (void*)[toolPath fileSystemRepresentation], 0};
	AuthorizationRights		authRights = {sizeof(authItems)/sizeof(AuthorizationItem), authItems};
	return (AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, authFlags, &auth) == errAuthorizationSuccess);
}

- (void)deauthorize {
	if (auth) {
		AuthorizationFree(auth, kAuthorizationFlagDefaults);
		auth = NULL;
	}
}

- (IBAction)showAbout:(id)sender {
    [self selectView:viewAbout];
}

- (IBAction)showPrefs:(id)sender {
    [self selectView:viewPreferences];
}

- (IBAction)selectView:(id)sender {
    if ([tabViewButtons containsObject:sender])
        [tabMain setSubviews:[NSArray arrayWithObject:[tabViews objectAtIndex:[tabViewButtons indexOfObject:sender]]]];
    for (NSButton *g in tabViewButtons) {
        if (![g isEqualTo:sender])
            [[g layer] setBackgroundColor:[NSColor clearColor].CGColor];
        else
            [[g layer] setBackgroundColor:[NSColor colorWithCalibratedRed:0.121f green:0.4375f blue:0.1992f alpha:0.2578f].CGColor];
    }
}

- (IBAction)aboutInfo:(id)sender {
    NSString *rsc = @"";
    if ([sender isEqualTo:showChanges]) rsc=@"Changelog";
    if ([sender isEqualTo:showCredits]) rsc=@"Credits";
    if ([sender isEqualTo:showEULA]) rsc=@"EULA";
    [changeLog setEditable:true];
    [[changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:rsc ofType:@"rtf"] documentAttributes:nil]];
    [changeLog selectAll:self];
    [changeLog alignLeft:nil];
    if ([sender isEqualTo:showCredits]) [changeLog alignCenter:nil];
    [changeLog setSelectedRange:NSMakeRange(0,0)];
    [changeLog setEditable:false];
    [NSAnimationContext beginGrouping];
    NSClipView* clipView = [[changeLog enclosingScrollView] contentView];
    NSPoint newOrigin = [clipView bounds].origin;
    newOrigin.y = 0;
    [[clipView animator] setBoundsOrigin:newOrigin];
    [NSAnimationContext endGrouping];
}

- (IBAction)selectImage:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowedFileTypes:@[@"png"]];
    [openDlg beginWithCompletionHandler:^(NSInteger result) {
        if(result==NSFileHandlingPanelOKButton) {
            NSImage * aimage = [[NSImage alloc] initWithContentsOfURL:[openDlg.URLs objectAtIndex:0]];
            if ([sender isEqual:sellogin])
                [loginImageView setImage:aimage];
            if ([sender isEqual:selboot])
                [bootImageView setImage:aimage];
        }
    }];
}

- (IBAction)showFeedbackDialog:(id)sender {
    [DevMateKit showFeedbackDialog:nil inMode:DMFeedbackIndependentMode];
}

- (void)reportIssue {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/DarkBoot/issues/new"]];
}

- (void)donate {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://goo.gl/DSyEFR"]];
}

- (void)sendEmail {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:aguywithlonghair@gmail.com"]];
}

- (void)visitGithub {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild"]];
}

- (void)visitSource {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/DarkBoot"]];
}

- (void)visitWebsite {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://w0lfschild.github.io/app_dBoot.html"]];
}

@end
