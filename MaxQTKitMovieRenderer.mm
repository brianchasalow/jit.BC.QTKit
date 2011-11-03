/*
 *  MaxQTKitMovieRenderer example
 *
 * Originally Created by James George, http://www.jamesgeorge.org for OpenFrameworks
 * over a long period of time for a few different projects in collaboration with
 * FlightPhase http://www.flightphase.com 
 * and the rockwell group lab http://lab.rockwellgroup.com
 *
 * Adapted to Max/MSP/Jitter by Brian Chasalow, brian@chasalow.com 2011 
 *
 **********************************************************
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * ----------------------
 * 
 * ofxQTKitVideoPlayer provides QTKit/CoreVideo accelerated movie playback
 * for openFrameworks on OS X
 * 
 * This class replaces almost all of the functionality of ofVideoPlayer on OS X
 * and uses the modern QTKit and CoreVideo libraries for playback
 *
 * Special Thanks to Marek Bereza for his initial QTKitVideoTexture
 * http://www.mrkbrz.com/
 *
 * Thanks to Anton Marini for help wrangling buffer contexts
 * http://vade.info/ 
 */

#import "MaxQTKitMovieRenderer.h"

//secret methods!
@interface QTMovie (QTFrom763)
- (QTTime)frameStartTime: (QTTime)atTime;
- (QTTime)frameEndTime: (QTTime)atTime;
- (QTTime)keyframeStartTime:(QTTime)atTime;
@end

struct OpenGLTextureCoordinates
{
    GLfloat topLeft[2];
    GLfloat topRight[2];
    GLfloat bottomRight[2];
    GLfloat bottomLeft[2];
};

typedef struct OpenGLTextureCoordinates OpenGLTextureCoordinates;

@implementation MaxQTKitMovieRenderer
@synthesize movieSize;
@synthesize movieTextureSize;
@synthesize useTexture;
@synthesize usePixels;
@synthesize frameCount;

- (BOOL) loadMovieReference:(NSString*)moviePath 
{
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:moviePath])
    {
		NSLog(@"No movie file found at %@", moviePath);
		return NO;
	}
    
    //create visual context
//	loadStateReference = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    _movieRef = [QTDataReference dataReferenceWithReferenceToURL:[NSURL fileURLWithPath:[moviePath stringByStandardizingPath]]];
    [pool drain];
    return YES;
}


- (BOOL) loadMovie:(NSString*)moviePath allowTexture:(BOOL)doUseTexture allowPixels:(BOOL)doUsePixels
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:moviePath])
    {
		NSLog(@"No movie file found at %@", moviePath);
		return NO;
	}
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	
	//create visual context
	useTexture = doUseTexture;
	usePixels = doUsePixels;
	loadState = 0;
	NSError* error;

    #ifdef MAC_OS_X_VERSION_10_6 || MAC_OS_X_VERSION_10_7
    
        if(self.useTexture && !self.usePixels){            
//         _movieRef = [QTDataReference dataReferenceWithReferenceToURL:[NSURL fileURLWithPath:[moviePath stringByStandardizingPath]]];
//            [self loadMovieReference:moviePath];

            NSLog(@"osx 10.6 or 10.7 texture only, so loading quicktime X for movie %@", moviePath);
            NSMutableDictionary* movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSURL fileURLWithPath:[moviePath stringByStandardizingPath]], QTMovieURLAttribute,
                                                   // _movieRef, QTMovieDataReferenceAttribute,
                                                    [NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute,
                                                    [NSNumber numberWithBool:YES], QTMovieOpenAsyncRequiredAttribute,
                                                    [NSNumber numberWithBool:NO], QTMovieOpenForPlaybackAttribute,
                                                    nil];
            
            _movie = [[QTMovie alloc] initWithAttributes:movieAttributes 
                                                   error: &error];
        }
        else{

         //   NSLog(@"osx 10.6 or 10.7, pixel buffer requested so no quicktime X");
             NSMutableDictionary* movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSURL fileURLWithPath:[moviePath stringByStandardizingPath]], QTMovieURLAttribute,
                                                    [NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute,
													 [NSNumber numberWithBool:YES], QTMovieOpenAsyncRequiredAttribute,
                                                    [NSNumber numberWithBool:NO], QTMovieOpenForPlaybackAttribute,
                                                    nil];
            _movie = [[QTMovie alloc] initWithAttributes:movieAttributes 
                                                   error: &error];
        }
    #endif
    
        #ifndef MAC_OS_X_VERSION_10_7
            #ifndef MAC_OS_X_VERSION_10_6
       //     NSLog(@"osx 10.x, no quicktime X");
            NSMutableDictionary* movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSURL fileURLWithPath:[moviePath stringByStandardizingPath]], QTMovieURLAttribute,
                                                    [NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
                                                    //[NSNumber numberWithBool:NO], QTMovieOpenAsyncRequiredAttribute,
                                                    [NSNumber numberWithBool:NO], QTMovieOpenForPlaybackAttribute,
                                                    nil];
            _movie = [[QTMovie alloc] initWithAttributes:movieAttributes 
                                                 error: &error];
            #endif
        #endif
	
//
	[[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(movieLoadStateChanged:)
     name:QTMovieLoadStateDidChangeNotification
     object:_movie];
    

	if(error || _movie == NULL){
		NSLog(@"Error Loading Movie: %@", error);
//		return NO;
	}
     
	
	if(!error)
	[self initializeContext];
	
	[_movie setAttribute:QTMovieApertureModeProduction forKey:QTMovieApertureModeAttribute];
	[_movie generateApertureModeDimensions];
	[_movie setVisualContext:_visualContext];
    
    [pool drain];
	return YES;
}

-(void)initializeContext{
    //if we are using pixels, make the visual context
    //a pixel buffer context with ARGB textures
    if(self.usePixels && _movie != NULL){
        NSDictionary *pixelBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                               //if we have a texture, make the pixel buffer OpenGL compatible
                                               [NSNumber numberWithBool:self.useTexture], (NSString*)kCVPixelBufferOpenGLCompatibilityKey, 
                                               //in general this shouldn't be forced. but in order to ensure we get good pixels use this one
                                               [NSNumber numberWithInt: '2vuy'], (NSString*)kCVPixelBufferPixelFormatTypeKey, 
                                               //specifying width and height can't hurt since we know
											   //trying k32ARGBPixelFormat cuz its better for glsubteximage2d copying!! also can use kCVPixelFormatType_32ARGB
											  // [NSNumber numberWithFloat:movieSize.height], (NSString*)kCVPixelBufferHeightKey,
											  // [NSNumber numberWithFloat:movieSize.width], (NSString*)kCVPixelBufferWidthKey,
											 //  [NSNumber numberWithInt:kQTApertureMode_ProductionAperture], kQTVisualPropertyID_ApertureMode,
											   
                                               nil];
        
        NSMutableDictionary *ctxAttributes = [NSMutableDictionary dictionaryWithObject:pixelBufferAttributes 
                                                                                forKey:(NSString*)kQTVisualContextPixelBufferAttributesKey];
        
        OSStatus err = QTPixelBufferContextCreate(kCFAllocatorDefault, (CFDictionaryRef)ctxAttributes, &_visualContext);
        if(err){
            NSLog(@"error %i creating OpenGLTextureContext", err);
            //  return NO;
        }
        
        // if we also have a texture, create a texture cache for it
        if(self.useTexture){
            //create a texture cache			
            err = CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL, 
                                             CGLGetCurrentContext(), CGLGetPixelFormat(CGLGetCurrentContext()), 
                                             (CFDictionaryRef)ctxAttributes, &_textureCache);
            if(err){
                NSLog(@"error %i creating CVOpenGLTextureCacheCreate", err);
                //   return NO;
            }
        }
    }
    //if we are using a texture, just create an OpenGL visual context and call it a day
    else if(self.useTexture && _movie != NULL){
        OSStatus err = QTOpenGLTextureContextCreate(kCFAllocatorDefault,
                                                    CGLGetCurrentContext(), CGLGetPixelFormat(CGLGetCurrentContext()),
                                                    (CFDictionaryRef)NULL, &_visualContext);	
        if(err){
            NSLog(@"error %i creating QTOpenGLTextureContextCreate", err);
            //   return NO;
        }
    }
    else {
        NSLog(@"Error - MaxQTKitMovieRenderer - Must specify either Pixels or Texture as rendering strategy");
        // return NO;
    }
	
	
}

-(void)handleLoadStateChanged:(QTMovie *)movie
{
    
    NSLog(@"something changed, changing something");

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    loadState = [[movie attributeForKey:QTMovieLoadStateAttribute] longValue];
    
    if (loadState == QTMovieLoadStateError) {
        /* what goes here is app-specific */
        /* you can query QTMovieLoadStateErrorAttribute to get the error code, if it matters */
        /* for example:
         /* NSError *err = [movie attributeForKey:QTMovieLoadStateErrorAttribute]; */
        /* you might also need to undo some operations done in the other state handlers */
		loadState = -1000;
		NSLog(@"removing observer. loaded enough of it to not care about more notifications.");
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:QTMovieLoadStateDidChangeNotification
													  object:movie];
		
    }
    
    if ((loadState >= QTMovieLoadStateLoaded) ) {
        /* can query properties here */
        /* for instance, if you need to size a QTMovieView based on the movie's natural size, you can do so now */
        /* you can also put the movie into a view now, even though no media data might yet be available and hence
         nothing will be drawn into the view */

        
                
        NSLog(@"movie loaded!");
        movieSize = [[_movie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];

        movieDuration = [_movie duration];
        //
        if ([_movie respondsToSelector: @selector(frameEndTime:)]) {
            // Only on QT 7.6.3
            QTTime	qtStep	= (QTTime)[_movie frameEndTime: QTMakeTime(0, _movie.duration.timeScale)];
            frameStep = qtStep.timeValue;
        }
		
        frameCount = movieDuration.timeValue / frameStep;
      //  NSLog(@" movie has %d frames ", frameCount);

        
 
        
    }
    
    if ((loadState >= QTMovieLoadStatePlayable) ) {
        /* can start movie playing here */
        NSLog(@"movie playable!");

        



        
        NSLog(@"removing observer. loaded enough of it to not care about more notifications.");
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:QTMovieLoadStateDidChangeNotification
													  object:movie];
    }
    
    if (loadState >= QTMovieLoadStateComplete) {
        

    }
    [pool drain];
}

-(void)movieLoadStateChanged:(NSNotification *)notification
{
    QTMovie *movie = (QTMovie *)[notification object];
    
    if (movie) {
       // NSLog(@"something changed");
        [self handleLoadStateChanged:movie];
    }
}


- (void) dealloc
{

	if(_latestTextureFrame != NULL){
		CVOpenGLTextureRelease(_latestTextureFrame);
		_latestTextureFrame = NULL;
	}
	
	if(_latestPixelFrame != NULL){
		CVPixelBufferRelease(_latestPixelFrame);
		_latestPixelFrame = NULL;
	}
	
	if(_movie != NULL){
		[_movie release];
		_movie = NULL;
	}
    
	
	if(_visualContext != NULL){
		QTVisualContextRelease(_visualContext);
		_visualContext = NULL;
	}
	
	if(_textureCache != NULL){
		CVOpenGLTextureCacheRelease(_textureCache);
		_textureCache = NULL;
	}
	

	[super dealloc];
}

- (void) draw:(NSRect)drawRect
{   
	
	if(!self.useTexture || _latestTextureFrame == NULL){
		return;
	}
	

	
	OpenGLTextureCoordinates texCoords;	
	
	CVOpenGLTextureGetCleanTexCoords(_latestTextureFrame, 
									 texCoords.bottomLeft, 
									 texCoords.bottomRight, 
									 texCoords.topRight, 
									 texCoords.topLeft);        
	
//	glPushAttrib(GL_ALL_ATTRIB_BITS);
//	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);

	glPushMatrix();

	[self bindTexture];
	
	
//	glLoadIdentity();
	glTranslatef(0, 0, -1);
	glBegin(GL_QUADS);
	glTexCoord2fv(texCoords.topLeft);
	glVertex2f(NSMinX(drawRect), NSMinY(drawRect));
	
	glTexCoord2fv(texCoords.topRight);
	glVertex2f(NSMaxX(drawRect), NSMinY(drawRect));
	
	glTexCoord2fv(texCoords.bottomRight);
	glVertex2f(NSMaxX(drawRect), NSMaxY(drawRect));
	
	glTexCoord2fv(texCoords.bottomLeft);
	glVertex2f(NSMinX(drawRect), NSMaxY(drawRect));
	
	glEnd();
	
	[self unbindTexture];
	glPopMatrix();
//	glPopClientAttrib();
//	glPopAttrib();

	
	
	QTVisualContextTask(_visualContext);
	
}


-(void)repairContext{
	
	//		NSLog("DO SOMETHING. CONTEXT CHANGED");	
	if(_visualContext != NULL){
		NSLog(@"releasing movie context");
		QTVisualContextRelease(_visualContext);
		_visualContext = NULL;
	}
	if(_textureCache != NULL){
		NSLog(@"releasing texture cache");
		CVOpenGLTextureCacheRelease(_textureCache);
		_textureCache = NULL;
	}
	
	//finally initialize the context
	[self initializeContext];
	NSLog(@"re-initing movie context");
	[_movie setVisualContext:_visualContext];			
	NSLog(@"cached context: %i, current context: %i", cachedContextObj, CGLGetCurrentContext());
	
	cachedContextObj = CGLGetCurrentContext();
	
}



- (BOOL) update
{    
	if(cachedContextObj != CGLGetCurrentContext()){
		[self repairContext];
	}
	
	
    if (_visualContext == NULL || !QTVisualContextIsNewImageAvailable(_visualContext, NULL)){
		return NO;
	}
	
	if(self.usePixels){
		if(_latestPixelFrame != NULL){
			CVPixelBufferRelease(_latestPixelFrame);
			_latestPixelFrame = NULL;
		}
		
		OSStatus error = QTVisualContextCopyImageForTime(_visualContext, NULL, NULL, &_latestPixelFrame);
		//movieTextureSize = NSMakeSize((int)CVPixelBufferGetBytesPerRowOfPlane(_latestPixelFrame, 0) / 4, CVPixelBufferGetHeight(_latestPixelFrame));
		//size_t x, y, z, w;
		//CVPixelBufferGetExtendedPixels(_latestPixelFrame, &x, &y, &z, &w);
		//NSLog(@"x/y/z/w : %i, %i, %i, %i, %i, %i, %i", x, y, z, w, (int)CVPixelBufferGetDataSize(_latestPixelFrame)/(int)CVPixelBufferGetHeight(_latestPixelFrame), CVPixelBufferGetWidthOfPlane(_latestPixelFrame, 0), [_latestPixelFrame attributeForKey:(NSString*)kCVPixelBufferWidthKey]);
		//NSLog(@"movietexture size %f, %f", movieTextureSize.width, movieTextureSize.height);

		//In general this shouldn't happen, but just in case...
		if (error != noErr) {
			CVPixelBufferRelease(_latestPixelFrame);
			return NO;
		}
		
		//if we are using a texture, create one from the texture cache
		if(self.useTexture){
			if(_latestTextureFrame != NULL){
				CVOpenGLTextureRelease(_latestTextureFrame);
				_latestTextureFrame = NULL;
				CVOpenGLTextureCacheFlush(_textureCache, 0);	
			}
			
			OSErr err = CVOpenGLTextureCacheCreateTextureFromImage(NULL, _textureCache, _latestPixelFrame, NULL, &_latestTextureFrame);

										  
			if(err != noErr){
				NSLog(@"Error creating OpenGL texture");
				return NO;
			}
		}
        
       //OSType myType = CVPixelBufferGetPixelFormatType(_latestPixelFrame);
        //NSLog(@"0x%x", myType);
        // returns kCVPixelFormatType_32ARGB
	}
	//just get the texture
	else if(self.useTexture){
        
		if(_latestTextureFrame != NULL){
			CVOpenGLTextureRelease(_latestTextureFrame);
			_latestTextureFrame = NULL;
		}
		
		OSStatus error = QTVisualContextCopyImageForTime(_visualContext, NULL, NULL, &_latestTextureFrame);	
		if (error != noErr) {
			CVOpenGLTextureRelease(_latestTextureFrame);
			return NO;
		}
	}
	
	return YES;
}

//writes out the pixels in RGBA format to outbuf
- (void) pixels:(unsigned char*) outbuf
{
	if(!self.usePixels || _latestPixelFrame == NULL){
		return;
	}
	
	CVPixelBufferLockBaseAddress(_latestPixelFrame, 0);
	unsigned char* pix = (unsigned char*)CVPixelBufferGetBaseAddress(_latestPixelFrame);

	//NOTE:
	//CoreVideo works on ARGB, and openFrameworks is RGBA so we need to swizzle the buffer 
	//before we return it to an openFrameworks app.
	//this is a bit tricky since CV pixel buffer's bytes per row are not always the same as movieWidth*4.  
	//We have to use the BPR given by CV for the input buffer, and the movie size for the output buffer
	int x,y, bpr, width, height;
	bpr = CVPixelBufferGetBytesPerRow(_latestPixelFrame);
	width = movieSize.width;
	height = movieSize.height;
	for(y = 0; y < movieSize.height; y++){
		for(x = 0; x < movieSize.width*4; x+=4){
			//copy rgb: dst, src, size. dst: outbuf+y*width*4 + x, src: pix + y*bpr+x+1
			memcpy(outbuf+(y*width*4 + x), pix + (y*bpr+x+1), 3);
			//swizzle in the alpha.
			outbuf[(y*width*4 + x)+3] = pix[y*bpr+x];
		}
	}
	
	CVPixelBufferUnlockBaseAddress(_latestPixelFrame, 0);	
}


- (void) bindTexture
{
	if(!self.useTexture || _latestTextureFrame == NULL) return;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	GLuint texID = 0;
	texID = CVOpenGLTextureGetName(_latestTextureFrame);
	
	GLenum target = GL_TEXTURE_RECTANGLE_ARB;
	target = CVOpenGLTextureGetTarget(_latestTextureFrame);
	
	glEnable(target);
	glBindTexture(target, texID);
	[pool drain];
}

- (void) unbindTexture
{
	if(!self.useTexture || _latestTextureFrame == NULL) return;
	
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	GLenum target = GL_TEXTURE_RECTANGLE_ARB;
	target = CVOpenGLTextureGetTarget(_latestTextureFrame);
    glBindTexture(target, 0);
	glDisable(target);	
    [pool drain];
}

- (void) setRate:(float) rate
{
	[_movie setRate:rate];
}

- (float) rate
{
	return _movie.rate;
}

- (void) setVolume:(float) volume
{
	[_movie setVolume:volume];
}

- (float) volume
{
	return [_movie volume];
}

- (void) setPosition:(float) position
{
    
    _movie.currentTime = QTMakeTimeWithTimeInterval((NSTimeInterval)position);
//    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//	_movie.currentTime = QTMakeTime(position*movieDuration.timeValue, movieDuration.timeScale);
//    [pool release];
}

- (float) position
{
    
//
    NSTimeInterval myTime = 0;
    QTGetTimeInterval([_movie currentTime], &myTime);
    float myFloatTime = (float)myTime;
    return myFloatTime;

//if(movieDuration.timeValue > 0)
//    double myTime = (float)[[_movie attributeForKey:QTMovieCurrentTimeAttribute] QTTimeValue].timeValue / (float)movieDuration.timeValue;	
//    NSLog(@"mytime float: %f", myTime);
//    return (float)myTime;
//     return 0;
}


- (void) setLoadState:(NSInteger) state
{
	loadState = state;
}

- (void) setFrame:(NSInteger) frame
{
	_movie.currentTime = QTMakeTime(frame*frameStep, movieDuration.timeScale);
}

- (NSInteger) frame
{
	return _movie.currentTime.timeValue / frameStep;
}

- (float) duration
{
    
//	return 1.0*movieDuration.timeValue / movieDuration.timeScale;
    
    QTTime durTime = movieDuration;
    //if there's no timeScale, give it one
    if(durTime.timeScale == 0)
        durTime.timeScale = 60;
    
    NSTimeInterval myTime = 0;
    QTGetTimeInterval(durTime, &myTime);
    float myDurationInSeconds = (float)myTime;
    return myDurationInSeconds; //this returns the time in seconds

}

- (void) setLoops:(BOOL)loops
{
	[_movie setAttribute:[NSNumber numberWithBool:loops] 
				  forKey:QTMovieLoopsAttribute];
}

- (BOOL) loops
{
	return [[_movie attributeForKey:QTMovieLoopsAttribute] boolValue];
}

- (BOOL) isFinished
{
	return !self.loops && _movie.currentTime.timeValue == movieDuration.timeValue;
}

- (CVOpenGLTextureRef) _latestTextureFrame
{
    
    return _latestTextureFrame;
}

- (CVPixelBufferRef) _latestPixelFrame
{
    
    return _latestPixelFrame;
}

- (QTVisualContextRef) _visualContext
{
    
    return _visualContext;
}

- (NSInteger) loadState
{
    
    return loadState;
}

@end
