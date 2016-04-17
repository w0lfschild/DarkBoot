/*
 *  BXApplication.m
 *  BootXChanger
 *
 *  Created by Zydeco on 2010-05-20.
 *
 *  Copyright 2010 namedfork.net. All rights reserved.
 *
 *
 *  Created by Zydeco on 2007-11-05.
 *  Copyright 2007-2010 namedfork.net. All rights reserved.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "BXApplication.h"

static NSString *bootPlistPath = @"/Library/Preferences/SystemConfiguration/com.apple.Boot.plist";
static NSString *BXErrorDomain = @"BootXChanger";

enum BXErrorCode {
	BXErrorNone,
	BXErrorCannotGetPNG,
	BXErrorCannotWriteTmpFile,
};

@implementation BXApplication

- (void)awakeFromNib {
	[self showCurrentImage:self];
	[self setDelegate:self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    [bootColorWell setColor:[self currentBackgroundColor]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[self deauthorize];
	return NSTerminateNow;
}

- (NSImage*)currentBootImage {
	NSDictionary *bootPlist = [NSDictionary dictionaryWithContentsOfFile:bootPlistPath];
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
	return [img autorelease];
}

- (NSColor*)currentBootColor {
	NSDictionary *bootPlist = [NSDictionary dictionaryWithContentsOfFile:bootPlistPath];
	if ([bootPlist objectForKey:@"Background Color"] == nil) return [self defaultBootColor];
	UInt32 colorVal = [[bootPlist objectForKey:@"Background Color"] unsignedIntValue];
	struct {int r,g,b;} color;
	color.r = (colorVal & 0xFF0000) >> 16;
	color.g = (colorVal & 0x00FF00) >> 8;
	color.b = (colorVal & 0x0000FF);
	return [NSColor colorWithDeviceRed:color.r/255.0 green:color.g/255.0 blue:color.b/255.0 alpha:1.0];
}

- (NSImage*)defaultBootImage {
	return [NSImage imageNamed:@"default.png"];
}

- (NSColor*)defaultBootColor {
	return [NSColor colorWithDeviceRed:191.0/255.0 green:191.0/255.0 blue:191.0/255.0 alpha:1.0];
}

- (IBAction)showDefaultImage:(id)sender {
	imageView.image = [self defaultBootImage];
	bgColorWell.color = [self defaultBootColor];
}

- (IBAction)showCurrentImage:(id)sender {
	imageView.image = [self currentBootImage];
	bgColorWell.color = [self currentBootColor];
}

- (IBAction)saveBootImage:(id)sender {
	BOOL success = [self installBootImage:imageView.image withBackgroundColor:bgColorWell.color error:NULL];
    [self setupDarkBoot];
	if (!success) {
		NSBeep();
		[self showCurrentImage:self];
	}
}

- (NSColor *)currentBackgroundColor {
    NSString* bootPlist = @"/Library/LaunchDaemons/com.dabrain13.darkboot.plist";
    NSColor* result = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:bootPlist]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:bootPlist];
        NSArray* args = [dict objectForKey:@"ProgramArguments"];
        NSString* color = [args objectAtIndex:1];
        NSArray* foo = [color componentsSeparatedByString: @"%"];
        long b = strtol([[foo objectAtIndex: 1] UTF8String], NULL, 16); // r
        long g = strtol([[foo objectAtIndex: 2] UTF8String], NULL, 16);
        long r = strtol([[foo objectAtIndex: 3] UTF8String], NULL, 16); // b
        result = [NSColor colorWithDeviceRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
        NSLog(@"r%ld g%ld b%ld", r, g, b);
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

- (void)installBXPlist:(NSString*)colorString
{
    OSStatus e;
    char *bootPlist = "/Library/LaunchDaemons/com.dabrain13.darkboot.plist";
    NSString* BXPlist = [[NSBundle mainBundle] pathForResource:@"com.dabrain13.darkboot" ofType:@"plist"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:BXPlist];
    NSMutableArray* bargs = [dict objectForKey:@"ProgramArguments"];
    // The magic
    [bargs setObject:colorString atIndexedSubscript:1];
    // The magic
    [dict setObject:bargs forKey:@"ProgramArguments"];
    [dict writeToFile:@"/tmp/BXplist.plist" atomically:YES];
    
    // Run the tool using the authorization reference
    char *tool = "/bin/mv";
    char *args0[] = { "-f", "/tmp/BXplist.plist", bootPlist, nil };
    FILE *pipe = NULL;
    e = AuthorizationExecuteWithPrivileges(auth, tool, kAuthorizationFlagDefaults, args0, &pipe);
    
    tool = "/usr/sbin/chown";
    char *args1[] = { "root:admin", bootPlist, nil };
    e = AuthorizationExecuteWithPrivileges(auth, tool, kAuthorizationFlagDefaults, args1, &pipe);
    
    system("launchctl unload /Library/LaunchDaemons/com.dabrain13.darkboot.plist");
    system("launchctl load /Library/LaunchDaemons/com.dabrain13.darkboot.plist");
}

- (void)setupDarkBoot {
//    long selectedbgc = [currentBGColor indexOfSelectedItem];
    if ([self currentBackgroundColor] != bootColorWell.color) {
        
//        NSString* bootPlist = @"/Library/LaunchDaemons/com.dabrain13.darkboot.plist";
//        NSString* BXPlist = [[NSBundle mainBundle] pathForResource:@"com.dabrain13.darkboot" ofType:@"plist"];
        
        NSLog(@"Boot Color : %@", bootColorWell.color);
        
//        if (selectedbgc == 0)
//        {
//            // Run the tool using the authorization reference
//            char *tool = "/bin/rm";
//            char *args[] = { "/Library/LaunchDaemons/com.dabrain13.darkboot.plist", nil };
//            FILE *pipe = NULL;
//            OSStatus e = AuthorizationExecuteWithPrivileges(auth, tool,
//                                                        kAuthorizationFlagDefaults, args, &pipe);
//        }
    
        NSString *bootColor = [self hexStringForColor:bootColorWell.color];
        NSLog(@"%@", bootColor);
        NSString *bootARG = [NSString stringWithFormat:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%@", bootColor];
        [self installBXPlist:bootARG];
        //[self installBXPlist:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%00%00%00"]; // Black
        //[self installBXPlist:@"4d1ede05-38c7-4a6a-9cc6-4bcca8b38c14:DefaultBackgroundColor=%99%99%99"]; // Grey
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
		NSData *pngData = [rep representationUsingType:NSPNGFileType properties:nil];
		[rep release];
		[img2 release];
		if (pngData == nil) {
			// could not get PNG representation
			if (err) *err = [NSError errorWithDomain:BXErrorDomain code:BXErrorCannotGetPNG userInfo:nil];
			return NO;
		}
		
		// write to file
		if (![pngData writeToFile:tmpPath atomically:NO]) {
			// could not write temporary file
			if (err) *err = [NSError errorWithDomain:BXErrorDomain code:BXErrorCannotWriteTmpFile userInfo:nil];
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
	OSStatus e = AuthorizationExecuteWithPrivileges(auth, [toolPath fileSystemRepresentation], kAuthorizationFlagDefaults, toolArgs, NULL);
	return (e == errAuthorizationSuccess);
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

@end
