using UnityEditor;
using UnityEngine;

namespace Eden
{

public static class ExportPrefabMenu
{
    private static bool IsExportable(Object obj) =>
        obj is SceneAsset || (obj is GameObject go && PrefabUtility.IsPartOfPrefabAsset(go));

    [MenuItem("Assets/Eden/Export", validate = true)]
    private static bool ValidateExport()
    {
        foreach (var obj in Selection.objects)
            if (IsExportable(obj))
                return true;
        return false;
    }

    [MenuItem("Assets/Eden/Export")]
    private static void Export()
    {
        if (!ExportGlobalConfig.EnsureExportFolderConfigured())
            return;
        foreach (var obj in Selection.objects)
        {
            if (!IsExportable(obj))
                continue;
            var path = AssetDatabase.GetAssetPath(obj);
            if (string.IsNullOrEmpty(path))
                continue;
            Eden.ExportPrefab.DoExportPrefab(path);
        }
    }

    [MenuItem("Assets/Eden/Configure Export...")]
    private static void ConfigureExport()
    {
        SettingsService.OpenProjectSettings("Project/EdenSpark Converter");
    }

    [MenuItem("Assets/Eden/Open Export Folder")]
    private static void OpenExportFolder() => ExportGlobalConfig.RevealExportFolder();
}

}
