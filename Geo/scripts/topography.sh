log "Starting DEM step"

DEM_DIR="$WORK_DIR/dem"
mkdir -p $DEM_DIR

log "Downloading GMTED2010 250m data, or using locally stored file"
url="https://edcintl.cr.usgs.gov/downloads/sciweb1/shared/topo/downloads/GMTED/Grid_ZipFiles/ds75_grd.zip"
get_local_dataset ds75_grd.zip $DEM_DIR/.
if [[ ! -f $DEM_DIR/ds75_grd.zip ]]; then
  log "Local DEM data not found. Downloading..."
  curl -C - --connect-timeout 10 --retry 60 --retry-delay 10 --retry-all-errors -L $url -o $DEM_DIR/ds75_grd.zip
fi

cd $DEM_DIR
log "Unzipping DEM data"
unzip -o ds75_grd.zip
save_dataset_locally ds75_grd.zip

log "Processing DEM data"

gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -te $LON_MIN_FINAL $LAT_MIN_FINAL $LON_MAX_FINAL $LAT_MAX_FINAL $output_projection -r cubicspline -te_srs $bbox_srs -co COMPRESS=lzw -co predictor=2 -co BIGTIFF=YES -ot Int16 ds75_grd/w001000.adf crop.tif

gdal_calc.py -A  crop.tif --co="COMPRESS=lzw" --co="predictor=2" --co="BIGTIFF=YES" --NoDataValue=-32768 --format="gtiff" --calc="(A*(A>-999)*"$vertical_terrain_multiplier_decimalprecision")" --outfile="$WORK_DIR/cropped_dem.tif"
