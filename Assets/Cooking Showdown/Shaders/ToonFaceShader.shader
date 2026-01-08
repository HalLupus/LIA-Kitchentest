Shader "Custom Shaders/Toon Shader Face"
{
    Properties
    {
        [MainTexture] _ColorMap ("Color Map", 2D) = "white" {}
        [MainColor] _Color ("Color", Color) = (0.91, 0.91, 0.38, 0.5)
		_Smoothness ("Smoothness", Float) = 16.0
		_RimSharpness ("Rim Sharpness", Float) = 16.0
		[HDR] _RimColor ("Rim Color", Color) = (1.0, 1.0, 1.0)
		[HDR] _WorldColor ("World Color", Color) = (0.1, 0.1, 0.1) 
        _FaceEyeState ("Eye State (0: Open, 1: Closed)", Float) = 0.0
        _FaceMouthPhoneme ("Mouth Phoneme (0: Closed, 1: A, 2: O, 3: E, 4: WR, 5: TS, 6: LN, 7: UQ, 8: MBP, 9: FV)", Float) = 0.0
        _FaceEyeOpen ("Eyes Open Texture", 2D) = "white" {}
        _FaceEyeClosed ("Eyes Closed Texture", 2D) = "white" {}
        _FaceMouthClosed ("Mouth Closed Texture", 2D) = "white" {}
        _FaceMouthA ("Mouth A Texture", 2D) = "white" {}
        _FaceMouthO ("Mouth O Texture", 2D) = "white" {}
        _FaceMouthE ("Mouth E Texture", 2D) = "white" {}
        _FaceMouthWR ("Mouth WR Texture", 2D) = "white" {}
        _FaceMouthTS ("Mouth TS Texture", 2D) = "white" {}
        _FaceMouthLN ("Mouth LN Texture", 2D) = "white" {}
        _FaceMouthUQ ("Mouth UQ Texture", 2D) = "white" {}
        _FaceMouthMBP ("Mouth MBP Texture", 2D) = "white" {}
        _FaceMouthFV ("Mouth FV Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Cull Back
        ZWrite On
        ZTest LEqual
        ZClip Off

        Pass
        {
            Name "ForwardLit"
            Tags {"LightMode" = "UniversalForwardOnly"}


            HLSLPROGRAM

            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "ToonFaceShaderPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags {"LightMode" = "ShadowCaster"}


            HLSLPROGRAM

            #define SHADOW_CASTER_PASS

            #pragma vertex Vertex
            #pragma fragment FragmentDepthOnly

            #include "ToonFaceShaderPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags {"LightMode" = "DepthOnly"}


            HLSLPROGRAM

            #pragma vertex Vertex
            #pragma fragment FragmentDepthOnly

            #include "ToonFaceShaderPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthNormalsOnly"
            Tags {"LightMode" = "DepthNormalsOnly"}


            HLSLPROGRAM

            #pragma vertex Vertex
            #pragma fragment FragmentDepthNormalsOnly

            #include "ToonFaceShaderPass.hlsl"

            ENDHLSL
        }
    }
}