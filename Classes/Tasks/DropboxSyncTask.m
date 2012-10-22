//
//  DropboxSyncTask.m
//  skydiveapp-4-iphone
//
//  Created by Mirko Buholzer on 10/12/12.
//
//

#import "DropboxSyncTask.h"
#import "FlySightLog.h"
#import "LogEntryRepository.h"
#import "LogEntry.h"



@interface DropboxSyncTask() <DBRestClientDelegate>

- (void)sync;

@property (nonatomic, strong) DBRestClient* restClient;

@end


@implementation DropboxSyncTask

static DropboxSyncTask *instance = NULL;

@synthesize restClient, cachePath, filesDownloaded, filesAnalized;

- (void)sync {
    
    // Clear cached files
    NSError *error = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
        
        [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:&error];
        
        if (error != nil) {
            NSLog(@"Error deleting cache directory: %@", error);
        }
    }
    // Create empty directory
    [[NSFileManager defaultManager] createDirectoryAtPath: self.cachePath
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: &error];
	
	if (error != nil) {
		NSLog(@"Error creating cache directory: %@", error);
	}
    
    NSString *syncRoot = nil;
    if ([DBSession sharedSession].root == kDBRootDropbox) {
        syncRoot = @"/SkydiveApp";
    } else {
        syncRoot = @"/";
    }
    
    self.totalLogFiles = 0;
    self.filesDownloaded = 0;
    self.filesAnalized = 0;
    
    [self.restClient loadMetadata:syncRoot];
}



#pragma mark DBRestClientDelegate methods

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {

    NSArray* validExtensions = [NSArray arrayWithObjects:@"csv", nil];
    
    if (metadata.isDirectory) {
        NSLog(@"Folder '%@' contains:", metadata.path);
        for (DBMetadata *child in metadata.contents) {
            if (child.isDirectory) {
                [self.restClient loadMetadata:[NSString stringWithFormat:@"/%@", child.filename]];
            } else {
                NSString* extension = [[child.path pathExtension] lowercaseString];
                if (!child.isDirectory && [validExtensions indexOfObject:extension] != NSNotFound) {
                    NSLog(@"\t\t%@", child.filename);

                    NSArray *parts = [child.path componentsSeparatedByString:@"/"];
                    NSString *dirname = [parts objectAtIndex:[parts count]-2];
                    
                    // add dir name to filename due to potential domain conflicts
                    NSString *filename = [NSString stringWithFormat:@"%@_%@", dirname, child.filename];
                    
                    [self.restClient loadFile:child.path intoPath:[self.cachePath stringByAppendingPathComponent:filename]];
                    self.totalLogFiles ++;
                }
            }
        }
    }
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    NSLog(@"Dropbox metadata unchanged at %@", path);
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
    NSLog(@"restClient:loadMetadataFailedWithError: %@", [error localizedDescription]);
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath {

    self.filesDownloaded ++;
    NSLog(@"(%d/%d) File loaded - %@", self.filesDownloaded, self.totalLogFiles, destPath);
    
    if (self.filesDownloaded >= self.totalLogFiles) {
        [self analyseCachedLogFiles];
    }
    
}

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath {
    
    NSArray *parts = [destPath componentsSeparatedByString:@"/"];
    NSString *filename = [parts objectAtIndex:[parts count]-1];
    
    NSLog(@"Loading - %@ (%1.0f%%)", filename, progress * 100);
     
}

- (DBRestClient*)restClient {
    if (restClient == nil) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}

- (void)analyseCachedLogFiles {

    NSError * error;
    NSArray * directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cachePath error:&error];

    
    NSLog(@"Analyzing loaded files");
    
    for (NSString *fileName in directoryContents) {
        NSLog(@"Analyzing - %@", fileName);
        FlySightLog *log = [[FlySightLog alloc] initWithFile:[self.cachePath stringByAppendingPathComponent:fileName]];
        NSLog(@"log %@", log);
        [log createLogEntry];
    }
}

- (NSString *) cachePath {
    
    if (cachePath == nil) {
        NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        cachePath = [cachesDirectory stringByAppendingPathComponent:@"sync"];
    }
	return cachePath;
}

+ (DropboxSyncTask *)instance
{
	@synchronized(self)
    {
		if (instance == NULL)
			instance = [[self alloc] init];
	}
	
	return instance;
}


@end
