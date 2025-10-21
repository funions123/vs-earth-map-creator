#https://github.com/globalmaps/gm_ve_v1/raw/refs/heads/master/gm_ve_v1.zip

TREE_DIR="$WORK_DIR/tree"
mkdir -p $TREE_DIR

log "Getting tree canopy cover data"

get_local_dataset gm_ve_v1.zip $TREE_DIR/.
cd $TREE_DIR
if [[ ! -f $TREE_DIR/gm_ve_v1.zip ]]; then
  url="https://github.com/globalmaps/gm_ve_v1/raw/refs/heads/master/gm_ve_v1.zip"
  log "Local tree canopy cover data not found. Downloading..."
  download_file $url gm_ve_v1.zip
fi

if [[ ! -f $TREE_DIR/gm_ve_v1.zip ]]; then
  log "CRITICAL ERROR: failed to download tree canopy cover data"
  abort_duetoerror_cleanup $VSERR_NO_TREECANOPY
fi

log "Unzipping"
unzip gm_ve_v1.zip 
save_dataset_locally gm_ve_v1.zip

log "Reprojecting"

TREE_FILE="gm_ve_v1.tif"

gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -te $LON_MIN_FINAL $LAT_MIN_FINAL $LON_MAX_FINAL $LAT_MAX_FINAL $output_projection -r cubicspline -te_srs $bbox_srs -co COMPRESS=lzw -co predictor=2 -co BIGTIFF=YES -ot Byte $TREE_FILE crop_tree.tif

gdal_edit -a_nodata 255 crop_tree.tif
gdal raster fill-nodata --strategy nearest --max-distance 500 crop_tree.tif $WORK_DIR/tree.tif

log "Tree canopy cover DONE"
