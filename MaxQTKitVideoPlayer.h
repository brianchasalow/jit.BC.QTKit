/*
 *  MaxQTKitVideoPlayer example
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
 * MaxQTKitVideoPlayer provides QTKit/CoreVideo accelerated movie playback
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

#ifndef OFX_QTKIT_VIDEO_PLAYER
#define OFX_QTKIT_VIDEO_PLAYER

//#include "ofMain.h"

#ifdef __OBJC__
#import "MaxQTKitMovieRenderer.h"
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import <OpenGL/OpenGL.h>
#include <string>
#endif
#include "jit.common.h"
#include "jit.gl.h"
#include "ext_obex.h"

//different modes for the video player to run in
//this mode just uses the quicktime texture and is really fast, but offers no pixels-level access
#define OFXQTVIDEOPLAYER_MODE_TEXTURE_ONLY 0 
//this mode just renders pixels and can't be drawn directly to the screen
#define OFXQTVIDEOPLAYER_MODE_PIXELS_ONLY 1
//this mode renders pixels and textures, is a little bit slower than DRAW_ONLY, but faster than uploading your own texture
#define OFXQTVIDEOPLAYER_MODE_PIXELS_AND_TEXTURE 2



class MaxQTKitVideoPlayer // : public ofBaseVideo //JG can't extend base video until i figure out how to integrate with ofTexture
{
public:	
	
	MaxQTKitVideoPlayer();
	virtual ~MaxQTKitVideoPlayer();
	
	bool				loadMovie(std::string path, int mode = OFXQTVIDEOPLAYER_MODE_TEXTURE_ONLY);
	
	void 				closeMovie();
	void 				close();
	
	void				idleMovie();
	bool				update();
	void				play();
	void				pause();
	
	//should use an ofTexture, but this will have to do for now
	void				bind();
	void				unbind();
	
	bool 				isFrameNew(); //returns true if the frame has changed in this update cycle
	
	//gets regular openFrameworks compatible RGBA pixels
	unsigned char * 	getPixels();
	float 				getPosition();
	float				getPositionInSeconds();
	float 				getSpeed();
	//	bool				getMovieLoopState();
	int                 getMovieLoopState();
	float 				getDuration();
	bool				getIsMovieDone();
	int					getTotalNumFrames();
	int					getCurrentFrame();
	
	
	void 				setPosition(float pct);
	void 				setVolume(float volume);
	void 				setLoopState(bool loops);
	void 				setLoopState(int ofLoopState);
	void   				setSpeed(float speed);
	void				setFrame(int frame);  // frame 0 = first frame...
	
	void 				draw(float x, float y, float w, float h);
	void 				draw(float x, float y);
	void                pseudoUpdate();
    void                pseudoDraw(int x, int y);
    
	int					getWidth();
	int					getHeight();
	
	//	bool				isPaused();
	bool				isLoaded();
	bool				isPlaying();
	
	int					width, height;			//deprecated, use getWidth() and getHeight()
	int					nFrames;				// number of frames: deprecated. should use getTotalFrames();	
	std::string getCurrentlyPlaying();
	std::string storedMovieFileName;
    int loopState;
    int speed;
	float volume;
    bool videoHasEnded, isPaused, iAmLoading, iAmLoaded, firstLoad;
    void resetToZeroIfDone();
    void setPaused(bool myPause);
	CVPixelBufferRef getPixelsRef();
	void repairContext();
	void handleVideoLoaded(MaxQTKitVideoPlayer* ptr);
	void handleVideoEnded(MaxQTKitVideoPlayer* ptr);
	void* jitterObj;

    //This #ifdef is so you can include this .h file in .cpp files
	//and avoid ugly casts in the .m file
#ifdef __OBJC__
	MaxQTKitMovieRenderer* moviePlayer;
#else
	void* moviePlayer;
	
#endif
	bool			bNewFrame;

protected:
	//do lazy allocation and copy on these so it's faster if they aren't used
	unsigned char*	moviePixels;
	bool 			bHavePixelsChanged;	
	float duration;
	
	
};

#endif