
uniform vec3      	iResolution; 			// viewport resolution (in pixels)
uniform float     	iTime; 			// shader playback time (in seconds)
uniform vec4      	iMouse; 				// mouse pixel coords. xy: current (if MLB down), zw: click
uniform sampler2D 	iChannel0; 				// input channel 0


out vec4 fragColor;
vec2  fragCoord = gl_FragCoord.xy; // keep the 2 spaces between vec2 and fragCoord

// https://www.shadertoy.com/view/ls2Xzd
// Algorithm found in https://medium.com/community-play-3d/god-rays-whats-that-5a67f26aeac2
vec4 crepuscular_rays(vec2 texCoords, vec2 pos) {
    float decay = 0.92;
    float density = 1.0;
    float weight = 0.58767;
    // NUM_SAMPLES will describe the rays quality, you can play with
    const int nsamples = 150;

    vec2 tc = texCoords.xy;
    vec2 deltaTexCoord = tc - pos.xy;
    deltaTexCoord *= (1.0 / float(nsamples) * density);
    float illuminationDecay = 1.0;

    vec4 color = texture(iChannel0, tc.xy) * vec4(0.9);
	
    tc += deltaTexCoord * fract( sin(dot(texCoords.xy+fract(iTime), vec2(12.9898, 78.233)))* 43758.5453 );
    for (int i = 0; i < nsamples; i++)
	{
        tc -= deltaTexCoord;
        vec4 sampl = texture(iChannel0, tc.xy) * vec4(0.2); 

        sampl *= illuminationDecay * weight;
        color += sampl;
        illuminationDecay *= decay;
    }
    
    return color;
}

void main( void ){
	vec2 uv = fragCoord.xy / iResolution.xy;
	//uv.x *= iResolution.x/iResolution.y; //fix aspect ratio
    //vec3 pos = vec3(iMouse.xy/iResolution.xy - 0.5,iMouse.z-.5);
	vec3 pos = vec3(iMouse.xy/iResolution.xy + vec2(0.32, 0.530),iMouse.z-.5);

	pos.x *= iResolution.x/iResolution.y; //fix aspect ratio
	if (iMouse.z>.5)
	{
		pos.x=sin(iTime*.09)*.95;
		pos.y=sin(iTime*.09)*.95;
	}
	fragColor = crepuscular_rays(uv, pos.xy);
	/*vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 aa = texture(iChannel0,uv);
    //vec2 raysource =vec2(sin(iTime*0.5)*0.25+0.35,0.89);
    vec2 raysource =vec2(sin(iTime*0.5)*0.25+iMouse.x,iMouse.y);
    float rayamount = 0.0f;
    for(float i = 0.; i < 1.0;i+=0.01){
        if(length(texture(iChannel0,mix(uv,raysource,i)))>1.9){
            
        rayamount += 0.03/pow(distance(mix(uv,raysource,i),raysource)+1.0,2.0);
        }
    }
    aa+=rayamount;
//    if(length(aa)>1.9){
//            aa.xyz = vec3(1.0/(distance(uv,raysource)+1.0));
//           }
    fragColor = vec4(rayamount) +aa; */
}
