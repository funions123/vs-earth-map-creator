import sys
import os
import rasterio
import numpy as np  # <-- This line was missing
from rasterio.warp import reproject, Resampling

def align_rasters_to_reference(ref_path, out_dir, files_to_align):
    """
    Aligns one or more rasters to a reference raster's grid using rasterio.

    Args:
        ref_path (str): Path to the reference GeoTIFF.
        out_dir (str): Directory to save the new aligned files.
        files_to_align (list): A list of paths to the GeoTIFFs to be aligned.
    """
    try:
        # --- 1. Open the reference raster and get its properties ---
        with rasterio.open(ref_path) as ref_src:
            ref_profile = ref_src.profile
            ref_transform = ref_src.transform
            ref_crs = ref_src.crs
            ref_width = ref_src.width
            ref_height = ref_src.height
            print(f"Reference grid defined by: {os.path.basename(ref_path)}")

        # --- 2. Loop through each file to be aligned ---
        for src_path in files_to_align:
            base_name = os.path.basename(src_path)
            # Create the output filename, e.g., 'dem_land_normalized.tif' -> 'dem_land_aligned.tif'
            out_name = base_name.replace('_normalized', '_aligned').replace('_initial', '_initial_aligned')
            out_path = os.path.join(out_dir, out_name)
            
            print(f"Aligning {base_name} -> {os.path.basename(out_path)}...")

            with rasterio.open(src_path) as src:
                # --- 3. Create a destination array and update metadata ---
                # Start with the reference profile and update with source-specific info
                dst_profile = ref_profile.copy()
                dst_profile.update({
                    'dtype': src.profile['dtype'],
                    'nodata': src.profile['nodata']
                })

                destination_array = np.zeros((ref_height, ref_width), dtype=src.profile['dtype'])

                # --- 4. Perform the reprojection/alignment ---
                reproject(
                    source=rasterio.band(src, 1),
                    destination=destination_array,
                    src_transform=src.transform,
                    src_crs=src.crs,
                    dst_transform=ref_transform,
                    dst_crs=ref_crs,
                    resampling=Resampling.nearest  # Use nearest neighbor for masks/data
                )

                # --- 5. Write the aligned array to a new GeoTIFF ---
                with rasterio.open(out_path, 'w', **dst_profile) as dst:
                    dst.write(destination_array, 1)
        
        print("Alignment complete.")

    except Exception as e:
        print(f"An error occurred during alignment: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: python {sys.argv[0]} <reference.tif> <output_directory> <file_to_align1.tif> [file_to_align2.tif...]")
        sys.exit(1)
        
    ref_file = sys.argv[1]
    output_dir = sys.argv[2]
    align_files = sys.argv[3:]
    
    align_rasters_to_reference(ref_file, output_dir, align_files)