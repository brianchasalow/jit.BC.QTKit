/**
 @file
 jit.BC.QTKit - qtkit jit.qt.movie replacement
 + high quality movie playback on OSX
 
 @ingroup	examples
 
 *
 * Brian Chasalow, brian@chasalow.com 2011 
 * Thanks to Anton Marini for FBO draw code! www.v002.info
 * Also, this would have been impossible without Rob Ramirez, for help with Jitter and file loading!

 */
//
#include "jit.common.h"
#include "jit.gl.h"
#include "jit.gl.ob3d.h"
#include "ext_obex.h"


//#include <iostream>
//#include <string>
//#include <fstream>
//#include <sstream>
//#include <cstddef>
#include "MaxQTKitVideoPlayer.h"
//#include <cstdio>    //std::remove
//#include <vector>
//using namespace std;

#ifdef MAC_VERSION
#if !TARGET_RT_MAC_MACHO
#define JIT_BC_QTKIT_PATH_STYLE		PATH_STYLE_COLON
#define JIT_BC_QTKIT_PATH_TYPE		PATH_TYPE_ABSOLUTE
#else
#define JIT_BC_QTKIT_PATH_STYLE		PATH_STYLE_SLASH
#define JIT_BC_QTKIT_PATH_TYPE		PATH_TYPE_BOOT
#endif
#endif

#ifdef WIN_VERSION
#define JIT_BC_QTKIT_PATH_STYLE		PATH_STYLE_NATIVE_WIN
#define JIT_BC_QTKIT_PATH_TYPE		PATH_TYPE_ABSOLUTE
#endif


// Our Jitter object instance data
typedef struct _jit_BC_QTKit {
	t_object	ob;

	//uh, what/why? "3d object extension.  This is what all objects in the GL group have in common."
	void				*ob3d;

	NSRect latestBounds;
	t_symbol			*texturename;	

	long dim[2];			// output dim
	BOOL needsRedraw;

	// internal jit.gl.texture object
	t_jit_object *output;
	
} t_jit_BC_QTKit;


t_jit_err jit_ob3d_dest_name_set(t_jit_object *x, void *attr, long argc, t_atom *argv);

// prototypes
BEGIN_USING_C_LINKAGE
t_jit_err		jit_BC_QTKit_init				(void); 
t_jit_BC_QTKit	*jit_BC_QTKit_new				(t_symbol * dest_name);
void			jit_BC_QTKit_free				(t_jit_BC_QTKit *x);

void jit_BC_QTKit_read(t_jit_BC_QTKit *x, t_symbol *s, long ac, t_atom *av);
t_jit_err jit_BC_QTKit_play(t_jit_BC_QTKit *x);

t_jit_err jit_BC_QTKit_draw(t_jit_BC_QTKit *jit_BC_QTKit_instance);
// dim
t_jit_err jit_BC_QTKit_setattr_dim(t_jit_BC_QTKit *x, void *attr, long argc, t_atom *argv);
// @texturename to read a named texture.
t_jit_err jit_BC_QTKit_texturename(t_jit_BC_QTKit *jit_BC_QTKit_instance, void *attr, long argc, t_atom *argv);
// @out_name for output...
t_jit_err jit_BC_QTKit_getattr_out_name(t_jit_BC_QTKit *jit_BC_QTKit_instance, void *attr, long *ac, t_atom **av);

// handle context changes - need to rebuild IOSurface + textures here.
t_jit_err jit_BC_QTKit_dest_closing(t_jit_BC_QTKit *x);
t_jit_err jit_BC_QTKit_dest_changed(t_jit_BC_QTKit *x);


END_USING_C_LINKAGE


// symbols
t_symbol *ps_texture;
t_symbol *ps_width;
t_symbol *ps_height;
t_symbol *ps_glid;
t_symbol *ps_flip;
t_symbol *ps_automatic;
t_symbol *ps_drawto;
t_symbol *ps_draw;

// for our internal texture
extern t_symbol *ps_jit_gl_texture;

// globals
static MaxQTKitVideoPlayer* videoPlayer = NULL;
static void *s_jit_BC_QTKit_class = NULL;
int numbiter = 0;
#define CELL_PTR_1D (info,data,x) (((uchar *)(data))+(info)->dimstride[0]*(x))
#define CELL_PTR_2D (info,data,x,y) (CELL_PTR_1D(info,data,x)+(info)->dimstride[1]*(y))
#define CELL_PTR_3D (info,data,x,y,z) (CELL_PTR_2D(info,data,x,y)+(info)->dimstride[2]*(z))



/************************************************************************************/




#pragma mark -
#pragma mark Init, New, Cleanup, Context changes

//---------------------------------------------------------------------------
t_jit_err jit_BC_QTKit_init(void) 
{
	
	// setup our OB3D flags to indicate our capabilities.
	long ob3d_flags = JIT_OB3D_NO_MATRIXOUTPUT; // no matrix output
	ob3d_flags |= JIT_OB3D_NO_ROTATION_SCALE;
	ob3d_flags |= JIT_OB3D_NO_POLY_VARS;
	ob3d_flags |= JIT_OB3D_NO_FOG;
	ob3d_flags |= JIT_OB3D_NO_MATRIXOUTPUT;
	ob3d_flags |= JIT_OB3D_NO_LIGHTING_MATERIAL;
	ob3d_flags |= JIT_OB3D_NO_DEPTH;
	ob3d_flags |= JIT_OB3D_NO_COLOR;
	
	s_jit_BC_QTKit_class = jit_class_new("jit_BC_QTKit", (method)jit_BC_QTKit_new, (method)jit_BC_QTKit_free, sizeof(t_jit_BC_QTKit),A_DEFSYM, 0L);
	void *ob3d;
	ob3d = jit_ob3d_setup(s_jit_BC_QTKit_class, 
						  calcoffset(t_jit_BC_QTKit, ob3d), 
						  ob3d_flags);
	// OB3D methods
	jit_class_addmethod(s_jit_BC_QTKit_class, 
						(method)jit_BC_QTKit_dest_closing, "dest_closing", A_CANT, 0L);
	jit_class_addmethod(s_jit_BC_QTKit_class, 
						(method)jit_BC_QTKit_dest_changed, "dest_changed", A_CANT, 0L);
	
	jit_class_addmethod(s_jit_BC_QTKit_class, 
						(method)jit_BC_QTKit_draw, "ob3d_draw", A_CANT, 0L);
	
	// must register for ob3d use
	//also, 	//NOTIFY EXAMPLE: WE NEED A "REGISTER" METHOD SO THAT CLIENTS CAN ATTACH TO US
	jit_class_addmethod(s_jit_BC_QTKit_class, 
						(method)jit_object_register, "register", A_CANT, 0L);

	// must register for ob3d use
	jit_class_addmethod(s_jit_BC_QTKit_class, 
						(method)jit_BC_QTKit_play, "play", A_GIMME, 0L);
//	
//	// define our dest_closing and dest_changed methods. 
//	// these methods are called by jit.gl.render when the 
//	// destination context closes or changes: for example, when 
//	// the user moves the window from one monitor to another. Any 
//	// resources your object keeps in the OpenGL machine 
//	// (e.g. textures, display lists, vertex shaders, etc.) 
//	// will need to be freed when closing, and rebuilt when it has 
//	// changed. In this object, these functions do nothing, and 
//	// could be omitted.
//	

//	// add attributes
	long attrflags = JIT_ATTR_GET_DEFER_LOW | JIT_ATTR_SET_USURP_LOW;
//	
	t_jit_object *attr;
	attr = (t_jit_object*)jit_object_new(_jit_sym_jit_attr_offset_array,"dim",_jit_sym_long,2,attrflags,
                          (method)0L,(method)jit_BC_QTKit_setattr_dim,0/*fix*/,calcoffset(t_jit_BC_QTKit,dim));

    jit_class_addattr(s_jit_BC_QTKit_class,attr);	
	attr = (t_jit_object*)jit_object_new(_jit_sym_jit_attr_offset,"texturename",_jit_sym_symbol,attrflags,
						  (method)0L,(method)jit_BC_QTKit_texturename,calcoffset(t_jit_BC_QTKit, texturename));		
	jit_class_addattr(s_jit_BC_QTKit_class,attr);	
	
	attrflags = JIT_ATTR_GET_DEFER_LOW | JIT_ATTR_SET_OPAQUE_USER;
	attr = (t_jit_object*)jit_object_new(_jit_sym_jit_attr_offset,"out_name",_jit_sym_symbol, attrflags,
						  (method)jit_BC_QTKit_getattr_out_name,(method)0L,0);	
	jit_class_addattr(s_jit_BC_QTKit_class,attr);
	
	
	
	ps_texture = gensym("texture");
	ps_width = gensym("width");
	ps_height = gensym("height");
	ps_glid = gensym("glid");
	ps_flip = gensym("flip");
	ps_automatic = gensym("automatic");
	ps_drawto = gensym("drawto");
	ps_draw = gensym("draw");
	
		
		// add method(s)
	jit_class_addmethod(s_jit_BC_QTKit_class, (method)jit_BC_QTKit_read, "read", A_GIMME, 0);

	// finalize class
	jit_class_register(s_jit_BC_QTKit_class);
	
	
	return JIT_ERR_NONE;
}



t_jit_err jit_BC_QTKit_getattr_out_name(t_jit_BC_QTKit *x, void *attr, long *ac, t_atom **av)
{
	if ((*ac)&&(*av)) {
		//memory passed in, use it
	} else {
		//otherwise allocate memory
		*ac = 1;
		if (!(*av = (t_atom*)jit_getbytes(sizeof(t_atom)*(*ac)))) {
			*ac = 0;
			return JIT_ERR_OUT_OF_MEM;
		}
	}
	jit_atom_setsym(*av,jit_attr_getsym(x->output,_jit_sym_name));
	// jit_object_post((t_object *)x,"jit.gl.imageunit: sending output: %s", JIT_SYM_SAFECSTR(jit_attr_getsym(x->output,_jit_sym_name)));
	
	return JIT_ERR_NONE;
}		

// #texturename
t_jit_err jit_BC_QTKit_texturename(t_jit_BC_QTKit *jit_BC_QTKit_instance, void *attr, long argc, t_atom *argv)
{
	t_symbol *s=jit_atom_getsym(argv);
	
	jit_BC_QTKit_instance->texturename = s;
	if (jit_BC_QTKit_instance->output)
		jit_attr_setsym(jit_BC_QTKit_instance->output,_jit_sym_name,s);
	jit_attr_setsym(jit_BC_QTKit_instance,ps_texture,s);
	
	return JIT_ERR_NONE;
}

// #play
t_jit_err jit_BC_QTKit_play(t_jit_BC_QTKit *x)
{
	if(videoPlayer && x){
		videoPlayer->play();	
	}
	return JIT_ERR_NONE;
}


t_jit_err jit_BC_QTKit_setattr_dim(t_jit_BC_QTKit *jit_BC_QTKit_instance, void *attr, long argc, t_atom *argv)
{
    long i;
	long v;
    
	if (jit_BC_QTKit_instance)
	{
		jit_BC_QTKit_instance->needsRedraw = YES;
		
		for(i = 0; i < JIT_MATH_MIN(argc, 2); i++)
		{
			v = jit_atom_getlong(argv+i);
			if (jit_BC_QTKit_instance->dim[i] != JIT_MATH_MIN(v,1))
			{
				jit_BC_QTKit_instance->dim[i] = v;
			}
		}
        
        // update our internal texture as well.
        jit_attr_setlong_array(jit_BC_QTKit_instance->output, _jit_sym_dim, 2, jit_BC_QTKit_instance->dim);
        
		return JIT_ERR_NONE;
	}
	return JIT_ERR_INVALID_PTR;
}



t_jit_err jit_BC_QTKit_dest_closing(t_jit_BC_QTKit *x)
{
	return JIT_ERR_NONE;
}

t_jit_err jit_BC_QTKit_dest_changed(t_jit_BC_QTKit *x)
{	
	post("dest changed!!!");
	if (x->output)
	{
	
		if(videoPlayer && videoPlayer->iAmLoaded &&  !videoPlayer->iAmLoading)
		{
			videoPlayer->repairContext();
		}
		
//		t_jit_object *jitob = (t_jit_object*)max_jit_obex_jitob_get(x);
		//	jit_object_error((t_jit_object *)jitob,"jit.BC_QTKIT: could not call draw");

		//		t_jit_object* myobj  = (t_jit_object*)jit_object_findregistered(context);
		//		if(myobj == NULL){
		//			post("cant find context!");	
		//		}
		//		else{
		//				post("found context");	
		//		jit_object_method(myobj, gensym("bang"), gensym("bang"), 0L, 0);
		//		}
		
		
		
		
		t_symbol *context = jit_attr_getsym(x,ps_drawto);		
		jit_attr_setsym(x->output,ps_drawto,context);
		
		// our texture has to be bound in the new context before we can use it
		// http://cycling74.com/forums/topic.php?id=29197
		t_jit_gl_drawinfo drawInfo;
		t_symbol *texName = jit_attr_getsym(x->output, gensym("name"));
		jit_gl_drawinfo_setup(x, &drawInfo);
		jit_gl_bindtexture(&drawInfo, texName, 0);
		jit_gl_unbindtexture(&drawInfo, texName, 0);
	}
	
	x->needsRedraw = YES;
	

	return JIT_ERR_NONE;
}
/************************************************************************************/
// Object Life Cycle

t_jit_BC_QTKit *jit_BC_QTKit_new(t_symbol * dest_name)
{
	t_jit_BC_QTKit	*x = NULL;
	
	if(videoPlayer == NULL){		
		videoPlayer = new MaxQTKitVideoPlayer();
	}
	
	if(x = (t_jit_BC_QTKit*)jit_object_alloc(s_jit_BC_QTKit_class)){
	x->output = (t_jit_object*)jit_object_new(ps_jit_gl_texture,dest_name);
	x->latestBounds = NSMakeRect(0, 0, 640, 480);
	x->needsRedraw = YES;

		if(x->output){
			x->texturename = jit_symbol_unique();		
			// set texture attributes.
			jit_attr_setsym(x->output,_jit_sym_name, x->texturename);
			jit_attr_setsym(x->output,gensym("defaultimage"),gensym("black"));
			jit_attr_setlong(x->output,gensym("rectangle"), 1);
			jit_attr_setlong(x->output, gensym("flip"), 0);
			
			x->dim[0] = 640;
			x->dim[1] = 480;
			jit_attr_setlong_array(x->output, _jit_sym_dim, 2, x->dim);
			
			
		}
		else
		{
			post("error creating internal texture object");
			jit_object_error((t_object *)x,"jit.BC.QTKit: could not create texture");
			x->texturename = _jit_sym_nothing;		
		}
		jit_ob3d_new(x, dest_name);

	}
	else 
	{
		x = NULL;
	}

	return x;
}

t_jit_err jit_BC_QTKit_draw(t_jit_BC_QTKit *x)
{
	
	if (!x){
		return JIT_ERR_INVALID_PTR;		
	}
	

	
	
	
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	
	if(videoPlayer != NULL){
		videoPlayer->update();
	}
    
///	post("videoplayer: %i iamloaded %i iamloading %i isframenew %i needsredraw %i", (videoPlayer == NULL), videoPlayer->iAmLoaded, !videoPlayer->iAmLoading, videoPlayer->isFrameNew(), x->needsRedraw);
	if((videoPlayer != NULL && videoPlayer->iAmLoaded &&  !videoPlayer->iAmLoading) && (videoPlayer->isFrameNew()|| x->needsRedraw))
	{
		// this means we need to render into our internal texture, via an FBO.
		// for now, we are going to do this all inline, in place.
		
		// clearly we need our texture for this...
		if(x->output)
		{
			x->needsRedraw = NO;
			
			// cache/restore context in case in capture mode
//			t_jit_gl_context ctx = jit_gl_get_context();
			
//			jit_ob3d_set_context(ctx);
			
			// add texture to OB3D list.
			jit_attr_setsym(x,ps_texture, jit_attr_getsym(x->output, gensym("name")));
			
                        
			// we need to update our internal texture to the latest known size of our movie's image.
            long newdim[2];			// output dim
			
			newdim[0] = videoPlayer->getWidth();
			newdim[1] = videoPlayer->getHeight();
			
            // update our internal attribute so attr messages work
			jit_attr_setlong_array(x, _jit_sym_dim, 2, newdim);
			
			
			// save some state
			GLint previousFBO;	// make sure we pop out to the right FBO
			GLint previousReadFBO;
			GLint previousDrawFBO;
			GLint previousMatrixMode;
			
			glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
			glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
			glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
			glGetIntegerv(GL_MATRIX_MODE, &previousMatrixMode);
			
			// save texture state, client state, etc.
			glPushAttrib(GL_ALL_ATTRIB_BITS);
			glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
			
			
			// We are going to bind our FBO to our internal jit.gl.texture as COLOR_0 attachment
			// We need the ID, width/height.
			
			GLuint texname = jit_attr_getlong(x->output,ps_glid);
			GLuint width = jit_attr_getlong(x->output,ps_width);
			GLuint height = jit_attr_getlong(x->output,ps_height);
			
			//post("texture id is %u width %u height %u", texname, width, height);
			
			// FBO generation/attachment to texture
			GLuint tempFBO;
			glGenFramebuffers(1, &tempFBO);
			glBindFramebuffer(GL_FRAMEBUFFER, tempFBO);
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_ARB, texname, 0);
			
			// it work?
			GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
			if(status == GL_FRAMEBUFFER_COMPLETE)
			{
				//post("qtkit FBO complete");
				
				// save more state.
				glClearColor(0.0, 0.0, 0.0, 0.0);
				glClear(GL_COLOR_BUFFER_BIT);				
				
				glMatrixMode(GL_TEXTURE);
				glPushMatrix();
				glLoadIdentity();
				
				
				glViewport(0, 0,  width, height);
				glMatrixMode(GL_PROJECTION);
				glPushMatrix();
				glLoadIdentity();
				
				glOrtho(0.0, width,  0.0,  height, -1, 1);		
				
				glMatrixMode(GL_MODELVIEW);
				glPushMatrix();
				glLoadIdentity();
				
				// render our qtkit texture to our jit.gl.texture's texture.
				glColor4f(1.0, 1.0, 1.0, 1.0);
				
				glActiveTexture(GL_TEXTURE0);
				
				{
                    
					// do not need blending if we use black border for alpha and replace env mode, saves a buffer wipe
					// we can do this since our image draws over the complete surface of the FBO, no pixel goes untouched.
//                    glEnable(GL_TEXTURE_RECTANGLE_EXT);
  //                  glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [frame textureName]);
					[videoPlayer->moviePlayer bindTexture];

					
					glDisable(GL_BLEND);
					glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);	
					
					// move to VA for rendering
					GLfloat tex_coords[] = 
					{
						width,height,
						0.0,height,
						0.0,0.0,
						width,0.0
					};
					
					GLfloat verts[] = 
					{
						width,height,
						0.0,height,
						0.0,0.0,
						width,0.0
					};
					
					glEnableClientState( GL_TEXTURE_COORD_ARRAY );
					glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
					glEnableClientState(GL_VERTEX_ARRAY);		
					glVertexPointer(2, GL_FLOAT, 0, verts );
					glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
					glDisableClientState(GL_VERTEX_ARRAY);
					glDisableClientState(GL_TEXTURE_COORD_ARRAY);
				}
				
				glMatrixMode(GL_MODELVIEW);
				glPopMatrix();
				glMatrixMode(GL_PROJECTION);
				glPopMatrix();
				
				glMatrixMode(GL_TEXTURE);
				glPopMatrix();
				
				glPopAttrib();
				glPopClientAttrib();
				
				[videoPlayer->moviePlayer unbindTexture];
				QTVisualContextTask(videoPlayer->moviePlayer._visualContext);

				glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
				glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
				glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
				
				glMatrixMode(previousMatrixMode);
				
				// clean up after ourselves
				glDeleteFramebuffers(1, &tempFBO);
				tempFBO = 0;
				
				glFlushRenderAPPLE();	
			}
			else 
			{
				post("jit.BC.QTKit could not attach to FBO");
			}
//			[frame release];
//			jit_gl_set_context(ctx);
		}
		
		
	}
	
	t_atom foo[1];
	jit_atom_setlong(&foo[0],videoPlayer->isFrameNew());			
	jit_object_notify(x,gensym("frameIsNew"), foo); //the last pointer argument could be anything.	
	
	
	[pool drain];
	
	return JIT_ERR_NONE;

}

void jit_BC_QTKit_free(t_jit_BC_QTKit *x)
{
	if(videoPlayer != NULL){		
		videoPlayer->close();

		if(videoPlayer)
		delete videoPlayer;

		videoPlayer = NULL;
		
		
		if(x->output)
			jit_object_free(x->output);
		
		// free ourselves
		jit_ob3d_free(x);
		
	}
	
	;	// nothing to free for our vertexreceive object
}

/************************************************************************************/
// Methods bound to input/inlets




void jit_BC_QTKit_read(t_jit_BC_QTKit *x, t_symbol *s, long ac, t_atom *av)
{
	char 				cpath[MAX_PATH_CHARS] = "";
	char 				filename[MAX_PATH_CHARS] = "mymovie.mov";
	short 				path;
	long				outtype;
	t_filehandle 		fh_read;
	t_symbol			*insym = NULL;
	
	if (av && ac)
		insym = jit_atom_getsym(av);
	
	if(insym == _jit_sym_nothing || insym == NULL){
		filename[0] = '\0';
		if (open_dialog(filename, &path, &outtype, 0L, 0)) {
			return;
		}
		insym = gensym(filename);
	}
	else { 
		strcpy(filename, insym->s_name);
		if (locatefile_extended(filename, &path, &outtype, 0L, 0)) {
			jit_object_error((t_object *)x,"jit.BC.QTKit: can't find file %s", insym->s_name);
			//result = JIT_ERR_GENERIC;
			//goto bail;
			return;
		}
	}
//	
	path_topathname(path, filename, cpath);
	path_nameconform(cpath,filename,JIT_BC_QTKIT_PATH_STYLE,JIT_BC_QTKIT_PATH_TYPE);
	strcpy(cpath,filename);			
	videoPlayer->loadMovie(filename, 0);

}















