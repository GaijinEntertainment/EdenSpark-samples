using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Eden
{

public static class ExportPrefabMenu
{
    [MenuItem("Assets/Eden/Export Prefab", validate = true)]
    private static bool ValidatePrefab()
    {
        foreach (var obj in Selection.objects)
            if (obj is GameObject && PrefabUtility.IsPartOfPrefabAsset(obj))
                return true;
        return false;
    }

    [MenuItem("Assets/Eden/Export Prefab")]
    private static void ExportPrefab()
    {
        if (!ExportGlobalConfig.EnsureExportFolderConfigured())
            return;
        foreach (var obj in Selection.objects)
        {
            if (obj is not GameObject || !PrefabUtility.IsPartOfPrefabAsset(obj))
                continue;
            var path = AssetDatabase.GetAssetPath(obj);
            if (string.IsNullOrEmpty(path))
                continue;
            var prefabContents = PrefabUtility.LoadPrefabContents(path);
            try
            {
                Eden.ExportPrefab.DoExportPrefab(prefabContents.transform, path);
            }
            finally
            {
                PrefabUtility.UnloadPrefabContents(prefabContents);
            }
        }
    }

    [MenuItem("Assets/Eden/Export Scene", validate = true)]
    private static bool ValidateScene()
    {
        foreach (var obj in Selection.objects)
            if (obj is SceneAsset)
                return true;
        return false;
    }

    [MenuItem("Assets/Eden/Export Scene")]
    private static void ExportScene()
    {
        if (!ExportGlobalConfig.EnsureExportFolderConfigured())
            return;
        foreach (var obj in Selection.objects)
        {
            if (obj is not SceneAsset)
                continue;
            var path = AssetDatabase.GetAssetPath(obj);
            if (string.IsNullOrEmpty(path))
                continue;

            var loaded = SceneManager.GetSceneByPath(path);
            var openedAdditively = !loaded.isLoaded;
            var scene = openedAdditively
                ? EditorSceneManager.OpenScene(path, OpenSceneMode.Additive)
                : loaded;
            try
            {
                Eden.ExportPrefab.DoExportScene(scene, path);
            }
            finally
            {
                if (openedAdditively)
                    EditorSceneManager.CloseScene(scene, true);
            }
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
