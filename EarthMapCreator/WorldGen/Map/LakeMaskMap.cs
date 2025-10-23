﻿using SixLabors.ImageSharp.PixelFormats;
using Vintagestory.API.Datastructures;

namespace EarthMapCreator;

/// <summary>
/// Loads the lake_mask.png file. A pixel with R > 0 indicates a lake.
/// </summary>
public class LakeMaskMap : DataMap<Rgb24>
{
    public LakeMaskMap(string filePath) : base(filePath)
    {
        int xRegions = Bitmap.Width / 512;
        int zRegions = Bitmap.Height / 512;
        IntValues = new IntDataMap2D[xRegions][];

        for (int x = 0; x < xRegions; x++)
        {
            IntValues[x] = new IntDataMap2D[zRegions];
            for (int z = 0; z < zRegions; z++)
            {
                IntValues[x][z] = IntDataMap2D.CreateEmpty();
                IntValues[x][z].Size = 512;
                IntValues[x][z].Data = new int[512 * 512];

                for (int i = 0; i < 512; i++)
                {
                    for (int j = 0; j < 512; j++)
                    {
                        int posX = x * 512 + i;
                        int posZ = z * 512 + j;
                        Rgb24 pixel = Bitmap[posX, posZ];
                        
                        // R > 1 marks a lake pixel
                        IntValues[x][z].SetInt(i, j, pixel.R);
                    }
                }
            }
        }

        Bitmap.Dispose();
    }
}