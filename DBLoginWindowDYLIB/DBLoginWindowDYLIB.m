//
//  DBLoginWindowDYLIB.m
//  DBLoginWindowDYLIB
//
//  Created by Wolfgang Baird on 5/28/18.
//

@import AppKit;
#import "FConvenience.h"
#import "DBLoginWindowDYLIB.h"
#import "ZKSwizzle.h"

void install(void) __attribute__ ((constructor));

void redirectConsoleLogToDocumentFolder() {
    NSString *logPath = [@"/Volumes/Macintosh HD/Users/w0lf/Desktop/" stringByAppendingPathComponent:@"console.txt"];
    freopen([logPath fileSystemRepresentation],"a+",stderr);
}

void install() {
    redirectConsoleLogToDocumentFolder();
    
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
    NSLog(@"%@",[dateFormatter stringFromDate:[NSDate date]]);

    
    ZKSwizzle(wb_LUIWindowController, LUIWindowController);
    ZKSwizzle(wb_LUIGoodSamaritanMessageView, LUIGoodSamaritanMessageView);
    ZKSwizzle(wb_Login1, Login1);
    ZKSwizzle(wb_DTDisplay, DTDisplay);
}



@interface DBLoginWindowDYLIB()

@end

@implementation DBLoginWindowDYLIB

+ (instancetype)sharedInstance {
    static DBLoginWindowDYLIB *plugin = nil;
    @synchronized(self) {
        if (!plugin) {
            plugin = [[self alloc] init];
        }
    }
    return plugin;
}

+ (void)load {
    //    DBLoginWindow *plugin = [DBLoginWindow sharedInstance];
    NSUInteger osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], (long)osx_ver);
}


@end

@interface wb_DTDisplay : NSObject
@end

@implementation wb_DTDisplay

- (void)updateDisplay:(unsigned int)arg1 {
    NSLog(@"loginwindow Hookers updateDisplay:%ul", arg1);
    ZKOrig(void, arg1);
}

- (void)transition {
    NSLog(@"loginwindow Hookers transition");
    ZKOrig(void);
}

@end

@interface wb_Login1 : NSObject
@end

@implementation wb_Login1

- (void)do_autologin_check {
    NSLog(@"loginwindow Hookers do_autologin_check");
    ZKOrig(void);
}

- (BOOL)isDarkInstall {
    NSLog(@"loginwindow Hookers isDarkInstall");
    return NO;
}

@end


//ZKSwizzleInterface(wb_LUIWindowController, LUIWindowController, NSObject)
@interface wb_LUIWindowController : NSObject
@end

@implementation wb_LUIWindowController

- (void)setUsesDesktopPicture:(BOOL)arg1 {
    if (db_EnableAnim) {
        ZKOrig(void, false);
        
        NSString *picturePath;
        for (NSString *ext in @[@"jpg", @"png", @"gif"])
            if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
                picturePath = [db_LockFile stringByAppendingPathExtension:ext];
        
        NSWindow *win = [self valueForKey:@"_mainWindow"];
        NSImageView *view = [[NSImageView alloc] initWithFrame:win.contentView.frame];
        NSImage *theImage = [[NSImage alloc] initWithContentsOfFile:picturePath];
        [theImage setSize: NSMakeSize(win.contentView.frame.size.width, win.contentView.frame.size.height)];
        view.image = theImage;
        view.canDrawSubviewsIntoLayer = YES;
        [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        
        if (db_LockAnim) {
            view.imageScaling = NSImageScaleNone;
            view.animates = YES;
            NSView *layerview = [[NSImageView alloc] initWithFrame:win.contentView.frame];
            layerview.wantsLayer = YES;
            [layerview addSubview:view];
            [layerview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [win.contentView setSubviews:@[layerview]];
        } else {
            [win.contentView setSubviews:@[view]];
        }
    } else {
        ZKOrig(void, arg1);
    }
}

@end

//ZKSwizzleInterface(wb_LUIGoodSamaritanMessageView, LUIGoodSamaritanMessageView, NSView)
@interface wb_LUIGoodSamaritanMessageView : NSView
@end

@implementation wb_LUIGoodSamaritanMessageView

- (id)_fontOfSize:(double)arg1 {
    if (db_EnableSize) {
        float lockSize = [db_LockSize floatValue];
        if (lockSize < 0 || lockSize > 64)
            return ZKOrig(id, arg1);
        return ZKOrig(id, lockSize);
    }
    return ZKOrig(id, arg1);
}

- (void)setMessage:(id)arg1 {
    if (db_EnableText) {
        NSString* lockText = db_LockText;
        if ([lockText isEqualToString:@""])
            lockText = @"🍣";
        ZKOrig(void, lockText);
    } else {
        ZKOrig(void, arg1);
    }
}

@end
