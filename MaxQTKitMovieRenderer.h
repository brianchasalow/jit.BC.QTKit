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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import <OpenGL/OpenGL.h>

@interface MaxQTKitMovieRenderer : NSObject 
{
    QTMovie*    _movie;
    QTDataReference*    _movieRef;

    QTVisualContextRef  _visualContext;
	CGLContextObj cachedContextObj;

	CVOpenGLTextureCacheRef _textureCache;	
    CVOpenGLTextureRef _latestTextureFrame;
	CVPixelBufferRef _latestPixelFrame;

	NSSize movieSize;
	QTTime movieDuration;
	NSInteger frameCount;
	NSInteger frameStep;
    NSInteger loadState;
    NSInteger loadStateReference;

	BOOL frameUpdated;
	BOOL useTexture;
	BOOL usePixels;
	
}

@property(nonatomic, readonly) NSSize movieSize;
@property(nonatomic, readonly) BOOL useTexture;
@property(nonatomic, readonly) BOOL usePixels;
@property(nonatomic, readonly) float duration; //duration in seconds
@property(nonatomic, readonly) NSInteger frameCount;  //total frames
@property(nonatomic, readonly) BOOL isFinished;  //returns true if the movie is not looping and over

@property(nonatomic, readwrite) float rate;
@property(nonatomic, readwrite) float volume;
@property(nonatomic, readwrite) float position;  //set and get frame position by percent
@property(nonatomic, readwrite) int loadState;  //set and get loadState
@property(nonatomic, readwrite) NSInteger frame;  //set and get frame position by percent
@property(nonatomic, readwrite) BOOL loops;  //set and get loopstate


- (void) draw:(NSRect)drawRect;
- (BOOL) loadMovieReference:(NSString*)moviePath;
- (BOOL) loadMovie:(NSString*)moviePath allowTexture:(BOOL)useTexture allowPixels:(BOOL)usePixels;
- (BOOL) update;
- (void) initializeContext;
- (void) repairContext;


- (void) bindTexture;
- (void) unbindTexture;
//copies ARGB pixels to RGBA into the outbuf
- (void) pixels:(unsigned char*) outbuf;


//brian@chasalow.com added
- (NSInteger) loadState; //lets you query the current load state of the movie
- (void) setLoadState:(NSInteger)state; //lets you query the current load state of the movie

//- (NSInteger) loadStateReference; //lets you query the current load state of the movie reference

-(CVPixelBufferRef) _latestPixelFrame;
- (CVOpenGLTextureRef) _latestTextureFrame; //returns the texture frame
- (QTVisualContextRef) _visualContext; //returns the texture frame

-(void)movieLoadStateChanged:(NSNotification *)notification; //notifies that a load state change happened
-(void)handleLoadStateChanged:(QTMovie *)movie; //handles different load states


@end

