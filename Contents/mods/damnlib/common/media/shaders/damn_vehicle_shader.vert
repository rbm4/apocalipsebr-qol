#version 330
// Created by KI5

varying vec3 vertColour;
varying vec3 vertNormal;
varying vec2 texCoords0;
varying vec2 texCoords1;
varying vec4 positionEye;

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec4 normal;
layout (location = 2) in vec4 boneWeights;
layout (location = 3) in vec4 boneIndices;
layout (location = 4) in vec2 uv;
layout (location = 5) in vec2 uv2;

uniform mat4 ModelViewProjection;
uniform mat4 MatrixPalette[60];
uniform float targetDepth = 0.5;

void main()
{
    vec4 position = vec4(vertex.xyz, 1.0);
    vec4 normal = vec4(normal.xyz, 0.0);

    texCoords0 = uv.st;
    texCoords1 = uv2.st;

    mat4 boneEffect = mat4(0.0);
    if (boneWeights.x > 0.0)
        boneEffect += MatrixPalette[int(boneIndices.x)] * boneWeights.x;
    if (boneWeights.y > 0.0)
        boneEffect += MatrixPalette[int(boneIndices.y)] * boneWeights.y;
    if (boneWeights.z > 0.0)
        boneEffect += MatrixPalette[int(boneIndices.z)] * boneWeights.z;
    if (boneWeights.w > 0.0)
        boneEffect += MatrixPalette[int(boneIndices.w)] * boneWeights.w;

    normal = boneEffect * normal;
    vertNormal = normal.xyz;
    vertColour = vec3(1.0, 1.0, 1.0);

    positionEye = (ModelViewProjection * boneEffect * position) - vec4(-0.2, 0.2, 0.2, 0);

    vec4 o = ModelViewProjection * boneEffect * position;
    float clip = ((o.z + 1.0) / 2.0);
    clip += targetDepth - 0.5;
    o.z = (clip * 2.0) - 1.0;
    gl_Position = o;
}
