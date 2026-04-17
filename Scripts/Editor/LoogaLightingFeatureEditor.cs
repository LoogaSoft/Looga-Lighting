using UnityEditor;

namespace LoogaSoft.Lighting.Editor
{
    [CustomEditor(typeof(LoogaLightingFeature))]
    public class LoogaLightingFeatureEditor : LoogaSoftBaseEditor
    {
        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            
            DrawLoogaSoftHeader();
            
            EditorGUILayout.PropertyField(serializedObject.FindProperty("activeLightingModel"));

            serializedObject.ApplyModifiedProperties();
        }
    }
}