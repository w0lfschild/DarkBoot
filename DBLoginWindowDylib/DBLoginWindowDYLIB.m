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
#import <objc/runtime.h>

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

    NSUInteger osx_ver = NSProcessInfo.processInfo.operatingSystemVersion.minorVersion;
    if (osx_ver < 14) {
        ZKSwizzle(wb_LUIWindowController, LUIWindowController);
        ZKSwizzle(wb_LUIGoodSamaritanMessageView, LUIGoodSamaritanMessageView);
    } else {
        ZKSwizzle(wb_LUI2Window, LUI2Window);
//        ZKSwizzle(wb_LUI2TextField, LUI2TextField);
        ZKSwizzle(wb_LUI2MessageViewController, LUI2MessageViewController);
//        ZKSwizzle(wb_NSTextView, NSTextView);
    }
    
    ZKSwizzle(wb_Login1, Login1);
    ZKSwizzle(wb_DTDisplay, DTDisplay);
}

@interface NSObject (logProperties)
- (void) logProperties;
@end

@implementation NSObject (logProperties)

- (void)logProperties {
    
    NSLog(@"----------------------------------------------- Properties for object %@", self);
    
    @autoreleasepool {
        unsigned int numberOfProperties = 0;
        objc_property_t *propertyArray = class_copyPropertyList([self class], &numberOfProperties);
        for (NSUInteger i = 0; i < numberOfProperties; i++) {
            @try {
                objc_property_t property = propertyArray[i];
                NSString *name = [[NSString alloc] initWithUTF8String:property_getName(property)];
                NSLog(@"Property %@ Value: %@", name, [self valueForKey:name]);
            }
            @catch (NSException *exception) {
                NSLog(@"%@", exception.reason);
            }
            @finally {
                NSLog(@"Hmmm Fail...");
            }
        }
        free(propertyArray);
    }
    NSLog(@"-----------------------------------------------");
}

@end

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
    install();
    NSUInteger osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], (long)osx_ver);
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


@interface wb_LWDefaultScreenLockUI : NSObject
@end

@implementation wb_LWDefaultScreenLockUI

@end


@interface wb_NSWindowController : NSWindowController
@end

@implementation wb_NSWindowController

- (void)showWindow:(id)sender {
    ZKOrig(void, sender);
    
    NSLog(@"windowDidLoad %@ : %@", self.className, self.window.className);
}

- (void)windowWillLoad {
    ZKOrig(void);
    
    NSLog(@"windowDidLoad %@ : %@", self.className, self.window.className);
}

@end

@interface wb_NSViewController : NSViewController
@end

@implementation wb_NSViewController

- (void)setMessage:(id)arg1 {
    NSLog(@"Hookers %@ : %@", [self className], arg1);    
    ZKOrig(void, arg1);
}

- (void)viewDidAppear {
    ZKOrig(void);
    
    NSLog(@"viewDidAppear %@ : %@", self.className, self.view.className);
    
    @try {
        NSLog(@"Contentview: %@", [self.view valueForKey:@"contentView"]);
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
    }
    @finally {
        NSLog(@"Hmmm Fail...");
    }
    
    if ([[self className] isEqualToString:@"LUI2BackgroundViewController"]) {
        NSLog(@"Hello sir : %@", [self className]);
        if (db_EnableAnim) {
            NSLog(@"We're in sir : %@", [self className]);
            NSString *picturePath;
            for (NSString *ext in @[@"jpg", @"png", @"gif"])
                if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
                    picturePath = [db_LockFile stringByAppendingPathExtension:ext];
            
            NSView *theView = self.view;
            
            [self.view logProperties];
            
            NSImageView *view = [[NSImageView alloc] initWithFrame:theView.frame];
            NSImage *theImage = [[NSImage alloc] initWithContentsOfFile:picturePath];
            [theImage setSize: NSMakeSize(theView.frame.size.width, theView.frame.size.height)];
            view.image = theImage;
            view.canDrawSubviewsIntoLayer = YES;
            [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            
//            Boolean addView = true;
//            for (NSView *v in self.view.subviews) {
//                if (v.tag == 69) {
//                    addView = false;
//                    break;
//                }
//            }
//            
//            if (addView) {
//                NSMutableArray *viewz = theView.subviews.mutableCopy;
//                [view setTag:69];
//                [viewz addObject:view];
//                [theView setSubviews:viewz];
//            }
            
            if (db_LockAnim) {
                view.imageScaling = NSImageScaleNone;
                view.animates = YES;
//                NSView *layerview = [[NSImageView alloc] initWithFrame:win.contentView.frame];
//                layerview.wantsLayer = YES;
//                [layerview addSubview:view];
//                [layerview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
//                [win.contentView setSubviews:@[layerview]];
            } else {
//                [win.contentView setSubviews:@[view]];
            }
            
            NSLog(@"%@", theView.subviews);
            
//            [theView setSubviews:@[view]];
        }
    }
}

- (void)viewDidLoad {
    ZKOrig(void);
    
    NSLog(@"viewDidLoad Turd wrangler sir : %@", self.view);
    
    if ([[self className] isEqualToString:@"LUI2BackgroundViewController"]) {
        NSLog(@"Hello sir : %@", [self className]);
        if (db_EnableAnim) {
            NSLog(@"We're in sir : %@", [self className]);
            NSString *picturePath;
            for (NSString *ext in @[@"jpg", @"png", @"gif"])
                if ([FileManager fileExistsAtPath:[db_LockFile stringByAppendingPathExtension:ext]])
                    picturePath = [db_LockFile stringByAppendingPathExtension:ext];
            
            
            
//            NSWindow *win = [self valueForKey:@"_mainWindow"];
//            NSImageView *view = [[NSImageView alloc] initWithFrame:win.contentView.frame];
//            NSImage *theImage = [[NSImage alloc] initWithContentsOfFile:picturePath];
//            [theImage setSize: NSMakeSize(theView.frame.size.width, theView.frame.size.height)];
//            theView.image = theImage;
//            theView.canDrawSubviewsIntoLayer = YES;
//            [theView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            
            //        NSButton *adButton = [[NSButton alloc] initWithFrame:NSMakeRect(win.contentView.frame.size.width - 160, 10, 150, 22)];
            //        [adButton setTitle:@"🍭 Try cDock"];
            //        [adButton setBezelStyle:NSTexturedRoundedBezelStyle];
            //        [adButton setTarget:self];
            //        [adButton setAction:@selector(getcDock)];
            
//            if (db_LockAnim) {
//                theView.imageScaling = NSImageScaleNone;
//                theView.animates = YES;
////                NSView *layerview = [[NSImageView alloc] initWithFrame:win.contentView.frame];
////                layerview.wantsLayer = YES;
////                [layerview addSubview:view];
////                [layerview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
////                [win.contentView setSubviews:@[layerview]];
//            } else {
////                [win.contentView setSubviews:@[view]];
//            }
        }
    }
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

- (void)appear {
    NSLog(@"loginwindow Hookers appear");
    ZKOrig(void);
}

- (void)relinquishMain {
    NSLog(@"loginwindow Hookers relinquish");
    ZKOrig(void);
}

- (void)becomeMain {
    NSLog(@"loginwindow Hookers become");
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

- (BOOL)lockScreenIfNeeded {
    NSLog(@"loginwindow Hookers lockScreenIfNeeded");
    return ZKOrig(BOOL);
}

- (void)doLoginHook {
    NSLog(@"loginwindow Hookers doLoginHook");
    ZKOrig(void);
}

- (BOOL)isDarkInstall {
    NSLog(@"loginwindow Hookers isDarkInstall");
    return ZKOrig(BOOL);
}

@end

@interface wb_LUI2Window : NSWindow
@end

@implementation wb_LUI2Window

- (void)_setupContentView {
//    NSLog(@"Hello sir : %@", [self className]);
    if (db_EnableAnim) {
        ZKOrig(void);
        [[DBLoginWindowDYLIB sharedInstance] setupLockBG:self];
    } else {
        ZKOrig(void);
    }
}

@end

@interface wb_LUIWindowController : NSObject
@end

@implementation wb_LUIWindowController

- (void)setUsesDesktopPicture:(BOOL)arg1 {
//    NSLog(@"Hello sir : %@", [self className]);
    if (db_EnableAnim) {
        ZKOrig(void, false);
        [[DBLoginWindowDYLIB sharedInstance] setupLockBG:[self valueForKey:@"_mainWindow"]];
    } else {
        ZKOrig(void, arg1);
    }
}

@end


@interface wb_NSTextView : NSTextView
@end

@implementation wb_NSTextView

- (void)setString:(NSString *)stringValue {
    NSString *result = stringValue;
    if (db_EnableSize) {
        double lockSize = [db_LockSize doubleValue];
        [self setFont:[NSFont fontWithDescriptor:self.font.fontDescriptor size:lockSize]];
        [self setFont:[NSFont fontWithDescriptor:self.font.fontDescriptor size:lockSize]];
    }
    if (db_EnableText) {
        NSString* lockText = db_LockText;
        NSLog(@"poop kaydog %@", lockText);
        if ([lockText isEqualToString:@""])
            lockText = @"🍣";
        result = lockText;
    }
    ZKOrig(void, result);
}

@end

@interface wb_LUI2MessageViewController : NSViewController
@end

@implementation wb_LUI2MessageViewController

- (void)viewDidAppear {
    ZKOrig(void);
    NSTextView *tv = [self valueForKey:@"messageTextView"];
    if (db_EnableSize) {
        double lockSize = [db_LockSize doubleValue];
        if (lockSize < 0.0 || lockSize > 64.0) {
            [tv setFont:[NSFont fontWithDescriptor:tv.font.fontDescriptor size:lockSize]];
            [tv setFont:[NSFont fontWithDescriptor:tv.font.fontDescriptor size:lockSize]];
        }
    }
    if (db_EnableText) {
        NSString* lockText = db_LockText;
        if ([lockText isEqualToString:@""])
            lockText = @"🍣";
        tv.string = lockText;
    }
    
}

@end

@interface wb_LUI2TextField : NSTextField
@end

@implementation wb_LUI2TextField

- (void)setStringValue:(NSString *)stringValue {
    NSString *result = stringValue;
//    if (db_EnableText) {
//        NSString* lockText = db_LockText;
//        NSLog(@"poop kaydog %@", lockText);
//        if ([lockText isEqualToString:@""])
//            lockText = @"🍣";
//        result = lockText;
//    }
    ZKOrig(void, result);
}

- (void)setFont:(NSFont *)font {
    NSFont *result = font;
//    if (db_EnableSize) {
//        double lockSize = [db_LockSize doubleValue];
//        NSLog(@"poop kaydog %f", lockSize);
//        if (lockSize < 0.0 || lockSize > 64.0)
//            result = [NSFont fontWithDescriptor:[self.font fontDescriptor] size:lockSize * 2.];
//    }
    ZKOrig(void, result);
}

@end

@interface wb_LUIGoodSamaritanMessageView : NSView
@end

@implementation wb_LUIGoodSamaritanMessageView

- (id)_fontOfSize:(double)arg1 {
    NSLog(@"Hello sir : %@", [self className]);
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
    NSLog(@"Hello sir : %@", [self className]);
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
