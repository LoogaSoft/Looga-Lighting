Shader "LoogaSoft/Lit Skin"
{
    Properties
    {
        [Header(Base Textures)]
        _BaseMap ("Albedo", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _MaskMap ("Mask (R:Metallic, G:Occlusion, A:Smoothness)", 2D) = "white" {}
        
        [Header(Skin Properties)]
        _BaseSmoothnessScale ("Base Flesh Smoothness", Range(0, 1)) = 0.5
        
        [Header(Oily Layer Properties)]
        _SecondarySmoothness ("Oily Layer Smoothness", Range(0, 1)) = 0.85
        _CavityMap ("Cavity/Lobe Mask (R)", 2D) = "white" {}
        _LobeMix ("Oily Layer Strength", Range(0, 1)) = 1.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }
            
            // --- THE STENCIL FLAG ---
            // This writes Bit 7 (128) to the Stencil Buffer.
            // Your future Screen-Space SSS Render Feature will check for this exact Reference.
            Stencil
            {
                Ref 128
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float4 tangentWS    : TEXCOORD3;
            };

            // Properties
            TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);
            TEXTURE2D(_CavityMap);  SAMPLER(sampler_CavityMap);

            CBUFFER_START(UnityPerMaterial)
                float _BaseSmoothnessScale;
                float _SecondarySmoothness;
                float _LobeMix;
            CBUFFER_END

            struct FragmentOutput
            {
                half4 GBuffer0 : SV_Target0;
                half4 GBuffer1 : SV_Target1;
                half4 GBuffer2 : SV_Target2;
                half4 GBuffer3 : SV_Target3;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = vertexInput.positionCS;
                output.uv = input.uv;
                output.normalWS = normalInput.normalWS;
                
                // Pack the float3 tangent and the original tangent sign (.w) into the float4 output
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);

                return output;
            }

            FragmentOutput Frag(Varyings input)
            {
                FragmentOutput outGBuffer;

                // 1. Sample Textures
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 normalSample = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                half cavitySample = SAMPLE_TEXTURE2D(_CavityMap, sampler_CavityMap, input.uv).r;

                // 2. Base Properties
                // Skin is dielectric, so metallic is forced to 0 regardless of map, but you could use maskSample.r if desired.
                half metallic = 0.0; 
                half occlusion = maskSample.g;
                half baseSmoothness = maskSample.a * _BaseSmoothnessScale;

                // 3. Normal Map Decoding
                half3 normalTS = UnpackNormal(normalSample);
                half3 viewDirWS = GetCameraPositionWS() - input.positionCS.xyz; // Needed for bitangent
                half sign = input.tangentWS.w * GetOddNegativeScale();
                half3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * sign;
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS));
                normalWS = NormalizeNormalPerPixel(normalWS);

                // 4. Dual Lobe Properties
                // Convert secondary smoothness to perceptual roughness for packing
                half secondaryRoughness = 1.0 - _SecondarySmoothness;
                
                // Mask the secondary oily layer using cavity map (less oil in deep pores) and the master slider
                half finalLobeMix = cavitySample * _LobeMix;

                // 5. PACKING TO GBUFFER
                // GBuffer 0: Albedo (RGB) and Material Flags (A)
                // Flag 16 (16/255) tells our lighting pass: "This is a Dual Lobe Material"
                outGBuffer.GBuffer0 = half4(albedo.rgb, 16.0 / 255.0);
                
                // GBuffer 1: Metallic (R), Secondary Roughness (G), Lobe Mix (B), Occlusion (A)
                outGBuffer.GBuffer1 = half4(metallic, secondaryRoughness, finalLobeMix, occlusion);
                
                // GBuffer 2: Normal (RGB) and Base Smoothness (A)
                outGBuffer.GBuffer2 = half4(normalWS, baseSmoothness);
                
                // GBuffer 3: Emission (RGB)
                outGBuffer.GBuffer3 = half4(0.0, 0.0, 0.0, 1.0);

                return outGBuffer;
            }
            ENDHLSL
        }
        
        // Include Standard ShadowCaster and DepthOnly passes here so the skin casts shadows properly
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
    }
}