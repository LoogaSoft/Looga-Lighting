using UnityEditor;

namespace LoogaSoft.Lighting.Editor
{
    [CustomEditor(typeof(LoogaGTBNFeature))]
    public class LoogaGTBNFeatureEditor : LoogaSoftBaseEditor
    {
        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            
            DrawLoogaSoftHeader();

            SerializedProperty iterator = serializedObject.GetIterator();
            bool enterChildren = true;
            
            while (iterator.NextVisible(enterChildren))
            {
                enterChildren = false;
                // m_Script is the uneditable default script reference, we hide it for a cleaner UI
                if (iterator.name != "m_Script") 
                {
                    EditorGUILayout.PropertyField(iterator, true);
                }
            }
            
            serializedObject.ApplyModifiedProperties();
        }
    }
}