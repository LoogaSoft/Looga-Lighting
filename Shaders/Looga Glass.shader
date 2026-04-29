Shader "LoogaSoft/Glass"
{
    Properties
    {
        [MainTexture] _BaseMap ("Dirt Albedo (RGB) & Opacity (A)", 2D) = "black" {}
        [MainColor] _BaseColor ("Glass Tint Color", Color) = (0.9, 0.95, 1.0, 1.0)
        [Enum(Specular, 0, Metallic, 1)] _WorkflowMode ("Workflow Mode", Float) = 1.0
        [Enum(Opaque, 0, Transparent, 1)] _Surface ("Surface Type", Float) = 1.0
        _Cull ("Render Face", Float) = 2.0
        [Enum(Mirror, 0, Flip, 1)] _BackfaceNormalMode ("Backface Normals", Float) = 0.0
        [ToggleUI] _AlphaClip ("Alpha Clipping", Float) = 0.0
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [ToggleUI] _ReceiveShadows ("Receive Shadows", Float) = 1.0
        
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1.0
        
        [Toggle(_USE_MASK_MAP)] _UseMaskMap ("Use Mask Map", Float) = 0.0
        _MaskMap ("Mask Map (R:Metallic, G:AO, A:Smoothness)", 2D) = "white" {}
        
        _MetallicMap ("Metallic Map", 2D) = "white" {}
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        _OcclusionMap ("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1.0
        
        [Enum(Metallic Alpha, 0, Albedo Alpha, 1)] _SmoothnessTextureChannel ("Smoothness Source", Float) = 0.0
        _Smoothness ("Master Smoothness", Range(0.0, 1.0)) = 0.95

        _Distortion ("Refraction Strength", Range(0.0, 0.5)) = 0.05

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
    }
    
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        
        Blend One Zero 
        ZWrite Off
        Cull [_Cull]

        // =========================================================
        // 1. FORWARD LIT PASS
        // =========================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            #pragma shader_feature_local _USE_MASK_MAP
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            
            // NEW: Use the global switchboard
            #include "Packages/com.loogasoft.loogalighting/Includes/LoogaMasterLighting.hlsl"

            struct AttributesGlass
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
            };

            struct VaryingsGlass
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float4 tangentWS    : TEXCOORD2;
                float3 viewDirWS    : TEXCOORD3;
                float4 screenPos    : TEXCOORD4;
                float3 positionWS   : TEXCOORD5;
            };

            TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);  SAMPLER(sampler_BumpMap);
            TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);
            TEXTURE2D(_MetallicMap);
            TEXTURE2D(_OcclusionMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _BumpScale;
                float _BackfaceNormalMode;
                float _Distortion;
                float _Smoothness;
                float _Metallic;
                float _OcclusionStrength;
                float _SmoothnessTextureChannel;
            CBUFFER_END

            VaryingsGlass Vert(AttributesGlass input)
            {
                VaryingsGlass output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.uv = input.uv;
                output.normalWS = normalInput.normalWS;
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                
                output.screenPos = ComputeScreenPos(vertexInput.positionCS);
                return output;
            }

            half4 Frag(VaryingsGlass input, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // 1. Texture Sampling
                half4 dirtSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                
                half metallic = 0.0;
                half occlusion = 1.0;
                half baseSmoothness = 0.5;

                #if defined(_USE_MASK_MAP)
                    half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    metallic = maskSample.r;
                    occlusion = maskSample.g;
                    baseSmoothness = maskSample.a * _Smoothness;
                #else
                    half4 metallicSample = SAMPLE_TEXTURE2D(_MetallicMap, sampler_BaseMap, input.uv);
                    metallic = metallicSample.r * _Metallic;
                    
                    half4 occlusionSample = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_BaseMap, input.uv);
                    occlusion = lerp(1.0, occlusionSample.g, _OcclusionStrength);
                    
                    if (_SmoothnessTextureChannel == 1.0)
                        baseSmoothness = dirtSample.a * _Smoothness;
                    else
                        baseSmoothness = metallicSample.a * _Smoothness;
                #endif

                half perceptualRoughness = 1.0 - baseSmoothness;
                half roughness = perceptualRoughness * perceptualRoughness;
                half3 f0 = lerp(half3(0.04, 0.04, 0.04), dirtSample.rgb, metallic);

                // 2. Normal Mapping
                half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                half sign = input.tangentWS.w * GetOddNegativeScale();
                half3 bitangentWS = cross(input.normalWS, input.tangentWS.xyz) * sign;
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS));
                normalWS = NormalizeNormalPerPixel(normalWS);
                normalWS = (!isFrontFace && _BackfaceNormalMode > 0.5) ? -normalWS : normalWS;

                // 3. Physical Fresnel
                float NoV = saturate(dot(normalWS, input.viewDirWS));
                float3 F = Fresnel(f0, NoV, roughness); 

                // 4. Refraction
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                float2 refractionOffset = normalTS.xy * _Distortion;
                
                float edgeFade = smoothstep(0.0, 0.1, screenUV.x) * smoothstep(1.0, 0.9, screenUV.x) * smoothstep(0.0, 0.1, screenUV.y) * smoothstep(1.0, 0.9, screenUV.y);
                screenUV += refractionOffset * edgeFade;
                
                // 5. Calculate Background Transmission
                half3 background = SampleSceneColor(screenUV);
                half3 transmission = background * _BaseColor.rgb * (1.0 - F) * (1.0 - dirtSample.a);

                // 6. Dirt Diffuse & Specular Accumulation (Routed through Global Switch)
                half3 dirtDiffuse = dirtSample.rgb * (1.0 - metallic) * dirtSample.a;
                half3 lightingAccumulation = 0.0;

                #if defined(_SPECULARHIGHLIGHTS_OFF)
                    f0 = half3(0.0, 0.0, 0.0); // Killing f0 prevents specular highlights, but keeps dirt diffuse intact!
                #endif

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1.0);
                half3 mainRadiance = mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                
                lightingAccumulation += EvaluateGlobalLoogaLighting(dirtDiffuse, f0, perceptualRoughness, normalWS, occlusion, input.viewDirWS, NoV, mainLight.direction, mainRadiance);

                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1,1,1,1));
                    half3 dynRadiance = light.color * light.shadowAttenuation * light.distanceAttenuation;
                    lightingAccumulation += EvaluateGlobalLoogaLighting(dirtDiffuse, f0, perceptualRoughness, normalWS, occlusion, input.viewDirWS, NoV, light.direction, dynRadiance);
                }

                // 7. Environment Reflection
                half3 indirectLighting = EvaluateLoogaAmbientDiffuse(dirtDiffuse, normalWS, occlusion);
                #if !defined(_ENVIRONMENTREFLECTIONS_OFF)
                    indirectLighting += EvaluateGlobalLoogaIndirect(f0, perceptualRoughness, occlusion, input.viewDirWS, normalWS, normalWS, NoV, input.positionWS, input.uv);
                #endif
                
                // 8. Final Composite
                half3 finalColor = transmission + lightingAccumulation + indirectLighting;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
        
        // =========================================================
        // 2. META PASS
        // =========================================================
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            Cull Off

            HLSLPROGRAM
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
        UsePass "Universal Render Pipeline/Lit/DEPTHONLY"
    }
    
    CustomEditor "LoogaSoft.LightingPrime.Editor.LoogaGlassShaderGUI"
    Fallback "Universal Render Pipeline/Lit"
}
