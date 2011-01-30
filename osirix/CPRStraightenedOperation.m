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

#import "CPRStraightenedOperation.h"
#import "CPRGeneratorRequest.h"
#import "CPRGeometry.h"
#import "CPRBezierCore.h"
#import "CPRBezierCoreAdditions.h"
#import "CPRBezierPath.h"
#import "CPRVolumeData.h"
#import "CPRHorizontalFillOperation.h"
#import "CPRProjectionOperation.h"
#include <libkern/OSAtomic.h>

static const NSUInteger FILL_HEIGHT = 80;
static NSOperationQueue *_straightenedOperationFillQueue = nil;

@interface CPRStraightenedOperation ()

+ (NSOperationQueue *) _fillQueue;
- (CGFloat)_slabSampleDistance;
- (NSUInteger)_pixelsDeep;

@end


@implementation CPRStraightenedOperation

@dynamic request;

- (id)initWithRequest:(CPRStraightenedGeneratorRequest *)request volumeData:(CPRVolumeData *)volumeData
{
    if ( (self = [super initWithRequest:request volumeData:volumeData]) ) {
        _fillOperations = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_fillOperations release];
    _fillOperations = nil;
	[_projectionOperation release];
	_projectionOperation = nil;
    [super dealloc];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting {
    return _operationExecuting;
}

- (BOOL)isFinished {
    return _operationFinished;
}

- (BOOL)didFail
{
    return _operationFailed;
}

- (void)cancel
{
    NSOperation *operation;
    @synchronized (_fillOperations) {
        for (operation in _fillOperations) {
            [operation cancel];
        }
    }
	[_projectionOperation cancel];
    
    [super cancel];
}

- (void)start
{
    if ([self isCancelled])
    {
        [self willChangeValueForKey:@"isFinished"];
        _operationFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _operationExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self main];
}

- (void)main
{
    NSAutoreleasePool *pool;
    CGFloat bezierLength;
    CGFloat spacing;
    CGFloat fillDistance;
    CGFloat slabDistance;
    NSInteger numVectors;
    NSInteger i;
    NSInteger y;
    NSInteger z;
    NSInteger pixelsWide;
    NSInteger pixelsHigh;
    NSInteger pixelsDeep;
    CPRVectorArray vectors;
    CPRVectorArray fillVectors;
    CPRVectorArray fillNormals;
    CPRVectorArray normals;
    CPRVectorArray tangents;
    CPRVectorArray inSlabNormals;
    CPRMutableBezierCoreRef flattenedBezierCore;
    CPRHorizontalFillOperation *horizontalFillOperation;
    NSMutableSet *fillOperations;
	NSOperationQueue *fillQueue;
    
    pool = nil;
        
    @try {
        pool = [[NSAutoreleasePool alloc] init];
        
        if ([self isCancelled] == NO && self.request.pixelsHigh > 0) {        
            flattenedBezierCore = CPRBezierCoreCreateMutableCopy([self.request.bezierPath CPRBezierCore]);
            CPRBezierCoreSubdivide(flattenedBezierCore, 3.0);
            CPRBezierCoreFlatten(flattenedBezierCore, 0.6);
            bezierLength = CPRBezierCoreLength(flattenedBezierCore);
            pixelsWide = self.request.pixelsWide;
            pixelsHigh = self.request.pixelsHigh;
            pixelsDeep = [self _pixelsDeep];
            
            numVectors = pixelsWide;
            spacing = bezierLength / (CGFloat)pixelsWide;
            
            _floatBytes = malloc(sizeof(float) * pixelsWide * pixelsHigh * pixelsDeep);
            vectors = malloc(sizeof(CPRVector) * pixelsWide);
            fillVectors = malloc(sizeof(CPRVector) * pixelsWide);
            fillNormals = malloc(sizeof(CPRVector) * pixelsWide);
            tangents = malloc(sizeof(CPRVector) * pixelsWide);
            normals = malloc(sizeof(CPRVector) * pixelsWide);
            inSlabNormals = malloc(sizeof(CPRVector) * pixelsWide);
            
            if (_floatBytes == NULL || vectors == NULL || fillVectors == NULL || fillNormals == NULL || tangents == NULL || normals == NULL || inSlabNormals == NULL) {
                free(_floatBytes);
                free(vectors);
                free(fillVectors);
                free(fillNormals);
                free(tangents);
                free(normals);
                free(inSlabNormals);
                
                _floatBytes = NULL;
                
                [self willChangeValueForKey:@"didFail"];
                [self willChangeValueForKey:@"isFinished"];
                [self willChangeValueForKey:@"isExecuting"];
                _operationExecuting = NO;
                _operationFinished = YES;
                _operationFailed = YES;
                [self didChangeValueForKey:@"isExecuting"];
                [self didChangeValueForKey:@"isFinished"];
                [self didChangeValueForKey:@"didFail"];
                
                CPRBezierCoreRelease(flattenedBezierCore);
                [pool release];
                return;
            }
            
            numVectors = CPRBezierCoreGetVectorInfo(flattenedBezierCore, spacing, 0, self.request.initialNormal, vectors, tangents, normals, pixelsWide);

            while (numVectors < pixelsWide) { // make sure that the full array is filled and that there is not a vector that did not get filled due to roundoff error
                vectors[numVectors] = vectors[numVectors - 1];
                tangents[numVectors] = tangents[numVectors - 1];
                normals[numVectors] = normals[numVectors - 1];
                numVectors++;
            }
                    
            memcpy(fillNormals, normals, sizeof(CPRVector) * pixelsWide);
            CPRVectorScalarMultiplyVectors(spacing, fillNormals, pixelsWide);
            
            memcpy(inSlabNormals, normals, sizeof(CPRVector) * pixelsWide);
            CPRVectorCrossProductWithVectors(inSlabNormals, tangents, pixelsWide);
            CPRVectorScalarMultiplyVectors([self _slabSampleDistance], inSlabNormals, pixelsWide);
            
            fillOperations = [NSMutableSet set];
            
            for (z = 0; z < pixelsDeep; z++) {
                for (y = 0; y < pixelsHigh; y += FILL_HEIGHT) {
                    fillDistance = (CGFloat)y - (CGFloat)pixelsHigh/2.0; // the distance to go out from the centerline
                    slabDistance = (CGFloat)z - (CGFloat)pixelsDeep/2.0; // the distance to go out from the centerline
                    for (i = 0; i < pixelsWide; i++) {
                        fillVectors[i] = CPRVectorAdd(CPRVectorAdd(vectors[i], CPRVectorScalarMultiply(fillNormals[i], fillDistance)), CPRVectorScalarMultiply(inSlabNormals[i], slabDistance));
                    }
                    
                    horizontalFillOperation = [[CPRHorizontalFillOperation alloc] initWithVolumeData:_volumeData floatBytes:_floatBytes + (y*pixelsWide) + (z*pixelsWide*pixelsHigh) width:pixelsWide height:MIN(FILL_HEIGHT, pixelsHigh - y)
                                                                                             vectors:fillVectors normals:fillNormals];
                    [fillOperations addObject:horizontalFillOperation];
                    [horizontalFillOperation addObserver:self forKeyPath:@"isFinished" options:0 context:&self->_fillOperations];
                    [self retain]; // so we don't get release while the operation is going
                    [horizontalFillOperation release];
                }
            }
            
            @synchronized (_fillOperations) {
                [_fillOperations setSet:fillOperations];
            }            
            
            if ([self isCancelled]) {
                for (horizontalFillOperation in fillOperations) {
                    [horizontalFillOperation cancel];
                }                
            }
            
            _oustandingFillOperationCount = [fillOperations count];
            
//            if ([fillOperations count] > 2) {
				fillQueue = [[self class] _fillQueue];
                for (horizontalFillOperation in fillOperations) {
                    [fillQueue addOperation:horizontalFillOperation];
                }
//            } else {
//                for (horizontalFillOperation in fillOperations) {
//                    [horizontalFillOperation start];
//                }
//                
//            }
//
            
            free(vectors);
            free(fillVectors);
            free(fillNormals);
            free(tangents);
            free(normals);
            free(inSlabNormals);
            CPRBezierCoreRelease(flattenedBezierCore);
        } else {
            [self willChangeValueForKey:@"isFinished"];
            [self willChangeValueForKey:@"isExecuting"];
            _operationExecuting = NO;
            _operationFinished = YES;
            [self didChangeValueForKey:@"isExecuting"];
            [self didChangeValueForKey:@"isFinished"];
			[pool release];
            return;
        }
        
        [pool release];
    }
    @catch (...) {
        [self willChangeValueForKey:@"isFinished"];
        [self willChangeValueForKey:@"isExecuting"];
        _operationExecuting = NO;
        _operationFinished = YES;
        [self didChangeValueForKey:@"isExecuting"];
        [self didChangeValueForKey:@"isFinished"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSOperation *operation;
    CPRVolumeData *generatedVolume;
    CPRProjectionOperation *projectionOperation;
    int32_t oustandingFillOperationCount;
    
    if (context == &self->_fillOperations) {
        assert([object isKindOfClass:[NSOperation class]]);
        operation = (NSOperation *)object;
        
        if ([keyPath isEqualToString:@"isFinished"]) {
            if ([operation isFinished]) {
                [operation removeObserver:self forKeyPath:@"isFinished"];
                [self autorelease]; // to balance the retain when we observe operations
                oustandingFillOperationCount = OSAtomicDecrement32Barrier(&_oustandingFillOperationCount);
                if (oustandingFillOperationCount == 0) { // done with the fill operations, now do the projection
                    generatedVolume = [[CPRVolumeData alloc] initWithFloatBytesNoCopy:_floatBytes pixelsWide:self.request.pixelsWide pixelsHigh:self.request.pixelsHigh pixelsDeep:[self _pixelsDeep]
                                                                      volumeTransform:CPRAffineTransform3DIdentity freeWhenDone:YES];
                    _floatBytes = NULL;
                    projectionOperation = [[CPRProjectionOperation alloc] init];
                    projectionOperation.volumeData = generatedVolume;
                    projectionOperation.projectionMode = self.request.projectionMode;
					if ([self isCancelled]) {
						[projectionOperation cancel];
					}
                    					
                    [generatedVolume release];
                    [projectionOperation addObserver:self forKeyPath:@"isFinished" options:0 context:&self->_fillOperations];
                    [self retain]; // so we don't get release while the operation is going
                    _projectionOperation = projectionOperation;
                    [[[self class] _fillQueue] addOperation:projectionOperation];
                } else if (oustandingFillOperationCount == -1) {
                    assert([operation isKindOfClass:[CPRProjectionOperation class]]);
                    projectionOperation = (CPRProjectionOperation *)operation;
                    self.generatedVolume = projectionOperation.generatedVolume;

                    [self willChangeValueForKey:@"isFinished"];
                    [self willChangeValueForKey:@"isExecuting"];
                    _operationExecuting = NO;
                    _operationFinished = YES;
                    [self didChangeValueForKey:@"isExecuting"];
                    [self didChangeValueForKey:@"isFinished"];
                }

            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

+ (NSOperationQueue *) _fillQueue
{
    @synchronized (self) {
        if (_straightenedOperationFillQueue == nil) {
            _straightenedOperationFillQueue = [[NSOperationQueue alloc] init];
        }
    }
    
    return _straightenedOperationFillQueue;
}

- (CGFloat)_slabSampleDistance
{
    if (self.request.slabSampleDistance != 0.0) {
        return self.request.slabSampleDistance;
    } else {
        return self.volumeData.minPixelSpacing;
    }
}

- (NSUInteger)_pixelsDeep
{
    CGFloat slabSampleDistance;
    return MAX(self.request.slabWidth / [self _slabSampleDistance], 0) + 1;
}


@end











