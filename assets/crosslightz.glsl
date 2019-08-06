
uniform vec3      	iResolution; 			// viewport resolution (in pixels)
uniform float     	iTime; 					// shader playback time (in seconds)
uniform float     	iElapsed; 				// shader playback time delta (in seconds)
uniform float     	iStart;					// start adjustment
uniform vec4      	iMouse; 				// mouse pixel coords. xy: current (if MLB down), zw: click
uniform sampler2D 	iChannel0; 				// input channel 0
// https://www.shadertoy.com/view/4sf3RN

// Number Printing - @P_Malin
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

const float kCharBlank = 12.0;
const float kCharMinus = 11.0;
const float kCharDecimalPoint = 10.0;

out vec4 fragColor;
vec2  fragCoord = gl_FragCoord.xy; // keep the 2 spaces between vec2 and fragCoord

// https://www.shadertoy.com/view/ls2Xzd
// Algorithm found in https://medium.com/community-play-3d/god-rays-whats-that-5a67f26aeac2
vec4 crepuscular_rays(vec2 texCoords, vec2 pos) {

    float decay = 0.98;
    float density = 1.0;
    float weight = 0.58767;
    // NUM_SAMPLES will describe the rays quality, you can play with
    const int nsamples = 150;

    vec2 tc = texCoords.xy;
    vec2 deltaTexCoord = tc - pos.xy; //* sin(iTime)
    deltaTexCoord *= (1.0 / float(nsamples) * density);
    float illuminationDecay = 1.0;

    vec4 color = texture(iChannel0, tc.xy) * vec4(0.9);
	
    tc += deltaTexCoord * fract( sin(dot(texCoords.xy+fract(iTime), vec2(12.9898, 78.233)))* 43758.5453 );
    for (int i = 0; i < nsamples; i++)
	{
        tc -= deltaTexCoord;
        vec4 sampl = texture(iChannel0, tc.xy) * vec4(0.2); 

        sampl *= illuminationDecay * weight;
        color += sampl * (sin(iTime*16.0) + iStart);
        //color += sampl* (sin(iElapsed) + 0.1);
        illuminationDecay *= decay;
    }
    
    return color;
}
float SampleDigit(const in float fDigit, const in vec2 vUV)
{       
    if(vUV.x < 0.0) return 0.0;
    if(vUV.y < 0.0) return 0.0;
    if(vUV.x >= 1.0) return 0.0;
    if(vUV.y >= 1.0) return 0.0;
    
    // In this version, each digit is made up of a 4x5 array of bits
    
    float fDigitBinary = 0.0;
    
    if(fDigit < 0.5) // 0
    {
        fDigitBinary = 7.0 + 5.0 * 16.0 + 5.0 * 256.0 + 5.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 1.5) // 1
    {
        fDigitBinary = 2.0 + 2.0 * 16.0 + 2.0 * 256.0 + 2.0 * 4096.0 + 2.0 * 65536.0;
    }
    else if(fDigit < 2.5) // 2
    {
        fDigitBinary = 7.0 + 1.0 * 16.0 + 7.0 * 256.0 + 4.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 3.5) // 3
    {
        fDigitBinary = 7.0 + 4.0 * 16.0 + 7.0 * 256.0 + 4.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 4.5) // 4
    {
        fDigitBinary = 4.0 + 7.0 * 16.0 + 5.0 * 256.0 + 1.0 * 4096.0 + 1.0 * 65536.0;
    }
    else if(fDigit < 5.5) // 5
    {
        fDigitBinary = 7.0 + 4.0 * 16.0 + 7.0 * 256.0 + 1.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 6.5) // 6
    {
        fDigitBinary = 7.0 + 5.0 * 16.0 + 7.0 * 256.0 + 1.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 7.5) // 7
    {
        fDigitBinary = 4.0 + 4.0 * 16.0 + 4.0 * 256.0 + 4.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 8.5) // 8
    {
        fDigitBinary = 7.0 + 5.0 * 16.0 + 7.0 * 256.0 + 5.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 9.5) // 9
    {
        fDigitBinary = 7.0 + 4.0 * 16.0 + 7.0 * 256.0 + 5.0 * 4096.0 + 7.0 * 65536.0;
    }
    else if(fDigit < 10.5) // '.'
    {
        fDigitBinary = 2.0 + 0.0 * 16.0 + 0.0 * 256.0 + 0.0 * 4096.0 + 0.0 * 65536.0;
    }
    else if(fDigit < 11.5) // '-'
    {
        fDigitBinary = 0.0 + 0.0 * 16.0 + 7.0 * 256.0 + 0.0 * 4096.0 + 0.0 * 65536.0;
    }
    
    vec2 vPixel = floor(vUV * vec2(4.0, 5.0));
    float fIndex = vPixel.x + (vPixel.y * 4.0);
    
    return mod(floor(fDigitBinary / pow(2.0, fIndex)), 2.0);
}

float PrintValue(const in vec2 vStringCharCoords, const in float fValue, const in float fMaxDigits, const in float fDecimalPlaces)
{
    float fAbsValue = abs(fValue);
    
    float fStringCharIndex = floor(vStringCharCoords.x);
    
    float fLog10Value = log2(fAbsValue) / log2(10.0);
    float fBiggestDigitIndex = max(floor(fLog10Value), 0.0);
    
    // This is the character we are going to display for this pixel
    float fDigitCharacter = kCharBlank;
    
    float fDigitIndex = fMaxDigits - fStringCharIndex;
    if(fDigitIndex > (-fDecimalPlaces - 1.5))
    {
        if(fDigitIndex > fBiggestDigitIndex)
        {
            if(fValue < 0.0)
            {
                if(fDigitIndex < (fBiggestDigitIndex+1.5))
                {
                    fDigitCharacter = kCharMinus;
                }
            }
        }
        else
        {       
            if(fDigitIndex == -1.0)
            {
                if(fDecimalPlaces > 0.0)
                {
                    fDigitCharacter = kCharDecimalPoint;
                }
            }
            else
            {
                if(fDigitIndex < 0.0)
                {
                    // move along one to account for .
                    fDigitIndex += 1.0;
                }

                float fDigitValue = (fAbsValue / (pow(10.0, fDigitIndex)));

                // This is inaccurate - I think because I treat each digit independently
                // The value 2.0 gets printed as 2.09 :/
                //fDigitCharacter = mod(floor(fDigitValue), 10.0);
                fDigitCharacter = mod(floor(0.0001+fDigitValue), 10.0); // fix from iq
            }       
        }
    }

    vec2 vCharPos = vec2(fract(vStringCharCoords.x), vStringCharCoords.y);

    return SampleDigit(fDigitCharacter, vCharPos);  
}

float PrintValue(in vec2 inFragCoord, const in vec2 vPixelCoords, const in vec2 vFontSize, const in float fValue, const in float fMaxDigits, const in float fDecimalPlaces)
{
    return PrintValue((inFragCoord.xy - vPixelCoords) / vFontSize, fValue, fMaxDigits, fDecimalPlaces);
}

void main( void ){
	vec2 uv = fragCoord.xy / iResolution.xy;
	//uv.x *= iResolution.x/iResolution.y; //fix aspect ratio
    //vec3 pos = vec3(iMouse.xy/iResolution.xy - 0.5,iMouse.z-.5);
	//vec3 pos = vec3(iMouse.xy/iResolution.xy + vec2(iMouse.x, iMouse.y),iMouse.z-.5);
	//vec3 pos = vec3(iMouse.xy/iResolution.xy + vec2(0.32, 0.530),iMouse.z-.5);
	//vec3 pos = vec3(iMouse.xy/iResolution.xy + vec2(0.3, 0.530),iMouse.z-.5);
	//if (iMouse.z>.5)
	//{
		vec3 pos = vec3(iMouse.xy/iResolution.xy + vec2(iMouse.x, iMouse.y),iMouse.z-.5);
		//pos.x=sin(iTime*.09)*.95;
		//pos.y=sin(iTime*.09)*.95;
	//}
	pos.x *= iResolution.x/iResolution.y; //fix aspect ratio
	   // Multiples of 4x5 work best
    /*vec2 vFontSize = vec2(8.0, 15.0);
	vec4 vColour = vec4(0.7);
	vColour = mix( vColour, vec4(1.0, 1.0, 1.0, 0.0), PrintValue(fragCoord, vec2(10.0, 10.0), vFontSize, iTime, 3.0, 5.0));
	fragColor = mix( vec4(1.0, 0.0, 0.0, 0.0), crepuscular_rays(uv, pos.xy), vColour);*/
	fragColor = crepuscular_rays(uv, pos.xy);
}
