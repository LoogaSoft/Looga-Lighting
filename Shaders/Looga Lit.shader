Shader "LoogaSoft/Lit"
{
    Properties
    {
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        [Enum(Specular, 0, Metallic, 1)] _WorkflowMode ("Workflow Mode", Float) = 1.0
        [Enum(Opaque, 0, Transparent, 1)] _Surface ("Surface Type", Float) = 0.0
        _Cull ("Render Face", Float) = 2.0
        [Enum(Mirror, 0, Flip, 1)] _BackfaceNormalMode ("Backface Normals", Float) = 0.0
        [ToggleUI] _AlphaClip ("Alpha Clipping", Float) = 0.0
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [ToggleUI] _ReceiveShadows ("Receive Shadows", Float) = 1.0
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1.0
        
        [Toggle(_USE_MASK_MAP)] _UseMaskMap ("Use Mask Map", Float) = 0.0
        _MaskMap ("Mask (R:Met, G:AO, A:Smooth)", 2D) = "white" {}
        _MetallicMap ("Metallic Map", 2D) = "white" {}
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        _OcclusionMap ("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1.0
        [Enum(Met Alpha, 0, Alb Alpha, 1)] _SmoothnessTextureChannel ("Smoothness Source", Float) = 0.0
        _BaseSmoothnessScale ("Smoothness", Range(0, 1)) = 0.5
        _EmissionMap("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)

        [Toggle(_USE_SSSS)] _UseSSSS ("Enable SSSS", Float) = 0.0
        _SubsurfaceColor ("Subsurface Color", Color) = (0.85, 0.4, 0.25, 1.0)
        _ScatterWidth ("Scatter Width", Range(0.1, 5.0)) = 2.0
        _ThicknessMap ("Thickness Map (Black=Glow, White=Solid)", 2D) = "black" {}
        _TransmissionStrength ("Transmission Strength", Range(0.0, 5.0)) = 1.0

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
    }
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        // =========================================================
        // 1. GBUFFER PASS
        // =========================================================
        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }
            Stencil { Ref 128 Comp Always Pass Replace }
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma shader_feature_local _USE_MASK_MAP
            #pragma shader_feature_local _USE_SSSS
            #pragma shader_feature_local _EMISSION
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaLightingHelpers.hlsl"

            struct Attributes 
            { 
                float4 positionOS : POSITION; 
                float3 normalOS : NORMAL; 
                float4 tangentOS : TANGENT; 
                float2 uv : TEXCOORD0; 
            };
            
            struct Varyings 
            { 
                float4 positionCS : SV_POSITION; 
                float2 uv : TEXCOORD0; 
                float3 normalWS : TEXCOORD1; 
                float4 tangentWS : TEXCOORD3; 
            };

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap); 
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            TEXTURE2D(_MetallicMap); 
            TEXTURE2D(_OcclusionMap); 
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap); 
            TEXTURE2D(_EmissionMap); 
            TEXTURE2D(_ThicknessMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor; 
                float _AlphaClip;
                float _Cutoff;
                float _BumpScale;
                float _BackfaceNormalMode;
                float _Metallic; 
                float _OcclusionStrength; 
                float _SmoothnessTextureChannel; 
                float _BaseSmoothnessScale; 
                float4 _EmissionColor; 
                float4 _SubsurfaceColor; 
                float _ScatterWidth; 
                float _TransmissionStrength;
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
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);
                return output;
            }

            FragmentOutput Frag(Varyings input, bool isFrontFace : SV_IsFrontFace)
            {
                FragmentOutput outGBuffer;
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                if (_AlphaClip > 0.5) clip(albedo.a - _Cutoff);
                half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                
                half metallic = 0.0; 
                half occlusion = 1.0; 
                half baseSmoothness = 0.5;
                
                #if defined(_USE_MASK_MAP)
                    half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    metallic = maskSample.r; 
                    occlusion = maskSample.g; 
                    baseSmoothness = maskSample.a * _BaseSmoothnessScale;
                #else
                    half4 metallicSample = SAMPLE_TEXTURE2D(_MetallicMap, sampler_BaseMap, input.uv);
                    metallic = metallicSample.r * _Metallic; 
                    half4 occlusionSample = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_BaseMap, input.uv);
                    occlusion = lerp(1.0, occlusionSample.g, _OcclusionStrength);
                    baseSmoothness = (_SmoothnessTextureChannel == 1.0) ? (albedo.a * _BaseSmoothnessScale) : (metallicSample.a * _BaseSmoothnessScale);
                #endif

                half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                half sign = input.tangentWS.w * GetOddNegativeScale();
                half3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * sign;
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS));
                normalWS = NormalizeNormalPerPixel(normalWS);
                normalWS = (!isFrontFace && _BackfaceNormalMode > 0.5) ? -normalWS : normalWS;

                half3 emission = 0.0;
                #if defined(_EMISSION)
                    emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, input.uv).rgb * _EmissionColor.rgb;
                #endif
                half3 diffuseColor = albedo.rgb * (1.0 - metallic);
                half3 ambientDiffuse = EvaluateLoogaAmbientDiffuse(diffuseColor, normalWS, occlusion);
                
                #if defined(_USE_SSSS)
                    half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_BaseMap, input.uv).r;
                    half transmissionMask = (1.0 - thickness) * _TransmissionStrength;
                    outGBuffer.GBuffer0 = half4(albedo.rgb, 33.0 / 255.0);
                    outGBuffer.GBuffer3 = half4(emission + ambientDiffuse, transmissionMask);
                #else
                    outGBuffer.GBuffer0 = half4(albedo.rgb, 1.0 / 255.0);
                    outGBuffer.GBuffer3 = half4(emission + ambientDiffuse, 0.0);
                #endif

                outGBuffer.GBuffer1 = half4(metallic, 0.0, 0.0, occlusion);
                outGBuffer.GBuffer2 = half4(PackGBufferNormal(normalWS), baseSmoothness);
                return outGBuffer;
            }
            ENDHLSL
        }

        // =========================================================
        // 2. FORWARD LIT PASS
        // =========================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha 
            ZWrite On 
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex VertForward
            #pragma fragment FragForward
            #pragma shader_feature_local _USE_MASK_MAP
            #pragma shader_feature_local _USE_SSSS
            #pragma shader_feature_local _EMISSION
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaLightingHelpers.hlsl"
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaMasterLighting.hlsl"

            struct AttributesForward 
            { 
                float4 positionOS : POSITION; 
                float3 normalOS : NORMAL; 
                float4 tangentOS : TANGENT; 
                float2 uv : TEXCOORD0; 
            };
            
            struct VaryingsForward 
            { 
                float4 positionCS : SV_POSITION; 
                float3 positionWS : TEXCOORD0; 
                float2 uv : TEXCOORD1; 
                float3 normalWS : TEXCOORD3; 
                float4 tangentWS : TEXCOORD4; 
            };

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap); 
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            TEXTURE2D(_MetallicMap); 
            TEXTURE2D(_OcclusionMap); 
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap); 
            TEXTURE2D(_EmissionMap); 
            TEXTURE2D(_ThicknessMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor; 
                float _AlphaClip;
                float _Cutoff;
                float _BumpScale;
                float _BackfaceNormalMode;
                float _Metallic; 
                float _OcclusionStrength; 
                float _SmoothnessTextureChannel; 
                float _BaseSmoothnessScale; 
                float4 _EmissionColor; 
                float4 _SubsurfaceColor; 
                float _ScatterWidth; 
                float _TransmissionStrength;
            CBUFFER_END

            VaryingsForward VertForward(AttributesForward input)
            {
                VaryingsForward output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.positionCS = vertexInput.positionCS; 
                output.positionWS = vertexInput.positionWS; 
                output.uv = input.uv; 
                output.normalWS = normalInput.normalWS; 
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);
                return output;
            }

            half4 FragForward(VaryingsForward input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                half4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                if (_AlphaClip > 0.5) clip(albedoSample.a - _Cutoff);
                half3 albedo = albedoSample.rgb; 
                half alpha = albedoSample.a;
                
                half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                half sign = input.tangentWS.w * GetOddNegativeScale();
                half3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * sign;
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS));
                normalWS = NormalizeNormalPerPixel(normalWS);
                normalWS = (!isFrontFace && _BackfaceNormalMode > 0.5) ? -normalWS : normalWS;
                
                half metallic = 0.0; 
                half occlusion = 1.0; 
                half baseSmoothness = 0.5;
                
                #if defined(_USE_MASK_MAP)
                    half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    metallic = maskSample.r; 
                    occlusion = maskSample.g; 
                    baseSmoothness = maskSample.a * _BaseSmoothnessScale;
                #else
                    half4 metallicSample = SAMPLE_TEXTURE2D(_MetallicMap, sampler_BaseMap, input.uv);
                    metallic = metallicSample.r * _Metallic; 
                    half4 occlusionSample = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_BaseMap, input.uv);
                    occlusion = lerp(1.0, occlusionSample.g, _OcclusionStrength);
                    baseSmoothness = (_SmoothnessTextureChannel == 1.0) ? (albedoSample.a * _BaseSmoothnessScale) : (metallicSample.a * _BaseSmoothnessScale);
                #endif

                half perceptualRoughness = 1.0 - baseSmoothness;
                half3 f0 = lerp(kDielectricSpec.rgb, albedo, metallic);
                half3 diffuseColor = albedo * (1.0 - metallic);

                float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
                float NoV = saturate(dot(normalWS, viewDirWS));
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                
                Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1.0);
                float3 mainRadiance = mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                
                float3 color = EvaluateGlobalLoogaLighting(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirWS, NoV, mainLight.direction, mainRadiance);

                #if defined(_USE_SSSS)
                    half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_BaseMap, input.uv).r;
                    half transmissionMask = (1.0 - thickness) * _TransmissionStrength;
                    color += EvaluateTransmission(_SubsurfaceColor.rgb, _ScatterWidth, mainLight.direction, viewDirWS, normalWS, mainRadiance, mainLight.shadowAttenuation, transmissionMask);
                #endif

                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1,1,1,1));
                    float3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;
                    color += EvaluateGlobalLoogaLighting(diffuseColor, f0, perceptualRoughness, normalWS, occlusion, viewDirWS, NoV, light.direction, dynRadiance);
                }

                color += EvaluateLoogaAmbientDiffuse(diffuseColor, normalWS, occlusion);
                half indirectOcclusion = GetLoogaMetalIndirectOcclusion(occlusion, metallic);
                color += EvaluateGlobalLoogaIndirect(f0, perceptualRoughness, indirectOcclusion, viewDirWS, normalWS, normalWS, NoV, input.positionWS, input.uv);
                color += EvaluateLoogaMetalAmbientReflection(f0, metallic, perceptualRoughness, normalWS, normalWS, viewDirWS, NoV, occlusion);
                #if defined(_EMISSION)
                    color += SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, input.uv).rgb * _EmissionColor.rgb;
                #endif

                return half4(color, alpha);
            }
            ENDHLSL
        }

        // =========================================================
        // 3. SSSS PROFILE PASS
        // =========================================================
        Pass 
        { 
            Name "SSSSProfile" 
            Tags { "LightMode" = "SSSSProfile" } 
            
            ZWrite Off 
            ZTest Equal 
            Cull [_Cull]

            HLSLPROGRAM 
            #pragma vertex VertProfile 
            #pragma fragment FragProfile 
            #pragma shader_feature_local _USE_SSSS 

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 

            struct AttributesProfile 
            { 
                float4 positionOS : POSITION; 
            }; 

            struct VaryingsProfile 
            { 
                float4 positionCS : SV_POSITION; 
            }; 

            CBUFFER_START(UnityPerMaterial) 
                float4 _SubsurfaceColor; 
                float _ScatterWidth; 
            CBUFFER_END 

            VaryingsProfile VertProfile(AttributesProfile input) 
            { 
                VaryingsProfile output; 
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz); 
                return output; 
            } 

            half4 FragProfile(VaryingsProfile input) : SV_Target 
            { 
                #if !defined(_USE_SSSS) 
                    discard; 
                #endif 
                
                return half4(_SubsurfaceColor.rgb, _ScatterWidth / 5.0); 
            } 
            ENDHLSL 
        }

        // =========================================================
        // 4. META PASS
        // =========================================================
        Pass 
        { 
            Name "Meta" 
            Tags { "LightMode" = "Meta" } 
            
            Cull Off 

            HLSLPROGRAM 
            #pragma vertex UniversalVertexMeta 
            #pragma fragment UniversalFragmentMetaLit 
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature EDITOR_VISUALIZATION 

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl" 
            ENDHLSL 
        }

        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER" 
        UsePass "Universal Render Pipeline/Lit/DEPTHONLY"
    }

    CustomEditor "LoogaSoft.LightingPrime.Editor.LoogaLitShaderGUI" 
    Fallback "Universal Render Pipeline/Lit"
}
