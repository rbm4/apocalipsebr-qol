// Railroader / rr_loco.frag -- the locomotive's fragment shader: vanilla lighting, PLUS a
// self-illuminated headlight.
//
// THE PROBLEM IT SOLVES. PZ gives a non-vehicle model no emissive channel at all. Vanilla's
// animalEffect.frag ends with
//     lighting = min(lighting + AmbientColour, 1.0);   col = albedo * Tint * lighting;
// -- a hard clamp, so a lit model can NEVER exceed its own albedo, and at night `lighting`
// falls to ~0 and the whole loco goes black with the world. The vehicle emissive path
// (TextureLights / textureLightsEnables) is a field on VehicleModelInstance only, behind
// `if (effect.isVehicleShader())`. There is no Lua-settable emissive input anywhere. So a
// headlight simply painted on the texture would be DARK exactly when a headlight matters.
//
// THE TRICK. The headlight lenses are painted on the loco's texture in KEY MAGENTA
// (255, 0, 255). Nothing on a weathered navy/white/rust locomotive comes anywhere near
// magenta, so it is a safe sentinel. Wherever the texture is magenta, this shader ignores
// the lighting entirely and writes a fixed warm sealed-beam white -- full-bright, at
// midnight as at noon. That IS the lamp being on.
//
// Which lamps are magenta is decided by WHICH TEXTURE is bound, and the texture is swapped
// from Lua (AnimalVisual.setSkinTextureName + resetModelNextFrame). Three variants:
//     RR_LocoTest         both lenses dark glass      (headlight OFF)
//     RR_LocoTest_dim     the upper lens magenta      (DIM  -- one sealed beam)
//     RR_LocoTest_bright  both lenses magenta         (BRIGHT -- both beams)
// That is the only per-instance channel PZ offers a modder here; there is no way to push a
// custom uniform.
//
// "Magenta-ness" is measured as min(r,b) - g and fed through a smoothstep rather than a
// hard equality test, for two reasons: bilinear filtering and mipmaps blend the lens edge
// with the dark housing around it, and a hard test would leave a jagged dark-purple fringe.
// The gradient turns that fringe into a soft glow edge instead.
//
// Everything else is vanilla animalEffect.frag. HueChange and LightingAmount are dropped:
// nothing sets them on our loco, and omitting a uniform is safe (Shader's setters silently
// no-op when glGetUniformLocation returns -1). Dropping HueChange also lets us drop the
// #include of util/hueShift, so this file has no include dependencies at all.
#version 110

varying vec3 vertNormal;
varying vec2 texCoords;

uniform sampler2D Texture;
uniform float Alpha;

uniform vec3 TintColour;
uniform vec3 AmbientColour;
uniform vec3 Light0Direction;
uniform vec3 Light0Colour;
uniform vec3 Light1Direction;
uniform vec3 Light1Colour;
uniform vec3 Light2Direction;
uniform vec3 Light2Colour;
uniform vec3 Light3Direction;
uniform vec3 Light3Colour;
uniform vec3 Light4Direction;
uniform vec3 Light4Colour;

// A warm sealed beam, near white. This is written straight to the framebuffer, so it is
// literally the on-screen colour of a burning lens.
const vec3 LAMP_COLOUR = vec3(1.0, 0.95, 0.84);

void main()
{
	vec3 normal = normalize(vertNormal);
	vec4 texSample = texture2D(Texture, texCoords);

	if (texSample.w < 0.01)
	{
		discard;
	}

	vec3 col = texSample.xyz;

	vec3 lighting = vec3(0.0);
	lighting += Light0Colour * max(dot(normal, normalize(Light0Direction)), 0.0);
	lighting += Light1Colour * max(dot(normal, normalize(Light1Direction)), 0.0);
	lighting += Light2Colour * max(dot(normal, normalize(Light2Direction)), 0.0);
	lighting += Light3Colour * max(dot(normal, normalize(Light3Direction)), 0.0);
	lighting += Light4Colour * max(dot(normal, normalize(Light4Direction)), 0.0);
	lighting += AmbientColour;
	lighting = min(lighting, vec3(1.0));

	col = col * TintColour * lighting;

	// --- the headlight ---------------------------------------------------------------
	float key = min(texSample.r, texSample.b) - texSample.g;   // how magenta is this texel?
	float emissive = smoothstep(0.15, 0.55, key);
	col = mix(col, LAMP_COLOUR, emissive);
	// ---------------------------------------------------------------------------------

	gl_FragColor = vec4(Alpha * col, Alpha * texSample.w);
}
