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


#import "OsiriXSCPDataHandler.h"
#import "DicomFile.h"
#import "DicomFileDCMTKCategory.h"
#import "browserController.h"
#import "AppController.h"
#import "DicomImage.h"
#import "DicomStudy.h"
#import "DicomSeries.h"
#import "DICOMToNSString.h"
#import "MutableArrayCategory.h"
#import "NSException+N2.h"

#include "dctk.h"

char currentDestinationMoveAET[ 60] = "";

extern NSManagedObjectContext *staticContext;

@implementation OsiriXSCPDataHandler

@synthesize callingAET;

- (void)dealloc
{
	context = 0L;
	
	for( int i = 0 ; i < moveArraySize; i++) free( moveArray[ i]);
	free( moveArray);
	moveArray = nil;
	moveArraySize = 0;
	
	if( logFiles) free( logFiles);
	logFiles = nil;
	
	[findArray release];
	findArray = nil;
	
	[specificCharacterSet release];
	[findEnumerator release];
	
	[callingAET release];
	[findTemplate release];
	
	[super dealloc];
}

- (id)init
{
	if (self = [super init])
	{
	}
	return self;
}

+ (id)allocRequestDataHandler
{
	return [[OsiriXSCPDataHandler alloc] init];
}

//- (NSPredicate *)predicateForObject:(DCMObject *)object
//{
//	NSPredicate *compoundPredicate = [NSPredicate predicateWithValue:YES];
//	NSEnumerator *enumerator = [[object attributes] keyEnumerator];
//	NSString *searchType = [object attributeValueWithName:@"Query/RetrieveLevel"];
//	
//	//should be STUDY, SERIES OR IMAGE
//	
//	NSString *key;
//	while (key = [enumerator nextObject])
//	{
//		id value;
//		//NSExpression *expression;
//		NSPredicate *predicate;
//		DCMAttribute *attr = [[object attributes] objectForKey:key];
//		if ([searchType isEqualToString:@"STUDY"])
//		{
//			// check for dicom
//			compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"hasDICOM == %d", YES], compoundPredicate, nil]];
//			//compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject: compoundPredicate, nil]];
//			if ([[[attr attrTag] name] isEqualToString:@"PatientsName"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"name LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"PatientID"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"patientID LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"AccessionNumber"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"accessionNumber LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"StudyInstanceUID"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"studyInstanceUID == %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"StudyID"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"id == %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"StudyDescription"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"studyName LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"InstitutionName"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"institutionName LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"ReferringPhysiciansName"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"referringPhysician LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"PerformingPhysiciansName"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"performingPhysician LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"PatientsBirthDate"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"dateOfBirth >= CAST(%lf, \"NSDate\") AND dateOfBirth <= CAST(%lf, \"NSDate\")", [self startOfDay:value], [self endOfDay:value]];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"StudyDate"])
//			{
//				value = [attr value];
//				if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];	
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];			
//					/*			
//					subPredicate = [NSPredicate predicateWithFormat: @"date >= CAST(%lf, \"NSDate\") AND date <= CAST(%lf, \"NSDate\")", [timeIntervalStart timeIntervalSinceReferenceDate], [timeIntervalEnd timeIntervalSinceReferenceDate]];
//					*/
//					predicate = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", [self endOfDay:query]];
//
//				}
//				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[[attr value] queryString] stringByTrimmingCharactersInSet:set];		
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];			
//					predicate = [NSPredicate predicateWithFormat:@"date  >= CAST(%lf, \"NSDate\")",[self startOfDay:query]];
//				}
//				else if ([(DCMCalendarDate *)value isQuery])
//				{
//					value = [attr value];
//					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
//					if ([values count] == 2)
//					{
//						DCMCalendarDate *startDate = [DCMCalendarDate dicomDate:[values objectAtIndex:0]];
//						DCMCalendarDate *endDate = [DCMCalendarDate dicomDate:[values objectAtIndex:1]];
//						//NSLog(@"startDate: %@", [startDate description]);
//						//NSLog(@"endDate :%@", [endDate description]);
//						//need two predicates for range
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\")", [self startOfDay:startDate]];
//						
//						//expression = [NSExpression expressionForConstantValue:(NSDate *)endDate];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")",[self endOfDay:endDate]];
//						
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
//					}
//					else
//						predicate = nil;
//				}
//				else
//				{
//					predicate = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\") AND date < CAST(%lf, \"NSDate\")",[self startOfDay:value],[self endOfDay:value]];
//				}
//			}
//			
//			else if ([[[attr attrTag] name] isEqualToString:@"StudyTime"])
//			{
//				value = [attr value];
//				if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];	
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime <= %@",query];
//				}
//				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[[attr value] queryString] stringByTrimmingCharactersInSet:set];		
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime >= %@",query];
//				}
//				else if ([(DCMCalendarDate *)value isQuery])
//				{
//					value = [attr value];
//					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
//					if ([values count] == 2)
//					{
//						NSNumber *startDate = [NSNumber numberWithInt:[[values objectAtIndex:0] intValue]];
//						NSNumber *endDate = [NSNumber numberWithInt:[[values objectAtIndex:1] intValue]];
//						
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"dicomTime >= %@",startDate];
//						
//						//expression = [NSExpression expressionForConstantValue:(NSDate *)endDate];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"dicomTime <= %@",endDate];
//						
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
//					}
//					else
//						predicate = nil;
//				}
//				else
//				{
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime == %@", [value dateAsNumber]];
//				}
//			}
//			else
//				predicate = nil;
//				
//			if (predicate)
//				compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate, compoundPredicate, nil]];
//		}
//		else if ([searchType isEqualToString:@"SERIES"])
//		{
//			if ([[[attr attrTag] name] isEqualToString:@"StudyInstanceUID"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"study.studyInstanceUID == %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"SeriesInstanceUID"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"seriesDICOMUID == %@", value];
//			} 
//			else if ([[[attr attrTag] name] isEqualToString:@"SeriesDescription"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"name LIKE[cd] %@", value];
//			}
//			else if ([[[attr attrTag] name] isEqualToString:@"SeriesNumber"])
//			{
//				value = [attr value];
//				predicate = [NSPredicate predicateWithFormat:@"id == %@", value];
//			} 
//			else if ([[[attr attrTag] name] isEqualToString:@"SeriesDate"])
//			{
//				value = [attr value];
//				if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];	
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];			
//					//id newValue = [DCMCalendarDate dicomDate:query];
//					predicate = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", [self endOfDay:query]];
//
//				}
//				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[[attr value] queryString] stringByTrimmingCharactersInSet:set];		
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];			
//					predicate = [NSPredicate predicateWithFormat:@"date  >= CAST(%lf, \"NSDate\")",[self startOfDay:query]];
//				}
//				else if ([(DCMCalendarDate *)value isQuery])
//				{
//					value = [attr value];
//					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
//					if ([values count] == 2)
//					{
//						DCMCalendarDate *startDate = [DCMCalendarDate dicomDate:[values objectAtIndex:0]];
//						DCMCalendarDate *endDate = [DCMCalendarDate dicomDate:[values objectAtIndex:1]];
//						
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\")", [self startOfDay:startDate]];
//						
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")",[self endOfDay:endDate]];
//						
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
//					}
//					else
//						predicate = nil;
//				}
//				else{
//					predicate = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\") AND date < CAST(%lf, \"NSDate\")",[self startOfDay:value],[self endOfDay:value]];
//				}
//			}
//			
//			else if ([[[attr attrTag] name] isEqualToString:@"SeriesTime"])
//			{
//				value = [attr value];
//				if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];	
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime <= %@",query];
//				}
//				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
//				{
//					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
//					NSString *queryString = [[[attr value] queryString] stringByTrimmingCharactersInSet:set];		
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime >= %@",query];
//				}
//				else if ([(DCMCalendarDate *)value isQuery])
//				{
//					value = [attr value];
//					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
//					if ([values count] == 2){
//						NSNumber *startDate = [NSNumber numberWithInt:[[values objectAtIndex:0] intValue]];
//						NSNumber *endDate = [NSNumber numberWithInt:[[values objectAtIndex:1] intValue]];
//
//						//need two predicates for range
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"dicomTime >= %@",startDate];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"dicomTime <= %@",endDate];
//						
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
//					}
//					else
//						predicate = nil;
//				}
//				else
//				{
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime == %@", [value dateAsNumber]];
//				}
//			}
//			else
//				predicate = nil;
//				
//			if (predicate)
//				compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate, compoundPredicate, nil]];
//
//		}
//		else if ([searchType isEqualToString:@"IMAGE"])
//		{
//			
//		}
//	}
//	
//	return compoundPredicate;
//}

-(NSTimeInterval) endOfDay:(NSCalendarDate *)day
{
	NSCalendarDate *start = [NSCalendarDate dateWithYear:[day yearOfCommonEra] month:[day monthOfYear] day:[day dayOfMonth] hour:0 minute:0 second:0 timeZone: nil];
	NSCalendarDate *end = [start dateByAddingYears:0 months:0 days:0 hours:24 minutes:0 seconds:0];
	return [end timeIntervalSinceReferenceDate];
}

-(NSTimeInterval) startOfDay:(NSCalendarDate *)day
{
	NSCalendarDate	*start = [NSCalendarDate dateWithYear:[day yearOfCommonEra] month:[day monthOfYear] day:[day dayOfMonth] hour:0 minute:0 second:0 timeZone: nil];
	return [start timeIntervalSinceReferenceDate];
}

- (NSPredicate*) predicateWithString: (NSString*) s forField: (NSString*) f any: (BOOL) any
{
	if( [s length] > 3)
	{
		for( int i = 1 ; i < [s length]-1; i++)
		{
			if( [s characterAtIndex: i] == '*') // contains a wildchar
			{
				if( any)
				{
					return [NSPredicate predicateWithFormat:@"ANY %K LIKE[cd] %@", f, s];
				}
				else
				{
					return [NSPredicate predicateWithFormat:@"%K LIKE[cd] %@", f, s];
				}
			}
		}
	}
	
	NSString *v = [s stringByReplacingOccurrencesOfString: @"*" withString:@""];
	NSPredicate *predicate = nil;
	
	if( any)
	{
		if( [v length] == 0)
			predicate = [NSPredicate predicateWithValue: YES];
		else if( [s characterAtIndex: 0] == '*' && [s characterAtIndex: [s length]-1] == '*')
			predicate = [NSPredicate predicateWithFormat:@"ANY %K CONTAINS[cd] %@", f, v];
		else if( [s characterAtIndex: 0] == '*')
			predicate = [NSPredicate predicateWithFormat:@"ANY %K ENDSWITH[cd] %@", f, v];
		else if( [s characterAtIndex: [s length]-1] == '*')
			predicate = [NSPredicate predicateWithFormat:@"ANY %K BEGINSWITH[cd] %@", f, v];
		else
			predicate = [NSPredicate predicateWithFormat:@"(ANY %K BEGINSWITH[cd] %@) AND (ANY %K ENDSWITH[cd] %@)", f, v, f, v];
	}
	else
	{
		if( [v length] == 0)
			predicate = [NSPredicate predicateWithValue: YES];
		else if( [s characterAtIndex: 0] == '*' && [s characterAtIndex: [s length]-1] == '*')
			predicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", f, v];
		else if( [s characterAtIndex: 0] == '*')
			predicate = [NSPredicate predicateWithFormat:@"%K ENDSWITH[cd] %@", f, v];
		else if( [s characterAtIndex: [s length]-1] == '*')
			predicate = [NSPredicate predicateWithFormat:@"%K BEGINSWITH[cd] %@", f, v];
		else
			predicate = [NSPredicate predicateWithFormat:@"(%K BEGINSWITH[cd] %@) AND (%K ENDSWITH[cd] %@)", f, v, f, v];
	}
	
	return predicate;
}

- (NSPredicate*) predicateWithString: (NSString*) s forField: (NSString*) f
{
	return [self predicateWithString: s forField: f any: NO];
}

- (NSPredicate *)predicateForDataset:( DcmDataset *)dataset compressedSOPInstancePredicate: (NSPredicate**) csopPredicate seriesLevelPredicate: (NSPredicate**) SLPredicate
{
	NSPredicate *compoundPredicate = nil;
	NSPredicate *seriesLevelPredicate = nil;
	const char *sType = NULL;
	const char *scs = NULL;
	
	NS_DURING 
	dataset->findAndGetString (DCM_QueryRetrieveLevel, sType, OFFalse);
	
	if (dataset->findAndGetString (DCM_SpecificCharacterSet, scs, OFFalse).good() && scs != NULL)
	{
		[specificCharacterSet release];
		
		NSArray	*c = nil;
		
		@try
		{
			c = [[NSString stringWithCString: scs] componentsSeparatedByString:@"\\"];
		
			if( [c count] > 0)
				specificCharacterSet = [[c objectAtIndex: 0] retain];
			else
				specificCharacterSet = [[NSString alloc] initWithCString: scs];
		}
		@catch (NSException * e)
		{
			NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		}
		
		encoding = [NSString encodingForDICOMCharacterSet: specificCharacterSet];
	}
	else
	{
		[specificCharacterSet release];
		specificCharacterSet = [[NSString alloc] initWithString:@"ISO_IR 100"];
		encoding = NSISOLatin1StringEncoding;
	}
	
	if (strcmp(sType, "STUDY") == 0) 
		compoundPredicate = [NSPredicate predicateWithFormat:@"hasDICOM == %d", YES];
	else if (strcmp(sType, "SERIES") == 0)
		compoundPredicate = [NSPredicate predicateWithFormat:@"study.hasDICOM == %d", YES];
	else if (strcmp(sType, "IMAGE") == 0)
		compoundPredicate = [NSPredicate predicateWithFormat:@"series.study.hasDICOM == %d", YES];
	
	NSString *dcmstartTime = nil;
	NSString *dcmendTime = nil;
	NSString *dcmstartDate = nil;
	NSString *dcmendDate = nil;
	
	int elemCount = (int)(dataset->card());
    for (int elemIndex=0; elemIndex<elemCount; elemIndex++)
	{
		NSPredicate *predicate = nil;
		DcmElement* dcelem = dataset->getElement(elemIndex);
		DcmTagKey key = dcelem->getTag().getXTag();
		
		if (strcmp(sType, "STUDY") == 0)
		{
			if (key == DCM_PatientsName)
			{
				char *pn;
				if (dcelem->getString(pn).good() && pn != NULL)
				{
					NSString *patientNameString = [NSString stringWithCString:pn  DICOMEncoding:specificCharacterSet];
					
					patientNameString = [patientNameString stringByReplacingOccurrencesOfString: @", " withString:@" "];
					patientNameString = [patientNameString stringByReplacingOccurrencesOfString: @"," withString:@" "];
					patientNameString = [patientNameString stringByReplacingOccurrencesOfString: @"^ " withString:@" "];
					patientNameString = [patientNameString stringByReplacingOccurrencesOfString: @"^" withString:@" "];
					
					predicate = [self predicateWithString: patientNameString forField: @"name"];
				}
			}
			else if (key == DCM_PatientID)
			{
				char *pid;
				if (dcelem->getString(pid).good() && pid != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:pid  DICOMEncoding:nil] forField: @"patientID"];
			}
			else if (key == DCM_AccessionNumber)
			{
				char *pid;
				if (dcelem->getString(pid).good() && pid != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:pid  DICOMEncoding:nil] forField: @"accessionNumber"];
			}
			else if (key == DCM_StudyInstanceUID)
			{
				char *suid;
				if (dcelem->getString(suid).good() && suid != NULL)
					predicate = [NSPredicate predicateWithFormat:@"studyInstanceUID == %@", [NSString stringWithCString:suid  DICOMEncoding:nil]];
			}
			else if (key == DCM_StudyID)
			{
				char *sid;
				if (dcelem->getString(sid).good() && sid != NULL)
					predicate = [NSPredicate predicateWithFormat:@"id == %@", [NSString stringWithCString:sid  DICOMEncoding:nil]];
			}
			else if (key ==  DCM_StudyDescription)
			{
				char *sd;
				if (dcelem->getString(sd).good() && sd != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:sd  DICOMEncoding:specificCharacterSet] forField: @"studyName"];
			}
			else if (key ==  DCM_ImageComments || key ==  DCM_StudyComments)
			{
				char *sd;
				if (dcelem->getString(sd).good() && sd != NULL)
				{
					NSPredicate *p1 = [self predicateWithString: [NSString stringWithCString:sd  DICOMEncoding:specificCharacterSet] forField: @"comment"];
					NSPredicate *p2 = [self predicateWithString: [NSString stringWithCString:sd  DICOMEncoding:specificCharacterSet] forField: @"series.comment" any: YES];
					
					predicate = [NSCompoundPredicate orPredicateWithSubpredicates: [NSArray arrayWithObjects: p1, p2, nil]];
				}
			}
			else if (key == DCM_InstitutionName)
			{
				char *inn;
				if (dcelem->getString(inn).good() && inn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:inn  DICOMEncoding:specificCharacterSet] forField: @"institutionName"];
			}
			else if (key == DCM_ReferringPhysiciansName)
			{
				char *rpn;
				if (dcelem->getString(rpn).good() && rpn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:rpn  DICOMEncoding:specificCharacterSet] forField: @"referringPhysician"];
			}
			else if (key ==  DCM_PerformingPhysiciansName)
			{
				char *ppn;
				if (dcelem->getString(ppn).good() && ppn != NULL)
					predicate = [self predicateWithString: [NSString stringWithCString:ppn  DICOMEncoding:specificCharacterSet] forField: @"performingPhysician"];
			}
			else if (key ==  DCM_ModalitiesInStudy)
			{
				char *mis;
				if (dcelem->getString(mis).good() && mis != NULL)
				{
					predicate = [NSPredicate predicateWithFormat:@"(ANY series.modality IN %@)", [[NSString stringWithCString:mis DICOMEncoding:nil] componentsSeparatedByString:@"\\"]];
				}
			}
			else if (key ==  DCM_Modality)
			{
				char *mis;
				if (dcelem->getString(mis).good() && mis != NULL)
				{
					predicate = [NSPredicate predicateWithFormat:@"(ANY series.modality IN %@)", [[NSString stringWithCString:mis DICOMEncoding:nil] componentsSeparatedByString:@"\\"]];
				}
			}
			else if (key == DCM_PatientsBirthDate)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL) {
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomDate:dateString];
				}
				if (!value) {
					predicate = nil;
				}
				else
				{
					predicate = [NSPredicate predicateWithFormat:@"(dateOfBirth >= CAST(%lf, \"NSDate\")) AND (dateOfBirth < CAST(%lf, \"NSDate\"))", [self startOfDay:value], [self endOfDay:value]];
				}
			}
			
			else if (key == DCM_StudyDate)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomDate:dateString];
				}
				
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmendDate = queryString;

				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmstartDate = queryString;
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartDate = [values objectAtIndex:0];
						dcmendDate = [values objectAtIndex:1];
					}
					else
						predicate = nil;
				}
				else{
					predicate = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\") AND date < CAST(%lf, \"NSDate\")",[self startOfDay:value],[self endOfDay:value]];
				}
			}
			else if (key == DCM_StudyTime)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomTime:dateString];
				}
  
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmendTime = queryString;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmstartTime = queryString;
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartTime = [values objectAtIndex:0];
						dcmendTime = [values objectAtIndex:1];
					}
					else
						predicate = nil;
				}
				else
				{
					predicate = [NSPredicate predicateWithFormat:@"dicomTime == %@", [value dateAsNumber]];
				}
			}
			else
				predicate = nil;
		}
		else if (strcmp(sType, "SERIES") == 0)
		{
			if (key == DCM_StudyInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"study.studyInstanceUID == %@", [NSString stringWithCString:string  DICOMEncoding:nil]];
			}
			else if (key == DCM_SeriesInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
				{
					NSString *u = [NSString stringWithCString:string  DICOMEncoding:nil];
					NSArray *uids = [u componentsSeparatedByString:@"\\"];
					NSArray *predicateArray = [NSArray array];
					
					int x;
					for(x = 0; x < [uids count]; x++)
					{
						NSString *curString = [uids objectAtIndex: x];
						
						predicateArray = [predicateArray arrayByAddingObject: [NSPredicate predicateWithFormat:@"seriesDICOMUID == %@", curString]];
					}
					
					predicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
				}
			} 
			else if (key == DCM_SeriesDescription)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [self predicateWithString:[NSString stringWithCString:string  DICOMEncoding:specificCharacterSet] forField:@"name"];
			}
			else if (key == DCM_SeriesNumber)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"id == %@", [NSString stringWithCString:string  DICOMEncoding:specificCharacterSet]];
			}
			else if (key ==  DCM_Modality)
			{
				char *mis;
				if (dcelem->getString(mis).good() && mis != NULL)
					predicate = [NSPredicate predicateWithFormat:@"study.modality == %@", [NSString stringWithCString:mis  DICOMEncoding:nil]];
			}
			
			else if (key == DCM_SeriesDate)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomDate:dateString];
				}
  
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					
					dcmendDate = queryString;
					
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];
//					predicate = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", [self endOfDay:query]];

				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];		
					
					dcmstartDate = queryString;
					
//					DCMCalendarDate *query = [DCMCalendarDate dicomDate:queryString];			
//					predicate = [NSPredicate predicateWithFormat:@"date  >= CAST(%lf, \"NSDate\")",[self startOfDay:query]];
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartDate = [values objectAtIndex:0];
						dcmendDate = [values objectAtIndex:1];
						
//						DCMCalendarDate *startDate = [DCMCalendarDate dicomDate:[values objectAtIndex:0]];
//						DCMCalendarDate *endDate = [DCMCalendarDate dicomDate:[values objectAtIndex:1]];
//
//						//need two predicates for range
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\")", [self startOfDay:startDate]];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")",[self endOfDay:endDate]];
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
					}
					else
						predicate = nil;
				}
				else
				{
					predicate = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\") AND date < CAST(%lf, \"NSDate\")",[self startOfDay:value],[self endOfDay:value]];
				}
			}
			else if (key == DCM_SeriesTime)
			{
				char *aDate;
				DCMCalendarDate *value = nil;
				if (dcelem->getString(aDate).good() && aDate != NULL)
				{
					NSString *dateString = [NSString stringWithCString:aDate DICOMEncoding:nil];
					value = [DCMCalendarDate dicomTime:dateString];
				}
  
				if (!value)
				{
					predicate = nil;
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasPrefix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];	
					dcmendTime = queryString;
					
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime <= %@",query];
				}
				else if ([(DCMCalendarDate *)value isQuery] && [[(DCMCalendarDate *)value queryString] hasSuffix:@"-"])
				{
					NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-"];
					NSString *queryString = [[value queryString] stringByTrimmingCharactersInSet:set];
					dcmstartTime = queryString;
					
//					NSNumber *query = [NSNumber numberWithInt:[queryString intValue]];			
//					predicate = [NSPredicate predicateWithFormat:@"dicomTime >= %@",query];
				}
				else if ([(DCMCalendarDate *)value isQuery])
				{
					NSArray *values = [[value queryString] componentsSeparatedByString:@"-"];
					if ([values count] == 2)
					{
						dcmstartTime = [values objectAtIndex:0];
						dcmendTime = [values objectAtIndex:1];
						
//						NSNumber *startDate = [NSNumber numberWithInt:[[values objectAtIndex:0] intValue]];
//						NSNumber *endDate = [NSNumber numberWithInt:[[values objectAtIndex:1] intValue]];
//
//						//need two predicates for range
//						NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"dicomTime >= %@",startDate];
//						NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"dicomTime <= %@",endDate];
//						predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
					}
					else
						predicate = nil;
				}

				else
				{
					predicate = [NSPredicate predicateWithFormat:@"dicomTime == %@", [value dateAsNumber]];
				}
			}
			else
			{
				predicate = nil;
			}
		}
		else if (strcmp(sType, "IMAGE") == 0)
		{
			if (key == DCM_StudyInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
				{
					predicate = [NSPredicate predicateWithFormat:@"study.studyInstanceUID == %@", [NSString stringWithCString:string  DICOMEncoding:nil]];
				
					if( seriesLevelPredicate == nil)
						seriesLevelPredicate = predicate;
					else
						seriesLevelPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate, seriesLevelPredicate, nil]];
						
					*SLPredicate = seriesLevelPredicate;
					
					predicate = nil;
				}
			}
			else if (key == DCM_SeriesInstanceUID)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
				{
					predicate = [NSPredicate predicateWithFormat:@"seriesDICOMUID == %@", [NSString stringWithCString:string  DICOMEncoding:nil]];
					
					if( seriesLevelPredicate == nil)
						seriesLevelPredicate = predicate;
					else
						seriesLevelPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: seriesLevelPredicate, predicate, nil]];
					
					*SLPredicate = seriesLevelPredicate;
					
					predicate = nil;
				}
			} 
			else if (key == DCM_SOPInstanceUID)
			{
				char *string = nil;
				
				if (dcelem->getString(string).good() && string != NULL)
				{
					NSArray *uids = [[NSString stringWithCString:string  DICOMEncoding:nil] componentsSeparatedByString:@"\\"];
					NSArray *predicateArray = [NSArray array];
					
					for(int x = 0; x < [uids count]; x++)
					{
						NSPredicate	*p = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"compressedSopInstanceUID"] rightExpression: [NSExpression expressionForConstantValue: [DicomImage sopInstanceUIDEncodeString: [uids objectAtIndex: x]]] customSelector: @selector( isEqualToSopInstanceUID:)];
						predicateArray = [predicateArray arrayByAddingObject: p];
					}
					
					predicate = [NSPredicate predicateWithFormat:@"compressedSopInstanceUID != NIL"];
					*csopPredicate = [NSCompoundPredicate orPredicateWithSubpredicates: predicateArray];
				}
			}
			else if (key == DCM_InstanceNumber)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"instanceNumber == %d", [[NSString stringWithCString:string  DICOMEncoding:nil] intValue]];
			}
			else if (key == DCM_NumberOfFrames)
			{
				char *string;
				if (dcelem->getString(string).good() && string != NULL)
					predicate = [NSPredicate predicateWithFormat:@"numberOfFrames == %d", [[NSString stringWithCString:string  DICOMEncoding:nil] intValue]];
			}
		}
		else
		{
			NSLog( @"OsiriX supports ONLY STUDY, SERIES, IMAGE levels ! Current level: %s", sType);
		}
		
		if (predicate)
			compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: compoundPredicate, predicate, nil]];
	}
	
	{
		NSPredicate *predicate = nil;
		
		NSTimeInterval startDate = nil;
		NSTimeInterval endDate = nil;
		
		if( dcmstartDate)
		{
			if( dcmstartTime)
			{
				DCMCalendarDate *time = [DCMCalendarDate dicomTime: dcmstartTime];
				startDate = [[[DCMCalendarDate dicomDate: dcmstartDate] dateByAddingYears: 0 months: 0 days: 0 hours: [time hourOfDay] minutes: [time minuteOfHour] seconds: [time secondOfMinute]] timeIntervalSinceReferenceDate];
			}
			else startDate = [self startOfDay: [DCMCalendarDate dicomDate: dcmstartDate]];
		}
		
		if( dcmendDate)
		{
			if( dcmendTime)
			{
				DCMCalendarDate *time = [DCMCalendarDate dicomTime: dcmendTime];
				endDate = [[[DCMCalendarDate dicomDate: dcmendDate] dateByAddingYears: 0 months: 0 days: 0 hours: [time hourOfDay] minutes: [time minuteOfHour] seconds: [time secondOfMinute]] timeIntervalSinceReferenceDate];
			}
			else endDate = [self endOfDay: [DCMCalendarDate dicomDate: dcmendDate]];
		}
		
		if( startDate && endDate)
		{
			//need two predicates for range
			
			NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"date >= CAST(%lf, \"NSDate\")", startDate];
			NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", endDate];
			predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate1, predicate2, nil]];
		}
		else if( startDate)
		{		
			predicate = [NSPredicate predicateWithFormat:@"date  >= CAST(%lf, \"NSDate\")", startDate];
		}
		else if( endDate)
		{
			predicate = [NSPredicate predicateWithFormat:@"date < CAST(%lf, \"NSDate\")", endDate];
		}
		
		if (predicate)
			compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: predicate, compoundPredicate, nil]];
	}
	
	NS_HANDLER
		NSLog(@"Exception getting predicate: %@ for dataset\n", [localException description]);
		dataset->print(COUT);
	NS_ENDHANDLER
	
	return compoundPredicate;
}

- (const char*) encodeString: (NSString*) str image: (NSManagedObject*) image
{
	if( str == nil)
		return nil;
		
	const char *a = [str cStringUsingEncoding: encoding];
	
	if( a == nil)
	{
		NSLog( @"--- cannot encode %@ -> switch to UTF-8 (ISO_IR 192) encoding", str);
		
		[specificCharacterSet release];
		specificCharacterSet = [[NSString alloc] initWithString: @"ISO_IR 192"];
		encoding = [NSString encodingForDICOMCharacterSet: specificCharacterSet];
		
		a = [str cStringUsingEncoding:encoding];
		
		if( a == nil)
		{
			NSLog( @"--- cannot encode %@ -> switch to dcm file encoding", str);
			
			NSArray	*c = [DicomFile getEncodingArrayForFile: [image valueForKey:@"completePathResolved"]];
			
			if( c)
			{
				for( NSString *encodingString in c)
				{
					if( [str cStringUsingEncoding: [NSString encodingForDICOMCharacterSet: encodingString]])
					{
						[specificCharacterSet release];
						specificCharacterSet = [[NSString alloc] initWithString: encodingString];
						encoding = [NSString encodingForDICOMCharacterSet: specificCharacterSet];
						
						a = [str cStringUsingEncoding:encoding];
						
						break;
					}
				}
			}
		}
	}
	
	if( a == nil)
		NSLog( @"***** encodeString FAILED for: %@", [image valueForKey:@"completePathResolved"]);
	
	return a;
}

- (void)studyDatasetForFetchedObject:(id)fetchedObject dataset:(DcmDataset *)dataset
{
	@try
	{
		NSManagedObject *image = [[[[fetchedObject valueForKey: @"series"] anyObject] valueForKey: @"images"] anyObject];
		
		for( NSString *keyString in [findTemplate allKeys])
		{
			NSArray *elementAndGroup = [keyString componentsSeparatedByString: @","];
			
			if( [elementAndGroup count] != 2)
			{
				NSLog( @"***** studyDatasetForFetchedObject ERROR");
			}
			else
			{
				DcmTagKey key( [[elementAndGroup objectAtIndex: 1] intValue], [[elementAndGroup objectAtIndex: 0] intValue]);
				
				if( key == DCM_PatientsName && [fetchedObject valueForKey:@"name"])
				{
					dataset->putAndInsertString( DCM_PatientsName, [self encodeString: [fetchedObject valueForKey:@"name"] image: image]);
				}
				
				else if( key == DCM_PatientID && [fetchedObject valueForKey:@"patientID"])
				{
					dataset->putAndInsertString(DCM_PatientID, [self encodeString: [fetchedObject valueForKey:@"patientID"] image: image]);
				}
				
				else if( key == DCM_PatientsSex && [fetchedObject valueForKey:@"patientSex"])
				{
					dataset->putAndInsertString(DCM_PatientsSex, [self encodeString: [fetchedObject valueForKey:@"patientSex"] image: image]);
				}
				
				else if( key == DCM_AccessionNumber && [fetchedObject valueForKey:@"accessionNumber"])
				{
					dataset->putAndInsertString(DCM_AccessionNumber, [self encodeString: [fetchedObject valueForKey:@"accessionNumber"] image: image]);
				}
				
				else if( key == DCM_StudyDescription && [fetchedObject valueForKey:@"studyName"])
				{
					dataset->putAndInsertString( DCM_StudyDescription, [self encodeString: [fetchedObject valueForKey:@"studyName"] image: image]);
				}
				
				else if( key == DCM_ImageComments && [fetchedObject valueForKey:@"comment"])
				{
					dataset->putAndInsertString( DCM_ImageComments, [self encodeString: [fetchedObject valueForKey:@"comment"] image: image]);
				}
				
				else if( key == DCM_StudyComments && [fetchedObject valueForKey:@"comment"])
				{
					dataset->putAndInsertString( DCM_StudyComments, [self encodeString: [fetchedObject valueForKey:@"comment"] image: image]);
				}
				
				else if( key == DCM_PatientsBirthDate && [fetchedObject valueForKey:@"dateOfBirth"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKey:@"dateOfBirth"]];
					dataset->putAndInsertString(DCM_PatientsBirthDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyDate && [fetchedObject valueForKey:@"date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKey:@"date"]];
					dataset->putAndInsertString(DCM_StudyDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyTime && [fetchedObject valueForKey:@"date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKey:@"date"]];
					dataset->putAndInsertString(DCM_StudyTime, [[dicomDate timeString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyInstanceUID && [fetchedObject valueForKey:@"studyInstanceUID"])
				{
					dataset->putAndInsertString(DCM_StudyInstanceUID, [[fetchedObject valueForKey:@"studyInstanceUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
				}
				else if( key == DCM_StudyID && [fetchedObject valueForKey:@"id"])
				{
					dataset->putAndInsertString(DCM_StudyID, [[fetchedObject valueForKey:@"id"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
				}
				else if( key == DCM_ModalitiesInStudy && [fetchedObject valueForKey:@"modality"])
				{
					NSMutableArray *modalities = [NSMutableArray array];
				
					BOOL SC = NO, SR = NO;
					
					for( NSString *m in [[fetchedObject valueForKeyPath:@"series.modality"] allObjects])
					{
						if( [modalities containsString: m] == NO)
						{
							if( [m isEqualToString:@"SR"]) SR = YES;
							else if( [m isEqualToString:@"SC"]) SC = YES;
							else [modalities addObject: m];
						}
					}
					
					if( SC) [modalities addObject: @"SC"];
					if( SR) [modalities addObject: @"SR"];
				
					dataset->putAndInsertString(DCM_ModalitiesInStudy, [[modalities componentsJoinedByString:@"\\"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_ReferringPhysiciansName && [fetchedObject valueForKey:@"referringPhysician"])
				{
					dataset->putAndInsertString(DCM_ReferringPhysiciansName, [self encodeString: [fetchedObject valueForKey:@"referringPhysician"] image: image]);
				}
				else if( key == DCM_PerformingPhysiciansName && [fetchedObject valueForKey:@"performingPhysician"])
				{
					dataset->putAndInsertString(DCM_PerformingPhysiciansName, [self encodeString: [fetchedObject valueForKey:@"performingPhysician"] image: image]);
				}
				else if( key == DCM_InstitutionName && [fetchedObject valueForKey:@"institutionName"])
				{
					dataset->putAndInsertString(DCM_InstitutionName, [self encodeString: [fetchedObject valueForKey:@"institutionName"] image: image]);
				}
				else if( key == DCM_NumberOfStudyRelatedInstances && [fetchedObject valueForKey:@"noFiles"])
				{
					int numberInstances = [[fetchedObject valueForKey:@"rawNoFiles"] intValue];
					char value[10];
					sprintf(value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfStudyRelatedInstances, value);
				}
				else if( key == DCM_NumberOfStudyRelatedSeries && [fetchedObject valueForKey:@"series"])
				{
					int numberInstances = [[fetchedObject valueForKey:@"series"] count];
					char value[10];
					sprintf(value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfStudyRelatedSeries, value);
				}
				else dataset->insertEmptyElement( key, OFTrue);
			}
		}
		
		dataset->putAndInsertString(DCM_QueryRetrieveLevel, "STUDY");
		
		if( specificCharacterSet)
			dataset->putAndInsertString(DCM_SpecificCharacterSet, [specificCharacterSet UTF8String]);
	}
	
	@catch (NSException *e)
	{
		NSLog( @"studyDatasetForFetchedObject exception: %@", e);
	}
}

- (void)seriesDatasetForFetchedObject:(id)fetchedObject dataset:(DcmDataset *)dataset
{
	@try
	{
		NSManagedObject *image = [[fetchedObject valueForKey: @"images"] anyObject];
		
		for( NSString *keyString in [findTemplate allKeys])
		{
			NSArray *elementAndGroup = [keyString componentsSeparatedByString: @","];
			
			if( [elementAndGroup count] != 2)
			{
				NSLog( @"***** seriesDatasetForFetchedObject ERROR");
			}
			else
			{
				DcmTagKey key( [[elementAndGroup objectAtIndex: 1] intValue], [[elementAndGroup objectAtIndex: 0] intValue]);
				
				if( key == DCM_SeriesDescription && [fetchedObject valueForKey:@"name"])
				{
					dataset->putAndInsertString(DCM_SeriesDescription, [self encodeString: [fetchedObject valueForKey:@"name"] image: image]);
				}
				
				else if( key == DCM_SeriesDate && [fetchedObject valueForKey:@"date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKey:@"date"]];
					dataset->putAndInsertString(DCM_SeriesDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SeriesTime && [fetchedObject valueForKey:@"date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKey:@"date"]];
					dataset->putAndInsertString(DCM_SeriesTime, [[dicomDate timeString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_Modality && [fetchedObject valueForKey:@"modality"])
				{
					dataset->putAndInsertString(DCM_Modality, [[fetchedObject valueForKey:@"modality"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SeriesNumber && [fetchedObject valueForKey:@"id"])
				{
					dataset->putAndInsertString( DCM_SeriesNumber, [[[fetchedObject valueForKey:@"id"] stringValue] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SeriesInstanceUID && [fetchedObject valueForKey:@"seriesDICOMUID"])
				{
					dataset->putAndInsertString(DCM_SeriesInstanceUID, [[fetchedObject valueForKey:@"seriesDICOMUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_NumberOfSeriesRelatedInstances && [fetchedObject valueForKey:@"noFiles"])
				{
					int numberInstances = [[fetchedObject valueForKey:@"rawNoFiles"] intValue];
					char value[ 20];
					sprintf( value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfSeriesRelatedInstances, value);
				}
				
				// ******************** STUDY
				
				else if( key == DCM_PatientsName && [fetchedObject valueForKeyPath:@"study.name"])
				{
					dataset->putAndInsertString(DCM_PatientsName, [self encodeString: [fetchedObject valueForKeyPath:@"study.name"] image: image]);
				}
				
				else if( key == DCM_PatientID && [fetchedObject valueForKeyPath:@"study.patientID"])
				{
					dataset->putAndInsertString(DCM_PatientID, [self encodeString: [fetchedObject valueForKeyPath:@"study.patientID"] image: image]);
				}
				
				else if( key == DCM_PatientsSex && [fetchedObject valueForKeyPath:@"study.patientSex"])
				{
					dataset->putAndInsertString(DCM_PatientsSex, [self encodeString: [fetchedObject valueForKeyPath:@"study.patientSex"] image: image]);
				}
				
				else if( key == DCM_AccessionNumber && [fetchedObject valueForKeyPath:@"study.accessionNumber"])
				{
					dataset->putAndInsertString(DCM_AccessionNumber, [self encodeString: [fetchedObject valueForKeyPath:@"study.accessionNumber"] image: image]);
				}
				
				else if( key == DCM_StudyDescription && [fetchedObject valueForKeyPath:@"study.studyName"])
				{
					dataset->putAndInsertString( DCM_StudyDescription, [self encodeString: [fetchedObject valueForKeyPath:@"study.studyName"] image: image]);
				}
				
				else if( key == DCM_ImageComments && [fetchedObject valueForKeyPath:@"comment"])
				{
					dataset->putAndInsertString( DCM_ImageComments, [self encodeString: [fetchedObject valueForKeyPath:@"comment"] image: image]);
				}
				
				else if( key == DCM_StudyComments && [fetchedObject valueForKeyPath:@"study.comment"])
				{
					dataset->putAndInsertString( DCM_StudyComments, [self encodeString: [fetchedObject valueForKeyPath:@"study.comment"] image: image]);
				}
				
				else if( key == DCM_PatientsBirthDate && [fetchedObject valueForKeyPath:@"study.dateOfBirth"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKeyPath:@"study.dateOfBirth"]];
					dataset->putAndInsertString(DCM_PatientsBirthDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyDate && [fetchedObject valueForKeyPath:@"study.date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKeyPath:@"study.date"]];
					dataset->putAndInsertString(DCM_StudyDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyTime && [fetchedObject valueForKeyPath:@"study.date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKeyPath:@"study.date"]];
					dataset->putAndInsertString(DCM_StudyTime, [[dicomDate timeString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyInstanceUID && [fetchedObject valueForKeyPath:@"study.studyInstanceUID"])
				{
					dataset->putAndInsertString(DCM_StudyInstanceUID, [[fetchedObject valueForKeyPath:@"study.studyInstanceUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
				}
				else if( key == DCM_StudyID && [fetchedObject valueForKeyPath:@"study.id"])
				{
					dataset->putAndInsertString(DCM_StudyID, [[fetchedObject valueForKeyPath:@"study.id"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
				}
				else if( key == DCM_ModalitiesInStudy && [fetchedObject valueForKeyPath:@"study.modality"])
				{
					NSMutableArray *modalities = [NSMutableArray array];
				
					BOOL SC = NO, SR = NO;
					
					NSManagedObject *study = [fetchedObject valueForKeyPath:@"study"];
					
					for( NSString *m in [[study valueForKeyPath:@"modality"] allObjects])
					{
						if( [modalities containsString: m] == NO)
						{
							if( [m isEqualToString:@"SR"]) SR = YES;
							else if( [m isEqualToString:@"SC"]) SC = YES;
							else [modalities addObject: m];
						}
					}
					
					if( SC) [modalities addObject: @"SC"];
					if( SR) [modalities addObject: @"SR"];
				
					dataset->putAndInsertString(DCM_ModalitiesInStudy, [[modalities componentsJoinedByString:@"\\"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_ReferringPhysiciansName && [fetchedObject valueForKeyPath:@"study.referringPhysician"])
				{
					dataset->putAndInsertString(DCM_ReferringPhysiciansName, [self encodeString: [fetchedObject valueForKeyPath:@"study.referringPhysician"] image: image]);
				}
				else if( key == DCM_PerformingPhysiciansName && [fetchedObject valueForKeyPath:@"study.performingPhysician"])
				{
					dataset->putAndInsertString(DCM_PerformingPhysiciansName, [self encodeString: [fetchedObject valueForKeyPath:@"study.performingPhysician"] image: image]);
				}
				else if( key == DCM_InstitutionName && [fetchedObject valueForKeyPath:@"study.institutionName"])
				{
					dataset->putAndInsertString(DCM_InstitutionName, [self encodeString: [fetchedObject valueForKeyPath:@"study.institutionName"] image: image]);
				}
				else if( key == DCM_NumberOfStudyRelatedInstances && [fetchedObject valueForKeyPath:@"study.noFiles"])
				{
					int numberInstances = [[fetchedObject valueForKeyPath:@"study.rawNoFiles"] intValue];
					char value[10];
					sprintf(value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfStudyRelatedInstances, value);
				}
				else if( key == DCM_NumberOfStudyRelatedSeries)
				{
					NSManagedObject *study = [fetchedObject valueForKeyPath:@"study"];
					
					int numberInstances = [[study valueForKeyPath:@"series"] count];
					char value[10];
					sprintf(value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfStudyRelatedSeries, value);
				}
				
				else dataset ->insertEmptyElement( key, OFTrue);
			}
		}
		dataset->putAndInsertString(DCM_QueryRetrieveLevel, "SERIES");
		if( specificCharacterSet)
			dataset->putAndInsertString(DCM_SpecificCharacterSet, [specificCharacterSet UTF8String]);
	}
	
	@catch( NSException *e)
	{
		NSLog( @"********* seriesDatasetForFetchedObject exception: %@");
		dataset->print(COUT);
	}
}

- (void)imageDatasetForFetchedObject:(id)fetchedObject dataset:(DcmDataset *)dataset
{
	@try
	{
		NSManagedObject *image = fetchedObject;
		
		for( NSString *keyString in [findTemplate allKeys])
		{
			NSArray *elementAndGroup = [keyString componentsSeparatedByString: @","];
			
			if( [elementAndGroup count] != 2)
			{
				NSLog( @"***** imageDatasetForFetchedObject ERROR");
			}
			else
			{
				DcmTagKey key( [[elementAndGroup objectAtIndex: 1] intValue], [[elementAndGroup objectAtIndex: 0] intValue]);
				
				if( key == DCM_SliceLocation && [fetchedObject valueForKey: @"sliceLocation"])
				{
					dataset->putAndInsertString( key, [[[fetchedObject valueForKey:@"sliceLocation"] stringValue] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SOPInstanceUID && [fetchedObject valueForKey: @"sopInstanceUID"])
				{
					dataset->putAndInsertString( key, [[fetchedObject valueForKey:@"sopInstanceUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_InstanceNumber && [fetchedObject valueForKey: @"instanceNumber"])
				{
					dataset->putAndInsertString( key, [[[fetchedObject valueForKey:@"instanceNumber"] stringValue] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_NumberOfFrames && [fetchedObject valueForKey: @"numberOfFrames"])
				{
					dataset->putAndInsertString( key, [[[fetchedObject valueForKey:@"numberOfFrames"] stringValue] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				// ******************** SERIES
				
				else if( key == DCM_ImageComments)
				{
					if( [(NSString*) [fetchedObject valueForKeyPath: @"series.comment"] length] > 0)
					{
						dataset->putAndInsertString( key, [self encodeString: [fetchedObject valueForKeyPath:@"series.comment"] image: image]);
					}
					else if( [(NSString*) [fetchedObject valueForKeyPath: @"series.study.comment"] length] > 0)
					{
						dataset->putAndInsertString( key, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.comment"] image: image]);
					}
					else dataset ->insertEmptyElement( key, OFTrue);
				}
				
				else if( key == DCM_SeriesDescription && [fetchedObject valueForKeyPath: @"series.name"])
				{
					dataset->putAndInsertString(DCM_SeriesDescription, [self encodeString: [fetchedObject valueForKeyPath:@"series.name"] image: image]);
				}
				
				else if( key == DCM_SeriesDate && [fetchedObject valueForKeyPath:@"series.date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKeyPath:@"series.date"]];
					dataset->putAndInsertString(DCM_SeriesDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SeriesTime && [fetchedObject valueForKeyPath:@"series.date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKeyPath:@"series.date"]];
					dataset->putAndInsertString(DCM_SeriesTime, [[dicomDate timeString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_Modality && [fetchedObject valueForKeyPath:@"series.modality"])
				{
					dataset->putAndInsertString(DCM_Modality, [[fetchedObject valueForKeyPath:@"series.modality"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SeriesNumber && [fetchedObject valueForKeyPath:@"series.id"])
				{
					dataset->putAndInsertString( DCM_SeriesNumber, [[[fetchedObject valueForKeyPath:@"series.id"] stringValue] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_SeriesInstanceUID && [fetchedObject valueForKeyPath:@"series.seriesDICOMUID"])
				{
					dataset->putAndInsertString(DCM_SeriesInstanceUID, [[fetchedObject valueForKeyPath:@"series.seriesDICOMUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				
				else if( key == DCM_NumberOfSeriesRelatedInstances && [fetchedObject valueForKeyPath:@"series.noFiles"])
				{
					int numberInstances = [[fetchedObject valueForKeyPath:@"series.rawNoFiles"] intValue];
					char value[ 20];
					sprintf( value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfSeriesRelatedInstances, value);
				}
				
				// ******************** STUDY
				
				else if( key == DCM_PatientsName && [fetchedObject valueForKeyPath:@"series.study.name"])
				{
					dataset->putAndInsertString(DCM_PatientsName, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.name"] image: image]);
				}
				
				else if( key == DCM_PatientID && [fetchedObject valueForKeyPath:@"series.study.patientID"])
				{
					dataset->putAndInsertString(DCM_PatientID, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.patientID"] image: image]);
				}
				
				else if( key == DCM_PatientsSex && [fetchedObject valueForKeyPath:@"series.study.patientSex"])
				{
					dataset->putAndInsertString(DCM_PatientsSex, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.patientSex"] image: image]);
				}
				
				else if( key == DCM_AccessionNumber && [fetchedObject valueForKeyPath:@"series.study.accessionNumber"])
				{
					dataset->putAndInsertString(DCM_AccessionNumber, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.accessionNumber"] image: image]);
				}
				
				else if( key == DCM_StudyDescription && [fetchedObject valueForKeyPath:@"series.study.studyName"])
				{
					dataset->putAndInsertString( DCM_StudyDescription, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.studyName"] image: image]);
				}
				
				else if( key == DCM_StudyComments && [fetchedObject valueForKeyPath:@"series.study.comment"])
				{
					dataset->putAndInsertString( DCM_ImageComments, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.comment"] image: image]);
				}
				
				else if( key == DCM_PatientsBirthDate && [fetchedObject valueForKeyPath:@"series.study.dateOfBirth"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKeyPath:@"series.study.dateOfBirth"]];
					dataset->putAndInsertString(DCM_PatientsBirthDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyDate && [fetchedObject valueForKeyPath:@"series.study.date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomDateWithDate:[fetchedObject valueForKeyPath:@"series.study.date"]];
					dataset->putAndInsertString(DCM_StudyDate, [[dicomDate dateString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyTime && [fetchedObject valueForKeyPath:@"series.study.date"])
				{
					DCMCalendarDate *dicomDate = [DCMCalendarDate dicomTimeWithDate:[fetchedObject valueForKeyPath:@"series.study.date"]];
					dataset->putAndInsertString(DCM_StudyTime, [[dicomDate timeString] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_StudyInstanceUID && [fetchedObject valueForKeyPath:@"series.study.studyInstanceUID"])
				{
					dataset->putAndInsertString(DCM_StudyInstanceUID, [[fetchedObject valueForKeyPath:@"series.study.studyInstanceUID"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
				}
				else if( key == DCM_StudyID && [fetchedObject valueForKeyPath:@"series.study.id"])
				{
					dataset->putAndInsertString(DCM_StudyID, [[fetchedObject valueForKeyPath:@"series.study.id"] cStringUsingEncoding:NSISOLatin1StringEncoding]) ;
				}
				else if( key == DCM_ModalitiesInStudy && [fetchedObject valueForKeyPath:@"series.study.modality"])
				{
					NSMutableArray *modalities = [NSMutableArray array];
				
					BOOL SC = NO, SR = NO;
					
					NSManagedObject *study = [fetchedObject valueForKeyPath:@"series.study"];
					
					for( NSString *m in [[study valueForKeyPath:@"series.modality"] allObjects])
					{
						if( [modalities containsString: m] == NO)
						{
							if( [m isEqualToString:@"SR"]) SR = YES;
							else if( [m isEqualToString:@"SC"]) SC = YES;
							else [modalities addObject: m];
						}
					}
					
					if( SC) [modalities addObject: @"SC"];
					if( SR) [modalities addObject: @"SR"];
				
					dataset->putAndInsertString(DCM_ModalitiesInStudy, [[modalities componentsJoinedByString:@"\\"] cStringUsingEncoding:NSISOLatin1StringEncoding]);
				}
				else if( key == DCM_ReferringPhysiciansName && [fetchedObject valueForKeyPath:@"series.study.referringPhysician"])
				{
					dataset->putAndInsertString(DCM_ReferringPhysiciansName, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.referringPhysician"] image: image]);
				}
				else if( key == DCM_PerformingPhysiciansName && [fetchedObject valueForKeyPath:@"series.study.performingPhysician"])
				{
					dataset->putAndInsertString(DCM_PerformingPhysiciansName, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.performingPhysician"] image: image]);
				}
				else if( key == DCM_InstitutionName && [fetchedObject valueForKeyPath:@"series.study.institutionName"])
				{
					dataset->putAndInsertString(DCM_InstitutionName, [self encodeString: [fetchedObject valueForKeyPath:@"series.study.institutionName"] image: image]);
				}
				else if( key == DCM_NumberOfStudyRelatedInstances && [fetchedObject valueForKeyPath:@"series.study.noFiles"])
				{
					int numberInstances = [[fetchedObject valueForKeyPath:@"series.study.rawNoFiles"] intValue];
					char value[10];
					sprintf(value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfStudyRelatedInstances, value);
				}
				else if( key == DCM_NumberOfStudyRelatedSeries)
				{
					NSManagedObject *study = [fetchedObject valueForKeyPath:@"series.study"];
					
					int numberInstances = [[study valueForKeyPath:@"series"] count];
					char value[10];
					sprintf(value, "%d", numberInstances);
					dataset->putAndInsertString(DCM_NumberOfStudyRelatedSeries, value);
				}
				
				else
					dataset ->insertEmptyElement( key, OFTrue);
			}
		}
		dataset->putAndInsertString(DCM_QueryRetrieveLevel, "IMAGE");
		if( specificCharacterSet)
			dataset->putAndInsertString(DCM_SpecificCharacterSet, [specificCharacterSet UTF8String]);
//		dataset->print(COUT);
	}
	
	@catch( NSException *e)
	{
		NSLog( @"********* imageDatasetForFetchedObject exception: %@");
		dataset->print(COUT);
	}
}

- (OFCondition)prepareFindForDataSet: (DcmDataset *) dataset
{
	NSManagedObjectModel *model = [[BrowserController currentBrowser] managedObjectModel];
	NSError *error = nil;
	NSEntityDescription *entity;
	NSPredicate *compressedSOPInstancePredicate = nil, *seriesLevelPredicate = nil;
	NSPredicate *predicate = [self predicateForDataset: dataset compressedSOPInstancePredicate: &compressedSOPInstancePredicate seriesLevelPredicate: &seriesLevelPredicate];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	const char *sType;
	dataset->findAndGetString (DCM_QueryRetrieveLevel, sType, OFFalse);
	OFCondition cond;
	
	[findTemplate release];
	findTemplate = [[NSMutableDictionary alloc] init];
	
//	dataset->print(COUT);
	
	int elemCount = (int)(dataset->card());
    for (int elemIndex=0; elemIndex<elemCount; elemIndex++)
	{
		NSPredicate *predicate = nil;
		DcmElement* dcelem = dataset->getElement(elemIndex);
		DcmTagKey key = dcelem->getTag().getXTag();
		
		[findTemplate setObject: [NSNumber numberWithBool: YES] forKey: [NSString stringWithFormat: @"%d,%d", key.getElement(), key.getGroup()]];
	}
	
	if (strcmp(sType, "STUDY") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Study"];
	else if (strcmp(sType, "SERIES") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Series"];
	else if (strcmp(sType, "IMAGE") == 0) 
		entity = [[model entitiesByName] objectForKey:@"Image"];
	else 
		entity = nil;
	
	if (entity)
	{
		[request setEntity: entity];
		[request setPredicate: predicate];
					
		error = nil;
		
		context = staticContext;
		[context lock];
		
		[findArray release];
		findArray = nil;
		
		@try
		{
			if( seriesLevelPredicate) // First find at series level, then move to image level
			{
				NSFetchRequest *seriesRequest = [[[NSFetchRequest alloc] init] autorelease];
				
				[seriesRequest setEntity: [[model entitiesByName] objectForKey:@"Series"]];
				[seriesRequest setPredicate: seriesLevelPredicate];
				
				NSArray *allSeries = [context executeFetchRequest: seriesRequest error: &error];
				
				findArray = [NSArray array];
				
				for( id series in allSeries)
					findArray = [findArray arrayByAddingObjectsFromArray: [[series valueForKey: @"images"] allObjects]];
				
				findArray = [findArray filteredArrayUsingPredicate: predicate];
			}
			else
				findArray = [context executeFetchRequest:request error:&error];
			
			if( strcmp(sType, "IMAGE") == 0 && compressedSOPInstancePredicate)
				findArray = [findArray filteredArrayUsingPredicate: compressedSOPInstancePredicate];
			
			if( strcmp(sType, "IMAGE") == 0)
				findArray = [findArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"instanceNumber" ascending: YES] autorelease]]];
			
			if( strcmp(sType, "SERIES") == 0)
			  findArray = [findArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: YES] autorelease]]];
			
			[findArray retain];
		}
		@catch (NSException * e)
		{
			NSLog( @"prepareFindForDataSet exception");
			NSLog( @"%@", [e description]);
		}
		
		[context unlock];
		
		if (error)
		{
			[findArray release];
			findArray = nil;
			cond = EC_IllegalParameter;
		}
		else
			cond = EC_Normal;
	}
	else
	{
		[findArray release];
		findArray = nil;
		
		cond = EC_IllegalParameter;
	}
	
	[findEnumerator release];
	findEnumerator = [[findArray objectEnumerator] retain];
	
//	for( int i = 0 ; i < 60; i++)
//	{
//		printf( "tic\r");
//		usleep( 1000000);
//	}
	
	return cond;
	 
}

- (void) updateLog:(NSArray*) mArray
{
	if( [[BrowserController currentBrowser] isNetworkLogsActive] == NO) return;
	if( [mArray count] == 0) return;
	
	char fromTo[ 200] = "";
	
	if( logFiles) free( logFiles);
	
	logFiles = (logStruct*) malloc( sizeof( logStruct));
	
	if ( currentDestinationMoveAET == nil || strcmp( currentDestinationMoveAET, [callingAET UTF8String]) == 0 || strlen( currentDestinationMoveAET) == 0)
	{
		strcpy( fromTo, [callingAET UTF8String]);
	}
	else
	{
		strcpy( fromTo, [callingAET UTF8String]);
		strcat( fromTo, " / ");
		strcat( fromTo, currentDestinationMoveAET);
	}
	
	for( NSManagedObject *object in mArray)
	{
		if( [[object valueForKey:@"type"] isEqualToString: @"Series"])
		{
			FILE * pFile;
			char dir[ 1024], newdir[1024];
			unsigned int random = (unsigned int)time(NULL);
			sprintf( dir, "%s/%s%d", [[BrowserController currentBrowser] cfixedIncomingDirectory], "TEMP.noindex/move_log_", random);
			pFile = fopen (dir,"w+");
			if( pFile)
			{
				strcpy( logFiles->logPatientName, [[object valueForKeyPath:@"study.name"] UTF8String]);
				strcpy( logFiles->logStudyDescription, [[object valueForKeyPath:@"study.studyName"] UTF8String]);
				strcpy( logFiles->logCallingAET, fromTo);
				logFiles->logStartTime = time (NULL);
				strcpy( logFiles->logMessage, "In Progress");
				logFiles->logNumberReceived = 0;
				logFiles->logNumberTotal = [[object valueForKey: @"rawNoFiles"] intValue];
				logFiles->logEndTime = time (NULL);
				strcpy( logFiles->logType, "Move");
				strcpy( logFiles->logEncoding, "UTF-8");
				
				unsigned int random = (unsigned int)time(NULL);
				unsigned int random2 = rand();
				sprintf( logFiles->logUID, "%d%d%s", random, random2, logFiles->logPatientName);

				fprintf (pFile, "%s\r%s\r%s\r%ld\r%s\r%s\r%ld\r%ld\r%s\r%s\r\%ld\r", logFiles->logPatientName, logFiles->logStudyDescription, logFiles->logCallingAET, logFiles->logStartTime, logFiles->logMessage, logFiles->logUID, logFiles->logNumberReceived, logFiles->logEndTime, logFiles->logType, logFiles->logEncoding, logFiles->logNumberTotal);
				
				fclose (pFile);
				strcpy( newdir, dir);
				strcat( newdir, ".log");
				rename( dir, newdir);
			}
		}
		else if( [[object valueForKey:@"type"] isEqualToString: @"Study"])
		{
			FILE * pFile;
			char dir[ 1024], newdir[1024];
			unsigned int random = (unsigned int)time(NULL);
			sprintf( dir, "%s/%s%d", [[BrowserController currentBrowser] cfixedIncomingDirectory], "TEMP.noindex/move_log_", random);
			pFile = fopen (dir,"w+");
			if( pFile)
			{
				strcpy( logFiles->logPatientName, [[object valueForKeyPath:@"name"] UTF8String]);
				strcpy( logFiles->logStudyDescription, [[object valueForKeyPath:@"studyName"] UTF8String]);
				strcpy( logFiles->logCallingAET, fromTo);
				logFiles->logStartTime = time (NULL);
				strcpy( logFiles->logMessage, "In Progress");
				logFiles->logNumberReceived = 0;
				logFiles->logNumberTotal = [[object valueForKey: @"rawNoFiles"] intValue];
				logFiles->logEndTime = time (NULL);
				strcpy( logFiles->logType, "Move");
				strcpy( logFiles->logEncoding, "UTF-8");
				
				unsigned int random = (unsigned int)time(NULL);
				unsigned int random2 = rand();
				sprintf( logFiles->logUID, "%d%d%s", random, random2, logFiles->logPatientName);
				
				fprintf (pFile, "%s\r%s\r%s\r%ld\r%s\r%s\r%ld\r%ld\r%s\r%s\r\%ld\r", logFiles->logPatientName, logFiles->logStudyDescription, logFiles->logCallingAET, logFiles->logStartTime, logFiles->logMessage, logFiles->logUID, logFiles->logNumberReceived, logFiles->logEndTime, logFiles->logType, logFiles->logEncoding, logFiles->logNumberTotal);
				
				fclose (pFile);
				strcpy( newdir, dir);
				strcat( newdir, ".log");
				rename( dir, newdir);
			}
		}
	}
}

- (OFCondition)prepareMoveForDataSet:( DcmDataset *)dataset
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	OFCondition cond = EC_IllegalParameter;
	@try 
	{
		NSManagedObjectModel *model = [[BrowserController currentBrowser] managedObjectModel];
		NSError *error = nil;
		NSEntityDescription *entity;
		NSPredicate *compressedSOPInstancePredicate = nil, *seriesLevelPredicate = nil;
		NSPredicate *predicate = [self predicateForDataset:dataset compressedSOPInstancePredicate: &compressedSOPInstancePredicate seriesLevelPredicate: &seriesLevelPredicate];
		NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
		const char *sType;
		dataset->findAndGetString (DCM_QueryRetrieveLevel, sType, OFFalse);
		
		if (strcmp(sType, "STUDY") == 0) 
			entity = [[model entitiesByName] objectForKey:@"Study"];
		else if (strcmp(sType, "SERIES") == 0) 
			entity = [[model entitiesByName] objectForKey:@"Series"];
		else if (strcmp(sType, "IMAGE") == 0) 
			entity = [[model entitiesByName] objectForKey:@"Image"];
		else 
			entity = nil;
		
		[request setEntity: entity];
		[request setPredicate: predicate];
		
		error = nil;
		
		context = staticContext;
		[context lock];
		
		NSArray *array = nil;
		
		@try
		{
			if( seriesLevelPredicate) // First find at series level, then move to image level
			{
				NSFetchRequest *seriesRequest = [[[NSFetchRequest alloc] init] autorelease];
				
				[seriesRequest setEntity: [[model entitiesByName] objectForKey:@"Series"]];
				[seriesRequest setPredicate: seriesLevelPredicate];
				
				NSArray *allSeries = [context executeFetchRequest: seriesRequest error: &error];
				
				array = [NSArray array];
				
				for( id series in allSeries)
					array = [array arrayByAddingObjectsFromArray: [[series valueForKey: @"images"] allObjects]];
				
				array = [array filteredArrayUsingPredicate: predicate];
			}
			else
				array = [context executeFetchRequest:request error:&error];
			
			if( strcmp(sType, "IMAGE") == 0 && compressedSOPInstancePredicate)
				array = [array filteredArrayUsingPredicate: compressedSOPInstancePredicate];
			
			if( [array count] == 0)
			{
				// not found !!!!
			}
			
			if (error)
			{
				for( int i = 0 ; i < moveArraySize; i++) free( moveArray[ i]);
				free( moveArray);
				moveArray = nil;
				moveArraySize = 0;
				
				cond = EC_IllegalParameter;
			}
			else
			{
				NSEnumerator *enumerator = [array objectEnumerator];
				id moveEntity;
				
				[self updateLog: array];
				
				NSMutableSet *moveSet = [NSMutableSet set];
				while (moveEntity = [enumerator nextObject])
					[moveSet unionSet:[moveEntity valueForKey:@"paths"]];
				
				NSArray *tempMoveArray = [moveSet allObjects];
				
				/*
				create temp folder for Move paths. 
				Create symbolic links. 
				Will allow us to convert the sytax on copies if necessary
				*/
				
				//delete if necessary and create temp folder. Allows us to compress and deompress files. Wish we could do on the fly
		//		tempMoveFolder = [[NSString stringWithFormat:@"/tmp/DICOMMove_%@", [[NSDate date] descriptionWithCalendarFormat:@"%H%M%S%F"  timeZone:nil locale:nil]] retain]; 
		//		
		//		NSFileManager *fileManager = [NSFileManager defaultManager];
		//		if ([fileManager fileExistsAtPath:tempMoveFolder]) [fileManager removeFileAtPath:tempMoveFolder handler:nil];
		//		if ([fileManager createDirectoryAtPath:tempMoveFolder attributes:nil]) 
		//			NSLog(@"created temp Folder: %@", tempMoveFolder);
		//		
		//		//NSLog(@"Temp Move array: %@", [tempMoveArray description]);
		//		NSEnumerator *tempEnumerator = [tempMoveArray objectEnumerator];
		//		NSString *path;
		//		while (path = [tempEnumerator nextObject]) {
		//			NSString *lastPath = [path lastPathComponent];
		//			NSString *newPath = [tempMoveFolder stringByAppendingPathComponent:lastPath];
		//			[fileManager createSymbolicLinkAtPath:newPath pathContent:path];
		//			[paths addObject:newPath];
		//		}
				
				tempMoveArray = [tempMoveArray sortedArrayUsingSelector:@selector(compare:)];
				
				for( int i = 0 ; i < moveArraySize; i++) free( moveArray[ i]);
				free( moveArray);
				moveArray = nil;
				moveArraySize = 0;
				
				moveArraySize = [tempMoveArray count];
				moveArray = (char**) malloc( sizeof( char*) * moveArraySize);
				for( int i = 0 ; i < moveArraySize; i++)
				{
					const char *str = [[tempMoveArray objectAtIndex: i] UTF8String];
					
					moveArray[ i] = (char*) malloc( strlen( str) + 1);
					strcpy( moveArray[ i], str);
				}
				
				cond = EC_Normal;
			}
		}
		@catch (NSException * e)
		{
			NSLog( @"prepareMoveForDataSet exception");
			NSLog( @"%@", [e description]);
			NSLog( @"%@", [predicate description]);
		}

		[context unlock];
		context = 0L;
		
		// TO AVOID DEADLOCK
		
		BOOL fileExist = YES;
		char dir[ 1024];
		sprintf( dir, "%s-%d", "/tmp/lock_process", getpid());
		
		int inc = 0;
		do
		{
			int err = unlink( dir);
			if( err  == 0 || errno == ENOENT) fileExist = NO;
			
			usleep( 1000);
			inc++;
		}
		while( fileExist == YES && inc < 100000);
		
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		#ifdef OSIRIX_VIEWER
		[e printStackTrace];
		#endif
	}
	[pool release];
	
	return cond;
}

- (BOOL)findMatchFound
{
	if (findArray) return YES;
	return NO;
}

- (int)moveMatchFound
{
	return moveArraySize;
}

- (OFCondition) nextFindObject:(DcmDataset *)dataset isComplete:(BOOL *)isComplete
{
	id item;
	
	[context lock];
	
	@try
	{
		if (item = [findEnumerator nextObject])
		{
			if ([[item valueForKey:@"type"] isEqualToString:@"Series"])
			{
				 [self seriesDatasetForFetchedObject:item dataset:(DcmDataset *)dataset];
			}
			else if ([[item valueForKey:@"type"] isEqualToString:@"Study"])
			{
				[self studyDatasetForFetchedObject:item dataset:(DcmDataset *)dataset];
			}
			else if ([[item valueForKey:@"type"] isEqualToString:@"Image"])
			{
				[self imageDatasetForFetchedObject:item dataset:(DcmDataset *)dataset];
			}
			*isComplete = NO;
		}
		else
		{
			[context unlock];
			context = nil;
			
			*isComplete = YES;
		}
	}
	
	@catch (NSException * e)
	{
		NSLog( @"******* nextFindObject exception : %@", e);
	}
	
	[context unlock];
	
	return EC_Normal;
}

- (OFCondition)nextMoveObject:(char *)imageFileName
{
	OFCondition ret = EC_Normal;
	
	if( moveArrayEnumerator >= moveArraySize)
	{
		return EC_IllegalParameter;
	}
	
	if( moveArray[ moveArrayEnumerator])
		strcpy(imageFileName, moveArray[ moveArrayEnumerator]);
	else
	{
		NSLog(@"No path");
		ret = EC_IllegalParameter;
	}
	
	moveArrayEnumerator++;
	
	if( logFiles)
	{
		FILE * pFile;
		char dir[ 1024], newdir[1024];
		unsigned int random = (unsigned int)time(NULL);
		sprintf( dir, "%s/%s%d", [[BrowserController currentBrowser] cfixedIncomingDirectory], "TEMP.noindex/move_log_", random);
		pFile = fopen (dir,"w+");
		if( pFile)
		{
			if( moveArrayEnumerator >= moveArraySize)
				strcpy( logFiles->logMessage, "Complete");
			
			logFiles->logNumberReceived++;
			logFiles->logEndTime = time (NULL);
			
			fprintf (pFile, "%s\r%s\r%s\r%ld\r%s\r%s\r%ld\r%ld\r%s\r%s\r\%ld\r", logFiles->logPatientName, logFiles->logStudyDescription, logFiles->logCallingAET, logFiles->logStartTime, logFiles->logMessage, logFiles->logUID, logFiles->logNumberReceived, logFiles->logEndTime, logFiles->logType, logFiles->logEncoding, logFiles->logNumberTotal);
			
			fclose (pFile);
			strcpy( newdir, dir);
			strcat( newdir, ".log");
			rename( dir, newdir);
		}
	}
	
	if( moveArrayEnumerator >= moveArraySize)
	{
		if( logFiles)
			free( logFiles);
		
		logFiles = nil;
	}
	
	return ret;
}

@end