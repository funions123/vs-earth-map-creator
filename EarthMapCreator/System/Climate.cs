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
    }

    public static System.Func<int, int, int, int> ClimatePostProcess = (val, blockX, blockZ) =>
    {
        // red -> temp
        // green -> rain
        byte red = (byte)((val >> 16) & 0xFF);
        byte green = (byte)((val >> 8) & 0xFF);

        // Apply modifications from the config file.
        red += EarthMapCreator.config.TemperatureAdd;
        green += EarthMapCreator.config.PrecipitationAdd;

        red = (byte)(EarthMapCreator.config.TemperatureMulti * red);
        green = (byte)(EarthMapCreator.config.PrecipitationMulti * green);

        int rgb = red;
        rgb = (rgb << 8) + green;
        rgb = (rgb << 8) + 0; // Blue channel is preserved but not modified.

        return rgb;
    };
    
    public static System.Func<int, int, int, int> ForestPostProcess = (val, blockX, blockZ) =>
    {
        // Determine the region and relative coordinates to look up the landmask value.
        // Assumes a region size of 512, which is standard.
        int regionX = blockX / 512;
        int regionZ = blockZ / 512;
        int relativeX = blockX % 512;
        int relativeZ = blockZ % 512;

        // Failsafe check for coordinates outside the map bounds.
        if (regionX < 0 || regionX >= EarthMapCreator.Layers.LandMaskMap.IntValues.Length ||
            regionZ < 0 || regionZ >= EarthMapCreator.Layers.LandMaskMap.IntValues[0].Length)
        {
            return 0; // Outside the map, so no trees.
        }
        
        // Get the landmask value for the current pixel.
        int landmaskValue = EarthMapCreator.Layers.LandMaskMap.IntValues[regionX][regionZ].GetInt(relativeX, relativeZ);

        // If the landmask value is 0 (or whatever signifies water), return 0 for tree density.
        if (landmaskValue == 0)
        {
            return 0;
        }

        // The pixel is on land, so proceed with the original tree density calculation.
        byte trees = (byte)val;
        
        trees = (byte)(trees + EarthMapCreator.config.ForestAdd);
        trees = (byte)(EarthMapCreator.config.ForestMulti * val);
        return trees;
    };
}