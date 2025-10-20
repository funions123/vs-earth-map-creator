using System;
using SixLabors.ImageSharp.PixelFormats;
using Vintagestory.API.Common;
using Vintagestory.API.Datastructures;
using Vintagestory.API.Server;

namespace EarthMapCreator;

public class Climate : ModSystem
{
    private const int RegionSize = 512;
    private ICoreServerAPI _api;
    
    public override void StartServerSide(ICoreServerAPI api)
    {
        _api = api;
        //api.Event.MapRegionGeneration(Event_After_OnMapRegionGen, "standard");
    }

    public static void Event_After_OnMapRegionGen(IMapRegion region, int rx, int rz, ITreeAttribute attribute = null)
    {
        if (!EarthWorldGenerator.GeneratingRegions.Exists(it => it.X == rx && it.Y == rz))
        {
            return;
        }

        Console.WriteLine("Modifying map data for region: " + rx + ", " + rz + " " + region.ClimateMap.Size);
        region.ClimateMap.Data = GenLayer(EarthMapCreator.Layers.ClimateMap, rx, rz, region.ClimateMap.Size, region.ClimateMap.Size, RegionSize / region.ClimateMap.Size, _climatePostProcess);
        region.ForestMap.Data = GenLayer(EarthMapCreator.Layers.TreeMap, rx, rz, region.ForestMap.Size, region.ForestMap.Size, RegionSize / region.ForestMap.Size, _forestPostProcess);
    }

    private static int[] GenLayer(DataMap<Rgb24> bmp, int xCoord, int zCoord, int sizeX, int sizeZ, int scale, System.Func<int, int> consumer)
    {
        // padding
        // |xx|16 chunks|xx|
        
        // 512 / 20 -> 25
        IntDataMap2D data = bmp.IntValues[xCoord][zCoord];
        
        int[] result = new int[sizeX * sizeZ];

        for (int x = 0; x < sizeX; x++)
        {
            for (int z = 0; z < sizeZ; z++)
            {
                result[z * sizeX + x] = consumer.Invoke(data.GetInt(x * scale, z * scale));
            }
        }

        return result;
    }

    private static System.Func<int, int> _climatePostProcess = (val) =>
    {
        // red -> temp
        // green -> rain
        byte red = (byte)((val >> 16) & 0xFF);
        byte green = (byte)((val >> 8) & 0xFF);

        red += EarthMapCreator.config.TemperatureAdd;
        green += EarthMapCreator.config.PrecipitationAdd;

        red = (byte)(EarthMapCreator.config.TemperatureMulti * red);
        green = (byte)(EarthMapCreator.config.PrecipitationMulti * green);

        int rgb = red;
        rgb = (rgb << 8) + green;
        rgb = (rgb << 8) + 0;

        return rgb;
    };
    
    private static System.Func<int, int> _forestPostProcess = (val) =>
    {
        byte trees = (byte)val;
        
        trees = (byte)(trees + EarthMapCreator.config.ForestAdd);
        trees = (byte)(EarthMapCreator.config.ForestMulti * val);
        return trees;
    };
}