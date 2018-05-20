//
//  DBLoginWindow.m
//  DBLoginWindow
//
//  Created by Wolfgang Baird on 5/19/18.
//
//

#import "DBLoginWindow.h"

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
    DBLoginWindow *plugin = [DBLoginWindow sharedInstance];
    NSUInteger osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], (long)osx_ver);
}


@end

ZKSwizzleInterface(wb_LUIWindowController, LUIWindowController, NSObject)
@implementation wb_LUIWindowController

- (void)setUsesDesktopPicture:(BOOL)arg1 {
    ZKOrig(void, false);
    NSLog(@"wbtest : setUsesDesktopPicture : %hhd", arg1);
    
    NSWindow *win = [self valueForKey:@"_mainWindow"];
    
    NSImageView *view = [[NSImageView alloc] initWithFrame:win.contentView.frame];
    view.imageScaling = NSImageScaleNone;
    view.animates = YES;
    
    NSImage *theImage = [[NSImage alloc] initWithContentsOfFile:@"/Users/w0lf/Desktop/0.gif"];
    [theImage setSize: NSMakeSize(win.contentView.frame.size.width, win.contentView.frame.size.height)];
    
    view.image = theImage;
    view.canDrawSubviewsIntoLayer = YES;
    [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    NSView *layerview = [[NSImageView alloc] initWithFrame:win.contentView.frame];
    layerview.wantsLayer = YES;
    [layerview addSubview:view];
    [layerview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    [win.contentView setSubviews:@[layerview]];
    
    //    NSImage *background = [[NSImage alloc] initWithContentsOfFile:@"/Library/Desktop Pictures/Abstract.jpg"];
    //    [background setSize:NSScreen.mainScreen.frame.size];
    //    NSWindow *win = [self valueForKey:@"_mainWindow"];
    //    NSImageView *im = [[NSImageView alloc] initWithFrame:win.contentView.frame];
    //    [im setImage:background];
    //    [im setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    //    [win.contentView setSubviews:@[im]];
    
    NSLog(@"wbtest : setUsesDesktopPicture : %@", win);
}

@end

ZKSwizzleInterface(wb_LUIGoodSamaritanMessageView, LUIGoodSamaritanMessageView, NSView)
@implementation wb_LUIGoodSamaritanMessageView

- (id)_fontOfSize:(double)arg1 {
    return ZKOrig(id, 64.0);
}

- (void)setMessage:(id)arg1 {
    ZKOrig(void, @"🍣🍣🍣🍣🍣🍣");
}

@end
