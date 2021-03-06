#version 420
layout (points) in;
layout (triangle_strip, max_vertices=54) out;

layout (binding=3) uniform sampler2D noiseMap;
layout (binding=4) uniform sampler2D noiseMap2;

uniform mat4 projection;
uniform mat4 world;
uniform mat4 view;

uniform float water_level;

in vec3[] v_normal;

out float lightLevel;
out vec3 g_position;
out vec3 w_eye;
out vec2 texCoord;
out vec3 g_normal;

uniform float time;

uniform vec3 sun;

// some "grass configurations" I pulled out of a hat...

// this one's a big plus (pun)
const vec2[] config1 = vec2[](
    vec2(-0.40,0),vec2(0.40,0),
    vec2(0,0.40),vec2(0,-0.40)
);
// this makes a weird star/asterisk thing
const vec2[] config2 = vec2[](
    vec2(-0.3,0.3),vec2(0.3,-0.3),
    vec2(0,0.4),vec2(0,-0.4),
    vec2(-0.3,-0.3),vec2(0.3,0.3)
);
// and this makes a drunk triangle...
const vec2[] config3 = vec2[](
    vec2(-0.12,0.35),vec2(0.25,-0.25),
    vec2(0.35,0.35),vec2(-0.25,-0.25),
    vec2(-0.35,-0.07),vec2(0.35,-0.07)
);

// center position offsets
const vec2[] posOffs = vec2[](
    vec2(0,0.5f),vec2(-0.43,-0.25),vec2(0.43,-0.25)
);



float ia = 0.2f;
float id = 0.7f;
float is = 0.1f;
float s = 10.0f;

float getIP(vec3 pos, vec3 norm, float random)
{
    vec3 v = normalize(w_eye-pos);
    vec3 l = normalize(sun);
    vec3 r = normalize(reflect(-l,norm));

    float epsilon = 0.0002f;

    vec2[] offsets = vec2[](
        vec2(0,1),vec2(0,-1),vec2(1,0),vec2(-1,0),
        vec2(1,1),vec2(1,-1),vec2(-1,-1),vec2(-1,1)
    );

    float ip = ia;

    if (sun.y > 0)
    {

        ip = ia + max(dot(l,norm),0)*id + pow(max(dot(r,v),0),s)*is;

    }

    return ip * ( 1.0f - random*0.1f );
}

void makeQuad(vec3 pos, vec2 sideA, vec2 sideB, float height, float topOffset, float jitter)
{
    float yoffset = height*0.5;

    float offABit = (jitter*2-1)*0.005f;
    float offAgain = -jitter;

    sideA += vec2(offABit);
    sideB += vec2(offAgain);


    lightLevel = getIP(pos,v_normal[0], jitter);

    g_position = pos+vec3(sideA.x,-yoffset,sideA.y);
    gl_Position = projection * view * world * vec4(g_position ,1.0f);
    texCoord = vec2(0,1);
    EmitVertex();
    g_position = pos+vec3(sideA.x+topOffset,yoffset+height,sideA.y);
    gl_Position = projection * view * world * vec4(g_position,1.0f);
    texCoord = vec2(0,0);
    EmitVertex();
    g_position = pos+vec3(sideB.x+topOffset,yoffset+height,sideB.y);
    gl_Position = projection * view * world * vec4(g_position ,1.0f);
    texCoord = vec2(1,0);
    EmitVertex();
    EndPrimitive();

    g_position = pos+vec3(sideB.x+topOffset,yoffset+height,sideB.y);
    gl_Position = projection * view * world * vec4(g_position ,1.0f);
    texCoord = vec2(1,0);
    EmitVertex();
    g_position = pos+vec3(sideB.x,-yoffset,sideB.y);
    gl_Position = projection * view * world * vec4(g_position ,1.0f);
    texCoord = vec2(1,1);
    EmitVertex();
    g_position = pos+vec3(sideA.x,-yoffset,sideA.y);
    gl_Position = projection * view * world * vec4(g_position ,1.0f);
    texCoord = vec2(0,1);
    EmitVertex();
    EndPrimitive();
}

void foo(vec3 pos)
{

    vec3 pos2 = (world * vec4(pos,1.0f)).xyz;

    float random = texture(noiseMap2, pos2.xz*0.05f)*2-1;

    float height = 0.45f + (texture(noiseMap, pos2.xz*0.2f)*2-1)*1f;
    float topOffset = sin(time)*0.1f;

    if (random < 0.333f)
    {
        for (int i = 0; i < config1.length(); i+=2)
        {
            makeQuad(pos, config1[i], config1[i+1], height, topOffset, random*3);
        }
    }
    else if (random < 0.667f)
    {
        for (int i = 0; i < config2.length(); i+=2)
        {
            makeQuad(pos, config2[i], config2[i+1], height, topOffset, (random-0.333f)*3 );
        }
    }
    else
    {
        for (int i = 0; i < config3.length(); i+=2)
        {
            makeQuad(pos, config3[i], config3[i+1], height, topOffset, (random-0.667f)*3);
        }
    }
}

void main()
{
    if (v_normal[0].y < 0.95f) return; // no grass on cliffs

    g_normal = v_normal[0];

    w_eye = (inverse(view) * vec4 (0, 0, 0, 1)).xyz;

    vec3 g_pos = gl_in[0].gl_Position.xyz;

    if (g_pos.y < water_level) return; // no grass below water

    vec3 v = normalize(w_eye-g_pos);

    if (dot(v_normal[0],v) < 0.0) return; // no grass on back-facing terrain

    vec3 w_pos = (world * vec4(g_pos,1.0f)).xyz;


    float dist = distance(w_eye, w_pos);

    // checking if grass is within the screen

    float ndcPadding = 0.1;

    vec4 ndc_pos = projection * view * world * vec4(g_pos,1.0f);
    ndc_pos = abs(ndc_pos/ndc_pos.w);

    if (ndc_pos.x > 1+ndcPadding || ndc_pos.y > 1+ndcPadding || ndc_pos.z > 1+ndcPadding) return;

    if (dist > 70) return; // skip distant grass (or at least make it less dense?)

    if (dist > 30)
    {
        foo(g_pos);
    }
    else
    for (int k = 0; k < posOffs.length(); k++)
    {
        vec3 pos = g_pos;
        pos.x += posOffs[k].x;
        pos.z += posOffs[k].y;

        foo(pos);
    }
}

