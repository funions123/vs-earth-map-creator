import sys
import rasterio
import numpy as np

def process_topography(dem_path, gebco_path, mask_path, out_dem_path, out_mask_path):
    """
    Combines DEM and GEBCO data based on an untrimmed lake mask, and
    simultaneously creates the final trimmed lake mask.

    This single operation replaces the separate trimming and collation steps.
    """
    try:
        print("Opening input files...")
        # Open the three aligned input files
        with rasterio.open(dem_path) as dem_src, \
             rasterio.open(gebco_path) as gebco_src, \
             rasterio.open(mask_path) as mask_src:

            # --- 1. Sanity Check: Ensure inputs are perfectly aligned ---
            if not (dem_src.profile['transform'] == gebco_src.profile['transform'] == mask_src.profile['transform'] and
                    dem_src.profile['crs'] == gebco_src.profile['crs'] == mask_src.profile['crs'] and
                    dem_src.width == gebco_src.width and dem_src.height == gebco_src.height):
                print("FATAL ERROR: Input rasters are not aligned.", file=sys.stderr)
                sys.exit(1)
            
            print("Inputs successfully verified as aligned.")

            # --- 2. Prepare metadata for the two output files ---
            # Profile for the final combined DEM (cropped_dem.tif)
            out_dem_meta = dem_src.profile.copy()
            out_dem_meta.update(dtype=rasterio.uint16, nodata=65535, compress='lzw', predictor=2)

            # Profile for the final trimmed mask (lakes_mask.tif)
            out_mask_meta = mask_src.profile.copy()
            out_mask_meta.update(dtype=rasterio.uint8, nodata=0, compress='lzw', predictor=2)

            # --- 3. Read raster data into NumPy masked arrays ---
            dem_array = dem_src.read(1, masked=True)
            gebco_array = gebco_src.read(1, masked=True)
            mask_array = mask_src.read(1, masked=True)

            print("Successfully read raster data into memory.")

            # --- 4. Perform the core calculation ---
            # This boolean array determines which pixels are "valid" lake surfaces.
            # Condition: (DEM >= GEBCO OR GEBCO is NoData) AND the pixel is in the initial mask.
            is_valid_lake_pixel_height = (
                ((dem_array >= gebco_array) | (gebco_array.mask))
            )
            
            is_valid_lake_pixel_mask = (
                # Condition 1: DEM is higher than GEBCO (safely handles NoData)
                np.ma.filled(dem_array >= gebco_array, fill_value=False) |
                
                # Condition 2: DEM is not NoData and GEBCO is NoData
                (~dem_array.mask & gebco_array.mask) |
                
                # Condition 3: DEM is zero and GEBCO is NoData
                ((dem_array == 0) & gebco_array.mask)

            ) & (mask_array) # And all conditions must be within the initial mask

            # --- 5. Generate the two output arrays ---
            
            # Output 1: The trimmed lake mask is the boolean condition itself.
            # True becomes 1, False becomes 0.
            trimmed_mask_array = is_valid_lake_pixel_mask.astype(rasterio.uint8)

            # Output 2: The combined DEM.
            # Where the condition is true, use the DEM value; otherwise, use the GEBCO value.
            combined_dem_array = np.where(
                is_valid_lake_pixel_height, 
                dem_array, 
                gebco_array
            )

            # Convert masked arrays back to regular arrays, filling NoData spots appropriately.
            final_dem_data = np.ma.filled(combined_dem_array, 65535).astype(rasterio.uint16)
            final_mask_data = np.ma.filled(trimmed_mask_array, 0).astype(rasterio.uint8)

            print("Calculation complete. Writing output files...")

            # --- 6. Write the two output GeoTIFFs ---
            with rasterio.open(out_dem_path, 'w', **out_dem_meta) as dst:
                dst.write(final_dem_data, 1)
            
            with rasterio.open(out_mask_path, 'w', **out_mask_meta) as dst:
                dst.write(final_mask_data, 1)

            print(f"Successfully created DEM: {out_dem_path}")
            print(f"Successfully created Mask: {out_mask_path}")

    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) != 6:
        print(f"Usage: python {sys.argv[0]} <dem.tif> <gebco.tif> <mask.tif> <output_dem.tif> <output_mask.tif>", file=sys.stderr)
        sys.exit(1)
        
    dem, gebco, mask, out_dem, out_mask = sys.argv[1:6]
    process_topography(dem, gebco, mask, out_dem, out_mask)