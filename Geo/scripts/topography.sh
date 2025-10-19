log "Starting Unified Topography and Bathymetry processing step"

log "Starting Unified Topography and Bathymetry processing step"

# --- Part 1: Data Acquisition and Initial Cropping ---
log "Preparing GEBCO and GMTED data..."

BATHY_DIR="$WORK_DIR/bathymetry"
DEM_DIR="$WORK_DIR/dem"
mkdir -p "$BATHY_DIR" "$DEM_DIR"

# Fetch and crop GEBCO. This establishes the MASTER grid using a fixed resolution (-tr).
cd "$BATHY_DIR"
get_local_dataset "gebco_2025_sub_ice_topo.zip" .
unzip -o "gebco_2025_sub_ice_topo.zip"
gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS \
    --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM $output_projection \
    -te "$LON_MIN_FINAL" "$LAT_MIN_FINAL" "$LON_MAX_FINAL" "$LAT_MAX_FINAL" \
    -r cubicspline -te_srs "$bbox_srs" -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=YES -ot Int16 \
    NETCDF:"GEBCO_2025_sub_ice.nc":elevation "crop.tif"

# --- Co-registration Step ---
# To ensure perfect horizontal alignment, we extract the exact dimensions from the
# master grid we just created. All subsequent raster operations will be forced to match it.
log "Extracting master grid dimensions for co-registration..."
dims=$(gdalinfo "crop.tif" | grep "Size is" | sed 's/Size is //;s/,//')
MASTER_WIDTH=$(echo $dims | cut -d' ' -f1)
MASTER_HEIGHT=$(echo $dims | cut -d' ' -f2)
log "Master grid dimensions set to ${MASTER_WIDTH}x${MASTER_HEIGHT} for alignment."

# Fetch and crop GMTED, forcing it to align to the master GEBCO grid's exact dimensions.
cd "$DEM_DIR"
get_local_dataset ds75_grd.zip .
unzip -o ds75_grd.zip
gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS \
    --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -ts "$MASTER_WIDTH" "$MASTER_HEIGHT" \
    -te "$LON_MIN_FINAL" "$LAT_MIN_FINAL" "$LON_MAX_FINAL" "$LAT_MAX_FINAL" -t_srs "$FORCE_FINAL_PROJ" \
    -r cubicspline -te_srs "$bbox_srs" -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=YES -ot Int16 \
    ds75_grd/w001000.adf "crop_gmted_for_lakes.tif"
cd "$MAIN_DIR"

# --- Part 2: Generate Bathymetry Map (Output 1) ---
log "Generating bathymetry map (oceans and lakebeds)..."
# Isolate only the negative elevation values from the full GEBCO map
gdal_calc.py -A "$BATHY_DIR/crop.tif" --outfile="$BATHY_DIR/bathymetry_raw.tif" --calc="A*(A<0)" --NoDataValue=0 --co="COMPRESS=LZW"
stats=$(gdalinfo -mm "$BATHY_DIR/bathymetry_raw.tif" | tr ',' '.')
min_val=$(echo "$stats" | grep "Computed Min/Max" | cut -d "=" -f 2 | cut -d "," -f 1 | tr -d ' ')
abs_min_val=$(echo "$min_val" | awk '{print $1 * -1}')
to_high=$BATHY_SCALE_SEALEVEL
to_low=$BATHY_SCALE_MAXDEPTH
ocean_scaling_logic="((A + $abs_min_val) / ($abs_min_val * 1.0)) * ($to_high - $to_low) + $to_low"
gdal_calc.py -A "$BATHY_DIR/bathymetry_raw.tif" --outfile="$WORK_DIR/bathymetry.tif" \
    --calc="where(A<0, $ocean_scaling_logic, 0)" --NoDataValue=0 --co="COMPRESS=LZW" --type='Byte' --overwrite

# --- Part 3: Generate Land Topography and Lake Surfaces ---
log "Generating land topography and lake surface maps..."

# 3a. Create land-only versions of both datasets for fair comparison.
log "Clipping GEBCO to land-only elevations..."
gdal_calc.py -A "$BATHY_DIR/crop.tif" --outfile="$BATHY_DIR/gebco_land_raw.tif" --calc="A*(A>=0)" --NoDataValue=0

log "Normalizing land datasets to a common vertical scale..."
stats_topo=$(gdalinfo -mm "$BATHY_DIR/gebco_land_raw.tif")
max_elev_topo=$(echo "$stats_topo" | grep "Computed Min/Max" | cut -d "=" -f 2 | cut -d "," -f 2)
stats_dem=$(gdalinfo -mm "$DEM_DIR/crop_gmted_for_lakes.tif")
max_elev_dem=$(echo "$stats_dem" | grep "Computed Min/Max" | cut -d "=" -f 2 | cut -d "," -f 2)
abs_max_elev=$(echo "if ($max_elev_topo > $max_elev_dem) $max_elev_topo else $max_elev_dem" | bc)
log "Common land elevation range for scaling: Min=0, Max=${abs_max_elev}"
gdal_translate -scale 0 "$abs_max_elev" 0 65535 -ot UInt16 "$BATHY_DIR/gebco_land_raw.tif" "$BATHY_DIR/gebco_land_normalized.tif"
gdal_translate -scale 0 "$abs_max_elev" 0 65535 -ot UInt16 "$DEM_DIR/crop_gmted_for_lakes.tif" "$DEM_DIR/dem_land_normalized.tif"

# 3b. Create and align the initial (untrimmed) lake mask.
log "Creating and aligning initial lake mask..."
ogr2ogr -t_srs "$FORCE_FINAL_PROJ" "$WORK_DIR/lakes_reprojected.gpkg" "$WORK_DIR/crop_lakes.gpkg"
ogr2ogr -dialect SQLite -sql "SELECT ST_Buffer(geom, 200) FROM ne_10m_lakes" -f GPKG "$WORK_DIR/lakes_buffered.gpkg" "$WORK_DIR/lakes_reprojected.gpkg"
# Rasterize the lake mask onto the master grid for perfect alignment.
gdal_rasterize -burn 1 -l SELECT -ts "$MASTER_WIDTH" "$MASTER_HEIGHT" -ot Byte "$WORK_DIR/lakes_buffered.gpkg" "$WORK_DIR/lakes_mask_initial.tif"

# --- NEW: Forceful Alignment Step using rasterio Python script ---
log "Forcefully aligning all inputs to the master grid using rasterio..."

# Define paths for the new script and the reference file
ALIGNER_PY="$SCRIPTS/python/aligner.py"
REFERENCE_TIF="$BATHY_DIR/gebco_land_normalized.tif"

# Run the alignment script. It will create the _aligned.tif files in the WORK_DIR
python "$ALIGNER_PY" "$REFERENCE_TIF" "$WORK_DIR" \
    "$DEM_DIR/dem_land_normalized.tif" \
    "$WORK_DIR/lakes_mask_initial.tif"

# For consistency, copy the reference file to its own "_aligned" version
cp "$REFERENCE_TIF" "$BATHY_DIR/gebco_land_aligned.tif"

# Overwrite the original files with their aligned versions for subsequent steps
mv "$WORK_DIR/dem_land_aligned.tif" "$DEM_DIR/dem_land_aligned.tif"
mv "$WORK_DIR/lakes_mask_initial_aligned.tif" "$WORK_DIR/lakes_mask_initial_aligned.tif"

# --- NEW: Unified DEM Collation and Lake Mask Trimming ---
log "Running unified Python script for DEM collation and mask trimming..."

# Define the path to the new unified processor script
UNIFIED_PROCESSOR_PY="$SCRIPTS/python/topography_processor.py"

# Run the script to generate both the final DEM and the final trimmed mask
python "$UNIFIED_PROCESSOR_PY" \
    "$DEM_DIR/dem_land_aligned.tif" \
    "$BATHY_DIR/gebco_land_aligned.tif" \
    "$WORK_DIR/lakes_mask_initial_aligned.tif" \
    "$WORK_DIR/cropped_dem.tif" \
    "$WORK_DIR/lakes_mask.tif"

# Set the complete_topo map for other steps
cp "$BATHY_DIR/gebco_land_aligned.tif" "$WORK_DIR/complete_topo.tif"

log "Unified Topography and Bathymetry processing DONE"