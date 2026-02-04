#version 120
// Created by KI5

varying vec3 vertColour;
varying vec3 vertNormal;
varying vec2 texCoords0;
varying vec2 texCoords1;
varying vec4 positionEye;

void main()
{
    vec4 position = vec4(gl_Vertex.xyz, 1.0);
    vec4 normal = vec4(gl_Normal.xyz, 0.0);

    texCoords0 = gl_MultiTexCoord0.st;
    texCoords1 = gl_MultiTexCoord1.st;

    positionEye = gl_ModelViewMatrix * position;

    vertNormal = gl_Normal.xyz;
    vertColour = vec3(1.0, 1.0, 1.0);

    gl_Position = gl_ModelViewProjectionMatrix * position;
}
