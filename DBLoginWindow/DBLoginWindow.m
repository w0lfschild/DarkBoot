//
//  DBLoginWindow.m
//  DBLoginWindow
//
//  Created by Wolfgang Baird on 5/19/18.
//
//

#import "DBLoginWindow.h"
#import "FConvenience.h"
#import <WebKit/WebKit.h>

@interface DBLoginWindow()

@end

@implementation DBLoginWindow

+ (instancetype)sharedInstance {
    static DBLoginWindow *plugin = nil;
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

ZKSwizzleInterface(wb_LUIWindowController, LUIWindowController, NSObject)
@implementation wb_LUIWindowController

- (void)getcDock {
//    NSWindow *win = [self valueForKey:@"_mainWindow"];
//
//    NSWindow *poopbutt = [[NSWindow alloc] init];
//    [poopbutt setFrame:CGRectMake(50, 50, 500, 500) display:YES];
//    [poopbutt setLevel:NSMainMenuWindowLevel + 2];
//
//    WebView *web = [[WebView alloc] initWithFrame:win.contentView.frame];
//    [web.mainFrame loadRequest:[NSURLRequest.alloc initWithURL:[NSURL.alloc initWithString:@"https://pay.paddle.com/checkout/520974"]]];
//    [poopbutt.contentView addSubview:web];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://pay.paddle.com/checkout/520974"]];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://w0lfschild.github.io/app_cDock.html"]];
}

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
        
//        NSButton *adButton = [[NSButton alloc] initWithFrame:NSMakeRect(win.contentView.frame.size.width - 160, 10, 150, 22)];
//        [adButton setTitle:@"🍭 Try cDock"];
//        [adButton setBezelStyle:NSTexturedRoundedBezelStyle];
//        [adButton setTarget:self];
//        [adButton setAction:@selector(getcDock)];
        
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

ZKSwizzleInterface(wb_LUIGoodSamaritanMessageView, LUIGoodSamaritanMessageView, NSView)
@implementation wb_LUIGoodSamaritanMessageView

- (id)_fontOfSize:(double)arg1 {
    if (db_EnableSize) {
        double lockSize = [db_LockSize doubleValue];
//        NSLog(@"kaydog %f", lockSize);
        if (lockSize < 0.0 || lockSize > 64.0)
            return ZKOrig(id, arg1);
        return ZKOrig(id, lockSize);
    }
    return ZKOrig(id, arg1);
}

- (void)setMessage:(id)arg1 {
    if (db_EnableText) {
        NSString* lockText = db_LockText;
//        NSLog(@"kaydog %@", lockText);
        if ([lockText isEqualToString:@""])
            lockText = @"🍣";
        ZKOrig(void, lockText);
    } else {
        ZKOrig(void, arg1);
    }
}

@end
