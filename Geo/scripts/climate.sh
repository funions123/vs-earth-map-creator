#https://geodata.ucdavis.edu/climate/worldclim/2_1/base/wc2.1_30s_tavg.zip
#https://geodata.ucdavis.edu/climate/worldclim/2_1/base/wc2.1_30s_prec.zip

CLIMATE_DIR="$WORK_DIR/climate"
mkdir -p $CLIMATE_DIR

log "Getting climate data"

get_local_dataset wc2.1_30s_prec_tavg.zip $CLIMATE_DIR/.

cd $CLIMATE_DIR
unzip wc2.1_30s_prec_tavg.zip

log "Processing climate data"

log "Reprojecting"

gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -te $LON_MIN_FINAL $LAT_MIN_FINAL $LON_MAX_FINAL $LAT_MAX_FINAL $output_projection -r cubicspline -te_srs $bbox_srs -co COMPRESS=lzw -co predictor=2 -co BIGTIFF=YES -ot Int16 wc2.1_30s_prec_01.tif crop_prec.tif

gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -te $LON_MIN_FINAL $LAT_MIN_FINAL $LON_MAX_FINAL $LAT_MAX_FINAL $output_projection -r cubicspline -te_srs $bbox_srs -co COMPRESS=lzw -co predictor=2 -co BIGTIFF=YES -ot Float32 wc2.1_30s_tavg_01.tif crop_tavg.tif

log "raster metadata clean step"

gdal_translate crop_prec.tif crop_prec_fixed.tif -co COMPRESS=LZW -co TILED=YES -co BIGTIFF=YES
gdal_translate crop_tavg.tif crop_tavg_fixed.tif -co COMPRESS=LZW -co TILED=YES -co BIGTIFF=YES

log "fill nodata step"

gdal raster fill-nodata --config CPL_LOG /dev/null --strategy nearest --max-distance 500 crop_prec_fixed.tif crop_prec_c.tif
gdal raster fill-nodata --config CPL_LOG /dev/null --strategy nearest --max-distance 500 crop_tavg_fixed.tif crop_tavg_c.tif

log "merging step"
# --- Piecewise Scaling Parameters for Precipitation ---

# The raw TIF value where the scaling rate changes.
threshold=30

# The maximum raw TIF value expected in your data (e.g., 288).
# This is used to scale the values *above* the threshold.
original_max=288

# The desired output value (0-255) at the threshold.
mid_output_val=80

# The maximum value of the output raster (typically 255 for 8-bit).
output_max=200

# --- gdal_calc implementation ---

# The formula is split into two parts:
# 1. (A <= $threshold) * (...): Scales values from [0, threshold] to [0, mid_output_val].
# 2. (A > $threshold) * (...): Scales values from (threshold, original_max] to (mid_output_val, output_max].
gdal_calc.py -A crop_prec_c.tif --outfile=crop_prec_f.tif \
    --co="COMPRESS=LZW" --co="TILED=YES" --co="BIGTIFF=YES" --type='Byte' \
    --calc="((A <= $threshold) * (A * ($mid_output_val / $threshold))) + \
            ((A > $threshold) * ($mid_output_val + ((A - $threshold) / ($original_max - $threshold)) * ($output_max - $mid_output_val)))"
			
gdal_translate crop_tavg_c.tif -scale -46.1 34.1 0 255 -ot Byte crop_tavg_f.tif

gdal_create -bands 1 -burn 0 -if crop_tavg_f.tif dummy_b.tif
gdal_merge.py -separate -o $WORK_DIR/climate.tif -co PHOTOMETRIC=RGB ./crop_tavg_f.tif ./crop_prec_f.tif ./dummy_b.tif

log "Climate data DONE" 
