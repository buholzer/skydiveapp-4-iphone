//
//  FlySightLog.m
//  skydiveapp-4-iphone
//
//  Created by Mirko Buholzer on 10/13/12.
//
//

#import "FlySightLog.h"
#import "NSString_CsvParser.h"
#import "RepositoryManager.h"
#import "LogEntryRepository.h"
#import "LocationRepository.h"
#import "AircraftRepository.h"
#import "SkydiveTypeRepository.h"
#import "RigRepository.h"


#define INDEX_TIME                  0
#define INDEX_HEIGHT                3
#define INDEX_VERTICAL_SPEED        6
#define INDEX_GPS_FIX               10
#define INDEX_NUM_SATELLITES        11

#define MIN_SATELLITES              3

#define MIN_FREEFALL_VERTICAL_SPEED 10.0
#define MIN_ALTITUDE_DEPLOY_LAND    500.0

@implementation FlySightLog

@synthesize exitAltitude, deploymentAltitude, exitTime, deploymentTime, verticalMaxSpeed, verticalAvgFreefallSpeed, verticalAvgCanopySpeed, notes;

- (id)initWithFile:(NSString *)flySightLogPath {

    if (self = [super init])
	{
        NSError*  error;
        NSString* flySightLog = [NSString stringWithContentsOfFile:flySightLogPath encoding:NSUTF8StringEncoding error:&error ];
        
        NSMutableArray *flySightLogRows = [flySightLog csvRows];

        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSZZZZ"];

        BOOL freefall = false;
        BOOL deployment = false;
        BOOL landed = false;
        
        float sumFreefallSpeed = 0;
        float sumCanopySpeed = 0;
        int countFreefallSpeed = 0;
        int countCanopySpeed = 0;
        
        int c;
        for (c = 2; c < [flySightLogRows count]; c++) {
    //        NSLog(@"content of line %d: %@", c, [flySightLogRows objectAtIndex: c]);
            
            NSArray *row = [flySightLogRows objectAtIndex: c];
            
            if (([[row objectAtIndex:INDEX_GPS_FIX] integerValue] == 3) && ([[row objectAtIndex:INDEX_NUM_SATELLITES] integerValue] >= MIN_SATELLITES)) {
                // We have valid data
                float verticalSpeed = [[row objectAtIndex:INDEX_VERTICAL_SPEED] floatValue];
                
                // Update max vertical speed
                if ([self.verticalMaxSpeed floatValue] < verticalSpeed)
                    self.verticalMaxSpeed = [NSNumber numberWithFloat:verticalSpeed];
                
                // Determine exit
                if (!freefall && (verticalSpeed > MIN_FREEFALL_VERTICAL_SPEED)) {
                    freefall = true;
                    self.exitAltitude = [row objectAtIndex:INDEX_HEIGHT];
                    
                    NSLog(@"Exit altitude:       %@", [row objectAtIndex:INDEX_HEIGHT]);
                    NSLog(@"Exit time:           %@", [dateFormatter dateFromString:[row objectAtIndex:INDEX_TIME]]);
                    
                    self.exitTime = [dateFormatter dateFromString:[row objectAtIndex:INDEX_TIME]];
                }
                
                // Determine deployment
                if (freefall && !deployment && (verticalSpeed < MIN_FREEFALL_VERTICAL_SPEED)) {
                    deployment = true;
                    self.deploymentAltitude = [row objectAtIndex:INDEX_HEIGHT];
                    
                    NSLog(@"Deployment altitude: %@", [row objectAtIndex:INDEX_HEIGHT]);
                    NSLog(@"Deployment time:     %@", [dateFormatter dateFromString:[row objectAtIndex:INDEX_TIME]]);
                    
                    self.deploymentTime = [dateFormatter dateFromString:[row objectAtIndex:INDEX_TIME]];
                }

                // Determine landing
                if (deployment && !landed && (verticalSpeed < 0.1) &&
                    ([self.deploymentAltitude floatValue] - [[row objectAtIndex:INDEX_HEIGHT] floatValue] > MIN_ALTITUDE_DEPLOY_LAND)) {

                    landed = true;
                    
                    NSLog(@"Landing altitude:    %@", [row objectAtIndex:INDEX_HEIGHT]);
                    NSLog(@"Landing time:        %@", [dateFormatter dateFromString:[row objectAtIndex:INDEX_TIME]]);
                    
                    // adjust height based on DZ offset
                    self.exitAltitude = [NSNumber numberWithFloat:[self.exitAltitude floatValue] - [[row objectAtIndex:INDEX_HEIGHT] floatValue]];
                    self.deploymentAltitude = [NSNumber numberWithFloat:[self.deploymentAltitude floatValue] - [[row objectAtIndex:INDEX_HEIGHT] floatValue]];

                    self.landingTime = [dateFormatter dateFromString:[row objectAtIndex:INDEX_TIME]];
                    self.verticalAvgFreefallSpeed = [NSNumber numberWithFloat:(sumFreefallSpeed / countFreefallSpeed)];
                    self.verticalAvgCanopySpeed = [NSNumber numberWithFloat:(sumCanopySpeed / countCanopySpeed)];
                    
                    NSLog(@"Summary:");
                    NSLog(@"Exit altitude:       %@", self.exitAltitude);
                    NSLog(@"Deployment altitude: %@", self.deploymentAltitude);
                    NSLog(@"Delay:               %.1fs/%.1fs", ([self.deploymentTime timeIntervalSince1970] - [self.exitTime timeIntervalSince1970]),
                                                               ([self.landingTime timeIntervalSince1970] - [self.deploymentTime timeIntervalSince1970]));
                    NSLog(@"Max Freefall:        %.1f", [self.verticalMaxSpeed floatValue]);
                    NSLog(@"Avg Freefall/Canopy: %.1f/%.1f", [self.verticalAvgFreefallSpeed floatValue], [self.verticalAvgCanopySpeed floatValue]);
                }

                // Update statistics
                if (freefall && !deployment) {
                    sumFreefallSpeed += verticalSpeed;
                    countFreefallSpeed ++;
                }
                if (deployment && !landed) {
                    sumCanopySpeed += verticalSpeed;
                    countCanopySpeed ++;
                }
            }
        }
	}
	
	return self;
}

- (LogEntry *)createLogEntry
{
    // create new
    LogEntryRepository *repository = [[RepositoryManager instance] logEntryRepository];
    LogEntry *logEntry = [repository createWithDefaults];
    
    // set default location
    LocationRepository *locationRepository = [[RepositoryManager instance] locationRepository];
    logEntry.Location = [locationRepository homeLocation];
    // set default aircraft
    AircraftRepository *aircraftRepository = [[RepositoryManager instance] aircraftRepository];
    logEntry.Aircraft = [aircraftRepository defaultAircraft];
    // set default skydive type
    SkydiveTypeRepository *skydiveTypeRepository = [[RepositoryManager instance] skydiveTypeRepository];
    logEntry.SkydiveType = [skydiveTypeRepository defaultSkydiveType];
    // set default rigs
    RigRepository *rigRepository = [[RepositoryManager instance] rigRepository];
    NSArray *rigs = [rigRepository primaryRigs];
    for (Rig *rig in rigs)
    {
        [logEntry addRigsObject:rig];
    }
    
    // Transfer log values
    logEntry.DeploymentAltitude = self.deploymentAltitude;
    logEntry.ExitAltitude = self.exitAltitude;
    logEntry.FreefallTime = [NSNumber numberWithFloat:[self.deploymentTime timeIntervalSince1970] - [self.exitTime timeIntervalSince1970]];
    logEntry.Date = self.exitTime;
    [repository save];
    
    return logEntry;
}


@end
