Shader "Unlit/DemoTesselation"
{
    Properties
    {
        _MainTexture("Main texture", 2D) = "white" {}
        _NormalStrength("Normal strength", Float) = 1
        _BaseColor("Base color", Color) = (1,1,1,1)
        _DeepColor("Color of low areas", Color) = (0,0,0,1)
        [NoScaleOffset] _NormalMap("Normal map", 2D) = "white" {}
        [NoScaleOffset] _HeightMap("Height map", 2D) = "white" {}
        [NoScaleOffset] _DeformationMap("Deformation texture", 2D) = "black" {}
        [KeywordEnum(MAP, HEIGHT)] _GENERATE_NORMALS("Normal mode", Float) = 0
        _HeightMapAltitude("Height map altitude", Float) = 0
        [KeywordEnum(INTEGER, FRAC_EVEN, FRAC_ODD, POW2)] _PARTITIONING("Partition algoritm", Float) = 0
        [KeywordEnum(CONSTANT, WORLD, SCREEN, WORLD_WITH_DEPTH)] _TESSELLATION_FACTOR("Tessellation mode", Float) = 0
        _TessellationFactor("Tessellation factor", Float) = 1
        _TessellationBias("Tessellation bias", Float) = 0
        [Toggle(_TESSELLATION_FACTOR_VCOLORS)]_TessellationFactorVColors("Multiply VColor.Green in factor", Float) = 0
        [Toggle(_DYNAMIC_HEIGHT)]_DynamicHeight("Multiply factor acording to the deformation texture", Float) = 0
        _FrustumCullTolerance("Frustum cull tolerance", Float) = 0.01
        _BackFaceCullTolerance("Back face cull tolerance", Float) = 0.01
    }
    SubShader
    {
        Tags {"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma target 5.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            // Material keywords
            #pragma shader_feature_local _PARTITIONING_INTEGER _PARTITIONING_FRAC_EVEN _PARTITIONING_FRAC_ODD _PARTITIONING_POW2
            #pragma shader_feature_local _TESSELLATION_FACTOR_CONSTANT _TESSELLATION_FACTOR_WORLD _TESSELLATION_FACTOR_SCREEN _TESSELLATION_FACTOR_WORLD_WITH_DEPTH
            #pragma shader_feature_local _TESSELLATION_FACTOR_VCOLORS
            #pragma shader_feature_local _DYNAMIC_HEIGHT
            #pragma shader_feature_local _GENERATE_NORMALS_MAP _GENERATE_NORMALS_HEIGHT


            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment Fragment

            #include "TessellationFactors.hlsl"
            ENDHLSL
        }
    }
}
