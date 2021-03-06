/*=========================================================================
 Program:   OsiriX
 
 Copyright (c) OsiriX Team
 All rights reserved.
 Distributed under GNU - LGPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/

#import "DicomDatabase.h"
#import "NSString+N2.h"


#import "BrowserController.h"


@implementation DicomDatabase

+(DicomDatabase*)defaultDatabase {
	static DicomDatabase* database = NULL;
	@synchronized(self) {
		if (!database) // TODO: the next line MUST CHANGE and BrowserController MUST DISAPPEAR
			database = [[self alloc] initWithPath:[[BrowserController currentBrowser] documentsDirectory] context:[[BrowserController currentBrowser] defaultManagerObjectContext]];
	}
	return database;
}

-(NSManagedObjectModel*)managedObjectModel {
	static NSManagedObjectModel* managedObjectModel = NULL;
	if (!managedObjectModel)
		managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"OsiriXDB_DataModel.momd"]]];
    return managedObjectModel;
}

-(NSEntityDescription*)imageEntity {
	return [self entityForName: @"Image"];
}

-(NSEntityDescription*)seriesEntity {
	return [self entityForName: @"Series"];
}

-(NSEntityDescription*)studyEntity {
	return [self entityForName: @"Study"];
}

-(NSEntityDescription*)albumEntity {
	return [self entityForName: @"Album"];
}

-(NSEntityDescription*)logEntryEntity {
	return [self entityForName: @"LogEntry"];
}


-(NSManagedObjectContext*)contextAtPath:(NSString*)sqlFilePath {
	NSLog(@"******* DO NOT CALL THIS FUNCTION - NOT FINISHED / BUGGED : %s", __PRETTY_FUNCTION__); // TODO: once BrowserController / DicomDatabase doubles are solved, REMOVE THIS METHOD as it is defined in N2ManagedDatabase
	[NSException raise:NSGenericException format:@"DicomDatabase NOT READY for complete usage (contextAtPath:)"];
	return nil;
}

-(NSString*)sqlFilePath {
	return [self.basePath stringByAppendingPathComponent:@"Database.sql"];
}

+(NSArray*)albumsInContext:(NSManagedObjectContext*)context {
	NSFetchRequest* req = [[[NSFetchRequest alloc] init] autorelease];
	req.entity = [NSEntityDescription entityForName: @"Album" inManagedObjectContext:context];
	req.predicate = [NSPredicate predicateWithValue:YES];
	return [context executeFetchRequest:req error:NULL];	
}

-(NSArray*)albums {
	NSArray* albums = [DicomDatabase albumsInContext:self.managedObjectContext];
	NSSortDescriptor* sd = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	return [albums sortedArrayUsingDescriptors:[NSArray arrayWithObject: sd]];
}

+(NSPredicate*)predicateForSmartAlbumFilter:(NSString*)string {
	if (!string.length)
		return [NSPredicate predicateWithValue:YES];
	
	NSMutableString* pred = [NSMutableString stringWithString: string];
	
	// DATES
	NSCalendarDate* now = [NSCalendarDate calendarDate];
	NSDate *start = [NSDate dateWithTimeIntervalSinceReferenceDate: [[NSCalendarDate dateWithYear:[now yearOfCommonEra] month:[now monthOfYear] day:[now dayOfMonth] hour:0 minute:0 second:0 timeZone: [now timeZone]] timeIntervalSinceReferenceDate]];
    
    NSDictionary	*sub = [NSDictionary dictionaryWithObjectsAndKeys:	[NSString stringWithFormat:@"%lf", [[now addTimeInterval: -60*60*1] timeIntervalSinceReferenceDate]],			@"$LASTHOUR",
							[NSString stringWithFormat:@"%lf", [[now addTimeInterval: -60*60*6] timeIntervalSinceReferenceDate]],			@"$LAST6HOURS",
							[NSString stringWithFormat:@"%lf", [[now addTimeInterval: -60*60*12] timeIntervalSinceReferenceDate]],			@"$LAST12HOURS",
							[NSString stringWithFormat:@"%lf", [start timeIntervalSinceReferenceDate]],										@"$TODAY",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24] timeIntervalSinceReferenceDate]],			@"$YESTERDAY",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24*2] timeIntervalSinceReferenceDate]],		@"$2DAYS",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24*7] timeIntervalSinceReferenceDate]],		@"$WEEK",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24*31] timeIntervalSinceReferenceDate]],		@"$MONTH",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24*31*2] timeIntervalSinceReferenceDate]],	@"$2MONTHS",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24*31*3] timeIntervalSinceReferenceDate]],	@"$3MONTHS",
							[NSString stringWithFormat:@"%lf", [[start addTimeInterval: -60*60*24*365] timeIntervalSinceReferenceDate]],		@"$YEAR",
							nil];
	
	NSEnumerator *enumerator = [sub keyEnumerator];
	NSString *key;
	
	while ((key = [enumerator nextObject]))
	{
		[pred replaceOccurrencesOfString:key withString: [sub valueForKey: key]	options: NSCaseInsensitiveSearch range:pred.range];
	}
	
	return [[NSPredicate predicateWithFormat:pred] predicateWithSubstitutionVariables: [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                        [now dateByAddingTimeInterval: -60*60*1],			@"NSDATE_LASTHOUR",
                                                                                        [now dateByAddingTimeInterval: -60*60*6],			@"NSDATE_LAST6HOURS",
                                                                                        [now dateByAddingTimeInterval: -60*60*12],			@"NSDATE_LAST12HOURS",
                                                                                        start,                                              @"NSDATE_TODAY",
                                                                                        [start dateByAddingTimeInterval: -60*60*24],        @"NSDATE_YESTERDAY",
                                                                                        [start dateByAddingTimeInterval: -60*60*24*2],		@"NSDATE_2DAYS",
                                                                                        [start dateByAddingTimeInterval: -60*60*24*7],		@"NSDATE_WEEK",
                                                                                        [start dateByAddingTimeInterval: -60*60*24*31],		@"NSDATE_MONTH",
                                                                                        [start dateByAddingTimeInterval: -60*60*24*31*2],	@"NSDATE_2MONTHS",
                                                                                        [start dateByAddingTimeInterval: -60*60*24*31*3],	@"NSDATE_3MONTHS",
                                                                                        [start dateByAddingTimeInterval: -60*60*24*365],    @"NSDATE_YEAR",
                                                                                        nil]];
}





@end
