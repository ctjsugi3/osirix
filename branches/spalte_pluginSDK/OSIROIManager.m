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

#import "OSIROIManager.h"
#import "OSIVolumeWindow.h"
#import "ViewerController.h"
#import "OSIROI.h"
#import "OSIROI+Private.h"
#import "Notifications.h"
#import "pluginSDKAdditions.h"
#import "DCMView.h"
#import "CPRMPRDCMView.h"


NSString* const OSIROIManagerROIsDidUpdateNotification = @"OSIROIManagerROIsDidUpdateNotification"; 

@interface OSIROIManager ()

- (void)_volumeWindowDidCloseNotification:(NSNotification *)notification;
- (void)_ROIChangeNotification:(NSNotification *)notification;
- (void)_removeROINotification:(NSNotification *)notification;
- (void)_addROINotification:(NSNotification *)notification;
- (void)_drawObjectsNotification:(NSNotification *)notification;
- (NSArray *)_ROIList;
- (NSArray *)_coalescedROIList;

- (BOOL)_isROIManaged:(ROI *)roi;

- (void)_rebuildOSIROIs;

//- (void)_sendDidAddROI:(OSIROI *)roi;
//- (void)_sendDidRemoveROI:(OSIROI *)roi;
//- (void)_sendDidModifyROI:(OSIROI *)roi;

@end

@implementation OSIROIManager

@synthesize delegate = _delegate;

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow
{
	return [self initWithVolumeWindow:volumeWindow coalesceROIs:NO];
}

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow coalesceROIs:(BOOL)coalesceROIs; // if coalesceROIs is YES, ROIs with the same name will 
{
	if ( (self = [super init]) ) {
		_volumeWindow = [volumeWindow retain]; // it is ok to retain the volumeWindow even if this is the ROIManager that is owned by an OSIVolumeWindow because it will be released when the window closes 
		_OSIROIs = [[NSMutableArray alloc] init];
		_coalesceROIs = coalesceROIs;
		[self _rebuildOSIROIs];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_volumeWindowDidCloseNotification:) name:OSIVolumeWindowDidCloseNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_ROIChangeNotification:) name:OsirixROIChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_removeROINotification:) name:OsirixRemoveROINotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_addROINotification:) name:OsirixAddROINotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_drawObjectsNotification:) name:OsirixDrawObjectsNotification object:nil];
		
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	_delegate = nil;
	
	[_volumeWindow release];
	_volumeWindow = nil;
	[_OSIROIs release];
	_OSIROIs = nil;
	
	[super dealloc];
}

- (NSArray *)ROIs
{
	return _OSIROIs;
}

- (OSIROI *)firstROIWithName:(NSString *)name // convenience method to get the first ROI with
{
	NSArray *rois;
	
	rois = [self ROIsWithName:name];
	
	if ([rois count] > 0) {
		return [rois objectAtIndex:0];
	} else {
		return nil;
	}
}

- (NSArray *)ROIsWithName:(NSString *)name
{
	NSMutableArray *rois;
	OSIROI *roi;
	
	rois = [NSMutableArray array];
	for (roi in _OSIROIs) {
		if ([[roi name] isEqualToString:name]) {
			[rois addObject:roi];
		}
	}
	return rois;
}

- (NSArray *)ROINames // returns all the unique ROI names
{
	OSIROI *roi;
	NSMutableSet *roiNames;
	
	roiNames = [NSMutableSet set];
	
	for (roi in _OSIROIs) {
		if ([roiNames containsObject:[roi name]] == NO) {
			[roiNames addObject:[roi name]];
		}
	}
	
	return [roiNames allObjects];
}

- (void)_volumeWindowDidCloseNotification:(NSNotification *)notification
{
	[_volumeWindow release];
	_volumeWindow = nil;
	[self _rebuildOSIROIs];
}

- (void)_ROIChangeNotification:(NSNotification *)notification
{
//	if ([self _isROIManaged:[notification object]]) {
		[self _rebuildOSIROIs];
//	}
//	[self _sendDidModifyROI:];
}

- (void)_removeROINotification:(NSNotification *)notification
{
	if ([self _isROIManaged:[notification object]]) {
		assert([NSThread isMainThread]);
		[self performSelector:@selector(_rebuildOSIROIs) withObject:nil afterDelay:0]; // OsiriX manages to send this notification before the ROI is
												// actually removed. This super ultra sketchy bit of code copies the stratagy used by ROIManagerController
	}
}

- (void)_addROINotification:(NSNotification *)notification
{
	[self _rebuildOSIROIs];
}

- (void)_drawObjectsNotification:(NSNotification *)notification
{
    DCMView *dcmView;
    OSIROI *roi;
    CGLPixelFormatObj pixelFormatObj;
    N3AffineTransform pixToDicomTransform;
    N3AffineTransform dicomToPixTransform;
    double pixToSubdrawRectOpenGLTransform[16];
	N3Plane plane;
    OSISlab slab;
//    float thickness;
//    float location;
    CGLContextObj cgl_ctx;
    
    cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
	
	if ([self.delegate isKindOfClass:[OSIVolumeWindow class]] == NO) { // only draw ROIs for the ROIs in an ROI manager that is owned by the VolumeWindow 
		return;
	}
    
    if ([[notification object] isKindOfClass:[DCMView class]] == NO) {
        return;
    }
    
    dcmView = (DCMView *)[notification object];
    N3AffineTransformGetOpenGLMatrixd([dcmView pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);
    pixelFormatObj = (CGLPixelFormatObj)[[dcmView pixelFormat] CGLPixelFormatObj];
	pixToDicomTransform = [[dcmView curDCM] pixToDicomTransform];
	if (N3AffineTransformDeterminant(pixToDicomTransform) != 0.0) {
		dicomToPixTransform = N3AffineTransformInvert(pixToDicomTransform);
		plane = N3PlaneApplyTransform(N3PlaneZZero, pixToDicomTransform);
	} else {
		dicomToPixTransform = N3AffineTransformIdentity;
		plane = N3PlaneZZero;
	}

//    [dcmView getThickSlabThickness:&thickness location:&location];
//    slab.thickness = thickness;
    slab.thickness = 0;
    slab.plane = plane;
//    slab.plane.point = N3VectorAdd(slab.plane.point, N3VectorScalarMultiply(N3VectorNormalize(slab.plane.normal), thickness/2.0));
	
    for (roi in [self ROIs]) {
        if ([roi respondsToSelector:@selector(drawSlab:inCGLContext:pixelFormat:dicomToPixTransform:)]) {
			glMatrixMode(GL_MODELVIEW);
			glPushMatrix();
			glMultMatrixd(pixToSubdrawRectOpenGLTransform);
            
			[roi drawSlab:slab inCGLContext:cgl_ctx pixelFormat:pixelFormatObj dicomToPixTransform:dicomToPixTransform];
			
			glMatrixMode(GL_MODELVIEW);
			glPopMatrix();
        }
    }
    
}

- (BOOL)_isROIManaged:(ROI *)roi
{
	OSIROI *osiROI;
	
	for (osiROI in [self ROIs]) {
		if ([[osiROI osiriXROIs] containsObject:roi]) {
			return YES;
		}
	}
	return NO;
}

- (void)_rebuildOSIROIs
{
	NSAutoreleasePool *pool;
	// because the OsiriX ROI post notifications at super weird times (like within dealloc!?!?!) 
	// we need to make surewe don't renter our ROI rebuilding call while rebuilding the ROIs;

	if (_rebuildingROIs) {
		return;
	}
	
	pool = [[NSAutoreleasePool alloc] init];
	
	_rebuildingROIs = YES;
	
	[self willChangeValueForKey:@"ROIs"];
	[_OSIROIs removeAllObjects];
	if (_coalesceROIs) {
		[_OSIROIs addObjectsFromArray:[self _coalescedROIList]];
	} else {
		[_OSIROIs addObjectsFromArray:[self _ROIList]];
	}
	[self didChangeValueForKey:@"ROIs"];
	[[NSNotificationCenter defaultCenter] postNotificationName:OSIROIManagerROIsDidUpdateNotification object:self];
	
	_rebuildingROIs = NO;
	[pool release];
}

- (NSArray *)_ROIList;
{
	ViewerController *viewController;
	NSArray *movieFrameROIList;
	NSArray *movieFramePixList;
	NSInteger i;
	NSInteger j;
	long maxMovieIndex;
	OSIROI *roi;
	ROI *osirixROI;
	NSMutableArray *newROIs;
	NSArray *pixROIList;
	DCMPix *pix;
	N3AffineTransform pixToDicomTransform;
	
	newROIs = [NSMutableArray array];
	
	viewController = [_volumeWindow viewerController];
	if (viewController) {
		maxMovieIndex = [viewController maxMovieIndex];
		
		for (i = 0; i < maxMovieIndex; i++) {
			movieFrameROIList = [viewController roiList:i];
			movieFramePixList = [viewController pixList:i];
			
			for (j = 0; j < [movieFramePixList count]; j++) {
				pix = [movieFramePixList objectAtIndex:j];
				pixROIList = [movieFrameROIList objectAtIndex:j];
				
				pixToDicomTransform = [pix pixToDicomTransform];
				if (N3AffineTransformDeterminant(pixToDicomTransform) == 0.0) {
					pixToDicomTransform = N3AffineTransformIdentity;
				}
				
				for (osirixROI in pixROIList) {
					roi = [OSIROI ROIWithOsiriXROI:osirixROI pixToDICOMTransfrom:pixToDicomTransform homeFloatVolumeData:[viewController floatVolumeDataForMovieIndex:i]];
					if (roi) {
						[newROIs addObject:roi];
					}
				}				
			}
		}
	}
	
	return newROIs;
}

- (NSArray *)_coalescedROIList;
{
	NSArray *roiList;
	NSArray *roisToCoalesce;
	NSMutableArray *coalescedROIs;
	NSMutableSet *roiNames;
	NSString *name;
	NSMutableDictionary *groupedNamesDict;
	OSIROI *roi;
    OSIFloatVolumeData *homeVolumeData;
	
	roiList = [self _ROIList];
	roiNames = [[NSMutableSet alloc] init];
	coalescedROIs = [NSMutableArray array];
	groupedNamesDict = [[NSMutableDictionary alloc] init];
	
	for (roi in roiList) {
		if ([roiNames containsObject:[roi name]] == NO) {
			[roiNames addObject:[roi name]];
		}
	}
	
	for (name in roiNames) {
		[groupedNamesDict setObject:[NSMutableArray array] forKey:name];
	}
	
	for (roi in roiList) {
		[[groupedNamesDict objectForKey:[roi name]] addObject:roi];
	}
	
	for (roisToCoalesce in [groupedNamesDict allValues]) {
        homeVolumeData = [[roisToCoalesce objectAtIndex:0] homeFloatVolumeData];
		roi = [OSIROI ROICoalescedWithSourceROIs:roisToCoalesce homeFloatVolumeData:homeVolumeData];
		if (roi) {
			[coalescedROIs addObject:roi];
		}
	}
	
	[roiNames release];
	[groupedNamesDict release];
	
	return coalescedROIs;
}

//- (void)_sendDidAddROI:(OSIROI *)roi
//{
//	if ([_delegate respondsToSelector:@selector(ROIManager:didAddROI:)]) {
//		[_delegate ROIManager:self didAddROI:roi];
//	}
//}
//
//- (void)_sendDidRemoveROI:(OSIROI *)roi
//{
//	if ([_delegate respondsToSelector:@selector(ROIManager:didRemoveROI:)]) {
//		[_delegate ROIManager:self didRemoveROI:roi];
//	}
//}

//- (void)_sendDidModifyROI:(OSIROI *)roi
//{
//	if ([_delegate respondsToSelector:@selector(ROIManager:didModifyROI:)]) {
//		[_delegate ROIManager:self didModifyROI:roi];
//	}
//}



@end














