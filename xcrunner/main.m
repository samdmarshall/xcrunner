//
//  main.m
//  xcrunner
//
//  Created by Samantha Marshall on 12/25/14.
//  Copyright (c) 2014 Samantha Marshall. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/stat.h>

int 	allpaths;
char *foundPath;

static int is_there(char *candidate)
{
	struct stat fin;
	
	/* XXX work around access(2) false positives for superuser */
	bool access_ok = (access(candidate, X_OK) == 0);
	bool stat_ok = (stat(candidate, &fin) == 0);
	bool isreg_ok = (S_ISREG(fin.st_mode));
	bool file_exists = (access_ok && stat_ok && isreg_ok);
	
	bool is_not_root = (getuid() != 0);
	bool stat_mode_ok = ((fin.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) != 0);
	
	bool found_match = (file_exists && (is_not_root || stat_mode_ok));
	if (found_match) {
		foundPath = candidate;
	}
	return found_match;
}

static int print_matches(char *path, char *filename)
{
	char candidate[PATH_MAX];
	const char *d;
	int found = 0;
	
	if (strchr(filename, '/') != NULL) {
		found = is_there(filename);
	}
	
	if (found == 0) {
		while ((d = strsep(&path, ":")) != NULL && found == 0) {
			if (*d == '\0') {
				d = ".";
			}
			
			if (snprintf(candidate, sizeof(candidate), "%s/%s", d, filename) >= (int)sizeof(candidate)) {
				continue;
			}
			
			found = is_there(candidate);
		}
	}
	
	return (found ? 0 : -1);
}

NSString * GetPath()
{
	NSString *xcrunPath;
	
	char *p = getenv("PATH");
	NSString *pathVar = [NSString stringWithFormat:@"%s",p];
	
	if (print_matches((char *)[pathVar UTF8String], "xcrun") == 0) {
		xcrunPath = [NSString stringWithFormat:@"%s", foundPath];
	}
	else {
		NSLog(@"ERROR! Could not find xcrun!");
		exit(0);
	}
	
	return xcrunPath;
}


int main(int argc, const char * argv[])
{
	@autoreleasepool {
		NSArray *args = [[NSProcessInfo processInfo] arguments];
		
		NSTask *sdkDirTask = [[NSTask alloc] init];
		[sdkDirTask setLaunchPath:GetPath()];
		
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
			[xcrunTask setLaunchPath:GetPath()];
			
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
