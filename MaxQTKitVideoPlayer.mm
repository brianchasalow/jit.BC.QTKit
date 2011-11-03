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

#include "MaxQTKitVideoPlayer.h"
//#include "MonoCallbacks.h"
enum ofLoopType{
	OF_LOOP_NONE=0,
//	OF_LOOP_PALINDROME=0x02,
	OF_LOOP_NORMAL=1
};

MaxQTKitVideoPlayer::MaxQTKitVideoPlayer()
{
	moviePlayer = NULL;
	moviePixels = NULL;
	bNewFrame = false;
	duration = 0;
	nFrames = 0;
    storedMovieFileName = "";
    loopState = OF_LOOP_NONE;
    videoHasEnded = false;
    speed = 1;
    volume = 0;
    iAmLoading = false;
    iAmLoaded = false;
    firstLoad = true;
}


MaxQTKitVideoPlayer::~MaxQTKitVideoPlayer()
{
	close();	
}

void MaxQTKitVideoPlayer::pseudoUpdate(){
    
    
}

void MaxQTKitVideoPlayer::pseudoDraw(int myint, int myotherint){
    
    
}

bool MaxQTKitVideoPlayer::loadMovie(std::string movieFilePath, int mode)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    if(movieFilePath == ""){
		NSLog(@"Load BLOCKED by null name");
		[pool drain];
		pool = NULL;
        return false;
    }
    
	if(mode < 0 || mode > 2){
		NSLog(@"MaxQTKitVideoPlayer -- Error, invalid mode specified for");
		[pool drain];
		pool = NULL;
		return false;
	}
	
    
    if(moviePlayer != NULL){
		close();
	}
    if(!iAmLoading){
		
		if(pool == NULL)
			pool = [[NSAutoreleasePool alloc] init];
		
		
		
		bool useTexture = (mode == OFXQTVIDEOPLAYER_MODE_TEXTURE_ONLY || mode == OFXQTVIDEOPLAYER_MODE_PIXELS_AND_TEXTURE);
		bool usePixels  = (mode == OFXQTVIDEOPLAYER_MODE_PIXELS_ONLY  || mode == OFXQTVIDEOPLAYER_MODE_PIXELS_AND_TEXTURE);
		//NSLog(@"inside: mode: %i, useTexture, usePixels. %@, %@",mode, (useTexture ? @"YES" : @"NO"),( usePixels? @"YES" : @"NO"));
		moviePlayer = [[MaxQTKitMovieRenderer alloc] init];
		
		//movieFilePath = ofToDataPath(movieFilePath, false);
		BOOL success = [moviePlayer loadMovie:[NSString stringWithCString:movieFilePath.c_str() encoding:NSUTF8StringEncoding] 
								 allowTexture:useTexture 
								  allowPixels:usePixels];
		
		
		storedMovieFileName = movieFilePath;
		
		
		
		
		if(!success) {
			NSLog(@"MaxQTKitVideoPlayer -- Loading file %s failed", movieFilePath.c_str());
			[moviePlayer release];
			moviePlayer = NULL;
			
		}
		else{
			
			
			iAmLoading = true;
			iAmLoaded = false; 
		}
		
		
		[pool drain];
		
		return success;
        
        
	}
	
	[pool drain];
    return false;
	
}

void MaxQTKitVideoPlayer::closeMovie()
{
	close();
}

bool MaxQTKitVideoPlayer::isLoaded()
{
	return moviePlayer != NULL;
}


std::string MaxQTKitVideoPlayer::getCurrentlyPlaying() {
    return storedMovieFileName;
}



void MaxQTKitVideoPlayer::close()
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    storedMovieFileName = "";	
	if(moviePlayer != NULL){
		[moviePlayer release];
		moviePlayer = NULL;
	}
	
	if(moviePixels != NULL){
		delete moviePixels;
		moviePixels = NULL;
	}
	
	duration = 0;
	nFrames = 0;
	
	[pool drain];	
}

void MaxQTKitVideoPlayer::pause()
{
	//if you're already stopped, don't pause it a second time, or you'll lose your cached value.
	if(getSpeed() != 0.0){
		//cache the value of speed so that when you unpause, it will return it
		speed = getSpeed();
	//	post("paused: speed: %f, getspeed: %f", speed, getSpeed());

		setSpeed(0);
	//	post("paused: speed: %f, getspeed: %f", speed, getSpeed());

	}
}

//bool MaxQTKitVideoPlayer::isPaused()
//{
//	return getSpeed() == 0.0;
//}

void MaxQTKitVideoPlayer::setPaused(bool myPause){
    //set it to paused
	if(myPause){
        isPaused = true;
		
        if(iAmLoaded)
			pause();
    }
	//set it to unpaused
    else{
        isPaused = false;
		
        
        if(iAmLoaded){
			
			if(speed != 0.0)
				setSpeed(speed);
			else 
				setSpeed(1);
            
        }
    }
}

void MaxQTKitVideoPlayer::setSpeed(float rate)
{
	//only cache a non-zero value
	if(rate != 0.0)
	speed = rate;

	if(moviePlayer == NULL) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	

	[moviePlayer setRate:rate];
	
	[pool drain];	
}

void MaxQTKitVideoPlayer::play()
{	
	if(moviePlayer == NULL) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

//	post("play: speed: %f, getspeed: %f", speed, getSpeed());
	[moviePlayer setRate: speed];
//	post("play: speed: %f, getspeed: %f", speed, getSpeed());

	[pool drain];
}

void MaxQTKitVideoPlayer::idleMovie()
{
	update();
}

void MaxQTKitVideoPlayer::handleVideoLoaded(MaxQTKitVideoPlayer* ptr){
	t_atom foo[1];
	jit_atom_setlong(&foo[0],!(ptr == NULL));
	jit_object_notify(jitterObj,gensym("videoLoaded"), foo); //the last pointer argument could be anything.	
	
	if(ptr != NULL){
		t_atom vol[1];
		jit_atom_setfloat(&vol[0],volume);
		jit_object_notify(jitterObj,gensym("volume"), vol); //the last pointer argument could be anything.

		t_atom dimz[2];
		jit_atom_setfloat(&dimz[0],width);
		jit_atom_setfloat(&dimz[1],height);
		jit_object_notify(jitterObj,gensym("dim"), dimz); //the last pointer argument could be anything.
		
		t_atom durationz[1];
		jit_atom_setfloat(&durationz[0],duration);
		jit_object_notify(jitterObj,gensym("duration"), durationz); //the last pointer argument could be anything.		
		//jit_object_post((t_object*)jitterObj, "duration: %f", duration);
	}
}

void MaxQTKitVideoPlayer::handleVideoEnded(MaxQTKitVideoPlayer* ptr){
	t_atom foo[1];
	jit_atom_setlong(&foo[0],!(ptr == NULL));
	jit_object_notify(jitterObj,gensym("videoEnded"), foo); //the last pointer argument could be anything.
}

bool MaxQTKitVideoPlayer::update()
{
    if(iAmLoading){
		if(moviePlayer.loadState == -1000){
			//CALLBACK HERE FOR VIDEO ENDED - IMPLEMENT IN MAX
			handleVideoLoaded(NULL);
			moviePlayer.loadState = -999;
		}
		
        if(moviePlayer.loadState >=2000){
            iAmLoading = false;
            iAmLoaded = true;
            videoHasEnded = false;
            //speed = 1;
			setSpeed(speed);
            setLoopState(loopState);
            setPaused(isPaused);
            setVolume(volume);
            duration = moviePlayer.duration;
            nFrames = moviePlayer.frameCount;
            width = moviePlayer.movieSize.width;
            height = moviePlayer.movieSize.height;
			//CALLBACK HERE FOR VIDEO ENDED - IMPLEMENT IN MAX
            handleVideoLoaded(this);
            firstLoad = false;
        }
        return false;
	}
	
    
    
	if(moviePlayer == NULL) return false;
	
	if(getPosition() != duration){
		
		videoHasEnded = false;	
	}
	
	bNewFrame = [moviePlayer update];
	if (bNewFrame) {
		bHavePixelsChanged = true;
	}
    resetToZeroIfDone();
    return bNewFrame;
}

void MaxQTKitVideoPlayer::resetToZeroIfDone(){
	if(getIsMovieDone()){
		//   NSLog(@"MOVIE ENDED");
		if(!iAmLoading){
			// NSLog(@"MOVIE NOT PAUSED, NOT LOADING");            
            if(!videoHasEnded){
				//       NSLog(@"MOVIE NOT ENDED");
                //you only get one shot to tell unity that the movie has ended, for each time the movie successfully loads.
                videoHasEnded = true;
				//     NSLog(@"MOVIE ENDED");
				
                
                //provide callback to Unity if the video ends
				
				
				//CALLBACK HERE FOR VIDEO ENDED - IMPLEMENT IN MAX
                handleVideoEnded(this);
                //reset to zero if you're set to loop normal mode.
//                if(!isPaused && loopState == OF_LOOP_NORMAL){
//                    setPosition(0.0);
//                    setPaused(isPaused);
//                }
				
            }
		}
        
	}	
}


int MaxQTKitVideoPlayer::getMovieLoopState()
{
	return loopState;
}


//bool MaxQTKitVideoPlayer::getMovieLoopState()
//{
//	if(moviePlayer == NULL) return NO;
//	
//	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//	
//	bool loops = moviePlayer.loops;
//	
//	[pool drain];
//	
//	return loops;
//}


bool MaxQTKitVideoPlayer::isFrameNew()
{
	return bNewFrame;
}

void MaxQTKitVideoPlayer::bind()
{
	if(moviePlayer == NULL || !moviePlayer.useTexture) return;
	
	[moviePlayer bindTexture];	
}

void MaxQTKitVideoPlayer::unbind()
{
	if(moviePlayer == NULL || !moviePlayer.useTexture) return;
	
	[moviePlayer unbindTexture];
}

void MaxQTKitVideoPlayer::draw(float x, float y)
{
	if(moviePlayer == NULL || !moviePlayer.useTexture) return;
	
	draw(x,y, moviePlayer.movieSize.width, moviePlayer.movieSize.height);
}

void MaxQTKitVideoPlayer::draw(float x, float y, float w, float h)
{
	if(moviePlayer == NULL || !moviePlayer.useTexture) return;
	
	[moviePlayer draw:NSMakeRect(x, y, w, h)];
}

CVPixelBufferRef MaxQTKitVideoPlayer::getPixelsRef(){
	
	if(!moviePlayer.usePixels) {
		return NULL;
	}
	
	return [moviePlayer _latestPixelFrame];	
}




unsigned char* MaxQTKitVideoPlayer::getPixels()
{
	if(moviePlayer == NULL || !moviePlayer.usePixels) {
		return NULL;
	}
	
	if(moviePixels == NULL){
		moviePixels = new unsigned char[int(moviePlayer.movieSize.width) * int(moviePlayer.movieSize.height) * 4];
	}
	
	//don't get the pixels every frame if it hasn't updated
	if(bHavePixelsChanged){
		[moviePlayer pixels:moviePixels];
		bHavePixelsChanged = false;
	}
	
	return moviePixels;
}

void MaxQTKitVideoPlayer::setPosition(float pct)
{
	if(moviePlayer == NULL) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    if(pct == 0.0){
        videoHasEnded = false;
    }
	moviePlayer.position = pct;
	
	[pool drain];
}

void MaxQTKitVideoPlayer::setVolume(float myVolume)
{
	if(moviePlayer == NULL) return;
	
    volume = myVolume;
    
    if(iAmLoaded){
		moviePlayer.volume = volume;
    }
	
}

void MaxQTKitVideoPlayer::setFrame(int frame)
{
	if(moviePlayer == NULL) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	moviePlayer.frame = frame % moviePlayer.frameCount;
	
	[pool drain];
	
}

int MaxQTKitVideoPlayer::getCurrentFrame()
{
	if(moviePlayer == NULL || iAmLoading || !iAmLoaded) return 0;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	int currentFrame = moviePlayer.frame;
	
	[pool drain];	
	
	return currentFrame;	
}

int MaxQTKitVideoPlayer::getTotalNumFrames()
{
	return nFrames;
}

void MaxQTKitVideoPlayer::setLoopState(bool loops)
{
	if(moviePlayer == NULL) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	moviePlayer.loops = loops;
	
	[pool drain];
}

void MaxQTKitVideoPlayer::setLoopState(int ofLoopState)
{
	if(ofLoopState == OF_LOOP_NONE){
		setLoopState(false);
	}
	else if(ofLoopState == OF_LOOP_NORMAL){
		setLoopState(true);
	}
	
	//TODO support OF_LOOP_PALINDROME
}



float MaxQTKitVideoPlayer::getSpeed()
{
	if(moviePlayer == NULL) return 0;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	float rate = moviePlayer.rate;
	[pool drain];

	return rate;
}

float MaxQTKitVideoPlayer::getDuration()
{
	return duration;
}

float MaxQTKitVideoPlayer::getPositionInSeconds()
{
	return getPosition() * duration;
}

float MaxQTKitVideoPlayer::getPosition()
{
	if(moviePlayer == NULL) return 0;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	float pos = moviePlayer.position;
	
	[pool drain];
	
	return pos;
}

bool MaxQTKitVideoPlayer::getIsMovieDone()
{
	if(moviePlayer == NULL) return false;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];	
	
	bool isDone = moviePlayer.isFinished;
	
	[pool drain];
	
	return isDone;
}

int MaxQTKitVideoPlayer::getTextureWidth()
{
	return moviePlayer.movieTextureSize.width;
}




int MaxQTKitVideoPlayer::getTextureHeight()
{
	return moviePlayer.movieTextureSize.height;
}

int MaxQTKitVideoPlayer::getWidth()
{
	return moviePlayer.movieSize.width;
}




int MaxQTKitVideoPlayer::getHeight()
{
	return moviePlayer.movieSize.height;
}
void MaxQTKitVideoPlayer::repairContext()
{
	[moviePlayer repairContext];
}
