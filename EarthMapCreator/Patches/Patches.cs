using System;
using HarmonyLib;
using Vintagestory.API.Common;
using Vintagestory.API.Datastructures;
using Vintagestory.API.Server;
using Vintagestory.ServerMods;

namespace EarthMapCreator.Patches;

public class EarthMapPatches : ModSystem
{
    private Harmony _patcher;
    
    public static ICoreServerAPI _api; 

    public override void StartServerSide(ICoreServerAPI api)
    {
        _api = api;
        
        _patcher = new Harmony(Mod.Info.ModID);
        _patcher.PatchCategory(Mod.Info.ModID);
    }
    
    public override void AssetsFinalize(ICoreAPI api)
    {
        if (api.Side != EnumAppSide.Server)
        {
            return;
        }
    }

    public override void Dispose()
    {
        _patcher?.UnpatchAll(Mod.Info.ModID);
    }
}

[HarmonyPatchCategory("earthmapcreator")]
internal static class Patches
{
    [HarmonyPrefix]
    [HarmonyPatch(typeof(GenTerra), "OnChunkColumnGen", new Type[] { typeof(IChunkColumnGenerateRequest) })]
    public static bool OnChunkColumnGen_Prefix(GenTerra __instance, IChunkColumnGenerateRequest request)
    {
        return false;
    }
    
    [HarmonyPrefix]
    [HarmonyPatch(typeof(GenMaps), "GetClimateMapGen")]
    public static bool GetClimateMapGen_Prefix(long seed, NoiseClimate climateNoise, ref MapLayerBase __result)
    {
        var sapi = EarthMapPatches._api;
        if (sapi == null) return true; 

        sapi.Logger.Notification("[EarthMapCreator] Harmony patch triggered: Overwriting GetClimateMapGen.");

        __result = new MapLayerFromImage(seed, EarthMapCreator.Layers.ClimateMap.IntValues, sapi, TerraGenConfig.climateMapScale, Climate.ClimatePostProcess);
        
        return false; // Skip the original method
    }
    
    [HarmonyPrefix]
    [HarmonyPatch(typeof(GenMaps), "GetForestMapGen")]
    public static bool GetForestMapGen_Prefix(long seed, int scale, ref MapLayerBase __result)
    {
        var sapi = EarthMapPatches._api;
        if (sapi == null) return true; 

        sapi.Logger.Notification("[EarthMapCreator] Harmony patch triggered: Overwriting GetForestMapGen.");

        __result = new MapLayerFromImage(seed, EarthMapCreator.Layers.TreeMap.IntValues, sapi, TerraGenConfig.forestMapScale, Climate.ForestPostProcess);
        
        return false; // Skip the original method
    }
    
    [HarmonyPrefix]
    [HarmonyPatch(typeof(GenBlockLayers), "GenBeach", new Type[] { typeof(int), typeof(int), typeof(int), typeof(IServerChunk[]), typeof(float), typeof(float), typeof(float), typeof(int) })]
    public static bool GenBeach_Prefix(GenBlockLayers __instance, int x, int posY, int z, IServerChunk[] chunks, float rainRel, float temp, float beachRel, int topRockId)
    {
        return false;
    }
}