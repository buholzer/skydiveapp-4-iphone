//
//  FlySightLog.h
//  skydiveapp-4-iphone
//
//  Created by Mirko Buholzer on 10/13/12.
//
//

#import <Foundation/Foundation.h>
#import "LogEntry.h"

@interface FlySightLog : NSObject

@property (nonatomic, retain) NSNumber *exitAltitude;
@property (nonatomic, retain) NSNumber *deploymentAltitude;

@property (nonatomic, retain) NSDate *exitTime;
@property (nonatomic, retain) NSDate *deploymentTime;
@property (nonatomic, retain) NSDate *landingTime;

@property (nonatomic, retain) NSNumber *verticalMaxSpeed;
@property (nonatomic, retain) NSNumber *verticalAvgFreefallSpeed;
@property (nonatomic, retain) NSNumber *verticalAvgCanopySpeed;

@property (nonatomic, retain) NSString *notes;


- (id)initWithFile:(NSString *)flySightLog;
- (LogEntry *)createLogEntry;



@end
