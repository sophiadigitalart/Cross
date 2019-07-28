// https://www.shadertoy.com/view/ttlXWS
uniform vec3      	iResolution; 			// viewport resolution (in pixels)
uniform float     	iTime; 			// shader playback time (in seconds)
uniform vec4      	iMouse; 				// mouse pixel coords. xy: current (if MLB down), zw: click
uniform sampler2D 	iChannel0; 				// input channel 0
/*
ad 2d crepuscular occlusion dither bayer eclipse

parent : https://www.shadertoy.com/view/4dyXWy
self   : https://www.shadertoy.com/view/ltsyWl

Instead of reading from a bitmap, this uses one of 2 bayer matrix generators.
Parents bufferA is a subroutine here: BuffA.mainImage() <- BA()

- no buffers (Bayer matrix bitmap is very optional)
- generalize to be more parametric, maybe?
*/

//blurriness of borders, sets contour line smoothness
// Will be scaled by shortest domain of screen resolution
// [>0.]!! Set to [1.] for ideal 1:1 subbixel smoothness.
// if (you use dFdx()) do [#define blur >=2.]
#define blur 1.

#define DITHER			//Dithering toggle
#define QUALITY		2	//0- low, 1- medium, 2- high

#define DECAY		.974
#define EXPOSURE	.24
#if (QUALITY==2)
 #define SAMPLES	64
 #define DENSITY	.97
 #define WEIGHT		.25
#else
#if (QUALITY==1)
 #define SAMPLES	32
 #define DENSITY	.95
 #define WEIGHT		.25
#else
 #define SAMPLES	16
 #define DENSITY	.93
 #define WEIGHT		.36
#endif
#endif


//planar zoom.
#define ViewZoom 3.
//sub-pixel blur
#define fsaa 14./min(iResolution.x,iResolution.y)
//View Frame
#define fra(u) (u-.5*iResolution.xy)*ViewZoom/iResolution.y

//maxiterations for bayer matrix, maximum value is number of bits of your data type?
//for crepuscular ray dithering [1..3] iterations are enough
//because it is basically "noisy scattering" so  any patterns in it are "just fine"
#define iterBayerMat 1
#define bayer2x2(a) (4-(a).x-((a).y<<1))%4
//return bayer matris (bitwise operands for speed over compatibility)
float GetBayerFromCoordLevel(vec2 pixelpos)
{ivec2 p=ivec2(pixelpos);int a=0
;for(int i=0; i<iterBayerMat; i++
){a+=bayer2x2(p>>(iterBayerMat-1-i)&1)<<(2*i);
}return float(a)/float(2<<(iterBayerMat*2-1));}
//https://www.shadertoy.com/view/XtV3RG

//analytic bayer over 2 domains, is unrolled loop of GetBayerFromCoordLevel().
//but in terms of reusing subroutines, which is faster,while it does not extend as nicely.
float bayer2  (vec2 a){a=floor(a);return fract(dot(a,vec2(.5, a.y*.75)));}
float bayer4  (vec2 a){return bayer2 (  .5*a)*.25    +bayer2(a);}
float bayer8  (vec2 a){return bayer4 (  .5*a)*.25    +bayer2(a);}
float bayer16 (vec2 a){return bayer4 ( .25*a)*.0625  +bayer4(a);}
float bayer32 (vec2 a){return bayer8 ( .25*a)*.0625  +bayer4(a);}
float bayer64 (vec2 a){return bayer8 (.125*a)*.015625+bayer8(a);}
float bayer128(vec2 a){return bayer16(.125*a)*.015625+bayer8(a);}
#define dither2(p)   (bayer2(  p)-.375      )
#define dither4(p)   (bayer4(  p)-.46875    )
#define dither8(p)   (bayer8(  p)-.4921875  )
#define dither16(p)  (bayer16( p)-.498046875)
#define dither32(p)  (bayer32( p)-.499511719)
#define dither64(p)  (bayer64( p)-.49987793 )
#define dither128(p) (bayer128(p)-.499969482)
//https://www.shadertoy.com/view/4ssfWM

//3 ways to approach a bayer matrix for dithering (or for loops within permutations)
float iib(vec2 u){
 return dither128(u);//analytic bayer, base2
 return GetBayerFromCoordLevel(u*999.);//iterative bayer 
 //optionally: instad just use bitmap of a bayer matrix: (LUT approach)
 //return texture(iChannel1,u/iChannelResolution[1].xy).x;
}


//x is result, yz are position in normalized coords.
 //This is just a quick hack for this shader only.
vec3 sun( vec2 uv ) {	
//o put op inside this function, making p not a parameter of it, because
    vec2 p=fra(iMouse.zw)*.666;//damnit, the source shader has rather silly frame scaling, this irons it out a bit
    //but this is a poor overwriting patch
    //has something t do with averaging over 3 occluders within this function.
    //this one is special, and far from general.
    if(iMouse.z<=0.)p=vec2(sin(iTime), sin(iTime*.5)*.5);
    vec3 res;
    float di = distance(uv, p);
    res.x =  di <= .3333 ? sqrt(1. - di*3.) : 0.;
    res.yz = p;
    res.y /= (iResolution.x / iResolution.y);
    res.yz = (res.yz+1.)*.5;
    return res;}

#define SS blur/min(iResolution.x,iResolution.y)

float circle( vec2 p, float r){
 return smoothstep(SS,-SS,length(p)-r);
 return step(length(p)-r,.0);
    return length(p) < r ? 1. : 0.;//why would you do that?
}


//[buffA of https://www.shadertoy.com/view/4dyXWy ], merged into [Image]
vec4 BA(in vec2 uv, in float tex ){  
    //This buffer calculates occluders and a gaussian glowing blob.
    //Just see what it returns for any uv input.
    //It makes sense to buffer this as a matrix (low res 2d frame buffer)
    // ,because it is being looked up multiple times
    // With different offsets.
    //  This is NOT doing that, for no good reason at all 
    //   other than brute force benchmaking a bufferless approach
    uv=uv*2.-1.;
    float aspect = iResolution.x / iResolution.y;
   uv.x *= aspect;
    vec2 m=iMouse.xy;
    if(m.x<=0.)m=vec2(iResolution*.1);else m=(m/iResolution.xy)*2.-1.;//set mouse position
    m.x *= aspect;
    //above framing is not pretty. but thats not what is demoed here.
    
    float occluders= tex;
        //circle(uv-vec2(-.66,0), .366)-circle(uv+vec2(.75,.1),.18) + tex.x;
    //occluders+=circle(uv-vec2(.6,.2),.23);
    float mouse=smoothstep(SS,-SS,abs(abs(length(uv-m)-.2)-.05)-.02);//double ring
    //mouse cursor has an occluding crosshair:
    float mouse2=smoothstep(SS,-SS,abs(uv.x-m.x)-.03);//vertical bar
          mouse=max(mouse,mouse2);//union
    //mouse=clamp((mouse-length(uv-m)*2.),.0,1.);//alpha-shade crosshair
    
    //transparent disk on the right
    mouse2=smoothstep(SS,-SS,length(uv-m-vec2(.5,0))-.2);
    mouse=max(mouse,mouse2*.5);//union
        
  // mouse=max(mouse,.0);//optical illusion checker!
    //occluders+=mouse;//-=mouse and you have a "nightmare moon spitlight"
    occluders = min(occluders, 1.);
    vec3 light=min(sun(uv),1.);
    float col = max(light.x - occluders, 0.);
    return vec4(col,occluders,light.yz); //Gross hack to pass light pos as B and A values
}

out vec4 fragColor;
vec2  fragCoord = gl_FragCoord.xy; // keep the 2 spaces between vec2 and fragCoord

//void mainImage( out vec4 fragColor, in vec2 fragCoord ){
void main( void ){
	vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 coord = uv;
    float texA = texture( iChannel0, uv ).x;
    vec4 ic=BA(uv, texA);
    vec2 lightpos = ic.zw;   	
    float occ = ic.x; //light
    float obj = ic.y; //objects
    float dither = iib(fragCoord);
    vec2 dtc = (coord - lightpos)*(1./float(SAMPLES)*DENSITY);
    float illumdecay = 1.;
    
    for(int i=0; i<SAMPLES; i++)    {
        coord -= dtc;
        #ifdef DITHER
        	float s = BA(coord+(dtc*dither), texA).x;
        #else
            float s = BA(coord, texA).x  ;     
        #endif
        s *= illumdecay * WEIGHT;
        occ += s;
        illumdecay *= DECAY;
    }
        
	fragColor = vec4(vec3(.5,.7,.1)*obj/3.+occ*EXPOSURE,1.0);
}


/*
//return 16x16 Bayer matrix, without bitwiseOP, most compatible!
//likely best for old mobile hardware, likely most energy efficient.
//slowest (kept small for small resolutions)
float B16( vec2 _P ) {
    vec2    P1 = mod( _P, 2.0 );                    // (P >> 0) & 1
    vec2    P2 = floor( 0.5 * mod( _P, 4.0 ) );        // (P >> 1) & 1
    vec2    P4 = floor( 0.25 * mod( _P, 8.0 ) );    // (P >> 2) & 1
    vec2    P8 = floor( 0.125 * mod( _P, 16.0 ) );    // (P >> 3) & 1
    return 4.0*(4.0*(4.0*B2(P1) + B2(P2)) + B2(P4)) + B2(P8);
}//https://www.shadertoy.com/view/4tVSDm
*/

/*
//A 64x64 bayer matrix LUT. FAST, static size.
//best for non-mobile hardware, least energy efficient.
void populatePatternTable(){    
    pattern[0x00]=   0.; pattern[0x01]= 32.; pattern[0x02]=  8.; pattern[0x03]= 40.; pattern[0x04]=  2.; pattern[0x05]= 34.; pattern[0x06]= 10.; pattern[0x07]= 42.;   
    pattern[0x08]=  48.; pattern[0x09]= 16.; pattern[0x0a]= 56.; pattern[0x0b]= 24.; pattern[0x0c]= 50.; pattern[0x0d]= 18.; pattern[0x0e]= 58.; pattern[0x0f]= 26.;  
    pattern[0x10]=  12.; pattern[0x11]= 44.; pattern[0x12]=  4.; pattern[0x13]= 36.; pattern[0x14]= 14.; pattern[0x15]= 46.; pattern[0x16]=  6.; pattern[0x17]= 38.;   
    pattern[0x10]=  60.; pattern[0x19]= 28.; pattern[0x1a]= 52.; pattern[0x1b]= 20.; pattern[0x1c]= 62.; pattern[0x1d]= 30.; pattern[0x1e]= 54.; pattern[0x1f]= 22.;  
    pattern[0x20]=   3.; pattern[0x21]= 35.; pattern[0x22]= 11.; pattern[0x23]= 43.; pattern[0x24]=  1.; pattern[0x25]= 33.; pattern[0x26]=  9.; pattern[0x27]= 41.;   
    pattern[0x20]=  51.; pattern[0x29]= 19.; pattern[0x2a]= 59.; pattern[0x2b]= 27.; pattern[0x2c]= 49.; pattern[0x2d]= 17.; pattern[0x2e]= 57.; pattern[0x2f]= 25.;
    pattern[0x30]=  15.; pattern[0x31]= 47.; pattern[0x32]=  7.; pattern[0x33]= 39.; pattern[0x34]= 13.; pattern[0x35]= 45.; pattern[0x36]=  5.; pattern[0x37]= 37.;
    pattern[0x30]=  63.; pattern[0x39]= 31.; pattern[0x3a]= 55.; pattern[0x3b]= 23.; pattern[0x3c]= 61.; pattern[0x3d]= 29.; pattern[0x3e]= 53.; pattern[0x3f]= 21.;
}//www.efg2.com/Lab/Library/ImageProcessing/DHALF.TXT
//https://www.shadertoy.com/view/MlByzh
*/