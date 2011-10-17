/**
 @file
 max.jit.BC.QTKit - qtkit jit.qt.movie replacement
 + high quality movie playback on OSX
 
 @ingroup	examples
 
 *
 * Brian Chasalow, brian@chasalow.com 2011 
 * thanks to Anton Marini for FBO draw code! www.v002.info
 * Also, this would have been impossible without Rob Ramirez, for help with Jitter and file loading!
 */



#include "jit.common.h"
#include "jit.gl.h"
#include "ext_obex.h"



// Max object instance data
// Note: most instance data is in the Jitter object which we will wrap
typedef struct _max_jit_BC_QTKit {
	t_object	ob;
	void		*obex;
	t_symbol		*servername; //NOTIFY EXAMPLE
	void			*texout;
    void            *dumpout;
	void			*renderer;
} t_max_jit_BC_QTKit;


// prototypes
BEGIN_USING_C_LINKAGE
t_jit_err	jit_BC_QTKit_init(void);
void		*max_jit_BC_QTKit_new(t_symbol *s, long argc, t_atom *argv);
void		max_jit_BC_QTKit_free(t_max_jit_BC_QTKit *x);
END_USING_C_LINKAGE

// custom draw
void max_jit_BC_QTKit_bang(t_max_jit_BC_QTKit *x);
void max_jit_BC_QTKit_draw(t_max_jit_BC_QTKit *x, t_symbol *s, long argc, t_atom *argv);

void max_jit_BC_QTKit_notify(t_max_jit_BC_QTKit *x, t_symbol *s, t_symbol *msg, void *ob, void *data);



t_symbol *ps_jit_gl_texture,*ps_draw, *ps_out_name;

// globals
static void	*max_jit_BC_QTKit_class = NULL;
static CGLContextObj cachedContextObj = NULL;
//			t_jit_gl_context ctx = jit_gl_get_context();

/************************************************************************************/
void max_jit_BC_QTKit_bang(t_max_jit_BC_QTKit *x)
{
	//	typedmess((t_object *)x,ps_draw,0,NULL);
	max_jit_BC_QTKit_draw(x,ps_draw,0,NULL);	
}

void max_jit_BC_QTKit_draw(t_max_jit_BC_QTKit *x, t_symbol *s, long argc, t_atom *argv)
{
	t_atom a;
	// get the jitter object
	t_jit_object *jitob = (t_jit_object*)max_jit_obex_jitob_get(x);
//	if(cachedContextObj != CGLGetCurrentContext()){
//		post("context changed, calling dest changed");	
//		cachedContextObj = CGLGetCurrentContext();
		
//		jit_object_method(jitob, gensym("dest_changed"), gensym("dest_changed"), 0L, 0);

//		void* renderer =  jit_object_method(jitob, gensym("get_render_ptr"));
//		if(renderer != NULL){
//			x->renderer = renderer;
//		//	post("found a jit.gl.render object!");	
//		}
//		else{
//		//	post("cant find jit.gl.render object!");	
//		}
//		if(x->renderer != NULL)
//		jit_object_method(x->renderer, gensym("drawswap"), gensym("drawswap"), 0L, 0);
//		t_symbol *obj_class = jit_object_classname(x->renderer);
//		jit_object_post((t_object*)x, obj_class->s_name); //jit_gl_render
		

//	}
	// call the jitter object's draw method
	jit_object_method(jitob,s,s,0L, 0);

	jit_atom_setsym(&a,jit_attr_getsym(jitob,ps_out_name));
	outlet_anything(x->texout,ps_jit_gl_texture,1,&a);			
	
	
}


int main(void)
{	
	void *p, *q;
	
	jit_BC_QTKit_init();	
	setup((t_messlist**)&max_jit_BC_QTKit_class, (method)max_jit_BC_QTKit_new, (method)max_jit_BC_QTKit_free, sizeof(t_max_jit_BC_QTKit), 0, A_GIMME, 0);
	
	p = max_jit_classex_setup(calcoffset(t_max_jit_BC_QTKit, obex));
	q = jit_class_findbyname(gensym("jit_BC_QTKit"));    
	max_jit_classex_standard_wrap(p, q, 0);						// attrs & methods for getattributes, dumpout, maxjitclassaddmethods, etc
	
	// custom draw handler so we can output our texture.
	// override default ob3d bang/draw methods
	addbang((method)max_jit_BC_QTKit_bang);
	max_addmethod_defer_low((method)max_jit_BC_QTKit_draw, "draw");  
	    
   	// use standard ob3d assist method
    addmess((method)max_jit_ob3d_assist, "assist", A_CANT,0);  
	
	//NOTIFY EXAMPLE: HERE'S WHERE WE DECLARE OUR OWN NOTIFY METHOD
    addmess((method)max_jit_BC_QTKit_notify, "notify", A_CANT,0);  

	
	// add methods for 3d drawing
    max_ob3d_setup();
	ps_jit_gl_texture = gensym("jit_gl_texture");
	ps_draw = gensym("draw");
	ps_out_name = gensym("out_name");
//    ps_servername = gensym("servername");
//    ps_appname = gensym("appname");
//    ps_clear = gensym("clear");
	
	//    addmess((method)max_jit_mop_assist, "assist", A_CANT, 0);	// standard matrix-operator (mop) assist fn
	return 0;
}


void max_jit_BC_QTKit_notify(t_max_jit_BC_QTKit *x, t_symbol *s, t_symbol *msg, void *ob, void *data)
{
	if (msg==gensym("splat")) {
		post("notify: server=%s message=%s",s->s_name,msg->s_name);
		if (!data) {
			error("splat message NULL pointer");
			return;
		}
		//here's where we output using the rightmost outlet
		//we just happen to know that "data" points to a t_atom[3]
		//alternately you could use max_jit_obex_dumpout_get just to get 
		//the outlet pointer
		max_jit_obex_dumpout(x,msg,3,(t_atom *)data); 
	}
	if (msg==gensym("frameIsNew")) {
		//post("notify: server=%s message=%s",s->s_name,msg->s_name);
		if (!data) {
			error("frameIsNew message NULL pointer");
			return;
		}
		//send frameIsNew 0 or 1 msg out
		max_jit_obex_dumpout(x,msg,1,(t_atom *)data);		
		
		//send texture out if the frameIsNew (unique 1 is forced. should override/implement this attribute)
//		if(jit_atom_getlong(data) == 1){
//		}
	}		
}

/************************************************************************************/
// Object Life Cycle

void *max_jit_BC_QTKit_new(t_symbol *s, long argc, t_atom *argv)
{
	t_max_jit_BC_QTKit	*x;
	void *jit_ob;
	long attrstart;
	t_symbol *dest_name_sym = _jit_sym_nothing;

	
	x = (t_max_jit_BC_QTKit*)max_jit_obex_new(max_jit_BC_QTKit_class, gensym("jit_BC_QTKit"));
	if (x) {
		//get normal args
		attrstart = max_jit_attr_args_offset(argc,argv);
		if (attrstart&&argv) 
		{
			jit_atom_arg_getsym(&dest_name_sym, 0, attrstart, argv);
		}
		
		if (jit_ob = jit_object_new(gensym("jit_BC_QTKit"), dest_name_sym)) 
		{
//			max_jit_obex_jitob_set(x, jit_ob);
//			max_jit_obex_dumpout_set(x, outlet_new(x,NULL));
//			max_jit_attr_args(x, argc, argv);		
//			
//			// attach the jit object's ob3d to a new outlet for sending drawing messages.	
//			max_jit_ob3d_attach(x, jit_ob, outlet_new(x, "jit_matrix"));
			// set internal jitter object instance
			max_jit_obex_jitob_set(x, jit_ob);
			
			// process attribute arguments 
			max_jit_attr_args(x, argc, argv);		
			
            // add a general purpose outlet (rightmost)
            x->dumpout = outlet_new(x,NULL);
			max_jit_obex_dumpout_set(x, x->dumpout);
			
			// this outlet is used to shit out textures! yay!
			x->texout = outlet_new(x, "jit_gl_texture");
			
			//NOTIFY EXAMPLE: GENERATING A UNIQUE NAME + ASSOCIATING WITH JIT OBJECT(SERVER)
			x->servername = jit_symbol_unique(); 
			jit_object_method(jit_ob,_jit_sym_register,x->servername); //this registers w/ the name
			jit_object_attach(x->servername,x);	//this attaches max object(client) with jit object(server)
			
		} 
		else 
		{
			jit_object_error((t_object *)x,"jit.BC.QTKit: could not allocate object");
			freeobject((t_object *)x);
			x = NULL;
		}
		
		}
	return (x);
}


void max_jit_BC_QTKit_free(t_max_jit_BC_QTKit *x)
{
//	max_jit_mop_free(x);
	//NOTIFY EXAMPLE: DETACH FROM JIT OBJECT(SERVER)
	jit_object_detach(x->servername,x);

	max_jit_ob3d_detach(x);
	jit_object_free(max_jit_obex_jitob_get(x));
	max_jit_obex_free(x);
}

