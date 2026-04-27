using UnityEditor;
using UnityEngine;

namespace LoogaSoft.LightingPrime.Editor
{
    public class LoogaGlassShaderGUI : LoogaShaderGUIBase
    {
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            Styles();
            DrawLoogaSoftHeader();

            MaterialProperty baseMap = FindProperty("_BaseMap", properties);
            MaterialProperty baseColor = FindProperty("_BaseColor", properties);
            MaterialProperty normalMap = FindProperty("_NormalMap", properties);
            
            MaterialProperty useMaskMap = FindProperty("_UseMaskMap", properties);
            MaterialProperty maskMap = FindProperty("_MaskMap", properties);
            
            MaterialProperty metallicMap = FindProperty("_MetallicMap", properties);
            MaterialProperty metallic = FindProperty("_Metallic", properties);
            MaterialProperty occlusionMap = FindProperty("_OcclusionMap", properties);
            MaterialProperty occlusionStrength = FindProperty("_OcclusionStrength", properties);
            
            MaterialProperty smoothnessSource = FindProperty("_SmoothnessTextureChannel", properties);
            MaterialProperty smoothness = FindProperty("_Smoothness", properties);
            
            MaterialProperty distortion = FindProperty("_Distortion", properties);
            
            MaterialProperty specHighlights = FindProperty("_SpecularHighlights", properties, false);
            MaterialProperty envReflections = FindProperty("_EnvironmentReflections", properties, false);

            Section("Surface Options", "LoogaGlass_SurfaceOptions", true, () =>
            {
                materialEditor.TexturePropertySingleLine(new GUIContent("Dirt Map (RGB) Opacity (A)"), baseMap, baseColor);
                EditorGUILayout.Space(2);
                materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map"), normalMap);
                EditorGUILayout.Space(2);
                
                // Mask Map Toggle Logic (Matching the Skin Shader)
                materialEditor.ShaderProperty(useMaskMap, "Use Mask Map");
                
                if (useMaskMap.floatValue > 0.5f)
                {
                    materialEditor.TexturePropertySingleLine(new GUIContent("Mask Map (M, AO, S)"), maskMap);
                    EditorGUI.indentLevel += 2;
                    materialEditor.ShaderProperty(smoothness, new GUIContent("Master Smoothness"));
                    EditorGUI.indentLevel -= 2;
                }
                else
                {
                    materialEditor.TexturePropertySingleLine(new GUIContent("Metallic Map"), metallicMap, metallic);
                    EditorGUI.indentLevel += 2;
                    materialEditor.ShaderProperty(smoothness, new GUIContent("Master Smoothness"));
                    materialEditor.ShaderProperty(smoothnessSource, new GUIContent("Source"));
                    EditorGUI.indentLevel -= 2;
                    
                    materialEditor.TexturePropertySingleLine(new GUIContent("Occlusion Map"), occlusionMap, occlusionStrength);
                }

                EditorGUILayout.Space();
                materialEditor.TextureScaleOffsetProperty(baseMap);
            });

            Section("Optical Properties", "LoogaGlass_OpticalProperties", true, () =>
            {
                materialEditor.ShaderProperty(distortion, "Refraction Index (IOR)");
            });

            Section("Advanced Options", "LoogaGlass_AdvancedOptions", false, () =>
            {
                if (specHighlights != null) materialEditor.ShaderProperty(specHighlights, "Specular Highlights");
                if (envReflections != null) materialEditor.ShaderProperty(envReflections, "Environment Reflections");
                materialEditor.EnableInstancingField();
                materialEditor.RenderQueueField();
            });
        }
    }
}