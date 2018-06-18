//
//  DBLoginWindowDYLIB.m
//  DBLoginWindowDYLIB
//
//  Created by Wolfgang Baird on 5/28/18.
//

@import AppKit;
#import "FConvenience.h"
#import "ZKSwizzle.h"
#import <objc/runtime.h>

@interface DBLoginWindowDYLIB : NSObject
@end

void install(void) __attribute__ ((constructor));

void redirectConsoleLogToDocumentFolder() {
    system("touch /tmp/BDLoginWindow.log");
    freopen([@"/tmp/BDLoginWindow.log" fileSystemRepresentation],"a+",stderr);
}

void install() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        redirectConsoleLogToDocumentFolder();
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSLog(@"%@",[dateFormatter stringFromDate:[NSDate date]]);
        NSUInteger osx_ver = NSProcessInfo.processInfo.operatingSystemVersion.minorVersion;
        if (osx_ver < 14) {
            ZKSwizzle(wb_LUIWindowController, LUIWindowController);
            ZKSwizzle(wb_LUIGoodSamaritanMessageView, LUIGoodSamaritanMessageView);
        } else {
            ZKSwizzle(wb_LUI2Window, LUI2Window);
            ZKSwizzle(wb_LUI2MessageViewController, LUI2MessageViewController);
        }
        NSLog(@"%@ loaded into %@ on macOS 10.%ld", [DBLoginWindowDYLIB class], [[NSBundle mainBundle] bundleIdentifier], (long)osx_ver);
    });
}

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
    install();
}

- (void)setupLockBG:(NSWindow*)win {
    NSString *picturePath;
    for (NSString *ext in @[@"jpg", @"png", @"gif"])
        if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
            picturePath = [db_LockFile stringByAppendingPathExtension:ext];
    
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
}

@end

// 10.14

@interface wb_LUI2Window : NSWindow
@end

@implementation wb_LUI2Window

- (void)_setupContentView {
    if (db_EnableAnim) {
        ZKOrig(void);
        [[DBLoginWindowDYLIB sharedInstance] setupLockBG:self];
    } else {
        ZKOrig(void);
    }
}

@end

@interface wb_LUI2MessageViewController : NSViewController
@end

@implementation wb_LUI2MessageViewController

-  (void)textStorage:(id)arg1 didProcessEditing:(unsigned long long)arg2 range:(struct _NSRange)arg3 changeInLength:(long long)arg4 {
    NSTextStorage *t = arg1;
    if (db_EnableSize) {
        double lockSize = [db_LockSize doubleValue];
        [t setFont:[NSFont fontWithDescriptor:t.font.fontDescriptor size:lockSize]];
    }
    ZKOrig(void, t, arg2, arg3, arg4);
}

- (void)viewDidAppear {
    if (db_EnableText) {
        NSTextView *tv = [self valueForKey:@"messageTextView"];
        NSString* lockText = db_LockText;
        if ([lockText isEqualToString:@""])
            lockText = @"🍣";
        tv.string = lockText;
    }
    ZKOrig(void);
}

@end

// 10.10 - 10.13

@interface wb_LUIWindowController : NSObject
@end

@implementation wb_LUIWindowController

- (void)setUsesDesktopPicture:(BOOL)arg1 {
    if (db_EnableAnim) {
        ZKOrig(void, false);
        [[DBLoginWindowDYLIB sharedInstance] setupLockBG:[self valueForKey:@"_mainWindow"]];
    } else {
        ZKOrig(void, arg1);
    }
}

@end

@interface wb_LUIGoodSamaritanMessageView : NSView
@end

@implementation wb_LUIGoodSamaritanMessageView

- (id)_fontOfSize:(double)arg1 {
    if (db_EnableSize) {
        double lockSize = [db_LockSize doubleValue];
        if (lockSize < 0.0 || lockSize > 64.0)
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
