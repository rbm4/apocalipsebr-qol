// Railroader / rr_loco.vert -- the locomotive's skinned vertex shader.
//
// A faithful copy of vanilla media/shaders/animalEffect.vert. We only ship it because a
// model script names ONE shader for both stages, and we need our own FRAGMENT stage
// (rr_loco.frag, which makes the painted headlight lenses self-illuminated). Nothing here
// differs from vanilla, and nothing here may be trimmed:
//   * the 4-bone MatrixPalette blend -- without it the mesh renders undeformed at the
//     world origin;
//   * FinalScale -- the animal render scale (1.5 * getAnimalSize());
//   * targetDepth / HighResDepthMultiplier -- the iso depth remap; drop them and the loco
//     sorts wrongly against the chunk FBO;
//   * UVScale -- correct UVs if the texture is packed into an atlas.
// Attribute locations are fixed by the skinned VBO format (ImportedSkinnedMesh):
// 0=vertex 1=normal 2=boneWeights 3=boneIndices 4=uv. Bone indices arrive as FLOATS.
//
// NOTE (ShaderProgram.getRootVertFileName): "_static" is a VERTEX-ONLY suffix and is chosen
// by the model script's `static` flag, so RR_LocoTest must keep `static = false` -- which it
// must anyway, since a static model draws blank on the animal path.
#version 330

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec4 normal;
layout (location = 2) in vec4 boneWeights;
layout (location = 3) in vec4 boneIndices;
layout (location = 4) in vec2 uv;

out vec3 vertNormal;
out vec2 texCoords;

uniform mat4 ModelViewProjection;
uniform mat4 MatrixPalette[60];
uniform float targetDepth = 0.5;
uniform vec2 UVScale = vec2(1, 1);
uniform float HighResDepthMultiplier = 0.0;
uniform float FinalScale = 1.0;

void main()
{
	vec4 position = vec4(vertex.xyz, 1.0);
	vec4 nrm = vec4(normal.xyz, 0.0);

	texCoords = uv * UVScale.xy;

	mat4 boneEffect = mat4(0.0);
	if (boneWeights.x > 0.0)
		boneEffect += MatrixPalette[int(boneIndices.x)] * boneWeights.x;
	if (boneWeights.y > 0.0)
		boneEffect += MatrixPalette[int(boneIndices.y)] * boneWeights.y;
	if (boneWeights.z > 0.0)
		boneEffect += MatrixPalette[int(boneIndices.z)] * boneWeights.z;
	if (boneWeights.w > 0.0)
		boneEffect += MatrixPalette[int(boneIndices.w)] * boneWeights.w;

	vertNormal = (boneEffect * nrm).xyz;

	vec4 bonedPos = boneEffect * position;
	bonedPos.xyz = bonedPos.xyz * FinalScale;

	vec4 o = ModelViewProjection * bonedPos;

	vec4 origin = ModelViewProjection * vec4(0, 0, 0, 1);
	o.z += (origin.z - o.z) * HighResDepthMultiplier;

	float clip = ((o.z + 1.0) / 2.0);   // -1,+1 -> 0,1
	clip += targetDepth - 0.5;
	o.z = (clip * 2.0) - 1.0;           // 0,1 -> -1,+1

	gl_Position = o;
}
