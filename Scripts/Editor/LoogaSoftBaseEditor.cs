using UnityEditor;
using UnityEngine;

namespace LoogaSoft.Lighting.Editor
{
    public class LoogaSoftBaseEditor : UnityEditor.Editor
    {
        protected void DrawLoogaSoftHeader()
        {
            GUIStyle titleStyle = new GUIStyle()
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 12,
                normal = { textColor = new Color(0.5f, 0.5f, 0.5f) }
            };
            
            EditorGUILayout.Space(3);
            
            GUILayout.Label("-  LoogaSoft  -", titleStyle);
            
            EditorGUILayout.Space(3);
        }
    }
}