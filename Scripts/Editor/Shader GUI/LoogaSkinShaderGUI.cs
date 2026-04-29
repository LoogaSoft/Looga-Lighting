using UnityEditor;
using UnityEngine;

namespace LoogaSoft.LightingPrime.Editor
{
    public class LoogaSkinShaderGUI : LoogaShaderGUIBase
    {
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            Styles();
            DrawLoogaSoftHeader();

            MaterialProperty baseMap = FindProperty("_BaseMap", properties);
            MaterialProperty baseColor = FindProperty("_BaseColor", properties);
            MaterialProperty normalMap = FindProperty("_BumpMap", properties);
            MaterialProperty normalScale = FindProperty("_BumpScale", properties);
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
            
            MaterialProperty cavityMap = FindProperty("_CavityMap", properties);
            MaterialProperty lobeMix = FindProperty("_LobeMix", properties);
            MaterialProperty secondarySmoothness = FindProperty("_SecondarySmoothness", properties);
            
            // NEW SSSS Properties
            MaterialProperty useSSSS = FindProperty("_UseSSSS", properties);
            MaterialProperty ssssColor = FindProperty("_SubsurfaceColor", properties);
            MaterialProperty ssssWidth = FindProperty("_ScatterWidth", properties);
            MaterialProperty thicknessMap = FindProperty("_ThicknessMap", properties);
            MaterialProperty transmissionStrength = FindProperty("_TransmissionStrength", properties);
            
            MaterialProperty specHighlights = FindProperty("_SpecularHighlights", properties, false);
            MaterialProperty envReflections = FindProperty("_EnvironmentReflections", properties, false);

            DrawSurfaceOptionsSection(materialEditor, properties, "LoogaSkin_SurfaceOptions");

            Section("Surface Inputs", "LoogaSkin_SurfaceInputs", true, () =>
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
                DrawEmissionToggle(materialEditor, emissionMap, emissionColor, "_EMISSION", "Emission Map");
                EditorGUILayout.Space();
                materialEditor.TextureScaleOffsetProperty(baseMap);
            });

            Section("Dual Lobe Specular", "LoogaSkin_DualLobe", true, () =>
            {
                materialEditor.TexturePropertySingleLine(new GUIContent("Cavity/Lobe Mask (R)"), cavityMap, lobeMix);
                EditorGUI.indentLevel += 2;
                materialEditor.ShaderProperty(secondarySmoothness, new GUIContent("Secondary Smoothness"));
                EditorGUI.indentLevel -= 2;
            });
            
            Section("Subsurface Scattering", "LoogaSkin_SubsurfaceScattering", true, () =>
            {
                materialEditor.ShaderProperty(useSSSS, "Enable Subsurface Scattering");
                materialEditor.ShaderProperty(ssssColor, "Subsurface Color");
                materialEditor.ShaderProperty(ssssWidth, "Scatter Width");
                EditorGUILayout.Space(2);
                materialEditor.TexturePropertySingleLine(new GUIContent("Thickness Map (Black=Glow)"), thicknessMap);
                materialEditor.ShaderProperty(transmissionStrength, "Transmission Strength");
            });

            Section("Advanced Options", "LoogaSkin_AdvancedOptions", false, () =>
            {
                if (specHighlights != null) materialEditor.ShaderProperty(specHighlights, "Specular Highlights");
                if (envReflections != null) materialEditor.ShaderProperty(envReflections, "Environment Reflections");
                materialEditor.EnableInstancingField();
                materialEditor.RenderQueueField();
            });
        }
    }
}
