#version 110

varying vec3 vertColour; 
varying vec3 vertNormal;
varying vec2 texCoords;

uniform sampler2D Texture;
uniform sampler2D TextureMask;
uniform sampler2D TextureLights; 

uniform mat4 TextureLightsEnables1;
uniform mat4 TextureLightsEnables2;

uniform vec3 TintColour;

uniform vec3 AmbientColour;
uniform vec3 Light0Direction;
uniform vec3 Light0Colour;
uniform vec3 Light1Direction;
uniform vec3 Light1Colour;
uniform vec3 Light2Direction;
uniform vec3 Light2Colour;

uniform float Alpha;

#include "util/math"
#include "util/dommat4"

#include "vehicle_common.frag"

void main()
{
	vec3 normal = normalize(vertNormal);
	vec3 col = texture2D(Texture, texCoords).xyz;
	vec4 texColorMask = texture2D(TextureMask, texCoords);
	vec4 texColorLights = texture2D(TextureLights, texCoords);

	float dotprod;
	float pixelVal = (col.x + col.y + col.z) / 3.0;

	vec3 lighting = AmbientColour;
	dotprod = max(dot(normal, normalize(Light0Direction)), 0.0);
	quantise(dotprod, 3.0);
	lighting += Light0Colour * dotprod;

	dotprod = max(dot(normal, normalize(Light1Direction)), 0.0);
	quantise(dotprod, 3.0);
	lighting += Light1Colour * dotprod;

	dotprod = max(dot(normal, normalize(Light2Direction)), 0.0);
	quantise(dotprod, 3.0);
	lighting += Light2Colour * dotprod;

    vec3 TintColourNew = desaturate(TintColour, 0.3);
	lighting.x = clamp(lighting.x, 0.0, 1.0);
	lighting.y = clamp(lighting.y, 0.0, 1.0);
	lighting.z = clamp(lighting.z, 0.0, 1.0);

	mat4 texen1 = mat4( 0.0 );
	texen1[0][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone1)));
	texen1[0][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone2)));
	texen1[0][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone3)));
	texen1[0][3] = (1.0-step(0.01,length(texColorMask.xyz-colZone4)));
	texen1[1][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone5)));
	texen1[1][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone6)));
	texen1[1][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone7)));
	texen1[1][3] = (1.0-step(0.01,length(texColorMask.xyz-colZone8)));
	texen1[2][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone9)));
	texen1[2][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone10)));
	texen1[2][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone11)));
	texen1[2][3] = (1.0-step(0.01,length(texColorMask.xyz-colZone12)));
	texen1[3][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone13)));
	texen1[3][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone14)));
	texen1[3][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone15)));
	texen1[3][3] = (1.0-step(0.01,length(texColorMask.xyz-colZone16)));

	mat4 texen2 = mat4( 0.0 );
	texen2[0][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone17)));
	texen2[0][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone18)));
	texen2[0][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone19)));
	texen2[0][3] = (1.0-step(0.01,length(texColorMask.xyz-colZone20)));
	texen2[1][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone21)));
	texen2[1][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone22)));
	texen2[1][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone23)));
	texen2[1][3] = (1.0-step(0.01,length(texColorMask.xyz-colZone24)));
	texen2[2][0] = (1.0-step(0.01,length(texColorMask.xyz-colZone25)));
	texen2[2][1] = (1.0-step(0.01,length(texColorMask.xyz-colZone26)));
	texen2[2][2] = (1.0-step(0.01,length(texColorMask.xyz-colZone27)));
	
	float t1en = step(0.5, dommat4(texen1, TextureLightsEnables1) + dommat4(texen2, TextureLightsEnables2) );

	float windowAlpha = clamp(texen1[1][2] + texen1[1][3] + texen1[2][0] + texen1[2][1] + texen1[2][2] + texen1[2][3], 0.0, 1.0);
	float frontAlpha = clamp(texen1[0][0] + texen2[0][1] + texen2[0][2], 0.0, 1.0);
	float tailAlpha = clamp(texen1[0][1] + texen2[0][3] + texen2[1][0] + texen2[1][1] + texen2[1][2], 0.0, 1.0);
	float noTintAlpha = clamp(windowAlpha + frontAlpha + tailAlpha, 0.0, 1.0);

	col = mix(col, texColorLights.xyz, texColorLights.a*t1en);

	col = vec3(col.x * lighting.x * TintColourNew.x, col.y * lighting.y * TintColourNew.y, col.z * lighting.z * TintColourNew.z);


	gl_FragColor = vec4(col.xyz, Alpha);
}
