//
//  Created by Wolfgang Baird on 11/23/16.
//  Copyright © 2016 macEnhance. All rights reserved.
//

@import Sparkle;
@import AppCenter;
@import AppCenterAnalytics;
@import AppCenterCrashes;
@import LetsMove;
@import CocoaMarkdown;

@import CoreImage;
@import CoreGraphics;
@import MachO;
@import MacForgeKit;

#import "DBApplication.h"
#import "FConvenience.h"
#import <Collaboration/Collaboration.h>

#include <sys/stat.h>
#include <unistd.h>
#include <sys/mount.h>

@import AppKit;

static NSString *DBErrorDomain          = @"Dark Boot";
static NSString *path_bootImagePlist    = @"/Library/Preferences/SystemConfiguration/com.apple.Boot.plist";
static NSString *path_bootColorPlist    = @"/Library/LaunchDaemons/com.macenhance.dbcolor.plist";
static NSString *path_loginImage        = @"/Library/Caches/com.apple.desktop.admin.png";

NSArray *tabViewButtons;
Boolean *animateBootColor = false;

enum BXErrorCode {
	BXErrorNone,
	BXErrorCannotGetPNG,
	BXErrorCannotWriteTmpFile,
};

@implementation DBApplication

- (NSString*)runCommand:(NSString*)command {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    NSArray *arguments = [NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@", command], nil];
    [task setArguments:arguments];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    [task launch];
    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}

- (void)awakeFromNib {
	[self setDelegate:(id)self];
}

// Cleanup some stuff when user changes dark mode
- (void)systemDarkModeChange:(NSNotification *)notif {
    if (osx_ver >= 14) {
        if (notif == nil) {
            // Need to fix for older versions of macos
            if ([NSApp.effectiveAppearance.name isEqualToString:NSAppearanceNameAqua]) {
                [changeLog setTextColor:[NSColor blackColor]];
            } else {
                [changeLog setTextColor:[NSColor whiteColor]];
            }
        } else {
            NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
            if ([osxMode isEqualToString:@"Dark"]) {
                [changeLog setTextColor:[NSColor whiteColor]];
            } else {
                [changeLog setTextColor:[NSColor blackColor]];
            }
        }
    }
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    lockImagePath = nil;
        
    osx_ver = 9;
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)])
        osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    
    [MSAppCenter start:@"30b5a540-9261-4660-97ed-c533c3304b63" withServices:@[
      [MSAnalytics class],
      [MSCrashes class]
    ]];
    
    [self dirCheck:db_Folder];
    
    // Mojave or greater
    if (osx_ver > 13) {
        path_loginImage = [self runCommand:@"find /Library/Caches/Desktop\\ Pictures -name lockscreen.png"];
        path_loginImage = [path_loginImage stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
        
    if ([db_LockSize doubleValue] > 0) {
        [lockTextSlider setDoubleValue:[db_LockSize doubleValue]];
        [self lockTextSlider:lockTextSlider];
    } else {
        [lockTextSlider setDoubleValue:8];
    }
    
    if (db_LockText) {
        [lockTextText setStringValue:db_LockText];
    } else {
        [lockTextText setStringValue:@"🍣"];
    }
    
    [self showCurrentImage:self];
    [self showCurrentLock:self];
    [self showCurrentLogin:self];
    
    lockUserIcon.image = [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].image;
    lockUserIcon.wantsLayer = YES;
    lockUserIcon.layer.cornerRadius = lockUserIcon.layer.frame.size.height/2;
    lockUserIcon.layer.masksToBounds = YES;
    lockUserIcon.animates = YES;
    
    loginUserIcon.image = [CBIdentity identityWithName:NSUserName() authority:[CBIdentityAuthority defaultIdentityAuthority]].image;
    loginUserIcon.wantsLayer = YES;
    loginUserIcon.layer.cornerRadius = loginUserIcon.layer.frame.size.height/2;
    loginUserIcon.layer.masksToBounds = YES;
    loginUserIcon.animates = YES;
    
    [lockTextCustomSize setState:db_EnableSize];
    [lockTextCustomText setState:db_EnableText];

    [mainWindow setMovableByWindowBackground:YES];
    [mainWindow setTitle:@""];
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    [appName setStringValue:[infoDict objectForKey:@"CFBundleExecutable"]];
    [appVersion setStringValue:[NSString stringWithFormat:@"Version %@ (%@)",
                                 [infoDict objectForKey:@"CFBundleShortVersionString"],
                                 [infoDict objectForKey:@"CFBundleVersion"]]];
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger year = [components year];

    [appCopyright setStringValue:[NSString stringWithFormat:@"Copyright © 2015 - %ld macEnhance", (long)year]];
    
    NSString *path = [[[NSBundle mainBundle] URLForResource:@"CHANGELOG" withExtension:@"md"] path];
    CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
    CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
    [changeLog.textStorage setAttributedString:asr.render];

    [self systemDarkModeChange:nil];
    
    Class vibrantClass=NSClassFromString(@"NSVisualEffectView");
    if (vibrantClass) {
        NSVisualEffectView *vibrant=[[vibrantClass alloc] initWithFrame:[[mainWindow contentView] bounds]];
        [vibrant setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [vibrant setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [[mainWindow contentView] addSubview:vibrant positioned:NSWindowBelow relativeTo:nil];
    } else {
        [mainWindow setBackgroundColor:[NSColor whiteColor]];
    }

    [_reportButton setAction:@selector(reportIssue)];
    [_donateButton setAction:@selector(donate)];
    
    [self tabs_sideBar];
    [self selectView:_sidebarBootColor];
    
    [bootColorProgress setHidden:true];
    bootColorIndicator = [[AYProgressIndicator alloc] initWithFrame:CGRectMake(bootColorProgress.frame.origin.x, bootColorProgress.frame.origin.y, bootColorProgress.frame.size.width, bootColorProgress.frame.size.height / 4)
                                                      progressColor:[NSColor whiteColor]
                                                         emptyColor:[NSColor blackColor]
                                                           minValue:0
                                                           maxValue:100
                                                       currentValue:0];
    [bootColorIndicator setDoubleValue:33];
    [bootColorIndicator setEmptyColor:[NSColor whiteColor]];
    [bootColorIndicator setProgressColor:[NSColor blackColor]];
    [bootColorIndicator setHidden:NO];
    [bootColorIndicator setWantsLayer:YES];
    [bootColorIndicator.layer setCornerRadius:bootColorIndicator.frame.size.height/2];
    [tabBootColor addSubview:bootColorIndicator];

    NSColor *bk = [self currentBackgroundColor];
    if (![bk isEqual:NSColor.clearColor]) {
        NSString *bgs = [self currentBackgroundString];
        if ([bgs isEqualToString:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%00%00%00"]) {
            [bootColorControl setSelectedSegment:1];
        } else if ([bgs isEqualToString:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%99%99%99"]) {
            [bootColorControl setSelectedSegment:2];
        } else {
            [bootColorControl setSelectedSegment:3];
        }
    } else {
        [bootColorView setColor:[[NSColor grayColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace]];
        [bootColorControl setSelectedSegment:0];
    }
    
    [aboutGif setImage:[NSImage.alloc initWithContentsOfURL:[NSURL URLWithString:@"https://media.giphy.com/media/3owypd1qwsPZVR5X5m/source.gif"]]];
    
    [self updateBootColorPreview];
    [self getBootOptions];
    [self bootPreviewAnimate];
    [self aboutInfo:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(systemDarkModeChange:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
    PFMoveToApplicationsFolderIfNecessary();
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[self deauthorize];
	return NSTerminateNow;
}

- (IBAction)resetSidebar:(id)sender {
    [self tabs_sideBar];
}

- (void)tabs_sideBar {
    tabViewButtons =  @[_sidebarBootColor, _sidebarBootImage, _sidebarBootOptions, _sidebarLoginScreen, _sidebarLockScreen];
    
    struct statfs output;
    statfs("/", &output);
    if ([[NSString stringWithFormat:@"%s", output.f_fstypename] isEqualToString:@"apfs"]) {
        [_sidebarBootImage.buttonClickArea setEnabled:NO];
        [_sidebarBootImage setToolTip:@"Requires HFS/HFS+ boot partition"];
    }
    
    // Setup top buttons
    NSInteger height = 42;
    NSArray *topButtons = @[_sidebarBootColor, _sidebarBootImage, _sidebarBootOptions, _sidebarLoginScreen, _sidebarLockScreen];
    NSUInteger yLoc = mainWindow.frame.size.height - height * 2;
    for (MF_sidebarButton *sideButton in topButtons) {
        NSButton *btn = sideButton.buttonClickArea;
        if (btn.enabled) {
            sideButton.hidden = false;
            NSRect newFrame = [sideButton frame];
            newFrame.origin.x = 0;
            newFrame.origin.y = yLoc;
            newFrame.size.height = 42;
            yLoc -= height;
            [sideButton setFrame:newFrame];
            [sideButton setWantsLayer:YES];
        } else {
            sideButton.hidden = true;
        }
    }

    // Set target + action
    for (MF_sidebarButton *sideButton in tabViewButtons) {
        NSButton *btn = sideButton.buttonClickArea;
        [btn setTarget:self];
        [btn setAction:@selector(selectView:)];
    }

    NSUInteger buttonYPos = 60;
    
    // Discord Button
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"prefHideDiscord"]) {
        [_sidebarDiscord setFrame:CGRectMake(0, buttonYPos, _sidebarDiscord.frame.size.width, 60)];
        [_sidebarDiscord.buttonClickArea setImage:[[NSImage alloc] initByReferencingURL:[NSURL URLWithString:@"https://discordapp.com/api/guilds/608740492561219617/widget.png?style=banner2"]]];
        [_sidebarDiscord.buttonClickArea setImageScaling:NSImageScaleAxesIndependently];
        [_sidebarDiscord.buttonClickArea setAutoresizingMask:NSViewMaxYMargin];
        [_sidebarDiscord setHidden:false];
        buttonYPos += 60;
    } else {
        [_sidebarDiscord setHidden:true];
    }
    
//    Warning button
    [_sidebarApplyAll setFrame:CGRectMake(0, 0, _sidebarApplyAll.frame.size.width, 60)];
    [_sidebarApplyAll setWantsLayer:YES];
    [_sidebarApplyAll.buttonLabel setStringValue:@"Apply All"];
//    [_sidebarApplyAll.layer setBackgroundColor:NSColor.systemGreenColor.CGColor];
}

- (NSString *)currentBackgroundString {
    NSString* result = nil;
    if ([FileManager fileExistsAtPath:path_bootColorPlist]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path_bootColorPlist];
        NSArray* args = [dict objectForKey:@"ProgramArguments"];
        result = [args objectAtIndex:1];
    }
    return result;
}

- (NSImage *)currentLockImage {
    NSImage *img;
    // get image
    NSString *filePath;
    for (NSString *ext in @[@"jpg", @"png", @"gif"])
        if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
            filePath = [db_LockFile stringByAppendingPathExtension:ext];
    
    if (filePath.length) {
        img = [[NSImage alloc] initWithContentsOfFile:filePath];
        lockImageView.path = filePath;
        if (img == nil) return [self defaultLoginImage];
    } else {
        img = [self defaultLoginImage];
        hashVal = img.hash;
    }
    return img;
}

- (NSImage *)currentLoginImage {
    // get image
    NSImage *img = [[NSImage alloc] initWithContentsOfFile:path_loginImage];
    if (img == nil) return [self defaultLoginImage];
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
	NSDictionary *bootPlist = [NSDictionary dictionaryWithContentsOfFile:path_bootColorPlist];
    NSArray *args;
    NSString *hex;
    NSColor *res = NSColor.clearColor;
    if (bootPlist) {
        args = [bootPlist valueForKey:@"ProgramArguments"];
        hex = args.lastObject;
        if (hex.length > 60) {
            hex = [hex substringFromIndex:60];
            hex = [hex stringByReplacingOccurrencesOfString:@"%" withString:@""];
            res = [self colorFromHexString:hex];
        }
        return res;
    } else {
        return [self defaultBootColor];
    }
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
    
    if (osx_ver > 13) {
        if (osx_ver == 14)
            path = @"/System/Library/Desktop Pictures/Mojave.heic";
        if (osx_ver >= 15)
            path = @"/System/Library/Desktop Pictures/Catalina.heic";
    }
    
    return [NSImage.alloc initWithContentsOfFile:path];;
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
    NSImage *theImage = [self defaultLoginImage];
    loginImageView.image = theImage;
}

- (IBAction)showCurrentLogin:(id)sender {
    NSImage *theImage = [self currentLoginImage];
    loginImageView.image = theImage;
    loginImageView.animates = YES;
    loginImageView.canDrawSubviewsIntoLayer = YES;
}

- (IBAction)showDefaultLock:(id)sender {
    NSImage *theImage = [self defaultLoginImage];
    hashVal = theImage.hash;
    lockImageView.path = @"";
    lockImageView.image = theImage;
}

- (IBAction)showCurrentLock:(id)sender {
    NSImage *theImage = [self currentLockImage];
    lockImageView.image = theImage;
    lockImageView.animates = YES;
    lockImageView.canDrawSubviewsIntoLayer = YES;
}

- (IBAction)lockTextTextEdit:(id)sender {
    [Defaults setObject:lockTextText.stringValue forKey:@"lock_text"];
}

- (IBAction)lockTextSlider:(id)sender {
    NSSlider *s = sender;
    NSFont *f = [NSFont fontWithName:lockTextText.font.fontName size:s.doubleValue/2];
    [lockTextText setFont:f];
    [Defaults setObject:[NSNumber numberWithDouble:s.doubleValue] forKey:@"lock_size"];
}

- (IBAction)saveLockScreen:(id)sender {
    [self installLockImage:lockImageView.image];
}

- (IBAction)saveLoginScreen:(id)sender {
    [self installLoginImage:loginImageView.image];
}

- (IBAction)saveBootColor:(id)sender {
    [self setupDarkBoot];
}

- (IBAction)saveBootImage:(id)sender {
    BOOL success = [self installBootImage:bootImageView.image withBackgroundColor:bgColorWell.color error:NULL];
    if (!success) { [self showCurrentImage:self]; }
}

- (IBAction)saveChanges:(id)sender {
	BOOL success = [self installBootImage:bootImageView.image withBackgroundColor:bgColorWell.color error:NULL];
    [self installLoginImage:loginImageView.image];
    [self installLockImage:lockImageView.image];
    [self setupDarkBoot];
	if (!success) { [self showCurrentImage:self]; }
}

- (NSColor *)currentBackgroundColor {
    NSColor* result = NSColor.clearColor;
    if ([FileManager fileExistsAtPath:path_bootColorPlist]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path_bootColorPlist];
        NSArray* args = [dict objectForKey:@"ProgramArguments"];
        if (args.count > 1) {
            NSString* color = [args objectAtIndex:1];
            NSArray* foo = [color componentsSeparatedByString: @"%"];
            long b = strtol([[foo objectAtIndex: 1] UTF8String], NULL, 16); // r
            long g = strtol([[foo objectAtIndex: 2] UTF8String], NULL, 16);
            long r = strtol([[foo objectAtIndex: 3] UTF8String], NULL, 16); // b
            result = [NSColor colorWithDeviceRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
        }
    }
    return result;
}

- (NSColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:0]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
//    return [NSColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
    return [NSColor colorWithRed:(rgbValue & 0xFF)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:((rgbValue & 0xFF0000) >> 16)/255.0 alpha:1.0];
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
    NSString* BXPlist = [[NSBundle mainBundle] pathForResource:@"com.macenhance.dbcolor" ofType:@"plist"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:BXPlist];
    NSMutableArray* bargs = [dict objectForKey:@"ProgramArguments"];
    [bargs setObject:colorString atIndexedSubscript:1];
    [dict setObject:bargs forKey:@"ProgramArguments"];
    [dict writeToFile:@"/tmp/BXplist.plist" atomically:YES];
    
    [self authorize];
    
    char *tool = "/bin/mv";
    char *args0[] = { "-f", "/tmp/BXplist.plist", (char*)[path_bootColorPlist UTF8String], nil };
    [self runAuthorization:tool :args0];
    
    tool = "/usr/sbin/chown";
    char *args1[] = { "root:admin", (char*)[path_bootColorPlist UTF8String], nil };
    [self runAuthorization:tool :args1];
    
    system("launchctl unload /Library/LaunchDaemons/com.macenhance.dbcolor.plist");
    system("launchctl load /Library/LaunchDaemons/com.macenhance.dbcolor.plist");
}

- (void)installLockImage:(NSImage*)img {
    for (NSString *ext in @[@"jpg", @"png", @"gif"])
        if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
            [FileManager removeItemAtPath:[db_LockFile stringByAppendingPathExtension:ext] error:nil];
    
    if ([FileManager isReadableFileAtPath:lockImageView.path]) {
        NSError *err;
        [FileManager copyItemAtURL:[NSURL fileURLWithPath:lockImageView.path]
                             toURL:[NSURL fileURLWithPath:[db_LockFile stringByAppendingPathExtension:lockImageView.path.pathExtension]]
                             error:&err];
        if (err != nil) NSLog(@"%@", err);
    } else {
        if ((long)hashVal != lockImageView.hashValue) {
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]];
            NSNumber *frames = [rep valueForProperty:@"NSImageFrameCount"];
            NSData *imgData2;;
            if (frames != nil) {   // bitmapRep is a Gif imageRep
                imgData2 = [rep representationUsingType:NSGIFFileType
                                             properties:[[NSDictionary alloc] init]];
                [imgData2 writeToFile:[db_LockFile stringByAppendingPathComponent:@"gif"] atomically:NO];
            } else {
                imgData2 = [rep representationUsingType:NSPNGFileType
                                             properties:[[NSDictionary alloc] init]];
                [imgData2 writeToFile:[db_LockFile stringByAppendingPathComponent:@"png"] atomically:NO];
            }
        }
    }
}

- (NSImage*)imageFromCGImageRef:(CGImageRef)image {
    NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
    CGContextRef imageContext = nil;
    NSImage* newImage = nil; // Get the image dimensions.
    imageRect.size.height = CGImageGetHeight(image);
    imageRect.size.width = CGImageGetWidth(image);
    
    // Create a new image to receive the Quartz image data.
    newImage = [[NSImage alloc] initWithSize:imageRect.size];
    [newImage lockFocus];
    
    // Get the Quartz context and draw.
    imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextDrawImage(imageContext, *(CGRect*)&imageRect, image); [newImage unlockFocus];
    return newImage;
}

- (void)installLoginImage:(NSImage*)img {
    chflags([path_loginImage UTF8String], 0);
    
    CGColorSpaceRef CGColorSpaceCreateDeviceRGB();
    
    CGImageSourceRef source;
    source = CGImageSourceCreateWithData((CFDataRef)[img TIFFRepresentation], NULL);
    CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef alter = CGImageCreateCopyWithColorSpace(maskRef, colorspace);
    NSImage *alterED = [self imageFromCGImageRef:alter];
        
    NSData *imageData = [img TIFFRepresentation];
    NSData *loginData = [[self defaultLoginImage] TIFFRepresentation];
    
    if ([imageData isEqualToData:loginData]) {
        [FileManager removeItemAtPath:path_loginImage error:nil];
    } else {
//        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]];
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[alterED TIFFRepresentation]];
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
        [img drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        [img2 unlockFocus];
        
        // change colorspace
        CGColorSpaceRef CGColorSpaceCreateDeviceRGB();
        CGImageSourceRef source;
        source = CGImageSourceCreateWithData((CFDataRef)[img2 TIFFRepresentation], NULL);
        CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGImageRef alter = CGImageCreateCopyWithColorSpace(maskRef, colorspace);
        NSImage *alterED = [self imageFromCGImageRef:alter];
        
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[alterED TIFFRepresentation]];
        NSData *pngData = [rep representationUsingType:NSPNGFileType properties:[[NSDictionary alloc] init]];
        [pngData writeToFile:@"/Library/Caches/BootLogo.png" atomically: NO];
                
//        // get png data
//        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[alterED TIFFRepresentation]];
//        [rep setProperty:NSImageColorSyncProfileData withValue:nil];
//        NSData *pngData = [rep representationUsingType:NSPNGFileType properties:[[NSDictionary alloc] init]];
//        if (pngData == nil) {
//            // could not get PNG representation
//            if (err) *err = [NSError errorWithDomain:DBErrorDomain code:BXErrorCannotGetPNG userInfo:nil];
//            return NO;
//        }

//        // write to file
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
    [self authorize];
    
    char *tool1 = "/usr/sbin/chmod";
    char *args1[] = { "755", (char*)[path_bootColorPlist UTF8String], nil };
    [self runAuthorization:tool1 :args1];
    
    char *tool0 = "/bin/mv";
    char *args0[] = { "-f", (char*)[path_bootColorPlist UTF8String], "/tmp/BXplist.plist", nil };
    [self runAuthorization:tool0 :args0];
    
    char *tool = "/bin/rm";
    char *args[] = { "-f", "/tmp/BXplist.plist", nil };
    [self runAuthorization:tool :args];
    system("launchctl unload /Library/LaunchDaemons/com.macenhance.dbcolor.plist");
    [bootColorView setColor:[self defaultBootColor]];
}

- (void)bootPreviewAnimate {
    if (animateBootColor) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [context setDuration:10.0];
            [[bootColorIndicator animator] setDoubleValue:100.0];
        } completionHandler:^{
            [bootColorIndicator setDoubleValue:0.0];
            [self bootPreviewAnimate];
        }];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self bootPreviewAnimate];
        });
    }
}

- (IBAction)cleanupBootColorView:(id)sender {
    NSColor *activeColor = bootColorView.color;
    
    NSColor *primary    = NSColor.blackColor;
    NSColor *secondary  = NSColor.whiteColor;
    NSImage *drawnImage = nil;
    if ([self useDarkColors:activeColor]) {
        primary     = NSColor.whiteColor;
        secondary   = NSColor.blackColor;
    }
    if (bootColorControl.selectedSegment == 1) secondary = NSColor.grayColor;
    
    drawnImage = [self imageTintedWithColor:bootColorApple.image :primary];
    [bootColorIndicator setEmptyColor:secondary];
    [bootColorIndicator setProgressColor:primary];
    [bootColorApple setImage:drawnImage];
}
    
- (void)updateBootColorPreview {
    NSColor *activeColor = nil;
    if (bootColorControl.selectedSegment == 0)
        activeColor = [[self defaultBootColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (bootColorControl.selectedSegment == 1)
        activeColor = [NSColor.blackColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (bootColorControl.selectedSegment == 2)
        activeColor = [NSColor.grayColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (bootColorControl.selectedSegment == 3)
        activeColor = [self currentBootColor];
    
    [bootColorView setColor:activeColor];
    [self cleanupBootColorView:nil];
}

- (Boolean*)colorCompare:(NSColor*)a :(NSColor*)b {
    Boolean *result = false;
    int similarities = 0;
    NSColor *normalizedA =  [a colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColor *normalizedB =  [b colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (normalizedA.redComponent * 255 > normalizedB.redComponent * 255 - 10 && normalizedA.redComponent * 255 < normalizedB.redComponent * 255 + 10)
        similarities++;
    
    if (normalizedA.greenComponent * 255 > normalizedB.greenComponent * 255 - 10 && normalizedA.greenComponent * 255 < normalizedB.greenComponent * 255 + 10)
        similarities++;
    
    if (normalizedA.blueComponent * 255 > normalizedB.blueComponent * 255 - 10 && normalizedA.blueComponent * 255 < normalizedB.blueComponent * 255 + 10)
        similarities++;
    
    if (similarities >= 3)
        result = true;
    
    return result;
}

- (IBAction)colorPickerChanged:(id)sender {
    [self updateBootColorPreview];
}

- (NSImage *)imageTintedWithColor:(NSImage *)img :(NSColor *)tint {
    NSImage *image = [img copy];
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    return image;
}

- (Boolean)useDarkColors:(NSColor*)backGround {
    Boolean result = true;
    double a = 1 - ( 0.299 * backGround.redComponent * 255 + 0.587 * backGround.greenComponent * 255 + 0.114 * backGround.blueComponent * 255)/255;
    if (a < 0.5)
        result = false; // bright colors - black font
    else
        result = true; // dark colors - white font
    return result;
}

- (void)setupDarkBoot {
    if (bootColorControl.selectedSegment == 0) {
        if ([FileManager fileExistsAtPath:path_bootColorPlist])
            [self removeBXPlist:nil];
    }
    
    if (bootColorControl.selectedSegment == 1) {
        [self installColorPlist:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%00%00%00"];
    }
    
    if (bootColorControl.selectedSegment == 2) {
        [self installColorPlist:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%99%99%99"];
    }
    
    if (bootColorControl.selectedSegment == 3) {
        if ([self currentBackgroundColor] != bootColorView.color) {
            NSString *bootColor = [self hexStringForColor:bootColorView.color];
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

- (IBAction)selectView:(id)sender {
    MF_sidebarButton *buttonContainer = nil;
    NSButton *button = (NSButton*)sender;
    if (button.superview.class == MF_sidebarButton.class) {
        buttonContainer = (MF_sidebarButton*)button.superview;
    } else if ([sender class] == MF_sidebarButton.class) {
        buttonContainer = (MF_sidebarButton*)sender;
        button = buttonContainer.buttonClickArea;
    }
           
    // Select the view
    if (buttonContainer) {
        // Log that the user clicked on a sidebar button
        [MSAnalytics trackEvent:@"Selected View" withProperties:@{@"View" : [button title]}];
        // Add the view to our main view
        [self setMainViewSubView:buttonContainer.linkedView];
    }

    animateBootColor = false;
    if ([buttonContainer isEqualTo:_sidebarBootColor]) animateBootColor = true;

    if ([buttonContainer isEqualTo:_sidebarBootImage]) {
        Boolean SIPStatus = [MacForgeKit SIP_enabled];
        if (SIPStatus) {
            NSTextView *blocked = [[NSTextView alloc] initWithFrame:tabLockScreen.frame];
            blocked.alignment = NSTextAlignmentCenter;
            [blocked setBackgroundColor:NSColor.clearColor];
            [blocked setString:@"\n\n\n\n\n⚠️ Editing this requires System Integrity Protection to be disabled! ⚠️"];
            [tabMain setSubviews:@[blocked]];
            NSViewController *vc = [[MFKSipView alloc] init];
            [tabMain setSubviews:[NSArray arrayWithObject:vc.view]];
        }
    }

    if ([buttonContainer isEqualTo:_sidebarLockScreen]) {
        NSString *MF_pluginDIR = @"/Library/Application Support/MacEnhance/Plugins";
        BOOL isDir;
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:MF_pluginDIR isDirectory:&isDir];
        if (!exists) {
            NSString *path = [[[NSBundle mainBundle] URLForResource:@"LOGININFO" withExtension:@"md"] path];
            CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
            CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
            [mfWarningText.textStorage setAttributedString:asr.render];
            NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
            [mfWarningText setTextColor:[NSColor blackColor]];
            if ([osxMode isEqualToString:@"Dark"])
                [mfWarningText setTextColor:[NSColor whiteColor]];
            [tabMain setSubviews:@[tabMacForge]];
        } else {
            NSString *DB_pluginSource = [NSBundle.mainBundle pathForResource:@"DBLoginWindow" ofType:@"bundle"];
            NSString *DB_pluginDest = @"/Library/Application Support/MacEnhance/Plugins/DBLoginWindow.bundle";
            if (![NSFileManager.defaultManager fileExistsAtPath:DB_pluginDest isDirectory:&isDir])
                [NSFileManager.defaultManager copyItemAtPath:DB_pluginSource toPath:DB_pluginDest error:nil];
        }
    }
    
    // Adjust text and background color
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    NSColor *primary = NSColor.darkGrayColor;
    NSColor *secondary = NSColor.blackColor;
    NSColor *highlight = NSColor.blackColor;
    if (osx_ver >= 14) {
        if ([osxMode isEqualToString:@"Dark"]) {
            primary = NSColor.lightGrayColor;
            secondary = NSColor.whiteColor;
            highlight = NSColor.whiteColor;
        }
    }

    for (MF_sidebarButton *sidebarButton in tabViewButtons) {
        NSTextField *g = sidebarButton.buttonLabel;
        NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithString:g.stringValue];
        if (![sidebarButton isEqualTo:buttonContainer]) {
            [[sidebarButton layer] setBackgroundColor:[NSColor clearColor].CGColor];
            [colorTitle addAttribute:NSForegroundColorAttributeName value:primary range:NSMakeRange(0, g.attributedStringValue.length)];
            [g setAttributedStringValue:colorTitle];
        } else {
            [[sidebarButton layer] setBackgroundColor:[highlight colorWithAlphaComponent:.25].CGColor];
            [colorTitle addAttribute:NSForegroundColorAttributeName value:secondary range:NSMakeRange(0, g.attributedStringValue.length)];
            [g setAttributedStringValue:colorTitle];
        }
    }
}

- (void)setMainViewSubView:(NSView*)subview {
    [subview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [subview setFrameSize:CGSizeMake(tabMain.frame.size.width, tabMain.frame.size.height - 2)];
    [tabMain setSubviews:@[subview]];
    [tabMain scrollPoint:CGPointZero];
}

- (IBAction)showAbout:(id)sender {
    [_preferencesTabController setSelectedSegment:_preferencesTabController.segmentCount - 1];
    [self selectPreference:_preferencesTabController];
}

- (IBAction)showPreferences:(id)sender {
    [self selectPreference:_preferencesTabController];
}

- (IBAction)selectPreference:(id)sender {
    NSArray *preferenceViews = @[_preferencesGeneral, _preferencesData, _preferencesAbout];
    NSView *selectedPane = [preferenceViews objectAtIndex:[(NSSegmentedControl*)sender selectedSegment]];
    [_windowPreferences setIsVisible:true];
    [_windowPreferences.contentView setSubviews:@[selectedPane]];
    Class vibrantClass=NSClassFromString(@"NSVisualEffectView");
    if (vibrantClass) {
        NSVisualEffectView *vibrant=[[vibrantClass alloc] initWithFrame:[[_windowPreferences contentView] bounds]];
        [vibrant setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [vibrant setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
        [vibrant setState:NSVisualEffectStateActive];
        [[_windowPreferences contentView] addSubview:vibrant positioned:NSWindowBelow relativeTo:nil];
    }
    CGRect newFrame = _windowPreferences.frame;
    CGFloat contentHeight = [_windowPreferences contentRectForFrameRect: _windowPreferences.frame].size.height;
    CGFloat titleHeight = _windowPreferences.frame.size.height - contentHeight;
    newFrame.size.height = selectedPane.frame.size.height + titleHeight;
    newFrame.size.width = selectedPane.frame.size.width;
    CGFloat yDiff = _windowPreferences.frame.size.height - newFrame.size.height;
    newFrame.origin.y += yDiff;
    [_windowPreferences setFrame:newFrame display:true animate:true];
    _windowPreferences.styleMask &= ~NSWindowStyleMaskResizable;
    [NSApp activateIgnoringOtherApps:true];
}

- (IBAction)aboutInfo:(id)sender {
    NSUInteger selected = [(NSSegmentedControl*)sender selectedSegment];
    
    if (selected == 0) {
        NSString *path = [[[NSBundle mainBundle] URLForResource:@"CHANGELOG" withExtension:@"md"] path];
        CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
        CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
        [changeLog.textStorage setAttributedString:asr.render];
    }
    if (selected == 1) {
        NSString *path = [[[NSBundle mainBundle] URLForResource:@"CREDITS" withExtension:@"md"] path];
        CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
        CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
        [changeLog.textStorage setAttributedString:asr.render];
    }
    if (selected == 2) {
        NSMutableAttributedString *mutableAttString = [[NSMutableAttributedString alloc] init];
        for (NSString *item in [FileManager contentsOfDirectoryAtPath:NSBundle.mainBundle.resourcePath error:nil]) {
            if ([item containsString:@"LICENSE"]) {
                
                NSString *unicodeStr = @"\n\u00a0\t\t\n\n";
                NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:unicodeStr];
                NSRange strRange = NSMakeRange(0, str.length);

                NSMutableParagraphStyle *const tabStyle = [[NSMutableParagraphStyle alloc] init];
                tabStyle.headIndent = 16; //padding on left and right edges
                tabStyle.firstLineHeadIndent = 16;
                tabStyle.tailIndent = -70;
                NSTextTab *listTab = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter location:changeLog.frame.size.width - tabStyle.headIndent + tabStyle.tailIndent options:@{}]; //this is how long I want the line to be
                tabStyle.tabStops = @[listTab];
                [str  addAttribute:NSParagraphStyleAttributeName value:tabStyle range:strRange];
                [str addAttribute:NSStrikethroughStyleAttributeName value:[NSNumber numberWithInt:2] range:strRange];
                
                [mutableAttString appendAttributedString:[[NSAttributedString alloc] initWithURL:[[NSBundle mainBundle] URLForResource:item withExtension:@""] options:[[NSDictionary alloc] init] documentAttributes:nil error:nil]];
                [mutableAttString appendAttributedString:str];
            }
        }
        [changeLog.textStorage setAttributedString:mutableAttString];
    }
    if (selected == 3) {
        NSString *path = [[[NSBundle mainBundle] URLForResource:@"README" withExtension:@"md"] path];
        CMDocument *cmd = [[CMDocument alloc] initWithContentsOfFile:path options:CMDocumentOptionsNormalize];
        CMAttributedStringRenderer *asr = [[CMAttributedStringRenderer alloc] initWithDocument:cmd attributes:[[CMTextAttributes alloc] init]];
        [changeLog.textStorage setAttributedString:asr.render];
    }
    
    [NSAnimationContext beginGrouping];
    NSClipView* clipView = changeLog.enclosingScrollView.contentView;
    NSPoint newOrigin = [clipView bounds].origin;
    newOrigin.y = 0;
    [[clipView animator] setBoundsOrigin:newOrigin];
    [NSAnimationContext endGrouping];
    
    [self systemDarkModeChange:nil];
}

- (void)getBootOptions {
    NSString *bootArgs = [self runCommand:@"nvram -p | grep boot-args"];
    bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if (bootArgs.length > 10) bootArgs = [bootArgs substringFromIndex:10];
    bootCamshell.state = [bootArgs containsString:@"iog=0x0"];
    bootVerbose.state = [bootArgs containsString:@"-v"];
    bootSingle.state = [bootArgs containsString:@"-s"];
    bootSafe.state = [bootArgs containsString:@"-x"];
    
    bootArgs = [self runCommand:@"nvram -p | grep AutoBoot"];
    bootAuto.state = [bootArgs containsString:@"%03"];
    
    bootArgs = [self runCommand:@"nvram -p | grep BootAudio"];
    Boolean bootsound = [bootArgs containsString:@"%01"];
    if (!bootsound) {
        bootArgs = [self runCommand:@"nvram -p | grep StartupMute"];
        bootsound = [bootArgs containsString:@"%00"];
    }
    bootAudio.state = bootsound;
}

- (IBAction)applyBootOptions:(id)sender {
    [self authorize];
    char *tool = "/usr/sbin/nvram";
    
    NSString *bootArgs = [self runCommand:@"nvram -p | grep boot-args"];
    bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if (bootArgs.length > 10)
        bootArgs = [bootArgs substringFromIndex:10];
    else
        bootArgs = @"";
    
    Boolean *currentArg = false;
    
    // CamShell
    currentArg = [bootArgs containsString:@"iog=0x0"];
    if (bootCamshell.state == NSOnState) {
        if (!currentArg) bootArgs = [NSString stringWithFormat:@"%@ iog=0x0", bootArgs];
    } else {
        if (currentArg) bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"iog=0x0" withString:@""];
    }
    
    // Verbose
    currentArg = [bootArgs containsString:@"-v"];
    if (bootVerbose.state == NSOnState) {
        if (!currentArg) bootArgs = [NSString stringWithFormat:@"%@ -v", bootArgs];
    } else {
        if (currentArg) bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"-v" withString:@""];
    }
    
    // Single
    currentArg = [bootArgs containsString:@"-s"];
    if (bootSingle.state == NSOnState) {
        if (!currentArg) bootArgs = [NSString stringWithFormat:@"%@ -s", bootArgs];
    } else {
        if (currentArg) bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"-s" withString:@""];
    }
    
    // Safe
    currentArg = [bootArgs containsString:@"-x"];
    if (bootSafe.state == NSOnState) {
        if (!currentArg) bootArgs = [NSString stringWithFormat:@"%@ -x", bootArgs];
    } else {
        if (currentArg) bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"-x" withString:@""];
    }
    
    // Remove extra spaces
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"  +" options:NSRegularExpressionCaseInsensitive error:&error];
    bootArgs = [regex stringByReplacingMatchesInString:bootArgs options:0 range:NSMakeRange(0, [bootArgs length]) withTemplate:@" "];
    bootArgs = [NSString stringWithFormat:@"boot-args=%@", bootArgs];
    char *args00[] = { (char*)[bootArgs UTF8String], nil };
    [self runAuthorization:tool :args00];
    NSLog(@"%@", bootArgs);
    
    // Auto
    bootArgs = [self runCommand:@"nvram -p | grep AutoBoot"];
    if (bootAuto.state == NSOnState) {
        bootArgs = @"AutoBoot=%03";
    } else {
        bootArgs = @"AutoBoot=%00";
    }
    char *args01[] = { (char*)[bootArgs UTF8String], nil };
    [self runAuthorization:tool :args01];
    NSLog(@"%@", bootArgs);
    
    // Audio
    bootArgs = @"BootAudio=%00";
    if (bootAudio.state == NSOnState)
        bootArgs = @"BootAudio=%01";
    char *args02[] = { (char*)[bootArgs UTF8String], nil };
    [self runAuthorization:tool :args02];
    
    bootArgs = @"StartupMute=%01";
    if (bootAudio.state == NSOnState)
        bootArgs = @"StartupMute=%00";
    char *args03[] = { (char*)[bootArgs UTF8String], nil };
    [self runAuthorization:tool :args03];
}

- (IBAction)selectImage:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseFiles:YES];
    
    if ([sender isEqual:sellogin])
        [openDlg setAllowedFileTypes:@[@"png", @"jpg"]];
    if ([sender isEqual:selboot])
        [openDlg setAllowedFileTypes:@[@"png"]];
    if ([sender isEqual:sellock])
        [openDlg setAllowedFileTypes:@[@"png", @"jpg", @"gif"]];

    [openDlg beginWithCompletionHandler:^(NSInteger result) {
        if(result==NSModalResponseOK) {
            NSImage * aimage = [[NSImage alloc] initWithContentsOfURL:[openDlg.URLs objectAtIndex:0]];
            if ([sender isEqual:sellogin])
                [loginImageView setImage:aimage];
            if ([sender isEqual:selboot])
                [bootImageView setImage:aimage];
            if ([sender isEqual:sellock]) {
                [lockImageView setImage:aimage];
                lockImageView.path = openDlg.URLs.firstObject.path;
            }
        }
    }];
}

- (void)dirCheck:(NSString *)directory {
    BOOL isDir;
    if(![FileManager fileExistsAtPath:directory isDirectory:&isDir])
        if(![FileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL])
            NSLog(@"Dark Boot : Error : Create folder failed %@", directory);
}

- (IBAction)toggleCustomLockText:(id)sender {
    [Defaults setObject:[NSNumber numberWithBool:[sender state]] forKey:@"custom_text"];
}

- (IBAction)toggleCustomLockSize:(id)sender {
    [Defaults setObject:[NSNumber numberWithBool:[sender state]] forKey:@"custom_size"];
}

- (void)reportIssue {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/w0lfschild/DarkBoot/issues/new"]];
}

- (void)donate {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://goo.gl/DSyEFR"]];
}

- (void)sendEmail {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:support@macenhance.com"]];
}

- (IBAction)sendEmail:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:support@macenhance.com"]];
}
    
- (IBAction)visitDiscord:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://discord.gg/zjCHuew"]];
}
    
@end
