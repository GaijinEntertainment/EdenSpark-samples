using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Eden
{

public enum CollisionDetection : byte
{
  Discrete = 0,
  Continuous = 1,
}


public enum ShapeType : byte
{
    Box = 0,
    Sphere = 1,
    Cylinder = 2, // does not exist in Unity
    Capsule = 3,
    Mesh = 4,
}

public enum MotionType : byte
{
  Dynamic = 0,
  Kinematic = 1,
}

public enum Interpolation : byte
{
  None = 0,
  Interpolate = 1,
  Extrapolate = 2,
}

public class ExportPrefab
{
    public static uint GenNodeUid(System.Random rng)
    {
        var bytes = new byte[4];
        uint val;
        do
        {
            rng.NextBytes(bytes);
            val = BitConverter.ToUInt32(bytes, 0);
        } while (val == 0);
        return val;
    }

    public static void DoExportPrefab(string path)
    {
        var globalCtx = new GlobalPrefabExportContext();
        globalCtx.EnqueuePrefab(path);
        while (globalCtx.pendingPrefabs.Count > 0)
            DoExportPrefabImpl(globalCtx.pendingPrefabs.Dequeue(), globalCtx);
        globalCtx.FlushFiles();
    }

    private static void DoExportPrefabImpl(string path, GlobalPrefabExportContext globalCtx)
    {
        var isScene = path.EndsWith(".unity", StringComparison.OrdinalIgnoreCase);

        Transform[] roots;
        Scene scene = default;
        GameObject prefabContents = null;
        var sceneOpenedAdditively = false;
        if (isScene)
        {
            var loaded = SceneManager.GetSceneByPath(path);
            sceneOpenedAdditively = !loaded.isLoaded;
            scene = sceneOpenedAdditively
                ? EditorSceneManager.OpenScene(path, OpenSceneMode.Additive)
                : loaded;
            roots = Array.ConvertAll(scene.GetRootGameObjects(), go => go.transform);
        }
        else
        {
            prefabContents = PrefabUtility.LoadPrefabContents(path);
            roots = new[] { prefabContents.transform };
        }

        var ctx = new PrefabExportContext
        {
            globalCtx = globalCtx,
            nodeRng = new System.Random(path.GetHashCode()),
        };

        uint parentUid = 0;
        if (isScene)
        {
            parentUid = GenNodeUid(ctx.nodeRng);
            ctx.body.OpenBlock("node");
            ctx.body.AddString("name", Path.GetFileNameWithoutExtension(path));
            ctx.body.AddInt("uid", (int)parentUid);
            ctx.body.CloseBlock(); // node
        }

        foreach (var root in roots)
            ExportTransform(root, ctx, parentUid);

        ctx.globalCtx.AddGeneratedFile(path, ctx.body, AssetFabriqueType.Prefab);

        if (isScene)
        {
            if (sceneOpenedAdditively)
                EditorSceneManager.CloseScene(scene, true);
        }
        else
        {
            PrefabUtility.UnloadPrefabContents(prefabContents);
        }
    }

    static bool FindMeshAsset(PrefabExportContext ctx, Mesh mesh, out string path)
    {
        path = null;
        if (mesh == null)
            return false;
        foreach (var guid in ctx.globalCtx.models)
        {
            var assetPath = AssetDatabase.GUIDToAssetPath(guid);
            GameObject model = AssetDatabase.LoadAssetAtPath<GameObject>(assetPath);
            foreach (MeshFilter filter in model.GetComponentsInChildren<MeshFilter>(true))
            {
                if (filter.sharedMesh == mesh)
                {
                    path = assetPath;
                    return true;
                }
            }
        }
        return false;
    }
    static ulong ExportMaterial(Material mat, PrefabExportContext ctx)
    {
        // TODO: more info export
        if (!mat)
            return 0;
        var matAssetPath = AssetDatabase.GetAssetPath(mat);
        if (string.IsNullOrEmpty(matAssetPath) || matAssetPath.StartsWith("Resources/"))
            return 0;
        var matGuid = AssetDatabase.AssetPathToGUID(matAssetPath);
        if (ctx.TryGetResource(matGuid, out var existingId))
            return existingId;

        var c = mat.HasProperty("_Color") ? mat.color : Color.white;
        var matBlk = new DataBlock();
        matBlk.AddString("shader", "mobile_shader");
        matBlk.OpenBlock("userShader");
        matBlk.CloseBlock(); // userShader
        matBlk.OpenBlock("textures");
        for (int i = 0; i < 6; i++) { matBlk.OpenBlock("it"); matBlk.CloseBlock(); /* it */ }
        matBlk.CloseBlock(); // textures
        matBlk.OpenBlock("properties");
        matBlk.OpenBlock("color");
        matBlk.AddInt("__variant_index", 1);
        matBlk.AddColor("f4", c);
        matBlk.CloseBlock(); // color
        var mainTex = mat.HasProperty("_MainTex") ? mat.mainTexture : null;
        if (mainTex)
        {
            var texAssetPath = AssetDatabase.GetAssetPath(mainTex);
            ctx.globalCtx.copyAssets.Add(texAssetPath);
            var texGuid = AssetDatabase.AssetPathToGUID(texAssetPath);
            ctx.RegisterResourceRef(texGuid, ResourceFabriqueType.Texture);
            matBlk.OpenBlock("diffuse");
            matBlk.AddInt("__variant_index", 5);
            matBlk.AddString("guid", ResourceTools.UnityGuidToEdenGuid(texGuid));
            matBlk.AddInt("type", (int)ResourceFabriqueType.Texture);
            matBlk.CloseBlock(); // diffuse
        }
        matBlk.CloseBlock(); // properties

        ctx.globalCtx.AddGeneratedFile(matAssetPath, matBlk, AssetFabriqueType.Material);
        return ctx.RegisterResourceRef(matGuid, ResourceFabriqueType.Material);
    }

    public static void ExportTransform(Transform tm, PrefabExportContext ctx, uint parentUid)
    {
        // == MAIN INFO
        var uid = GenNodeUid(ctx.nodeRng);
        ctx.transformUids[tm] = uid;
        ctx.body.OpenBlock("node");
        ctx.body.AddString("name", tm.name);
        ctx.body.AddInt("uid", (int)uid);
        var prefabAssetPath = PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(tm.gameObject);
        var isNestedPrefabRoot = !string.IsNullOrEmpty(prefabAssetPath);
        if (isNestedPrefabRoot)
        {
            var prefabGuid = AssetDatabase.AssetPathToGUID(prefabAssetPath);
            var prefabRefId = ctx.RegisterResourceRef(prefabGuid, ResourceFabriqueType.Prefab);
            ctx.body.AddInt64("prefab", prefabRefId);

            if (prefabAssetPath.EndsWith(".prefab", StringComparison.OrdinalIgnoreCase))
            {
                ctx.globalCtx.EnqueuePrefab(prefabAssetPath);
            }
            else
            {
                ctx.globalCtx.copyAssets.Add(prefabAssetPath);
                var modelMeta = new MetaAsset(prefabAssetPath, AssetFabriqueType.Model);
                modelMeta.content.AddFloat("sceneScale", 1);
                ctx.globalCtx.metaAssets.Add(modelMeta);
            }
        }
        if (parentUid != 0)
            ctx.body.AddInt("parent", (int)parentUid);
        if (!tm.gameObject.activeSelf)
            ctx.body.AddBool("active", false);
        var lp = tm.localPosition;
        if (lp != Vector3.zero)
            ctx.body.AddVec3("pos", lp);
        var lr = tm.localRotation;
        if (lr != Quaternion.identity)
            ctx.body.AddQuat("rot", lr);
        var ls = tm.localScale;
        if (ls != Vector3.one)
            ctx.body.AddVec3("scl", ls);

        var tag = tm.tag;
        if (tag != "Untagged")
        {
            ctx.body.OpenBlock("Tag");
            ctx.body.AddString("name", tag);
            ctx.body.CloseBlock(); // Tag
        }


        // COLLIDER

        // TODO: query all collider components
        // TODO: walk tree and collect all colliders
        // TODO: support mesh collider
        var friction = -1f;
        var restitution = -1f;
        var isTrigger = false;

        var boxCollider = tm.GetComponent<BoxCollider>();
        if (boxCollider)
        {
            isTrigger = boxCollider.isTrigger;
            if (boxCollider.material)
            {
                friction = boxCollider.material.dynamicFriction;
                restitution = boxCollider.material.bounciness;
            }
        }

        var sphereCollider = tm.GetComponent<SphereCollider>();
        if (sphereCollider)
        {
            isTrigger = sphereCollider.isTrigger;
            if (sphereCollider.material)
            {
                friction = sphereCollider.material.dynamicFriction;
                restitution = sphereCollider.material.bounciness;
            }
        }

        var capsuleCollider = tm.GetComponent<CapsuleCollider>();
        if (capsuleCollider)
        {
            isTrigger = capsuleCollider.isTrigger;
            if (capsuleCollider.material)
            {
                friction = capsuleCollider.material.dynamicFriction;
                restitution = capsuleCollider.material.bounciness;
            }
        }

        if (boxCollider || sphereCollider || capsuleCollider)
        {
            ctx.body.OpenBlock("Collider");
            ctx.body.AddFloat("friction", friction);
            ctx.body.AddFloat("restitution", restitution);
            ctx.body.AddBool("isSensor", isTrigger);
            ctx.body.AddInt("collisionLayer", 0);
            ctx.body.OpenBlock("shapes");

            void EmitShape(int shapeType, Vector3 translation, Vector3 shapeParams, Quaternion rotation)
            {
                ctx.body.OpenBlock("shape");
                ctx.body.AddInt("shapeType", shapeType);
                ctx.body.AddVec3("translation", translation);
                ctx.body.AddQuat("rotation", rotation);
                ctx.body.AddVec3("params", shapeParams);
                ctx.body.AddInt64("__mesh", 0);
                ctx.body.CloseBlock(); // shape
            }

            if (boxCollider)
                EmitShape((int)ShapeType.Box,
                    boxCollider.center,
                    boxCollider.size,
                    Quaternion.identity);

            if (sphereCollider)
                EmitShape((int)ShapeType.Sphere,
                    sphereCollider.center,
                    new Vector3(sphereCollider.radius, sphereCollider.radius, sphereCollider.radius),
                    Quaternion.identity);

            if (capsuleCollider)
                EmitShape((int)ShapeType.Capsule,
                    capsuleCollider.center,
                    new Vector3(capsuleCollider.height, capsuleCollider.radius, capsuleCollider.direction),
                    Quaternion.identity);

            ctx.body.CloseBlock(); // shapes
            ctx.body.CloseBlock(); // Collider
        }

        var rigidBody = tm.GetComponent<Rigidbody>();
        if (rigidBody)
        {
            ctx.body.OpenBlock("RigidBody");
            ctx.body.AddBool("enabled", true);
            ctx.body.AddFloat("mass", rigidBody.mass);
            ctx.body.AddFloat("linearDamping", rigidBody.linearDamping);
            ctx.body.AddFloat("angularDamping", rigidBody.angularDamping);
            ctx.body.AddBool("useGravity", rigidBody.useGravity);
            var motionType = rigidBody.isKinematic ? MotionType.Kinematic : MotionType.Dynamic;
            ctx.body.AddInt("motionType", (int)motionType);
            var collisionMode = rigidBody.collisionDetectionMode == CollisionDetectionMode.Discrete ? CollisionDetection.Discrete : CollisionDetection.Continuous;
            ctx.body.AddInt("collisionDetection", (int)collisionMode);
            var c = rigidBody.constraints;
            int dofs = 0;
            if ((c & RigidbodyConstraints.FreezePositionX) == 0) dofs |= 1;  // AllowTranslationX
            if ((c & RigidbodyConstraints.FreezePositionY) == 0) dofs |= 2;  // AllowTranslationY
            if ((c & RigidbodyConstraints.FreezePositionZ) == 0) dofs |= 4;  // AllowTranslationZ
            if ((c & RigidbodyConstraints.FreezeRotationX) == 0) dofs |= 8;  // AllowRotationX
            if ((c & RigidbodyConstraints.FreezeRotationY) == 0) dofs |= 16; // AllowRotationY
            if ((c & RigidbodyConstraints.FreezeRotationZ) == 0) dofs |= 32; // AllowRotationZ
            ctx.body.AddInt("allowedDofs", dofs);
            ctx.body.AddFloat("maxVelocity", rigidBody.maxLinearVelocity);
            ctx.body.AddFloat("maxAngularVelocity", rigidBody.maxAngularVelocity);
            var interpolation = rigidBody.interpolation switch
            {
                RigidbodyInterpolation.None        => Interpolation.None,
                RigidbodyInterpolation.Interpolate => Interpolation.Interpolate,
                RigidbodyInterpolation.Extrapolate => Interpolation.Extrapolate,
                _                                  => Interpolation.None,
            };
            ctx.body.AddInt("interpolation", (int)interpolation);
            ctx.body.CloseBlock(); // RigidBody

        }


        // MESH
        var renderer = tm.GetComponent<MeshRenderer>();
        var mesh = tm.GetComponent<MeshFilter>();
        if (renderer && mesh)
        {
            int RendererVisibility(MeshRenderer r)
            {
                const int AllCameras            = 0x00FF; // Camera0..Camera7
                const int EditorCamera          = 1 << 8;
                const int CastShadowsFromSun    = 1 << 9;
                const int CastShadowsFromLights = 1 << 10;

                return r.shadowCastingMode switch
                {
                    ShadowCastingMode.Off         => AllCameras | EditorCamera,
                    ShadowCastingMode.ShadowsOnly => CastShadowsFromSun | CastShadowsFromLights,
                    _                             => AllCameras | EditorCamera | CastShadowsFromSun | CastShadowsFromLights,
                };
            }

            var meshData = mesh.sharedMesh;
            ulong meshId = 0;
            if (FindMeshAsset(ctx, meshData, out var path))
            {
                ctx.globalCtx.copyAssets.Add(path);

                var guid = AssetDatabase.AssetPathToGUID(path);
                meshId = ctx.RegisterResourceRef(guid, ResourceFabriqueType.Mesh, meshData.name);

                var meshMeta = new MetaAsset(path, AssetFabriqueType.Model);
                meshMeta.content.AddFloat("sceneScale", 1);
                ctx.globalCtx.metaAssets.Add(meshMeta);
            }
            else if (meshData != null)
            {
                switch (meshData.name)
                {
                    case "Cube":
                        meshId = ctx.RegisterResourceRefByEdenGuid("0193c180-91e6-7806-87dd-19e8d41cd80f", ResourceFabriqueType.Mesh);
                        break;
                    default:
                        break;
                }
            }

            var materialId = ExportMaterial(renderer.sharedMaterial, ctx);

            ctx.body.OpenBlock("Mesh");
            ctx.body.AddInt64("__meshId", meshId);
            ctx.body.AddInt64("__materialId", materialId);
            ctx.body.AddInt("visibility", RendererVisibility(renderer));
            ctx.body.AddBool("isStatic", false);
            ctx.body.CloseBlock(); // Mesh
        }

        ctx.body.CloseBlock(); // node

        ctx.EmitAccumulatedRefLinks();

        if (!isNestedPrefabRoot)
        {
            foreach (Transform child in tm)
            {
                ExportTransform(child, ctx, uid);
            }
        }
    }
}

}
