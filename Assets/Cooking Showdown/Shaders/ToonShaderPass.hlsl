#ifndef MY_TOON_SHADER_INCLUDE
#define MY_TOON_SHADER_INCLUDE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
///////////////////////////////////////////////////////////////////////////////
//                      CBUFFER                                              //
///////////////////////////////////////////////////////////////////////////////
CBUFFER_START(UnityPerMaterial)
    TEXTURE2D(_ColorMap);
    SAMPLER(sampler_ColorMap);
    float4 _ColorMap_ST;
    float4 _Color;
    float _Smoothness;
    float _RimSharpness;
    float4 _RimColor;
    float4 _WorldColor;
CBUFFER_END
///////////////////////////////////////////////////////////////////////////////
//                      STRUCTS                                              //
///////////////////////////////////////////////////////////////////////////////

struct Attributes {
	float4 positionOS : POSITION;
	float3 normalOS   : NORMAL;
	float2 uv         : TEXCOORD0;

	// This line is required for VR SPI to work.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionHCS     : SV_POSITION;
    float2 uv              : TEXCOORD0;
    float3 positionWS      : TEXCOORD1;
    float3 normalWS        : TEXCOORD2;
    float3 viewDirectionWS : TEXCOORD3;

    // This line is required for VR SPI to work.
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};
///////////////////////////////////////////////////////////////////////////////
//                      Common Lighting Transforms                           //
///////////////////////////////////////////////////////////////////////////////
float3 _LightDirection;

float4 GetClipSpacePosition(float3 positionWS, float3 normalWS) {
    #if defined(SHADOW_CASTER_PASS)
        float4 positionHCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

    #if UNITY_REVERSED_Z
        positionHCS.z = min(positionHCS.z, positionHCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        positionHCS.z = max(positionHCS.z, positionHCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif

        return positionHCS;
    #endif

    return TransformWorldToHClip(positionWS);
}

float4 GetMainLightShadowCoord(float3 positionWS, float4 positionHCS) {
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
        return ComputeScreenPos(positionHCS);
    #else
        return TransformWorldToShadowCoord(positionWS);
    #endif
}

float4 GetMainLightShadowCoord(float3 PositionWS) {
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
        float4 clipPos = TransformWorldToHClip(PositionWS);
        return ComputeScreenPos(clipPos);
    #else
        return TransformWorldToShadowCoord(PositionWS);
    #endif
}

void GetMainLightData(float3 PositionWS, out Light light) {
    float4 shadowCoord = GetMainLightShadowCoord(PositionWS);
    light = GetMainLight(shadowCoord);
}
///////////////////////////////////////////////////////////////////////////////
//                      Helper Functions                                     //
///////////////////////////////////////////////////////////////////////////////
static inline float easysmoothstep(float min, float x) {
    return smoothstep(min, min + 0.01, x);
}
///////////////////////////////////////////////////////////////////////////////
//                      Functions                                            //
///////////////////////////////////////////////////////////////////////////////
Varyings Vertex(Attributes IN) {
    Varyings OUT = (Varyings)0;

    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

    // Set up each field of the Varyings struct, then return it.
    OUT.positionWS = mul(unity_ObjectToWorld, IN.positionOS).xyz;
    OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
    OUT.positionHCS = GetClipSpacePosition(OUT.positionWS, OUT.normalWS);
    OUT.viewDirectionWS = normalize(GetWorldSpaceViewDir(OUT.positionWS));
    OUT.uv = TRANSFORM_TEX(IN.uv, _ColorMap);

    return OUT;
}

float FragmentDepthOnly(Varyings IN) : SV_Target {
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    return 0;
}

float4 FragmentDepthNormalsOnly(Varyings IN) : SV_Target {
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    return float4(normalize(IN.normalWS), 0);
}

float4 FragmentTransparent(Varyings IN) : SV_Target {
    // These macros are required for VR SPI compatibility
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

    IN.normalWS = normalize(IN.normalWS);
    IN.viewDirectionWS = normalize(IN.viewDirectionWS);

    Light light;
    GetMainLightData(IN.positionWS, light);
    float NoL = dot(IN.normalWS, light.direction);

    float toonLighting = easysmoothstep(0, NoL);
    float toonShadows = easysmoothstep(0.5, light.shadowAttenuation);

    float3 halfVector = normalize(light.direction + IN.viewDirectionWS);
    float NoH = max(dot(IN.normalWS, halfVector), 0);

    float specularTerm = pow(NoH, _Smoothness * _Smoothness);
    specularTerm *= toonLighting * toonShadows;
    specularTerm = easysmoothstep(0.01, specularTerm);

    float NoV = max(dot(IN.normalWS, IN.viewDirectionWS), 0);
    float rimTerm = pow(1.0 - NoV, _RimSharpness);
    rimTerm *= toonLighting * toonShadows;
    rimTerm = easysmoothstep(0.01, rimTerm);

    float4 surfaceColor = _Color * SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, IN.uv);

    float3 directionalLighting = toonLighting * toonShadows * light.color;
    float3 specularLighting = specularTerm * light.color;
    float3 rimLighting = rimTerm * _RimColor;

    float3 finalLighting = float3(0, 0, 0);
    finalLighting += _WorldColor;
    finalLighting += directionalLighting;
    finalLighting += specularLighting;
    finalLighting += rimLighting;

    float3 rgb = surfaceColor.rgb * finalLighting;

    float alpha = saturate(surfaceColor.a);

    return float4(rgb, alpha);
}

float3 Fragment(Varyings IN) : SV_Target 
{ 
    // These macros are required for VR SPI compatibility 
    UNITY_SETUP_INSTANCE_ID(IN); 
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN); 
    
    IN.normalWS = normalize(IN.normalWS); 
    IN.viewDirectionWS = normalize(IN.viewDirectionWS); 
    
    Light light; 
    GetMainLightData(IN.positionWS, light); 
    float NoL = dot(IN.normalWS, light.direction); 
    
    float toonLighting = easysmoothstep(0, NoL); 
    float toonShadows = easysmoothstep(0.5, light.shadowAttenuation); 
    
    float3 halfVector = normalize(light.direction + IN.viewDirectionWS); 
    float NoH = max(dot(IN.normalWS, halfVector), 0); 
    
    float specularTerm = pow(NoH, _Smoothness * _Smoothness); 
    specularTerm *= toonLighting * toonShadows; 
    specularTerm = easysmoothstep(0.01, specularTerm); 
    
    float NoV = max(dot(IN.normalWS, IN.viewDirectionWS), 0); 
    float rimTerm = pow(1.0 - NoV, _RimSharpness); 
    rimTerm *= toonLighting * toonShadows; 
    rimTerm = easysmoothstep(0.01, rimTerm); 
    
    float3 surfaceColor = _Color * SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, IN.uv); 
    
    float3 directionalLighting = toonLighting * toonShadows * light.color; 
    float3 specularLighting = specularTerm * light.color; 
    float3 rimLighting = rimTerm * _RimColor; 
    
    float3 finalLighting = float3(0, 0, 0); 
    finalLighting += _WorldColor; 
    finalLighting += directionalLighting; 
    finalLighting += specularLighting; 
    finalLighting += rimLighting; 
    
    return surfaceColor * finalLighting;
}
#endif