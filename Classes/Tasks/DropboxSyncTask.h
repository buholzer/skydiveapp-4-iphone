//
//  DropboxSyncTask.h
//  skydiveapp-4-iphone
//
//  Created by Mirko Buholzer on 10/12/12.
//
//

#import <DropBoxSDK/DropBoxSDK.h>

@interface DropboxSyncTask : NSObject {


  DBRestClient* restClient;
}

@property (nonatomic, strong) NSString *cachePath;
@property (nonatomic, assign) int totalLogFiles;
@property (nonatomic, assign) int filesDownloaded;
@property (nonatomic, assign) int filesAnalized;

+ (DropboxSyncTask *)instance;

- (void)sync;

@end
