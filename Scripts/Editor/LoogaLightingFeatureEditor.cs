using UnityEditor;
using UnityEngine;

namespace LoogaSoft.Lighting.Editor
{
    [CustomEditor(typeof(LoogaLightingFeature))]
    public class LoogaLightingFeatureEditor : LoogaSoftBaseEditor
    {
        private SerializedProperty _activeLightingModel;
        private SerializedProperty _useGTBN;
        private SerializedProperty _gtbnSettings;
        
        // Shader properties for diagnostics
        private SerializedProperty _customLightingShader;
        private SerializedProperty _gtbnApplyShader;
        private SerializedProperty _gtbnCompute;
        private SerializedProperty _gtbnBlurCompute;

        private bool _showDebugFoldout = true;
        
        private void OnEnable()
        {
            _activeLightingModel = serializedObject.FindProperty("activeLightingModel");
            _useGTBN = serializedObject.FindProperty("useGTBN");
            _gtbnSettings = serializedObject.FindProperty("gtbnSettings");

            _customLightingShader = serializedObject.FindProperty("_customLightingShader");
            _gtbnApplyShader = serializedObject.FindProperty("gtbnApplyShader");
            _gtbnCompute = serializedObject.FindProperty("gtbnCompute");
            _gtbnBlurCompute = serializedObject.FindProperty("gtbnBlurCompute");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            
            DrawLoogaSoftHeader();
            
            EditorGUILayout.PropertyField(_activeLightingModel);
            EditorGUILayout.PropertyField(_useGTBN, new GUIContent("Use Ground Truth Bent Normals"));

            if (_useGTBN.boolValue)
            {
                EditorGUI.indentLevel++;

                _gtbnSettings.isExpanded = true;
                
                SerializedProperty iterator = _gtbnSettings.Copy();
                SerializedProperty endProperty = iterator.GetEndProperty();

                if (iterator.NextVisible(true))
                {
                    do
                    {
                        if (SerializedProperty.EqualContents(iterator, endProperty))
                            break;
                        
                        EditorGUILayout.PropertyField(iterator);
                    } 
                    while (iterator.NextVisible(false));
                }
                
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space();

            // Shader Diagnostics Foldout
            GUIStyle foldoutStyle = new GUIStyle(EditorStyles.foldout) { fontStyle = FontStyle.Normal };
            Color originalColor = GUI.color;
            GUI.color = new Color(originalColor.r, originalColor.g, originalColor.b, 0.5f);
            
            _showDebugFoldout = EditorGUILayout.Foldout(_showDebugFoldout, "Debug", true, foldoutStyle);

            if (_showDebugFoldout)
            {
                EditorGUILayout.BeginVertical(EditorStyles.helpBox);

                DrawShaderStatus("Looga Lighting (HLSL)", _customLightingShader.objectReferenceValue);
                DrawShaderStatus("GTBN Apply (HLSL)", _gtbnApplyShader.objectReferenceValue);
                DrawShaderStatus("GTBN Generation (Compute)", _gtbnCompute.objectReferenceValue);
                DrawShaderStatus("GTBN Blur (Compute)", _gtbnBlurCompute.objectReferenceValue);

                EditorGUILayout.EndVertical();
            }
            
            GUI.color = originalColor;
            
            serializedObject.ApplyModifiedProperties();
        }

        private void DrawShaderStatus(string label, Object shaderObj)
        {
            EditorGUILayout.BeginHorizontal();
            GUILayout.Label(label, GUILayout.Width(175));

            GUIStyle statusStyle = new GUIStyle(EditorStyles.label) { richText = true };
            if (shaderObj != null)
            {
                GUILayout.Label("<color=#2ecc71><b>✔ OK</b></color>", statusStyle);
            }
            else
            {
                GUILayout.Label("<color=#e74c3c><b>✘ Missing</b></color>", statusStyle);
            }
            EditorGUILayout.EndHorizontal();
        }
    }
}