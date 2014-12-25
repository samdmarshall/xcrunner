//
//  main.m
//  xcrunner
//
//  Created by Sam Marshall on 12/25/14.
//  Copyright (c) 2014 Sam Marshall. All rights reserved.
//

#import <Foundation/Foundation.h>



int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSArray *args = [[NSProcessInfo processInfo] arguments];
		
		NSTask *sdkDirTask = [[NSTask alloc] init];
		[sdkDirTask setLaunchPath:@"/usr/bin/xcrun"];
		
		NSInteger sdkIndex = [args indexOfObject:@"-sdk"];
		if (sdkIndex != NSNotFound) {
			sdkIndex++;
			[sdkDirTask setArguments:@[@"--show-sdk-path", @"--sdk", [args objectAtIndex:sdkIndex]]];
		}
		else {
			[sdkDirTask setArguments:@[@"--show-sdk-path"]];
		}
		
		NSPipe *sdkDirOutput = [[NSPipe alloc] init];
		[sdkDirTask setStandardOutput:sdkDirOutput];
		
		[[sdkDirOutput fileHandleForReading] waitForDataInBackgroundAndNotify];
		
		__block NSString *fullSDKDirPath = @"";
		
		[[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:[sdkDirOutput fileHandleForReading] queue:nil usingBlock:^(NSNotification *notification){
			
			NSData *output = [[sdkDirOutput fileHandleForReading] availableData];
			NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
			
			if (![outStr isEqualToString:@""]) {
				fullSDKDirPath = [outStr substringToIndex:outStr.length-1];
			}
			
			[[sdkDirOutput fileHandleForReading] waitForDataInBackgroundAndNotify];
		}];
		
		[sdkDirTask launch];
		
		[sdkDirTask waitUntilExit];
		
		
		if (![fullSDKDirPath isEqualToString:@""]) {
			NSTask *xcrunTask = [[NSTask alloc] init];
			[xcrunTask setLaunchPath:@"/usr/bin/xcrun"];
			
			NSMutableDictionary *newEnv = [[[NSProcessInfo processInfo] environment] mutableCopy];
			
			NSString *currentPath = [newEnv objectForKey:@"PATH"];
			currentPath = [currentPath stringByAppendingString:@":"];
			fullSDKDirPath = [fullSDKDirPath stringByAppendingPathComponent:@"/usr/bin/"];
			currentPath = [currentPath stringByAppendingString:fullSDKDirPath];
			[newEnv setObject:currentPath forKey:@"PATH"];
			
			[xcrunTask setEnvironment:newEnv];
			
			[xcrunTask setArguments:[args subarrayWithRange:NSMakeRange(1, args.count-1)]];
			
			[xcrunTask launch];
			
			[xcrunTask waitUntilExit];
		}
		
	}
    return 0;
}
