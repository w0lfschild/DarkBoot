/*
 *  InstallBootImage.c
 *  BootXChanger
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

#import <Cocoa/Cocoa.h>
#define DEFAULT_COLOR 12566463

// usage: InstallBootImage color [image]
//		  color as integer
//        path to image

static NSString *bootPlistPath = @"/Library/Preferences/SystemConfiguration/com.apple.Boot.plist";
static NSString *bootLogoPath = @"/System/Library/CoreServices/BootLogo.png";

BOOL InstallBootImage(int color, NSString *path);

int main (int argc, char ** argv) {
	// validate arguments
	if (argc != 3 && argc != 2) return EXIT_FAILURE;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	int color = strtol(argv[1], NULL, 10);
	NSString *path = nil;
	if (argc == 3) path = [NSString stringWithUTF8String:argv[2]];
	int err = InstallBootImage(color, path)?EXIT_SUCCESS:EXIT_FAILURE;
	if (argc == 3) unlink(argv[2]);
	[pool release];
	return err;
}

BOOL InstallBootImage(int color, NSString *path) {
	// read property list
	NSData *plistData = [NSData dataWithContentsOfFile:bootPlistPath];
	if (plistData == nil) return NO;
	NSString *err = nil;
	NSMutableDictionary *bootPlist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:&err];
	if (bootPlist == nil) {
		NSLog(@"propertyListFromData: %@", err);
		[err release];
		return NO;
	}
	
	// set color
	if (color == DEFAULT_COLOR) [bootPlist removeObjectForKey:@"Background Color"];
	else [bootPlist setObject:[NSNumber numberWithInt:color] forKey:@"Background Color"];
	
	// set image
	if (path == nil) [bootPlist removeObjectForKey:@"Boot Logo"];
	else {
		NSData *bootLogo = [NSData dataWithContentsOfFile:path];
		if (bootLogo == nil) {
			NSLog(@"Could not find boot image");
			return NO;
		}
		if (![bootLogo writeToFile:bootLogoPath atomically:YES]) {
			NSLog(@"Could not write boot image");
			return NO;
		}
		NSMutableString *bootLogoPathEFI = [NSMutableString stringWithString:bootLogoPath];
		[bootLogoPathEFI replaceOccurrencesOfString:@"/" withString:@"\\" options:NSLiteralSearch range:NSMakeRange(0, [bootLogoPathEFI length])];
		[bootPlist setObject:bootLogoPathEFI forKey:@"Boot Logo"];
		
	}
	
	// write new file
	plistData = [NSPropertyListSerialization dataFromPropertyList:bootPlist format:NSPropertyListXMLFormat_v1_0 errorDescription:&err];
	if (plistData == nil) {
		NSLog(@"dataFromPropertyList: %@", err);
		[err release];
		return NO;
	}
	if (![plistData writeToFile:bootPlistPath atomically:YES]) {
		NSLog(@"could not write com.apple.Boot.plist");
		return NO;
	}
	
	// at last
	return YES;
}