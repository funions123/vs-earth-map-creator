using HarmonyLib;
using Vintagestory.API.Common;
using Vintagestory.API.Datastructures;
using Vintagestory.API.Server;
using Vintagestory.ServerMods;

namespace EarthMapCreator.Patches;

public class EarthMapPatches : ModSystem
{
    private Harmony _patcher;

    public override void StartServerSide(ICoreServerAPI api)
    {
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
    [HarmonyPrefix()]
    [HarmonyPatch(typeof(GenTerra), "OnChunkColumnGen")]
    public static bool IgnoreVanillaGeneration(GenTerra __instance, IChunkColumnGenerateRequest request)
    {
        return false;
    }

    [HarmonyPostfix()]
    [HarmonyPatch(typeof(GenMaps), "OnMapRegionGen")]
    public static void After_OnMapRegionGen(GenMaps __instance, IMapRegion mapRegion, int regionX, int regionZ, ITreeAttribute chunkGenParams)
    {
        Climate.Event_After_OnMapRegionGen(mapRegion, regionX, regionZ, chunkGenParams);
    }
    
    [HarmonyPrefix()]
    [HarmonyPatch(typeof(GenBlockLayers), "GenBeach")]
    public static bool IgnoreVanillaGeneration(GenBlockLayers __instance)
    {
        return false;
    }
}