// TODO:
// checkbox for shadowing
// density controls
// brightness controls

#version 100
precision highp float;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

attribute vec3 aPosition;
varying vec3 pos;

void main() {
    gl_Position = uProjection * uView * uModel * vec4(aPosition, 1);
    pos = (uModel * vec4(aPosition, 1)).xyz;
}


__split__

#version 100
precision highp float;

uniform vec3 uColor;
uniform vec3 uOffset;
uniform vec3 uRot;

uniform float uDensity;
uniform float uOpacity;
uniform float uBrightness;

uniform float uNoiseScale;


varying vec3 pos;


// "Dusty nebula 4" by Duke
// https://www.shadertoy.com/view/MsVXWW
//-------------------------------------------------------------------------------------
// Based on "Dusty nebula 3" (https://www.shadertoy.com/view/lsVSRW) 
// and "Protoplanetary disk" (https://www.shadertoy.com/view/MdtGRl) 
// otaviogood's "Alien Beacon" (https://www.shadertoy.com/view/ld2SzK)
// and Shane's "Cheap Cloud Flythrough" (https://www.shadertoy.com/view/Xsc3R4) shaders
// Some ideas came from other shaders from this wonderful site
// Press 1-2-3 to zoom in and zoom out.
// License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
//-------------------------------------------------------------------------------------

// #define ROTATION


#define DITHERING



// 6qx0x8z096k0 - wow

#define TONEMAPPING

// #define SHADOWING

//-------------------
#define pi 3.14159265
#define R(p, a) p=cos(a)*p+sin(a)*vec2(p.y, -p.x)

// // iq's noise
// float noise( in vec3 x )
// {
//     vec3 p = floor(x);
//     vec3 f = fract(x);
// 	f = f*f*(3.0-2.0*f);
// 	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
// 	vec2 rg = textureLod( iChannel0, (uv+ 0.5)/256.0, 0.0 ).yx;
// 	return 1. - 0.82*mix( rg.x, rg.y, f.z );
// }

__noise4d__

float noise(vec3 p) {
    return cnoise(vec4(p*1000.0, 0)) ;
}


float rand(vec2 co)
{
	return fract(sin(dot(co*0.123,vec2(12.9898,78.233))) * 43758.5453);
}

//=====================================
// otaviogood's noise from https://www.shadertoy.com/view/ld2SzK
//--------------------------------------------------------------
// This spiral noise works by successively adding and rotating sin waves while increasing frequency.
// It should work the same on all computers since it's not based on a hash function like some other noises.
// It can be much faster than other noise functions if you're ok with some repetition.
const float nudge = 0.739513;	// size of perpendicular vector
float normalizer = 1.0 / sqrt(1.0 + nudge*nudge);	// pythagorean theorem on that perpendicular to maintain scale

const float iTime = 0.5;

float SpiralNoiseC(vec3 p)
{
    float n = 0.0;	// noise amount
    float iter = 1.0;
    for (int i = 0; i < 8; i++)
    {
        // add sin and cos scaled inverse with the frequency
        n += -abs(sin(p.y*iter) + cos(p.x*iter)) / iter;	// abs for a ridged look
        // rotate by adding perpendicular and scaling down
        p.xy += vec2(p.y, -p.x) * nudge;
        p.xy *= normalizer;
        // rotate on other axis
        p.xz += vec2(p.z, -p.x) * nudge;
        p.xz *= normalizer;
        // increase the frequency
        iter *= 1.733733;
    }
    return n;
}

float SpiralNoise3D(vec3 p)
{
    float n = 0.0;
    float iter = 1.0;
    for (int i = 0; i < 4; i++)
    {
        n += (sin(p.y*iter) + cos(p.x*iter)) / iter;
        p.xz += vec2(p.z, -p.x) * nudge;
        p.xz *= normalizer;
        iter *= 1.33733;
    }
    return n;
}
//p.zxy*0.5123
float NebulaNoise(vec3 p)
{
   float final = p.y + 4.5;
    final -= SpiralNoiseC(p.xyz);   // mid-range noise
    final += SpiralNoiseC(p.zxy*0.1123 +100.0)*4.0;   // large scale features
    final -= SpiralNoise3D(p);   // more large scale features, but 3d

    return final;
}

float map(vec3 p) 
{
	#ifdef ROTATION
	R(p.xz, iMouse.x*0.008*pi+iTime*0.1);
	#endif
    
	float NebNoise = abs(NebulaNoise(p*pow(2.0, uNoiseScale)*2.0)*0.5);
    
	return NebNoise+0.03;
}
//--------------------------------------------------------------
const float eps = 0.0000001;

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


vec3 rgb2hsl( vec3 col )
{
    float minc = min( col.r, min(col.g, col.b) );
    float maxc = max( col.r, max(col.g, col.b) );
    vec3  mask = step(col.grr,col.rgb) * step(col.bbg,col.rgb);
    vec3 h = mask * (vec3(0.0,2.0,4.0) + (col.gbr-col.brg)/(maxc-minc + eps)) / 6.0;
    return vec3( fract( 1.0 + h.x + h.y + h.z ),              // H
                 (maxc-minc)/(1.0-abs(minc+maxc-1.0) + eps),  // S
                 (minc+maxc)*0.5 );                           // L
}


vec3 hsl2rgb( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}


// assign color to the media
vec3 computeColor( float density, float radius )
{
	// color based on density alone, gives impression of occlusion within
	// the media
//1l75k29oumn4

	// vec3 result = mix( col3, col4, density );

    
 //    col2.x += 1.0;
 //    col2.y -= 0.5;
 //    col2 = clamp(col2, 0.0, 1.0);
 //    col2 = hsv2rgb(col2);

	// // color added to the media
	// vec3 colCenter = 8.*uColor;   //vec3(0.8,1.0,1.0);
	// vec3 colEdge = 1.0*col2; //vec3(0.48,0.53,0.5);
	// result *= mix( colCenter, colEdge, min( (radius+.05)/.9, 1.15 ) );

    vec3 col2 = rgb2hsv(uColor);
    col2.x -= density * 0.3 - radius * 0.1;
    //col2.y -= density * 0.5;
    col2.z += density * 0.5;
    col2.yz = clamp(col2.yz, 0.0, 1.0);
    col2.x = mod(col2.x, 1.0);

     vec3 result = hsv2rgb( col2 );
     //mix( col3, col4, density );

    

    // color added to the media
    vec3 colCenter = mix(uColor, vec3(3.0, 3.0, 2.5), 0.5);
    //5.*vec3(1.0,1.0,0.8);
    vec3 colEdge = mix(uColor, vec3(0.35, 0.25, 0.35), 0.5);
    //1.0*vec3(0.5, 0.5, 0.5);
    //vec3(0.48,0.53,0.5);
    result *= mix( colCenter, colEdge, min( (radius+.05)/.9, 1.15 ) );
    
	return result;
}

bool RaySphereIntersect(vec3 org, vec3 dir, out float near, out float far)
{
	float b = dot(dir, org);
	float c = dot(org, org) - 36.;
	float delta = b*b - c;
	if( delta < 0.0) 
		return false;
	float deltasqrt = sqrt(delta);
	near = -b - deltasqrt;
	far = -b + deltasqrt;
	return far > 0.0;
}

// Applies the filmic curve from John Hable's presentation
// More details at : http://filmicgames.com/archives/75
vec3 ToneMapFilmicALU(vec3 _color)
{
	_color = max(vec3(0), _color - vec3(0.004));
	_color = (_color * (6.2*_color + vec3(0.5))) / (_color * (6.2 * _color + vec3(1.7)) + vec3(0.06));

    // vec3 col2 = rgb2hsv(_color);

    // col2.y -= 0.1;
    // col2.z -= 0.1;

    // col2.yz = clamp(col2.yz, 0.0, 1.0);


    //  vec3 result = hsv2rgb( col2 );

	return _color;
}


float RayMarchLight( vec3 ro, vec3 rd, float seedOffs )
{  


    // t: length of the ray
    // d: distance function
    float d=1., t=0.;
    
    const float h = 0.15;
   
    vec4 sum = vec4(0.0);
   
    float min_dist=0.0, max_dist=length(ro);
    
    float alpha = 1.0;
    #ifdef DITHERING
        //vec2 seed = rd.xy / 128.0;
        vec2 seed = vec2(0);
        seed.x = cnoise(vec4(rd.xyz, 0)) + seedOffs;
        seed.y = cnoise(vec4(rd.zyx, 0)) - seedOffs;
    #endif 

    t = min_dist*step(t,min_dist);
    float density = 0.0;
    
    // raymarch loop
    for (int i=0; i<200; i++) 
    {
     
        vec3 pos = ro + t*rd;
  
        // Loop break conditions.
        if( t>max_dist) break;
        
        // evaluate distance function
        float d = map(pos);
               
        // change this string to control density 
        d = max(d,0.01+uDensity);
        
        // point light calculations
        vec3 ldst = vec3(0.0)-pos;
        float lDist = max(length(ldst), 0.001);
      
        if (d<h) 
        {
           density += 2. * (h-d)*3./(lDist*lDist);
        }
      
        density += 0.4/(lDist*lDist); 

       
        // enforce minimum stepsize
        d = max(d, 0.04); 
        #ifdef DITHERING
        // add in noise to reduce banding and create fuzz
        d=abs(d)*(.8+0.2*rand(seed*vec2(i)));
        #endif 
        
        // trying to optimize step size near the camera and near the light source
        t += max(d * 0.1 * max(min(length(ldst),length(ro)),1.0), 0.02);

    }

    return density;
}

//3u8y6eojbwo0
vec4 RayMarchNebula(vec3 rd, vec3 ro, float seedOffs) 
{

    const float KEY_1 = 49.5/256.0;
    const float KEY_2 = 50.5/256.0;
    const float KEY_3 = 51.5/256.0;
    float key = KEY_3;



    R(rd.yz, -pi*uRot.x);
    R(rd.xz, pi*uRot.y);
    R(ro.yz, -pi*uRot.x);
    R(ro.xz, pi*uRot.y);    

    #ifdef DITHERING
        //vec2 seed = rd.xy / 128.0;
        vec2 seed = vec2(0);
        seed.x = cnoise(vec4(rd.xyz, 0)) + seedOffs;
        seed.y = cnoise(vec4(rd.zyx, 0)) - seedOffs;
    #endif 
    
    // t: length of the ray
    // d: distance function
    float d=1., t=0.;
    
    const float h = 0.15;
   
    vec4 sum = vec4(0.0);
   
    float min_dist=0.5, max_dist=15.0;
    
    float alpha = 0.0;
    float density = 0.;
    
    if(RaySphereIntersect(ro, rd, min_dist, max_dist))
    {
       
    t = min_dist*step(t,min_dist);
   
    // raymarch loop
    for (int i=0; i<200; i++) 
    {
        vec3 pos = ro + t*rd;
  
        // Loop break conditions.
        if( t>max_dist) break;
        
        // evaluate distance function
        float d = map(pos);
               
        // change this string to control density 
        d = max(d,0.01+uDensity);
        
        // point light calculations
        vec3 ldst = vec3(0.0)-pos;
        float lDist = max(length(ldst)*0.6, 0.001);

        // star in center
        //vec3 lightColor=vec3(1.0,0.7,0.25)*uBrightness;

        vec3 lightColor = rgb2hsl(uColor);

        lightColor.x += 0.3333;
        lightColor.y == 0.25;
        lightColor.z += 0.25;
        lightColor.yz = clamp(lightColor.yz, 0.0, 1.0);
        lightColor.x = mod(lightColor.x, 1.0);

        lightColor = hsv2rgb( lightColor ) * uBrightness * 0.8;

        vec3 nebulaColor=uColor*0.5;
        sum.rgb+=(lightColor/(lDist*lDist*20.)); // star itself and bloom around the light
        alpha += (0.01/lDist*lDist);
        if (d<h) 
        {

            density += (h-d)*2./(lDist*lDist);  

            sum.rgb+=(nebulaColor*uBrightness / exp( density * 0.5 )/(lDist*lDist)); // star itself and bloom around the light

            float td = density + RayMarchLight(pos, -pos, seedOffs);
            
            float shadowedFactor = 1.0 / (exp( td * 0.15 )) / (lDist*lDist);
            sum.rgb += lightColor * (0.2 * shadowedFactor);

            alpha += (0.01*(h-d)/lDist*lDist*lDist) + 0.01 * shadowedFactor;
        }
        
        density += 0.2*uDensity/(lDist*lDist); 
        
        // enforce minimum stepsize
        d = max(d, 0.04); 
      
        #ifdef DITHERING
        // add in noise to reduce banding and create fuzz
        d=abs(d)*(.8+0.2*rand(seed*vec2(i)));
        #endif 
        
        // trying to optimize step size near the camera and near the light source
        t += max(d * 0.1 * max(min(length(ldst),length(ro)), 1.0), 0.02);

    }
        

   
    
    // simple scattering
    //sum *= 1. / exp( ld * 0.2 ) * 0.6;

        
    sum = clamp( sum, 0.0, 1.0 );
   
    sum.xyz = sum.xyz*sum.xyz*(3.0-2.0*sum.xyz);
    sum.w = uOpacity * clamp(alpha, 0.0, 1.0);
    }
    

    #ifdef TONEMAPPING
        return vec4(ToneMapFilmicALU(sum.xyz), sum.w);
    #else
        return sum;
    #endif
}

void main()
{  
    // ro: ray origin
    // rd: direction of the ray
    vec3 rd = normalize(pos);
    //normalize(vec3((gl_FragCoord.xy-0.5*iResolution.xy)/iResolution.y, 1.));
    vec3 ro = vec3(0,0,-0.1) + uOffset;

    vec4 col1 = RayMarchNebula(rd, ro, 0.0);
    vec4 col2 = RayMarchNebula(rd, ro, 0.01);
    vec4 col3 = RayMarchNebula(rd, ro, -0.01);
    vec4 col4 = RayMarchNebula(rd, ro, -0.03);

    gl_FragColor = (col1 + col2 + col3 + col4) * 0.25;

}