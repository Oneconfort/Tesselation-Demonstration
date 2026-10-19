#ifndef TESSELLATION_FACTORS_INCLUDED
#define TESSELLATION_FACTORS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#if defined(_DYNAMIC_HEIGHT)
    #define DYNAMIC_HEIGHT_ON
#endif

#if defined(_TESSELLATION_FACTOR_VCOLORS)
    #define REQUIRES_VERTEX_COLORS
#endif



struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    #ifdef REQUIRES_VERTEX_COLORS
        float4 color : COLOR;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct TessellationControlPoint
{   
    float4 positionCS : SV_POSITION;
    float3 positionWS : INTERNALTESSPOS;
    float3 normalWS : NORMAL;
    float4 tangentWS : TANGENT;
    float2 uv : TEXCOORD0;
    #ifdef REQUIRES_VERTEX_COLORS
        float4 color : COLOR;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct TessellationFactors 
{
    float edge[3] : SV_TessFactor; // Tessellation factors specified per edge, factor the number of times an edge subdivide
    float inside : SV_InsideTessFactor; // Inside factor squared is roughly the number of new triangles created inside the original.
};

struct Interpolators
{
    #ifdef DYNAMIC_HEIGHT_ON
        float height : PSIZE;
    #endif
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD2;
    float3 positionWS : TEXCOORD3;
    float4 tangentWS  : TEXCOORD4;
    float4 fogFactorAndVertexLight  : TEXCOORD5;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

TEXTURE2D(_MainTexture); SAMPLER(sampler_MainTexture);
TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_HeightMap); SAMPLER(sampler_HeightMap);
TEXTURE2D(_DeformationMap); SAMPLER(sampler_DeformationMap);


CBUFFER_START(UnityPerMaterial)
    float4 _MainTexture_ST;
    float4 _DeformationMap_ST;
    float4 _MainTexture_TexelSize;
    float4 _BaseColor;
    float4 _DeepColor;
    float _NormalStrength;
    float _HeightMapAltitude;
    float _TessellationFactor;
    float _TessellationBias;
    float _FrustumCullTolerance;
    float _BackFaceCullTolerance;
CBUFFER_END

float3 GetViewDirectionFromPosition(float3 positionWS) 
{
    return normalize(GetCameraPositionWS() - positionWS);
}

float4 GetShadowCoord(float3 positionWS, float4 positionCS) 
{
// Calculate the shadow coordinate depending on the type of shadows currently in use
    #if SHADOWS_SCREEN
        return ComputeScreenPos(positionCS);
    #else
        return TransformWorldToShadowCoord(positionWS);
    #endif
}


//Vertex shader

TessellationControlPoint Vertex(Attributes input)
{
    TessellationControlPoint output;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
    VertexNormalInputs norInputs = GetVertexNormalInputs(input.normalOS);

    output.positionCS = posInputs.positionCS;
    output.positionWS = posInputs.positionWS;
    output.normalWS = norInputs.normalWS;
    output.tangentWS = float4(norInputs.tangentWS, input.tangentOS.w);
    output.uv = TRANSFORM_TEX(input.uv, _MainTexture);
    #ifdef REQUIRES_VERTEX_COLORS
        output.color = input.color;
    #endif

    return output;
}

//start Hull

bool IsOutOfBounds(float3 p, float3 lower, float3 higher) 
{
    return p.x < lower.x || p.x > higher.x || p.y < lower.y || p.y > higher.y || p.z < lower.z || p.z > higher.z;
}

// Returns true if the given vertex is outside the camera fustum and should be culled
bool IsPointOutOfFrustum(float4 positionCS, float tolerance) 
{
    float3 culling = positionCS.xyz;
    float w = positionCS.w;
    float3 lowerBounds = float3(-w - tolerance, -w - tolerance, -w * UNITY_RAW_FAR_CLIP_VALUE - tolerance);
    float3 higherBounds = float3(w + tolerance, w + tolerance, w + tolerance);
    return IsOutOfBounds(culling, lowerBounds, higherBounds);
}

bool ShouldBackFaceCull(float4 p0PositionCS, float4 p1PositionCS, float4 p2PositionCS, float tolerance) 
{
    float3 point0 = p0PositionCS.xyz / p0PositionCS.w;
    float3 point1 = p1PositionCS.xyz / p1PositionCS.w;
    float3 point2 = p2PositionCS.xyz / p2PositionCS.w;
    // In clip space, the view direction is float3(0, 0, 1), so we can just test the z coord
    #if UNITY_REVERSED_Z
        return cross(point1 - point0, point2 - point0).z < -tolerance;
    #else // In OpenGL, the test is reversed
        return cross(point1 - point0, point2 - point0).z > tolerance;;
    #endif
}

bool ShouldClipPatch(float4 p0PositionCS, float4 p1PositionCS, float4 p2PositionCS, float frustumTolerance, float backFaceTolerance) 
{
    bool allOutside = IsPointOutOfFrustum(p0PositionCS, frustumTolerance) && IsPointOutOfFrustum(p1PositionCS, frustumTolerance) && IsPointOutOfFrustum(p2PositionCS, frustumTolerance);
    return allOutside || ShouldBackFaceCull(p0PositionCS, p1PositionCS, p2PositionCS, backFaceTolerance);
}

//Calculate the factor based on the length of the edge
float EdgeTessellationFactor(float scale, float bias,  float multiplier, TessellationControlPoint p1, TessellationControlPoint p2)
{
    float factor = 1;
    #if defined(_TESSELLATION_FACTOR_CONSTANT)
    factor = scale;
    #elif defined(_TESSELLATION_FACTOR_WORLD)
    factor = distance(p1.positionWS, p2.positionWS) / scale;
    #elif defined(_TESSELLATION_FACTOR_WORLD_WITH_DEPTH)
    float length = distance(p1.positionWS, p2.positionWS);
    float distanceToCamera = distance(GetCameraPositionWS(), (p1.positionWS +  p2.positionWS) * 0.5);
    factor = length / (scale * distanceToCamera);
    #elif defined(_TESSELLATION_FACTOR_SCREEN)
    factor = distance(p1.positionCS.xyz / p1.positionCS.w, p2.positionCS.xyz / p2.positionCS.w) * _ScreenParams.y / scale;
    #endif

    return max(bias, (factor + bias) * multiplier);
}



// PatchConstant runs once per patch or tri
// It runs parallel to the hull function
float3 BarycentricInterpolate(float3 bary, float3 a, float3 b, float3 c) 
{
    return bary.x * a + bary.y * b + bary.z * c;
}


#define BARYCENTRIC_INTERPOLATE(fieldName) \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z

TessellationFactors PatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
    UNITY_SETUP_INSTANCE_ID(patch[0]);
    TessellationFactors f = (TessellationFactors)0;
    // Check if this patch should be culled (it is out of view)
    if (ShouldClipPatch(patch[0].positionCS, patch[1].positionCS, patch[2].positionCS,  _FrustumCullTolerance, _BackFaceCullTolerance)) 
    {
        f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0; // Cull the patch
    } 
    else
    {
        float3 multipliers;
        #ifdef _TESSELLATION_FACTOR_VCOLORS
                // If applying vertex colors, get each vertice's green channel
                [unroll] for (int i = 0; i < 3; i++) 
                {
                    multipliers[i] = patch[i].color.g;
                }
        #else
                multipliers = 1; // Each vertex has the same multipler
        #endif

        #ifdef DYNAMIC_HEIGHT_ON
            
                [unroll] for (int i = 0; i < 3; i++)
                {
                    multipliers[i] = SAMPLE_TEXTURE2D_LOD(_DeformationMap, sampler_DeformationMap, patch[i].uv, 0).r;
                }
        #else
            multipliers = 1;
        #endif
        // Calculate tessellation factors
        f.edge[0] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, (multipliers[1] + multipliers[2]) / 2, patch[1], patch[2]);
        f.edge[1] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, (multipliers[2] + multipliers[0]) / 2, patch[2], patch[0]);
        f.edge[2] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, (multipliers[0] + multipliers[1]) / 2, patch[0], patch[1]);
        f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0;
    }
    return f;
}

//Hull function, runs once per vertex
[domain("tri")] // Inputting Tris
[outputcontrolpoints(3)] // Tris with 3 points
[outputtopology("triangle_cw")] // Outputting tris
[patchconstantfunc("PatchConstantFunction")] //  Constant function for each patch
// Select a partitioning mode based on keywords
#if defined(_PARTITIONING_INTEGER)
[partitioning("integer")]
#elif defined(_PARTITIONING_FRAC_EVEN)
[partitioning("fractional_even")]
#elif defined(_PARTITIONING_FRAC_ODD)
[partitioning("fractional_odd")]
#elif defined(_PARTITIONING_POW2)
[partitioning("pow2")]
#else 
[partitioning("fractional_odd")]
#endif

TessellationControlPoint Hull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id]; //Vertex index
}

//End Hull

//Start domain

// Domain function runs once per vertex in the tesseleted mesh
// Use to displace vertex for the fragment shader
[domain("tri")] // Signal we're inputting triangles
Interpolators  Domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
    Interpolators output;

    // Setup instancing and stereo support (for VR)
    UNITY_SETUP_INSTANCE_ID(patch[0]);
    UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
    float3 positionWS = BARYCENTRIC_INTERPOLATE(positionWS);
    float3 normalWS = BARYCENTRIC_INTERPOLATE(normalWS);
    float3 tangentWS = BARYCENTRIC_INTERPOLATE(tangentWS.xyz);
    
    float2 uv = BARYCENTRIC_INTERPOLATE(uv); // Interpolate UV
    // Sample the height map and offset position along the normal vector accordingly
    float height = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, uv, 0).r * (_HeightMapAltitude);
    #ifdef DYNAMIC_HEIGHT_ON
        float deform =  1 - SAMPLE_TEXTURE2D_LOD(_DeformationMap, sampler_DeformationMap, uv, 0).r;
        output.height = deform;
        positionWS += normalWS * (height * deform);
    #else
        positionWS += normalWS * height;
    #endif
    output.uv = uv;
    output.positionCS = TransformWorldToHClip(positionWS);
    output.normalWS = normalWS;
    output.positionWS = positionWS;
    output.tangentWS = float4(tangentWS, patch[0].tangentWS.w);
    return output;
}

float SampleHeight(float2 uv) 
{
    return SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
}

float3 GenerateNormalFromHeightMap(float2 uv) {
    // Sample the height from adjacent pixels
    float left = SampleHeight(uv - float2(_MainTexture_TexelSize.x, 0));
    float right = SampleHeight(uv + float2(_MainTexture_TexelSize.x, 0));
    float down = SampleHeight(uv - float2(0, _MainTexture_TexelSize.y));
    float up = SampleHeight(uv + float2(0, _MainTexture_TexelSize.y));

    // Generate a tangent space normal using the slope along the U and V axes
    float3 normalTS = float3((left - right) / (_MainTexture_TexelSize.x * 2), (down - up) / (_MainTexture_TexelSize.y * 2), 1);

    normalTS.xy *= _NormalStrength; // Adjust the XY channels to create stronger or weaker normals
    return normalize(normalTS);
}


float4 Fragment(Interpolators input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float4 mainSample = SAMPLE_TEXTURE2D(_MainTexture, sampler_MainTexture, input.uv);
    float3x3 tangentToWorld = CreateTangentToWorld(input.normalWS, input.tangentWS.xyz, input.tangentWS.w);
    // Calculate a tangent space normal either from the normal map or the height map
    #if defined(_GENERATE_NORMALS_MAP)
        float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalStrength);
    #elif defined(_GENERATE_NORMALS_HEIGHT)
        float3 normalTS = GenerateNormalFromHeightMap(input.uv);
    #else
        float3 normalTS = float3(0, 0, 1);
    #endif
    float3 normalWS = normalize(TransformTangentToWorld(normalTS, tangentToWorld)); // Convert to world space

    // Fill the various lighting and surface data structures for the PBR algorithm
    InputData lightingInput = (InputData)0; // Found in URP/Input.hlsl
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = normalWS;
    lightingInput.viewDirectionWS = GetViewDirectionFromPosition(lightingInput.positionWS);
    lightingInput.shadowCoord = GetShadowCoord(lightingInput.positionWS, input.positionCS);
    lightingInput.fogCoord = input.fogFactorAndVertexLight.x;
    lightingInput.vertexLighting = input.fogFactorAndVertexLight.yzw;
    lightingInput.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, lightingInput.normalWS);
    lightingInput.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    lightingInput.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);

    SurfaceData surface = (SurfaceData)0; // Found in URP/SurfaceData.hlsl
    surface.metallic = 0;
    surface.smoothness = 0.5;
    surface.normalTS = normalTS;
    surface.occlusion = 1;

    #ifdef DYNAMIC_HEIGHT_ON
        float mask = input.height;
        float3 colorMain = _BaseColor.rgb * mask;
        float3 colorDown = _DeepColor.rgb * (1 - mask);
        surface.albedo = colorMain + colorDown;
    #else
        float3 colorMain = mainSample.rgb * _BaseColor.rgb;
        surface.albedo = colorMain;
    #endif

   
    return UniversalFragmentPBR(lightingInput, surface);
}

#endif
