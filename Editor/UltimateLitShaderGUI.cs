using System;
using UnityEditor;
using UnityEngine;

public class UltimateLitShaderGUI : ShaderGUI
{
    private static readonly int SrcBlend = Shader.PropertyToID("_SrcBlend");
    private static readonly int DstBlend = Shader.PropertyToID("_DstBlend");
    private static readonly int ZWrite = Shader.PropertyToID("_ZWrite");

    private static readonly string UseHeightmap = "_USE_HEIGHTMAP";
    private static readonly string UseBaseMaskMap = "_USE_BASE_MASK_MAP";
    private static readonly string UseDetailMap = "_USE_DETAIL_MAP";
    private static readonly string UseDetailHeightmap = "_USE_DETAIL_HEIGHTMAP";
    private static readonly string UseDetailMaskMap = "_USE_DETAIL_MASK_MAP";
    private static readonly string UseSubsurface = "_USE_SUBSURFACE";
    private static readonly string UseVertexColorMask = "_USE_VERTEX_COLOR_MASK";
    private static readonly string UseSpecularAA = "_USE_SPECULAR_AA";
    private static readonly string UseHalfLambert = "_USE_HALF_LAMBERT";
    
    private bool _expandDetailSettings;
    private bool _expandSubsurfaceSettings;
    private bool _expandAdvancedSettings;
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material[] materials = Array.ConvertAll(materialEditor.targets, x => x as Material);

        #region Material Properties
        
        MaterialProperty surfaceType = FindProperty("_Surface", properties, false);
        MaterialProperty blendMode = FindProperty("_Blend", properties, false);
        MaterialProperty renderFaceType = FindProperty("_Cull", properties, false);
        MaterialProperty alphaClip = FindProperty("_AlphaClip", properties, false);
        MaterialProperty clipThreshold = FindProperty("_Cutoff", properties, false);
        MaterialProperty receiveShadows = FindProperty("_ReceiveShadows", properties, false);
        MaterialProperty backfaceNormalMode = FindProperty("_Backface_Normal_Mode", properties, false);
        
        MaterialProperty albedoMap = FindProperty("_BaseMap", properties, false);
        MaterialProperty albedoColor = FindProperty("_BaseColor", properties, false);
		MaterialProperty albedoContrast = FindProperty("_Albedo_Contrast", properties, false);
        MaterialProperty normalMap = FindProperty("_Normal_Map", properties, false);
        MaterialProperty normalStrength = FindProperty("_Normal_Strength", properties, false);
        MaterialProperty emissionMap = FindProperty("_EmissionMap", properties, false);
        MaterialProperty emissiveColor = FindProperty("_EmissionColor", properties, false);
        
        MaterialProperty heightMap = FindProperty("_Height_Map", properties, false);
        MaterialProperty heightStrength = FindProperty("_Height_Amplitude", properties, false);
        
        MaterialProperty maskMap = FindProperty("_Mask_Map", properties, false);
        
        MaterialProperty metallicMap = FindProperty("_Metallic_Map", properties, false);
        MaterialProperty metallicChannel = FindProperty("_Metallic_Channel", properties, false);
        MaterialProperty metallicStrength = FindProperty("_Metallic_Strength", properties, false);
        
        MaterialProperty occlusionMap = FindProperty("_Occlusion_Map", properties, false);
        MaterialProperty occlusionChannel = FindProperty("_Occlusion_Channel", properties, false);
        MaterialProperty occlusionStrength = FindProperty("_Occlusion_Strength", properties, false);
        
        MaterialProperty detailBlendMap = FindProperty("_Detail_Blend_Map", properties, false);
        MaterialProperty detailBlendChannel = FindProperty("_Detail_Blend_Channel", properties, false);
        MaterialProperty detailBlendOpacity = FindProperty("_Detail_Blend_Opacity", properties, false);
        
        MaterialProperty roughnessMap = FindProperty("_Roughness_Map", properties, false);
        MaterialProperty roughnessChannel = FindProperty("_Roughness_Channel", properties, false);
        MaterialProperty roughnessStrength = FindProperty("_Roughness_Strength", properties, false);
        MaterialProperty invertRoughnessMap = FindProperty("_Invert_Roughness_Map", properties, false);
        
        MaterialProperty tiling = FindProperty("_Tiling", properties, false);
        MaterialProperty offset = FindProperty("_Offset", properties, false);
        
        MaterialProperty useVertexColorMask = FindProperty(UseVertexColorMask, properties, false);
        MaterialProperty detailAlbedoMap = FindProperty("_Detail_Albedo_Map", properties, false);
        MaterialProperty detailAlbedoColor = FindProperty("_Detail_Albedo_Color", properties, false);
        MaterialProperty detailNormalMap = FindProperty("_Detail_Normal_Map", properties, false);
        MaterialProperty detailNormalStrength = FindProperty("_Detail_Normal_Strength", properties, false);
        MaterialProperty detailEmissionMap = FindProperty("_Detail_Emission_Map", properties, false);
        MaterialProperty detailEmissionColor = FindProperty("_Detail_Emission_Color", properties, false);
        
        MaterialProperty detailHeightMap = FindProperty("_Detail_Height_Map", properties, false);
        MaterialProperty detailHeightStrength = FindProperty("_Detail_Height_Amplitude", properties, false);
        
        MaterialProperty detailMaskMap = FindProperty("_Detail_Mask_Map", properties, false);
        
        MaterialProperty detailMetallicMap = FindProperty("_Detail_Metallic_Map", properties, false);
        MaterialProperty detailMetallicChannel = FindProperty("_Detail_Metallic_Channel", properties, false);
        MaterialProperty detailMetallicStrength = FindProperty("_Detail_Metallic_Strength", properties, false);
        
        MaterialProperty detailOcclusionMap = FindProperty("_Detail_Occlusion_Map", properties, false);
        MaterialProperty detailOcclusionChannel = FindProperty("_Detail_Occlusion_Channel", properties, false);
        MaterialProperty detailOcclusionStrength = FindProperty("_Detail_Occlusion_Strength", properties, false);
        
        MaterialProperty detailRoughnessMap = FindProperty("_Detail_Roughness_Map", properties, false);
        MaterialProperty detailRoughnessChannel = FindProperty("_Detail_Roughness_Channel", properties, false);
        MaterialProperty detailRoughnessStrength = FindProperty("_Detail_Roughness_Strength", properties, false);
        MaterialProperty invertDetailRoughnessMap = FindProperty("_Invert_Detail_Roughness_Map", properties, false);
        
        MaterialProperty detailTiling = FindProperty("_Detail_Tiling", properties, false);
        MaterialProperty detailOffset = FindProperty("_Detail_Offset", properties, false);
        
        MaterialProperty ssColor = FindProperty("_SS_Color", properties, false);
        MaterialProperty ssThickness = FindProperty("_SS_Thickness", properties, false);
        MaterialProperty ssFalloff = FindProperty("_SS_Falloff", properties, false);
        MaterialProperty ssAmbient = FindProperty("_SS_Ambient", properties, false);
        MaterialProperty ssDistortion = FindProperty("_SS_Distortion", properties, false);
        
        MaterialProperty useSpecularAA = FindProperty(UseSpecularAA, properties, false);
        MaterialProperty useHalfLambert = FindProperty(UseHalfLambert, properties, false);
        MaterialProperty diffuseWrap = FindProperty("_Diffuse_Wrap", properties, false);
        
        #endregion
        
        EditorGUI.BeginChangeCheck();

        DrawSurfaceOptions(materialEditor, surfaceType, blendMode, renderFaceType, alphaClip, clipThreshold, receiveShadows, backfaceNormalMode);

        EditorGUILayout.Space();

        DrawMainSurfaceInputs(materialEditor, materials, albedoMap, albedoColor, albedoContrast, normalMap, normalStrength, emissionMap,
            emissiveColor, heightMap, heightStrength, maskMap, metallicMap, metallicChannel, metallicStrength, occlusionMap, 
            occlusionChannel, occlusionStrength, detailBlendMap, detailBlendChannel, detailBlendOpacity, useVertexColorMask, 
            roughnessMap, roughnessChannel, roughnessStrength, invertRoughnessMap, tiling, offset);

        EditorGUILayout.Space();

        DrawDetailSurfaceInputs(materialEditor, materials, useVertexColorMask, detailAlbedoMap, detailAlbedoColor, detailNormalMap,
            detailNormalStrength, detailEmissionMap, detailEmissionColor, detailHeightMap, detailHeightStrength,
            detailMaskMap, detailMetallicMap, detailMetallicChannel, detailMetallicStrength, detailOcclusionMap, detailOcclusionChannel, 
            detailOcclusionStrength, detailRoughnessMap, detailRoughnessChannel, detailRoughnessStrength, invertDetailRoughnessMap, detailTiling,
            detailOffset);
        DrawSubsurfaceScatteringSettings(materialEditor, materials, ssColor, ssThickness, ssFalloff, ssAmbient, ssDistortion);
        DrawAdvancedOptions(materialEditor, useSpecularAA, useHalfLambert, diffuseWrap);

        EditorGUI.EndChangeCheck();
    }

    private void DrawFeatureGroup(Material[] materials, string title, string keyword, ref bool isExpanded,
        Action drawContents)
    {
        bool isEnabled = materials[0]!.IsKeywordEnabled(keyword);
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.Space(2f);
        EditorGUI.indentLevel++;
        
        Rect controlRect = EditorGUILayout.GetControlRect();
        
        float rightPadding = 15f;
        GUIContent enabledContent = new GUIContent("Enabled");
        float rightLabelWidth = EditorStyles.label.CalcSize(enabledContent).x;
        float toggleWidth = EditorStyles.toggle.CalcSize(GUIContent.none).x;
        float spacing = 5f;
        
        Rect toggleRect = new Rect(controlRect.xMax - toggleWidth, controlRect.y, toggleWidth, controlRect.height);
        Rect rightLabelRect = new Rect(toggleRect.x - spacing - rightLabelWidth, toggleRect.y, rightLabelWidth + rightPadding, toggleRect.height);
        Rect foldoutRect = new Rect(controlRect.x, controlRect.y, rightLabelRect.x - controlRect.x, controlRect.height);
        
        //draw foldout or label depending on if feature is enabled
        if (isEnabled)
        {
            GUIStyle boldFoldout = new(EditorStyles.foldout) { fontStyle = FontStyle.Bold };
            isExpanded = EditorGUI.Foldout(foldoutRect, isExpanded, title, true, boldFoldout);
        }
        else
        {
            EditorGUI.LabelField(foldoutRect, title, EditorStyles.boldLabel);
        }
        
        GUI.Label(rightLabelRect, enabledContent, EditorStyles.boldLabel);
        EditorGUI.BeginChangeCheck();
        
        isEnabled = GUI.Toggle(toggleRect, isEnabled, GUIContent.none, EditorStyles.toggle);
        
        if (EditorGUI.EndChangeCheck())
        {
            foreach (var mat in materials)
            {
                if (isEnabled)
                    mat.EnableKeyword(keyword);
                else
                    mat.DisableKeyword(keyword);
            }
            
            isExpanded = isEnabled;
        }
        
        if (isEnabled && isExpanded)
        {
            EditorGUI.indentLevel++;
            drawContents?.Invoke();
            EditorGUI.indentLevel--;
        }
        
        EditorGUI.indentLevel--;
        EditorGUILayout.Space(2f);
        EditorGUILayout.EndVertical();
    }

    private void DrawChannelSelector(MaterialEditor materialEditor, string label, MaterialProperty channel,
        MaterialProperty strength, MaterialProperty invert = null)
    {
        if (channel == null) return;
        
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.PrefixLabel(label + " Channel");
        
        EditorGUI.BeginChangeCheck();
        
        Vector4 channelVal = channel.vectorValue;
        
        int currentIndex = 0;
        
        if (channelVal.x > 0.5f) currentIndex = 1;
        if (channelVal.y > 0.5f) currentIndex = 2;
        if (channelVal.z > 0.5f) currentIndex = 3;
        if (channelVal.w > 0.5f) currentIndex = 4;
        
        int newIndex = EditorGUILayout.Popup(currentIndex, new[] { "-", "R", "G", "B", "A" });
        
        if (EditorGUI.EndChangeCheck())
        {
            channel.vectorValue = new Vector4(
                newIndex == 1 ? 1 : 0,
                newIndex == 2 ? 1 : 0,
                newIndex == 3 ? 1 : 0,
                newIndex == 4 ? 1 : 0
            );
        }
        
        EditorGUILayout.EndHorizontal();
        EditorGUI.indentLevel++;
        
        if (strength != null && currentIndex != 0)
            materialEditor.ShaderProperty(strength, "Strength");

        if (invert != null)
        {
            EditorGUI.BeginChangeCheck();
            bool invertVal = invert.floatValue > 0.5f;
            invertVal = EditorGUILayout.Toggle("Invert", invertVal);
            if (EditorGUI.EndChangeCheck())
                invert.floatValue = invertVal ? 1f : 0f;
        }
        
        EditorGUI.indentLevel--;
    }
    private static void DrawSurfaceOptions(MaterialEditor materialEditor, MaterialProperty surfaceType,
        MaterialProperty blendMode, MaterialProperty renderFaceType, MaterialProperty alphaClip, 
        MaterialProperty clipThreshold, MaterialProperty receiveShadows, MaterialProperty backfaceNormalMode)
    {
        GUILayout.Label("Surface Options", EditorStyles.boldLabel);
        
        bool surfaceOptionsChanged = false;
        
        if (surfaceType != null)
        {
            EditorGUI.BeginChangeCheck();
            string[] surfaceTypes = { "Opaque", "Transparent" };
            int surfVal = (int)surfaceType.floatValue;
            surfVal = EditorGUILayout.Popup("Surface Type", surfVal, surfaceTypes);
            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Surface Type");
                surfaceType.floatValue = surfVal;
                surfaceOptionsChanged = true;
            }

            //if transparent, draw blend mode
            if (surfVal == 1 && blendMode != null)
            {
                EditorGUI.indentLevel++;
                EditorGUI.BeginChangeCheck();
                string[] blendModes = { "Alpha", "Premultiply", "Additive", "Multiply" };
                int blendVal = (int)blendMode.floatValue;
                blendVal = EditorGUILayout.Popup("Blending Mode", blendVal, blendModes);
                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo("Blending Mode");
                    blendMode.floatValue = blendVal;
                    surfaceOptionsChanged = true;
                }
                EditorGUI.indentLevel--;
            }

            if (surfaceOptionsChanged)
            {
                foreach (var obj in materialEditor.targets)
                {
                    Material mat = obj as Material;
                    if (mat == null) continue;
                    
                    //if opaque
                    if (surfaceType.floatValue == 0)
                    {
                        mat.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Geometry;
                        mat.SetOverrideTag("RenderType", "Opaque");
                        mat.SetInt(SrcBlend, (int)UnityEngine.Rendering.BlendMode.One);
                        mat.SetInt(DstBlend, (int)UnityEngine.Rendering.BlendMode.Zero);
                        mat.SetInt(ZWrite, 1);
                        mat.DisableKeyword("_SURFACE_TYPE_TRANSPARENT_ON");
                    }
                    //if transparent
                    else
                    {
                        mat.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                        mat.SetOverrideTag("RenderType", "Transparent");
                        mat.SetInt(ZWrite, 0);
                        mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT_ON");
                        
                        int blendVal = blendMode != null ? (int)blendMode.floatValue : 0;
                        switch (blendVal)
                        {
                            case 0: //alpha
                                mat.SetInt(SrcBlend, (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                                mat.SetInt(DstBlend, (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                                break;
                            case 1: //premultiply
                                mat.SetInt(SrcBlend, (int)UnityEngine.Rendering.BlendMode.One);
                                mat.SetInt(DstBlend, (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                                break;
                            case 2: //additive
                                mat.SetInt(SrcBlend, (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                                mat.SetInt(DstBlend, (int)UnityEngine.Rendering.BlendMode.One);
                                break;
                            case 3: //multiply
                                mat.SetInt(SrcBlend, (int)UnityEngine.Rendering.BlendMode.DstColor);
                                mat.SetInt(DstBlend, (int)UnityEngine.Rendering.BlendMode.Zero);
                                break;
                        }
                    }
                }
            }
        }

        if (renderFaceType != null)
        {
            EditorGUI.BeginChangeCheck();
            string[] renderFaceTypes = { "Both", "Front", "Back" };
            int val = (int)renderFaceType.floatValue;
            val = EditorGUILayout.Popup("Render Face", val, renderFaceTypes);
            if (EditorGUI.EndChangeCheck())
                renderFaceType.floatValue = val;

            //if rendering both faces and backfaceNormalMode exists
            if (val == 0 && backfaceNormalMode != null)
            {
                EditorGUI.indentLevel++;
                EditorGUI.BeginChangeCheck();
                string[] backfaceNormalModes = { "Flip", "Mirror" };
                int backfaceVal = (int)backfaceNormalMode.floatValue;
                backfaceVal = EditorGUILayout.Popup("Backface Normal Mode", backfaceVal, backfaceNormalModes);
                if (EditorGUI.EndChangeCheck())
                    backfaceNormalMode.floatValue = backfaceVal;
                EditorGUI.indentLevel--;
            }
        }

        if (alphaClip != null)
        {
            EditorGUI.BeginChangeCheck();
            bool isClipping = alphaClip.floatValue > 0.5f;
            isClipping = EditorGUILayout.Toggle("Alpha Clipping", isClipping);
            if (EditorGUI.EndChangeCheck())
                alphaClip.floatValue = isClipping ? 1f : 0f;
            if (isClipping && clipThreshold != null)
            {
                EditorGUI.indentLevel++;
                materialEditor.ShaderProperty(clipThreshold, "Threshold");
                EditorGUI.indentLevel--;
            }
        }

        if (receiveShadows != null)
        {
            EditorGUI.BeginChangeCheck();
            bool isShadows = receiveShadows.floatValue > 0.5f;
            isShadows = EditorGUILayout.Toggle("Receive Shadows", isShadows);
            if (EditorGUI.EndChangeCheck())
                receiveShadows.floatValue = isShadows ? 1f : 0f;
        }
    }

    private void DrawMainSurfaceInputs(MaterialEditor materialEditor, Material[] materials, 
        MaterialProperty albedoMap, MaterialProperty albedoColor, MaterialProperty albedoContrast, 
		MaterialProperty normalMap, MaterialProperty normalStrength, MaterialProperty emissionMap, 
		MaterialProperty emissiveColor, MaterialProperty heightMap, MaterialProperty heightStrength, 
		MaterialProperty maskMap, MaterialProperty metallicMap, MaterialProperty metallicChannel, 
		MaterialProperty metallicStrength, MaterialProperty occlusionMap, MaterialProperty occlusionChannel, 
		MaterialProperty occlusionStrength, MaterialProperty detailBlendMask, MaterialProperty detailBlendChannel, 
		MaterialProperty detailBlendStrength, MaterialProperty useVertexColorMask, MaterialProperty roughnessMap, 
		MaterialProperty roughnessChannel, MaterialProperty roughnessStrength, MaterialProperty invertRoughness, 
		MaterialProperty tiling, MaterialProperty offset)
    {
        GUILayout.Label("Surface Inputs", EditorStyles.boldLabel);
        
        if (albedoMap != null && albedoColor != null)
        {
            GUIContent albedoContent = new GUIContent("Albedo Map", "Albedo map and color");
            materialEditor.TexturePropertySingleLine(albedoContent, albedoMap, albedoColor);

            if (albedoContrast != null)
            {
                EditorGUI.indentLevel += 2;
                materialEditor.ShaderProperty(albedoContrast, "Contrast");
                EditorGUI.indentLevel -= 2;
            }
        }
        if (normalMap != null && normalStrength != null)
        {
            GUIContent normalContent = new GUIContent("Normal Map", "Normal map and strength");
            
            //hide strength slider if no normal map assigned
            if (normalMap.textureValue != null)
                materialEditor.TexturePropertySingleLine(normalContent, normalMap, normalStrength);
            else
                materialEditor.TexturePropertySingleLine(normalContent, normalMap);
                
        }
        if (emissionMap != null && emissiveColor != null)
        {
            GUIContent emissionContent = new GUIContent("Emission Map", "Emission map and color");
            materialEditor.TexturePropertyWithHDRColor(emissionContent, emissionMap, emissiveColor, false);
        }

        if (heightMap != null && heightStrength != null)
        {
            GUIContent heightContent = new GUIContent("Height Map", "Height map and amplitude");
            
            //hide strength slider if no height map assigned
            if (heightMap.textureValue != null)
                materialEditor.TexturePropertySingleLine(heightContent, heightMap, heightStrength);
            else
                materialEditor.TexturePropertySingleLine(heightContent, heightMap);
            
            foreach (Material mat in materials)
            {
                if (mat == null) continue;
            
                if (heightMap.textureValue != null && heightStrength.floatValue > 0f)
                    mat.EnableKeyword(UseHeightmap);
                else
                    mat.DisableKeyword(UseHeightmap);
            }
        }
        
        GUILayout.Label("PBR Maps", EditorStyles.boldLabel);
        if (maskMap != null)
            materialEditor.TexturePropertySingleLine(new GUIContent("Mask Map", "Assign to use a packed texture or leave empty for specific maps"), maskMap);
        
        bool hasBaseMask = maskMap != null && maskMap.textureValue != null;

        foreach (Material mat in materials)
        {
            if (mat == null) continue;
            
            if (hasBaseMask)
                mat.EnableKeyword(UseBaseMaskMap);
            else
                mat.DisableKeyword(UseBaseMaskMap);
        }

        bool usingVertexColorMask = useVertexColorMask != null && useVertexColorMask.floatValue > 0.5f;
        
        if (hasBaseMask)
        {
            EditorGUILayout.BeginVertical();
            
            DrawChannelSelector(materialEditor, "Metallic", metallicChannel, metallicStrength);
            DrawChannelSelector(materialEditor, "Occlusion", occlusionChannel, occlusionStrength);
            
            if (!usingVertexColorMask)
                DrawChannelSelector(materialEditor, "Detail Blend Mask", detailBlendChannel, detailBlendStrength);
            
            DrawChannelSelector(materialEditor, "Roughness", roughnessChannel, roughnessStrength, invertRoughness);
            
            EditorGUILayout.EndVertical();
        }
        else
        {
            EditorGUILayout.BeginVertical();
            
            if (metallicMap != null)
                materialEditor.TexturePropertySingleLine(new GUIContent("Metallic Map", "Metallic map"), metallicMap, metallicStrength);
            if (occlusionMap != null)
                materialEditor.TexturePropertySingleLine(new GUIContent("Occlusion Map", "Occlusion map"), occlusionMap, occlusionStrength);
            if (detailBlendMask != null && !usingVertexColorMask)
                materialEditor.TexturePropertySingleLine(new GUIContent("Detail Blend Mask", "Detail blend mask"), detailBlendMask, detailBlendStrength);
            if (roughnessMap != null)
                materialEditor.TexturePropertySingleLine(new GUIContent("Roughness Map", "Roughness map"), roughnessMap, roughnessStrength);
            if (invertRoughness != null)
                materialEditor.ShaderProperty(invertRoughness, "Invert Roughness");
            
            EditorGUILayout.EndVertical();
        }

        EditorGUILayout.Space();
        
        if (tiling != null && offset != null)
        {
            EditorGUI.BeginChangeCheck();
            
            Vector2 tVal = tiling.vectorValue;
            Vector2 oVal = offset.vectorValue;
            
            tVal = EditorGUILayout.Vector2Field("Tiling", tVal);
            oVal = EditorGUILayout.Vector2Field("Offset", oVal);
            
            if (EditorGUI.EndChangeCheck())
            {
                tiling.vectorValue = new Vector4(tVal.x, tVal.y, 0f, 0f);
                offset.vectorValue = new Vector4(oVal.x, oVal.y, 0f, 0f);;
            }
        }
    }
    private void DrawDetailSurfaceInputs(MaterialEditor materialEditor, Material[] materials, 
        MaterialProperty useVertexColorMask, MaterialProperty detailAlbedoMap, MaterialProperty detailAlbedoColor, 
        MaterialProperty detailNormalMap, MaterialProperty detailNormalStrength, MaterialProperty detailEmissionMap, 
        MaterialProperty detailEmissionColor, MaterialProperty detailHeightMap, MaterialProperty detailHeightStrength, 
        MaterialProperty detailMaskMap, MaterialProperty detailMetallicMap, MaterialProperty detailMetallicChannel, 
        MaterialProperty detailMetallicStrength, MaterialProperty detailOcclusionMap, MaterialProperty detailOcclusionChannel, 
        MaterialProperty detailOcclusionStrength, MaterialProperty detailRoughnessMap, MaterialProperty detailRoughnessChannel,
        MaterialProperty detailRoughnessStrength, MaterialProperty invertDetailRoughness, MaterialProperty detailTiling, 
        MaterialProperty detailOffset)
    {
        DrawFeatureGroup(materials, "Detail", UseDetailMap, ref _expandDetailSettings, () =>
        {
            if (useVertexColorMask != null)
                materialEditor.ShaderProperty(useVertexColorMask, new GUIContent("Use Vertex Color Mask", "Use vertex color mask (R) to blend detail map"));
            if (detailAlbedoMap != null && detailAlbedoColor != null)
                materialEditor.TexturePropertySingleLine(new GUIContent("Albedo Map", "Albedo map (Alpha = Detail Opacity)"), detailAlbedoMap, detailAlbedoColor);
            if (detailNormalMap != null)
            {
                if (detailNormalMap.textureValue != null)
                    materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map", "Normal map"), detailNormalMap, detailNormalStrength);
                else
                    materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map", "Normal map"), detailNormalMap);
            }
            if (detailEmissionMap != null && detailEmissionColor != null)
                materialEditor.TexturePropertyWithHDRColor(new GUIContent("Emission Map", "Emission map"), detailEmissionMap, detailEmissionColor, false);
            if (detailHeightMap != null)
            {
                if (detailHeightMap.textureValue != null)
                    materialEditor.TexturePropertySingleLine(new GUIContent("Height Map", "Height map"), detailHeightMap, detailHeightStrength);
                else
                    materialEditor.TexturePropertySingleLine(new GUIContent("Height Map", "Height map"), detailHeightMap);
                
                foreach (Material mat in materials)
                {
                    if (mat == null) continue;
            
                    if (detailHeightMap.textureValue != null && detailHeightStrength != null && detailHeightStrength.floatValue > 0f)
                        mat.EnableKeyword(UseDetailHeightmap);
                    else
                        mat.DisableKeyword(UseDetailHeightmap);
                }
            }
            
            if (detailMaskMap != null)
                materialEditor.TexturePropertySingleLine(new GUIContent("Mask Map", "Assign to use a packed texture or leave empty for specific maps"), detailMaskMap);
            
            bool hasDetailMask = detailMaskMap != null && detailMaskMap.textureValue != null;

            foreach (Material mat in materials)
            {
                if (mat == null) continue;
                
                if (hasDetailMask)
                    mat.EnableKeyword(UseDetailMaskMap);
                else
                    mat.DisableKeyword(UseDetailMaskMap);
            }

            if (hasDetailMask)
            {
                EditorGUILayout.BeginVertical();
                
                DrawChannelSelector(materialEditor, "Metallic", detailMetallicChannel, detailMetallicStrength);
                DrawChannelSelector(materialEditor, "Occlusion", detailOcclusionChannel, detailOcclusionStrength);
                DrawChannelSelector(materialEditor, "Roughness", detailRoughnessChannel, detailRoughnessStrength, invertDetailRoughness);
                
                EditorGUILayout.EndVertical();
            }
            else
            {
                EditorGUILayout.BeginVertical();
                
                if (detailMetallicMap != null)
                    materialEditor.TexturePropertySingleLine(new GUIContent("Metallic Map", "Metallic map"), detailMetallicMap, detailMetallicStrength);
                if (detailOcclusionMap != null)
                    materialEditor.TexturePropertySingleLine(new GUIContent("Occlusion Map", "Occlusion map"), detailOcclusionMap, detailOcclusionStrength);
                if (detailRoughnessMap != null)
                    materialEditor.TexturePropertySingleLine(new GUIContent("Roughness Map", "Roughness map"), detailRoughnessMap, detailRoughnessStrength);
                if (invertDetailRoughness != null)
                    materialEditor.ShaderProperty(invertDetailRoughness, "Invert Roughness");
                
                EditorGUILayout.EndVertical();
            }
            
            EditorGUILayout.Space();

            if (detailTiling != null && detailOffset != null)
            {
                EditorGUI.BeginChangeCheck();

                Vector2 tVal = detailTiling.vectorValue;
                Vector2 oVal = detailOffset.vectorValue;
                
                tVal = EditorGUILayout.Vector2Field("Tiling", tVal);
                oVal = EditorGUILayout.Vector2Field("Offset", oVal);
                
                if (EditorGUI.EndChangeCheck())
                {
                    detailTiling.vectorValue = new Vector4(tVal.x, tVal.y, 0f, 0f);
                    detailOffset.vectorValue = new Vector4(oVal.x, oVal.y, 0f, 0f);
                }
            }
        });
    }
    
    private void DrawSubsurfaceScatteringSettings(MaterialEditor materialEditor, Material[] materials,
        MaterialProperty ssColor, MaterialProperty ssThickness, MaterialProperty ssFalloff, MaterialProperty ssAmbient,
        MaterialProperty ssDistortion)
    {
        DrawFeatureGroup(materials, "Subsurface Scattering", UseSubsurface, ref _expandSubsurfaceSettings, () =>
        {
            if (ssColor != null)
                materialEditor.ColorProperty(ssColor, "Color");
            if (ssThickness != null)
                materialEditor.ShaderProperty(ssThickness, "Thickness");
            if (ssFalloff != null)
                materialEditor.ShaderProperty(ssFalloff, "Falloff");
            if (ssAmbient != null)
                materialEditor.ShaderProperty(ssAmbient, "Ambient");
            if (ssDistortion != null)
                materialEditor.ShaderProperty(ssDistortion, "Distortion");
        });
    }
    private void DrawAdvancedOptions(MaterialEditor materialEditor, MaterialProperty specularAA, MaterialProperty halfLambert, MaterialProperty diffuseWrap)
    {
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.Space(2f);
        EditorGUI.indentLevel++;

        GUIStyle boldFoldout = new(EditorStyles.foldout) { fontStyle = FontStyle.Bold };
        _expandAdvancedSettings = EditorGUI.Foldout(EditorGUILayout.GetControlRect(), _expandAdvancedSettings, "Advanced Options", true, boldFoldout);

        if (_expandAdvancedSettings)
        {
            if (specularAA != null)
                materialEditor.ShaderProperty(specularAA, "Geometric Specular Anti-Aliasing");

            if (halfLambert != null)
            {
                materialEditor.ShaderProperty(halfLambert, "Half Lambert Shading");

                if (halfLambert.floatValue > 0.5f && diffuseWrap != null)
                {
                    EditorGUI.indentLevel++;
                    materialEditor.ShaderProperty(diffuseWrap, new GUIContent("Diffuse Wrap", "0 = Sharp corners, 1 = Smooth wrapping"));
                    EditorGUI.indentLevel--;
                }
            }

            EditorGUILayout.Space(5f);
            
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
        }
        
        EditorGUI.indentLevel--;
        EditorGUILayout.Space(2f);
        EditorGUILayout.EndVertical();
    }
}
