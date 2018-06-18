//
//  Created by Wolfgang Baird on 11/23/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

@import LetsMove;
@import CoreImage;
@import SIMBLManager;
@import CoreGraphics;
@import MachO;

#import "DBApplication.h"
#import "FConvenience.h"
#import <SIMBLManager/SIMBLManager.h>
#import <DevMateKit/DevMateKit.h>

#include <sys/stat.h>
#include <unistd.h>
#include <sys/mount.h>

@import AppKit;

static NSString *path_bootImagePlist    = @"/Library/Preferences/SystemConfiguration/com.apple.Boot.plist";
static NSString *path_bootColorPlist    = @"/Library/LaunchDaemons/com.w0lf.dbcolor.plist";
static NSString *path__injectorPlist    = @"/Library/LaunchDaemons/com.w0lf.dblockinjector.plist";
static NSString *path__osxinj           = @"/Library/Caches/DarkBoot/osxinj";
static NSString *path_loginImage        = @"/Library/Caches/com.apple.desktop.admin.png";
static NSString *DBErrorDomain          = @"Dark Boot";

NSArray *tabViewButtons;
NSArray *tabViews;
Boolean *animateBootColor = false;

enum BXErrorCode
{
	BXErrorNone,
	BXErrorCannotGetPNG,
	BXErrorCannotWriteTmpFile,
};

SIMBLManager *sim;
sim_c *simc;
sip_c *sipc;

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
	[self showCurrentImage:self];
    [self showCurrentLock:self];
    [self showCurrentLogin:self];
    [self showCurrentBootColor:self];
	[self setDelegate:(id)self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    lockImagePath = nil;
    
    [DevMateKit sendTrackingReport:nil delegate:nil];
    [DevMateKit setupIssuesController:nil reportingUnhandledIssues:YES];
    
    PFMoveToApplicationsFolderIfNecessary();
    
    sim = [SIMBLManager sharedInstance];
    if (!simc) simc = [[sim_c alloc] initWithWindowNibName:@"sim_c"];
    if (!sipc) sipc = [[sip_c alloc] initWithWindowNibName:@"sip_c"];
    
    [self dirCheck:db_Folder];
    [self setupBundle];
    [self setupDylib];
    
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
    
    [lockTextCustomSize setState:db_EnableSize];
    [lockTextCustomText setState:db_EnableText];

    [mainWindow setMovableByWindowBackground:YES];
    [mainWindow setTitle:@""];
    
    int osx_ver = 9;
    
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)])
        osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    
    if (osx_ver < 10)
    {
        //        _window.centerTrafficLightButtons = false;
        //        _window.showsBaselineSeparator = false;
        //        _window.titleBarHeight = 0.0;
    } else {
        [mainWindow setTitlebarAppearsTransparent:true];
        mainWindow.styleMask |= NSFullSizeContentViewWindowMask;
//        NSRect frame = mainWindow.frame;
//        frame.size.height += 22;
//        [mainWindow setFrame:frame display:true];
    }
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    [appName setStringValue:[infoDict objectForKey:@"CFBundleExecutable"]];
    [appVersion setStringValue:[NSString stringWithFormat:@"Version %@ (%@)",
                                 [infoDict objectForKey:@"CFBundleShortVersionString"],
                                 [infoDict objectForKey:@"CFBundleVersion"]]];
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger year = [components year];

    [appCopyright setStringValue:[NSString stringWithFormat:@"Copyright © 2015 - %ld Wolfgang Baird", (long)year]];
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
    
    _needsSIMBL = false;
    if ([sim AGENT_needsUpdate] || [sim OSAX_needsUpdate]) _needsSIMBL = true;
    
    [self updateAdButton];
    [self tabs_sideBar];
    
    struct statfs output;
    statfs("/", &output);
    if ([[NSString stringWithFormat:@"%s", output.f_fstypename] isEqualToString:@"apfs"]) {
        [viewBootImage setEnabled:NO];
        [viewBootImage setToolTip:@"Requires HFS/HFS+ boot partition"];
    }
    
    tabViews = [NSArray arrayWithObjects:tabBootColor, tabBootImage, tabBootOptions, tabLoginScreen, tabLockScreen, tabAbout, tabPreferences, nil];
    
    [self selectView:viewBootColor];
    [viewBootColor setState:NSOnState];
    
    bootColorIndicator = [[AYProgressIndicator alloc] initWithFrame:NSMakeRect(92, 148, 100, 4)
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
    [bootColorIndicator.layer setCornerRadius:2];
    [tabBootColor addSubview:bootColorIndicator];

    NSColor *bk = [self currentBackgroundColor];
    if (![bk isEqual:NSColor.clearColor]) {
        [bootColorWell setColor:[self currentBackgroundColor]];
        [bootColorView setColor:[[self currentBackgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace]];
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
        [bootColorView setColor:[[NSColor grayColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace]];
        [bootColorWell setColor:[NSColor grayColor]];
        [defColor setState:NSOnState];
    }
    
    [self updateBootColorPreview];
    [self aboutInfo:showChanges];
    [self getBootOptions];
    
    [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(keepThoseAdsFresh) userInfo:nil repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(bootPreviewAnimate) userInfo:nil repeats:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[self deauthorize];
	return NSTerminateNow;
}

- (void)tabs_sideBar {
    NSInteger height = viewBootColor.frame.size.height;
    
    tabViewButtons = [NSArray arrayWithObjects:viewBootColor, viewBootImage, viewBootOptions, viewLoginScreen, viewLockScreen, viewAbout, viewPreferences, nil];
    NSArray *topButtons = [NSArray arrayWithObjects:viewBootColor, viewBootImage, viewBootOptions, viewLoginScreen, viewLockScreen, viewAbout, viewPreferences, nil];
    NSUInteger yLoc = mainWindow.frame.size.height - 22 - height;
    for (NSButton *btn in topButtons) {
        NSRect newFrame = [btn frame];
        newFrame.origin.x = 0;
        newFrame.origin.y = yLoc;
        yLoc -= (height - 1);
        [btn setFrame:newFrame];
        
        if (!(btn.tag == 1234)) {
            NSBox *line = [[NSBox alloc] initWithFrame:CGRectMake(0, 0, btn.frame.size.width, 1)];
            [line setBoxType:NSBoxSeparator];
            [btn addSubview:line];
            NSBox *btm = [[NSBox alloc] initWithFrame:CGRectMake(0, btn.frame.size.height - 1, btn.frame.size.width, 1)];
            [btm setBoxType:NSBoxSeparator];
            [btn addSubview:btm];
            [btn setTag:1234];
        }
        
        [btn setWantsLayer:YES];
        [btn setTarget:self];
    }
    
    for (NSButton *btn in tabViewButtons)
        [btn setAction:@selector(selectView:)];
    
    NSArray *bottomButtons = [NSArray arrayWithObjects:applyButton, donateButton, adButton, feedbackButton, reportButton, nil];
    NSMutableArray *visibleButons = [[NSMutableArray alloc] init];
    for (NSButton *btn in bottomButtons)
        if (![btn isHidden])
            [visibleButons addObject:btn];
    bottomButtons = [visibleButons copy];
    
    yLoc = ([bottomButtons count] - 1) * (height - 1);
    for (NSButton *btn in bottomButtons) {
        NSRect newFrame = [btn frame];
        newFrame.origin.x = 0;
        newFrame.origin.y = yLoc;
        yLoc -= (height - 1);
        [btn setFrame:newFrame];
        
        if (!(btn.tag == 1234)) {
            NSBox *line = [[NSBox alloc] initWithFrame:CGRectMake(0, 0, btn.frame.size.width, 1)];
            [line setBoxType:NSBoxSeparator];
            [btn addSubview:line];
            NSBox *btm = [[NSBox alloc] initWithFrame:CGRectMake(0, btn.frame.size.height - 1, btn.frame.size.width, 1)];
            [btm setBoxType:NSBoxSeparator];
            [btn addSubview:btm];
            [btn setTag:1234];
        }
        
        [btn setWantsLayer:YES];
        //        [btn.layer setBackgroundColor:[NSColor colorWithCalibratedRed:80/255.0 green:80/255.0 blue:150/255.0 alpha:0.25f].CGColor];
        //        [btn.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.1f green:0.1f blue:0.1f alpha:0.25f].CGColor];
    }
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
    if (db_EnableAnim) {
        NSString *filePath;
        for (NSString *ext in @[@"jpg", @"png", @"gif"]) {
            if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
                filePath = [db_LockFile stringByAppendingPathExtension:ext];
        }
        img = [[NSImage alloc] initWithContentsOfFile:filePath];
        lockImageView.path = filePath;
        if (img == nil) return [self blurImage:[self defaultLoginImage] :25.0];
    } else {
        img = [self blurImage:[self defaultLoginImage] :25.0];
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

- (IBAction)showCurrentBootColor:(id)sender {
    if (![[self currentBackgroundColor] isEqual:NSColor.clearColor]) {
        [bootColorView setColor:[[self currentBackgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace]];
    } else {
        [bootColorView setColor:[self defaultBootColor]];
    }
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
    theImage = [self blurImage:theImage :25.0];
    [theImage setSize: NSMakeSize(loginImageView.frame.size.width, loginImageView.frame.size.height)];
    loginImageView.image = theImage;
}

- (IBAction)showCurrentLogin:(id)sender {
    NSImage *theImage = [self currentLoginImage];
    [theImage setSize: NSMakeSize(loginImageView.frame.size.width, loginImageView.frame.size.height)];
    loginImageView.image = theImage;
    loginImageView.animates = YES;
    loginImageView.canDrawSubviewsIntoLayer = YES;
}

- (NSImage*)blurImage:(NSImage*)input :(float)radius {
    CIImage *imageToBlur = [CIImage imageWithData:[input TIFFRepresentation]];
    CIFilter *gaussianBlurFilter = [CIFilter filterWithName: @"CIGaussianBlur"];
    [gaussianBlurFilter setValue:imageToBlur forKey:kCIInputImageKey];
    [gaussianBlurFilter setValue:[NSNumber numberWithFloat:radius] forKey: @"inputRadius"];
    
    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:[gaussianBlurFilter valueForKey:kCIOutputImageKey]];
    NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
    [nsImage addRepresentation:rep];
    return nsImage;
}

- (IBAction)showDefaultLock:(id)sender {
    NSImage *theImage = [self defaultLoginImage];
    theImage = [self blurImage:theImage :25.0];
//    CIImage *imageToBlur = [CIImage imageWithData:[theImage TIFFRepresentation]];
//    CIFilter *gaussianBlurFilter = [CIFilter filterWithName: @"CIGaussianBlur"];
//    [gaussianBlurFilter setValue:imageToBlur forKey:kCIInputImageKey];
//    [gaussianBlurFilter setValue:[NSNumber numberWithFloat: 25.0] forKey: @"inputRadius"];
//
//    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:[gaussianBlurFilter valueForKey:kCIOutputImageKey]];
//    NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
//    [nsImage addRepresentation:rep];
//    theImage = nsImage;
    
    [theImage setSize: NSMakeSize(loginImageView.frame.size.width, loginImageView.frame.size.height)];
    lockImageView.image = theImage;
}

- (IBAction)showCurrentLock:(id)sender {
    NSImage *theImage = [self currentLockImage];
    [theImage setSize: NSMakeSize(lockImageView.frame.size.width, lockImageView.frame.size.height)];
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
//            NSLog(@"r%ld g%ld b%ld", r, g, b);
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
    NSString* BXPlist = [[NSBundle mainBundle] pathForResource:@"com.w0lf.dbcolor" ofType:@"plist"];
    
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
    
    system("launchctl unload /Library/LaunchDaemons/com.w0lf.dbcolor.plist");
    system("launchctl load /Library/LaunchDaemons/com.w0lf.dbcolor.plist");
}

- (void)installLockImage:(NSImage*)img {
    NSData *imageData = [img TIFFRepresentation];
    NSData *loginData = [[self blurImage:[self defaultLoginImage] :25.0] TIFFRepresentation];
    
    if ([imageData isEqualToData:loginData]) {
        [Defaults setObject:[NSNumber numberWithBool:false] forKey:@"custom_anim"];
    } else {
        [Defaults setObject:[NSNumber numberWithBool:true] forKey:@"custom_anim"];

        if ([FileManager isReadableFileAtPath:lockImageView.path]) {
            
            NSLog(@"%@", lockImageView.path);
            
            NSString *ext = lockImageView.path.pathExtension;

            for (NSString *ext in @[@"jpg", @"png", @"gif"]) {
                if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
                    if (![[db_LockFile stringByAppendingPathExtension:ext] isEqualToString:lockImageView.path])
                        [FileManager removeItemAtPath:[db_LockFile stringByAppendingPathExtension:ext] error:nil];
            }

            NSError *err;
            [FileManager copyItemAtURL:[NSURL fileURLWithPath:lockImageView.path]
                                                    toURL:[NSURL fileURLWithPath:[db_LockFile stringByAppendingPathExtension:ext]]
                                                    error:&err];
            if (err != nil)
                NSLog(@"%@", err);
        } else {
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
        [img drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
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
    system("launchctl unload /Library/LaunchDaemons/com.w0lf.dbcolor.plist");
    [bootColorWell setColor:[NSColor grayColor]];
}

- (void)bootPreviewAnimate {
    if (animateBootColor) {
        double displayNum = bootColorIndicator.doubleValue;
        if (displayNum < 100.0) {
            displayNum += ((double)rand() / RAND_MAX) * 2;
            [bootColorIndicator setDoubleValue:displayNum - 2];
        } else {
            displayNum = 0;
        }
        [bootColorIndicator setDoubleValue:displayNum];
    }
//    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
//        [context setDuration:1.25];
//        [[bootColorIndicator animator] setDoubleValue:displayNum];
//    } completionHandler:^{
//    }];
}

- (void)updateBootColorPreview {
    NSColor *activeColor = nil;
    if (clrColor.state == NSOnState)
        activeColor = [bootColorWell.color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (defColor.state == NSOnState)
        activeColor = [[self defaultBootColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (gryColor.state == NSOnState)
        activeColor = [NSColor.grayColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    if (blkColor.state == NSOnState)
        activeColor = [NSColor.blackColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    [bootColorView setColor:activeColor];

    NSImage *drawnImage = nil;
    if ([self useDarkColors:activeColor]) {
        drawnImage = [self imageTintedWithColor:bootColorApple.image :[NSColor whiteColor]];
        [bootColorIndicator setEmptyColor:[NSColor blackColor]];
        [bootColorIndicator setProgressColor:[NSColor whiteColor]];
    } else {
        drawnImage = [self imageTintedWithColor:bootColorApple.image :[NSColor blackColor]];
        [bootColorIndicator setEmptyColor:[NSColor whiteColor]];
        [bootColorIndicator setProgressColor:[NSColor blackColor]];
    }
    
    if (clrColor.state == NSOnState) {
        if ([self colorCompare:bootColorWell.color :NSColor.blackColor]) {
            [bootColorIndicator setEmptyColor:[NSColor grayColor]];
            [bootColorIndicator setProgressColor:[NSColor whiteColor]];
        }
        
        if ([self colorCompare:bootColorWell.color :NSColor.whiteColor]) {
            [bootColorIndicator setEmptyColor:[NSColor blackColor]];
            [bootColorIndicator setProgressColor:[NSColor grayColor]];
        }
    }
    
    if (blkColor.state == NSOnState) {
        [bootColorIndicator setEmptyColor:[NSColor grayColor]];
        [bootColorIndicator setProgressColor:[NSColor whiteColor]];
    }
    
    if (activeColor)
    
    [bootColorApple setImage:drawnImage];
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
        NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop);
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

- (IBAction)colorRadioButton:(id)sender {
    [self updateBootColorPreview];
}

- (void)setupDarkBoot {
    if ([defColor state] == NSOnState) {
        if ([FileManager fileExistsAtPath:path_bootColorPlist])
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
    
    if ([sender isEqualTo:viewBootColor]) {
        animateBootColor = true;
    } else {
        animateBootColor = false;
    }
    
    if ([sender isEqualTo:viewBootImage]) {
        Boolean SIPStatus = [sim SIP_enabled];
        if (SIPStatus) {
            NSTextView *blocked = [[NSTextView alloc] initWithFrame:tabLockScreen.frame];
            blocked.alignment = NSCenterTextAlignment;
            [blocked setBackgroundColor:NSColor.clearColor];
            [blocked setString:@"\n\n\n\n\n⚠️ Editing this requires System Integrity Protection to be disabled! ⚠️"];
            [tabMain setSubviews:@[blocked]];
            [sipc displayInWindow:mainWindow];
        }
    }
    
    if ([sender isEqualTo:viewLockScreen]) {
        if (_needsSIMBL) {
            Boolean SIPStatus = [sim SIP_enabled];
            Boolean needsUpdate = false;
            Boolean systemUpdate = false;
            
            if ([sim AGENT_needsUpdate])
                needsUpdate = true;
            
            if ([sim OSAX_needsUpdate]) {
                needsUpdate = true;
                systemUpdate = true;
            }
            
            if (systemUpdate) {
                NSTextView *blocked = [[NSTextView alloc] initWithFrame:tabLockScreen.frame];
                blocked.alignment = NSCenterTextAlignment;
                [blocked setBackgroundColor:NSColor.clearColor];
                [blocked setString:@"\n\n\n\n\n* Requires system component installation\n\
                 * Initial install requires SIP to be disabled\n\
                 * Applies instantly\n\
                 * Image must be .png / .jpg / .gif format"];
                [tabMain setSubviews:@[blocked]];
                
                if (SIPStatus)
                    [sipc displayInWindow:mainWindow];
                else
                    [simc displayInWindow:mainWindow];
            } else {
                [simc displayInWindow:mainWindow];
            }
        }
    }
}

- (IBAction)aboutInfo:(id)sender {
    if ([sender isEqualTo:showChanges]) {
        [changeLog setEditable:true];
        [[changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Changelog" ofType:@"rtf"] documentAttributes:nil]];
        [changeLog selectAll:self];
        [changeLog alignLeft:nil];
        [changeLog setSelectedRange:NSMakeRange(0,0)];
        [changeLog setEditable:false];
        
        [NSAnimationContext beginGrouping];
        NSClipView* clipView = [[changeLog enclosingScrollView] contentView];
        NSPoint newOrigin = [clipView bounds].origin;
        newOrigin.y = 0;
        [[clipView animator] setBoundsOrigin:newOrigin];
        [NSAnimationContext endGrouping];
    }
    if ([sender isEqualTo:showCredits]) {
        [changeLog setEditable:true];
        [[changeLog textStorage] setAttributedString:[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:nil]];
        [changeLog selectAll:self];
        [changeLog alignCenter:nil];
        [changeLog setSelectedRange:NSMakeRange(0,0)];
        [changeLog setEditable:false];
    }
    if ([sender isEqualTo:showEULA]) {
        NSMutableAttributedString *mutableAttString = [[NSMutableAttributedString alloc] init];
//        NSArray *licenseFiles = [[NSArray alloc] initWithObjects:@"", nil];
//
        NSAttributedString *newAttString = nil;
//
//        for (NSString *str in licenseFiles) {
//            NSString *fileName = [NSString stringWithFormat:@"%@_LICENSE", str];
//            newAttString = [[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:fileName ofType:@"txt"] documentAttributes:nil];
//            [mutableAttString appendAttributedString:newAttString];
//        }
        
        newAttString = [[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"EULA" ofType:@"rtf"] documentAttributes:nil];
        [mutableAttString appendAttributedString:newAttString];
        
        [[changeLog textStorage] setAttributedString:mutableAttString];
        
        [NSAnimationContext beginGrouping];
        NSClipView* clipView = [[changeLog enclosingScrollView] contentView];
        NSPoint newOrigin = [clipView bounds].origin;
        newOrigin.y = 0;
        [[clipView animator] setBoundsOrigin:newOrigin];
        [NSAnimationContext endGrouping];
    }
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    if (![mainWindow.appearance.name isEqualToString:NSAppearanceNameAqua]) {
        if ([osxMode isEqualToString:@"Dark"]) {
            [changeLog setTextColor:[NSColor whiteColor]];
        } else {
            [changeLog setTextColor:[NSColor blackColor]];
        }
    }
}

- (void)getBootOptions {
    NSString *bootArgs = [self runCommand:@"nvram -p | grep boot-args"];
    bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if (bootArgs.length > 10) bootArgs = [bootArgs substringFromIndex:10];
    NSLog(@"%@", bootArgs);
    bootAMFI.state = [bootArgs containsString:@"amfi_get_out_of_my_way=1"];
    bootCamshell.state = [bootArgs containsString:@"iog=0x0"];
    bootVerbose.state = [bootArgs containsString:@"-v"];
    bootSingle.state = [bootArgs containsString:@"-s"];
    bootSafe.state = [bootArgs containsString:@"-x"];
    
    bootArgs = [self runCommand:@"nvram -p | grep AutoBoot"];
    bootAudio.state = [bootArgs containsString:@"%03"];
    
    bootArgs = [self runCommand:@"nvram -p | grep BootAudio"];
    bootAuto.state = [bootArgs containsString:@"%01"];
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
    NSLog(@"%@", bootArgs);
    
    Boolean *currentArg = false;
    
    // AMFI
    currentArg = [bootArgs containsString:@"amfi_get_out_of_my_way=1"];
    if (bootAMFI.state == NSOnState) {
        if (!currentArg) bootArgs = [NSString stringWithFormat:@"%@ amfi_get_out_of_my_way=1", bootArgs];
    } else {
        if (currentArg) bootArgs = [bootArgs stringByReplacingOccurrencesOfString:@"amfi_get_out_of_my_way=1" withString:@""];
    }
    
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
    bootArgs = [self runCommand:@"nvram -p | grep BootAudio"];
    currentArg = [bootArgs containsString:@"%01"];
    if (bootAudio.state == NSOnState) {
        bootArgs = @"BootAudio=%01";
    } else {
        bootArgs = @"BootAudio=%00";
    }
    char *args02[] = { (char*)[bootArgs UTF8String], nil };
    [self runAuthorization:tool :args02];
    NSLog(@"%@", bootArgs);
    
    /*
     sudo nvram AutoBoot=%00    no auto
     sudo nvram AutoBoot=%03
     
     sudo nvram BootAudio=%00   no audio
     sudo nvram BootAudio=%01
     
     sudo nvram boot-args="-v"  verbose
     
     sudo nvram boot-args="-x"  safe
     
     sudo nvram boot-args="-s"  single
     */
    
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
        if(result==NSFileHandlingPanelOKButton) {
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

- (void)mergeContentsOfPath:(NSString *)srcDir intoPath:(NSString *)dstDir error:(NSError**)err {
    
    NSLog(@"- mergeContentsOfPath: %@\n intoPath: %@", srcDir, dstDir);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *srcDirEnum = [fm enumeratorAtPath:srcDir];
    NSString *subPath;
    while ((subPath = [srcDirEnum nextObject])) {
        
        NSLog(@" subPath: %@", subPath);
        NSString *srcFullPath =  [srcDir stringByAppendingPathComponent:subPath];
        NSString *potentialDstPath = [dstDir stringByAppendingPathComponent:subPath];
        
        // Need to also check if file exists because if it doesn't, value of `isDirectory` is undefined.
        BOOL isDirectory = ([[NSFileManager defaultManager] fileExistsAtPath:srcFullPath isDirectory:&isDirectory] && isDirectory);
        
        // Create directory, or delete existing file and move file to destination
        if (isDirectory) {
            NSLog(@"   create directory");
            [fm createDirectoryAtPath:potentialDstPath withIntermediateDirectories:YES attributes:nil error:err];
            if (err && *err) {
                NSLog(@"ERROR: %@", *err);
                return;
            }
        }
        else {
            if ([fm fileExistsAtPath:potentialDstPath]) {
                NSLog(@"   removeItemAtPath");
                [fm removeItemAtPath:potentialDstPath error:err];
                if (err && *err) {
                    NSLog(@"ERROR: %@", *err);
                    return;
                }
            }
            
            NSLog(@"   copyItemAtPath");
//            [fm moveItemAtPath:srcFullPath toPath:potentialDstPath error:err];
            [fm copyItemAtPath:srcFullPath toPath:potentialDstPath error:err];
            if (err && *err) {
                NSLog(@"ERROR: %@", *err);
                return;
            }
        }
    }
}

- (void)setupDylib {
    [self dirCheck:@"/Library/Caches/DarkBoot"];
    
    if (![FileManager fileExistsAtPath:path__injectorPlist]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"com.w0lf.dblockinjector"
                                                                                                                      ofType:@"plist"]];
        [dict writeToFile:@"/tmp/com.w0lf.dblockinjector.plist" atomically:YES];
        [self authorize];
        
        char *tool = "/bin/mv";
        char *args0[] = { "-f", "/tmp/com.w0lf.dblockinjector.plist", (char*)[path__injectorPlist UTF8String], nil };
        [self runAuthorization:tool :args0];
        
        tool = "/usr/sbin/chown";
        char *args1[] = { "root:admin", (char*)[path__injectorPlist UTF8String], nil };
        [self runAuthorization:tool :args1];
        
        system("launchctl unload /Library/LaunchDaemons/com.w0lf.dblockinjector.plist");
        system("launchctl load /Library/LaunchDaemons/com.w0lf.dblockinjector.plist");
    }
    
    NSError *error;
    [self mergeContentsOfPath:[[NSBundle mainBundle] pathForResource:@"osxinj" ofType:@""] intoPath:@"/Library/Caches/DarkBoot" error:&error];
}

- (void)setupBundle {
    // Directory check
//    [self dirCheck:@"/Library/Application Support/SIMBL/Plugins/"];
//    
//    NSError *error;
//    NSString *srcPath = [[NSBundle mainBundle] pathForResource:@"DBLoginWindow" ofType:@"bundle"];
//    NSString *dstPath = @"/Library/Application Support/SIMBL/Plugins/DBLoginWindow.bundle";
//    NSString *srcBndl = [[NSBundle mainBundle] pathForResource:@"DBLoginWindow.bundle/Contents/Info" ofType:@"plist"];
//    NSString *dstBndl = @"/Library/Application Support/SIMBL/Plugins/DBLoginWindow.bundle/Contents/Info.plist";
//    
//    DLog(@"Dark Boot : Checking bundle...");
//    if ([FileManager fileExistsAtPath:dstBndl]){
//        NSString *srcVer = [[[NSMutableDictionary alloc] initWithContentsOfFile:srcBndl] objectForKey:@"CFBundleVersion"];
//        NSString *dstVer = [[[NSMutableDictionary alloc] initWithContentsOfFile:dstBndl] objectForKey:@"CFBundleVersion"];
//        if (![srcVer isEqual:dstVer] && ![srcPath isEqualToString:@""]) {
//            DLog(@"Dark Boot : Updating bundle... Destination: %@ > Source: %@", srcVer, dstVer);
//            [FileManager removeItemAtPath:@"/tmp/DBLoginWindow.bundle" error:&error];
//            [FileManager copyItemAtPath:srcPath toPath:@"/tmp/DBLoginWindow.bundle" error:&error];
//            [FileManager replaceItemAtURL:[NSURL fileURLWithPath:dstPath] withItemAtURL:[NSURL fileURLWithPath:@"/tmp/DBLoginWindow.bundle"] backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:nil error:&error];
//        } else {
//            DLog(@"Dark Boot : Bundle is up to date...");
//        }
//    } else {
//        DLog(@"Dark Boot : Installing bundle... %@", srcPath);
//        [FileManager copyItemAtPath:srcPath toPath:dstPath error:&error];
//    }
}


- (IBAction)toggleCustomLockText:(id)sender {
    [Defaults setObject:[NSNumber numberWithBool:[sender state]] forKey:@"custom_text"];
}

- (IBAction)toggleCustomLockSize:(id)sender {
    [Defaults setObject:[NSNumber numberWithBool:[sender state]] forKey:@"custom_size"];
}

- (IBAction)showFeedbackDialog:(id)sender {
    [DevMateKit showFeedbackDialog:nil inMode:DMFeedbackIndependentMode];
}

- (void)keepThoseAdsFresh {
    if (_adArray != nil) {
        if (!adButton.hidden) {
            NSInteger arraySize = _adArray.count;
            NSInteger displayNum = (NSInteger)arc4random_uniform((int)[_adArray count]);
            if (displayNum == _lastAD) {
                displayNum++;
                if (displayNum >= arraySize)
                    displayNum -= 2;
                if (displayNum < 0)
                    displayNum = 0;
            }
            _lastAD = displayNum;
            NSDictionary *dic = [_adArray objectAtIndex:displayNum];
            NSString *name = [dic objectForKey:@"name"];
            name = [NSString stringWithFormat:@"%@", name];
            NSString *url = [dic objectForKey:@"homepage"];
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:1.25];
                [[adButton animator] setTitle:name];
            } completionHandler:^{
            }];
            if (url)
                _adURL = url;
            else
                _adURL = @"https://w0lfschild.github.io/app_cDock.html";
        }
    }
}

- (void)updateAdButton {
    // Local ads
    NSArray *dict = [[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ads" ofType:@"plist"]];
    NSInteger displayNum = (NSInteger)arc4random_uniform((int)[dict count]);
    NSDictionary *dic = [dict objectAtIndex:displayNum];
    NSString *name = [dic objectForKey:@"name"];
    name = [NSString stringWithFormat:@"%@", name];
    NSString *url = [dic objectForKey:@"homepage"];
    
    [adButton setTitle:name];
    if (url)
        _adURL = url;
    else
        _adURL = @"https://w0lfschild.github.io/app_cDock.html";
    
    _adArray = dict;
    _lastAD = displayNum;
    
    // Check web for new ads
    dispatch_queue_t queue = dispatch_queue_create("com.yourdomain.yourappname", NULL);
    dispatch_async(queue, ^{
        //code to be executed in the background
        
        NSURL *installURL = [NSURL URLWithString:@"https://github.com/w0lfschild/app_updates/raw/master/DarkBoot/ads.plist"];
        NSURLRequest *request = [NSURLRequest requestWithURL:installURL];
        NSError *error;
        NSURLResponse *response;
        NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if (!result) {
            // Download failed
            DLog(@"Dark Boot : Error");
        } else {
            NSPropertyListFormat format;
            NSError *err;
            NSArray *dict = (NSArray*)[NSPropertyListSerialization propertyListWithData:result
                                                                                options:NSPropertyListMutableContainersAndLeaves
                                                                                 format:&format
                                                                                  error:&err];
            DLog(@"Dark Boot : %@", dict);
            if (dict) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    //code to be executed on the main thread when background task is finished
                    
                    NSInteger displayNum = (NSInteger)arc4random_uniform((int)[dict count]);
                    NSDictionary *dic = [dict objectAtIndex:displayNum];
                    NSString *name = [dic objectForKey:@"name"];
                    name = [NSString stringWithFormat:@"%@", name];
                    NSString *url = [dic objectForKey:@"homepage"];
                    
                    [adButton setTitle:name];
                    if (url)
                        _adURL = url;
                    else
                        _adURL = @"https://w0lfschild.github.io/app_cDock.html";
                    
                    _adArray = dict;
                    _lastAD = displayNum;
                });
            }
        }
    });
}

- (IBAction)visit_ad:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_adURL]];
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
    
