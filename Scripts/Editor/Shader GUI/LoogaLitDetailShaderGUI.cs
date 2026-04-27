using UnityEditor;
using UnityEngine;

namespace LoogaSoft.LightingPrime.Editor
{
    public class LoogaLitDetailShaderGUI : LoogaShaderGUIBase
    {
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            Styles();
            DrawLoogaSoftHeader();

            MaterialProperty baseMap = FindProperty("_BaseMap", properties);
            MaterialProperty baseColor = FindProperty("_BaseColor", properties);
            MaterialProperty normalMap = FindProperty("_NormalMap", properties);
            MaterialProperty normalScale = FindProperty("_NormalScale", properties);
            MaterialProperty useMaskMap = FindProperty("_UseMaskMap", properties);
            MaterialProperty maskMap = FindProperty("_MaskMap", properties);
            MaterialProperty metallicMap = FindProperty("_MetallicMap", properties);
            MaterialProperty metallic = FindProperty("_Metallic", properties);
            MaterialProperty occlusionMap = FindProperty("_OcclusionMap", properties);
            MaterialProperty occlusionStrength = FindProperty("_OcclusionStrength", properties);
            MaterialProperty emissionMap = FindProperty("_EmissionMap", properties);
            MaterialProperty emissionColor = FindProperty("_EmissionColor", properties);
            MaterialProperty smoothnessSource = FindProperty("_SmoothnessTextureChannel", properties);
            MaterialProperty baseSmoothness = FindProperty("_BaseSmoothnessScale", properties);
            
            MaterialProperty detailBlendMap = FindProperty("_DetailBlendMap", properties);
            MaterialProperty detailBlendStrength = FindProperty("_DetailBlendStrength", properties);
            MaterialProperty detailBaseMap = FindProperty("_DetailBaseMap", properties);
            MaterialProperty detailBaseColor = FindProperty("_DetailBaseColor", properties);
            MaterialProperty detailNormalMap = FindProperty("_DetailNormalMap", properties);
            MaterialProperty detailNormalScale = FindProperty("_DetailNormalScale", properties);
            MaterialProperty useDetailMaskMap = FindProperty("_UseDetailMaskMap", properties);
            MaterialProperty detailMaskMap = FindProperty("_DetailMaskMap", properties);
            MaterialProperty detailMetallicMap = FindProperty("_DetailMetallicMap", properties);
            MaterialProperty detailMetallic = FindProperty("_DetailMetallic", properties);
            MaterialProperty detailOcclusionMap = FindProperty("_DetailOcclusionMap", properties);
            MaterialProperty detailOcclusionStrength = FindProperty("_DetailOcclusionStrength", properties);
            MaterialProperty detailEmissionMap = FindProperty("_DetailEmissionMap", properties);
            MaterialProperty detailEmissionColor = FindProperty("_DetailEmissionColor", properties);
            MaterialProperty detailSmoothnessSource = FindProperty("_DetailSmoothnessTextureChannel", properties);
            MaterialProperty detailBaseSmoothness = FindProperty("_DetailBaseSmoothnessScale", properties);
            
            // NEW SSSS Properties
            MaterialProperty useSSSS = FindProperty("_UseSSSS", properties);
            MaterialProperty ssssColor = FindProperty("_SubsurfaceColor", properties);
            MaterialProperty ssssWidth = FindProperty("_ScatterWidth", properties);
            MaterialProperty thicknessMap = FindProperty("_ThicknessMap", properties);
            MaterialProperty transmissionStrength = FindProperty("_TransmissionStrength", properties);
            
            MaterialProperty specHighlights = FindProperty("_SpecularHighlights", properties, false);
            MaterialProperty envReflections = FindProperty("_EnvironmentReflections", properties, false);

            Section("Surface Options", "LoogaLitDetail_Surface", true, () =>
            {
                materialEditor.TexturePropertySingleLine(new GUIContent("Base Map"), baseMap, baseColor);
                materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map"), normalMap, normalScale);
                EditorGUILayout.Space(2);
                materialEditor.ShaderProperty(useMaskMap, "Use Mask Map");
                
                if (useMaskMap.floatValue > 0.5f)
                {
                    materialEditor.TexturePropertySingleLine(new GUIContent("Mask Map (M, AO, S)"), maskMap);
                    EditorGUI.indentLevel += 2;
                    materialEditor.ShaderProperty(baseSmoothness, new GUIContent("Master Smoothness"));
                    EditorGUI.indentLevel -= 2;
                }
                else
                {
                    materialEditor.TexturePropertySingleLine(new GUIContent("Metallic Map"), metallicMap, metallic);
                    EditorGUI.indentLevel += 2;
                    materialEditor.ShaderProperty(baseSmoothness, new GUIContent("Master Smoothness"));
                    materialEditor.ShaderProperty(smoothnessSource, new GUIContent("Source"));
                    EditorGUI.indentLevel -= 2;
                    materialEditor.TexturePropertySingleLine(new GUIContent("Occlusion Map"), occlusionMap, occlusionStrength);
                }
                
                EditorGUILayout.Space(2);
                materialEditor.TexturePropertySingleLine(new GUIContent("Emission Map"), emissionMap, emissionColor);
                EditorGUILayout.Space();
                materialEditor.TextureScaleOffsetProperty(baseMap);
            });

            Section("Detail Options", "LoogaLitDetail_Detail", true, () =>
            {
                materialEditor.TexturePropertySingleLine(new GUIContent("Blend Mask (R)"), detailBlendMap, detailBlendStrength);
                EditorGUILayout.Space(4);
                GUILayout.Label("Detail Textures", EditorStyles.boldLabel);
                materialEditor.TexturePropertySingleLine(new GUIContent("Detail Base Map"), detailBaseMap, detailBaseColor);
                materialEditor.TexturePropertySingleLine(new GUIContent("Detail Normal Map"), detailNormalMap, detailNormalScale);
                EditorGUILayout.Space(2);
                materialEditor.ShaderProperty(useDetailMaskMap, "Use Detail Mask Map");
                
                if (useDetailMaskMap.floatValue > 0.5f)
                {
                    materialEditor.TexturePropertySingleLine(new GUIContent("Detail Mask Map (M, AO, S)"), detailMaskMap);
                    EditorGUI.indentLevel += 2;
                    materialEditor.ShaderProperty(detailBaseSmoothness, new GUIContent("Master Smoothness"));
                    EditorGUI.indentLevel -= 2;
                }
                else
                {
                    materialEditor.TexturePropertySingleLine(new GUIContent("Detail Metallic Map"), detailMetallicMap, detailMetallic);
                    EditorGUI.indentLevel += 2;
                    materialEditor.ShaderProperty(detailBaseSmoothness, new GUIContent("Master Smoothness"));
                    materialEditor.ShaderProperty(detailSmoothnessSource, new GUIContent("Source"));
                    EditorGUI.indentLevel -= 2;
                    materialEditor.TexturePropertySingleLine(new GUIContent("Detail Occlusion Map"), detailOcclusionMap, detailOcclusionStrength);
                }
                
                EditorGUILayout.Space(2);
                materialEditor.TexturePropertySingleLine(new GUIContent("Detail Emission Map"), detailEmissionMap, detailEmissionColor);
                EditorGUILayout.Space();
                materialEditor.TextureScaleOffsetProperty(detailBaseMap);
            });
            
            Section("Subsurface Scattering", "LoogaLitDetail_SSSS", true, () =>
            {
                materialEditor.ShaderProperty(useSSSS, "Enable Subsurface Scattering");
                materialEditor.ShaderProperty(ssssColor, "Subsurface Color");
                materialEditor.ShaderProperty(ssssWidth, "Scatter Width");
                EditorGUILayout.Space(2);
                materialEditor.TexturePropertySingleLine(new GUIContent("Thickness Map (Black=Glow)"), thicknessMap);
                materialEditor.ShaderProperty(transmissionStrength, "Transmission Strength");
            });

            Section("Advanced Options", "LoogaLitDetail_Advanced", false, () =>
            {
                if (specHighlights != null) materialEditor.ShaderProperty(specHighlights, "Specular Highlights");
                if (envReflections != null) materialEditor.ShaderProperty(envReflections, "Environment Reflections");
                materialEditor.EnableInstancingField();
                materialEditor.RenderQueueField();
            });
        }
    }
}