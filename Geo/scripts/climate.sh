#https://geodata.ucdavis.edu/climate/worldclim/2_1/base/wc2.1_30s_tavg.zip
#https://geodata.ucdavis.edu/climate/worldclim/2_1/base/wc2.1_30s_prec.zip

CLIMATE_DIR="$WORK_DIR/climate"
mkdir -p $CLIMATE_DIR

log "Getting climate data"
cd $CLIMATE_DIR
get_local_dataset wc2.1_30s_prec_tavg.zip $CLIMATE_DIR/.

if [[ ! -f wc2.1_30s_prec_tavg.zip ]]; then
  log "climate data not found locally, downloading"
  url="https://huggingface.co/spaces/tlm9201/vs-earth-map-mod/resolve/main/wc2.1_30s_prec_tavg.zip"
  download_file $url wc2.1_30s_prec_tavg.zip
fi

if [[ ! -f wc2.1_30s_prec_tavg.zip ]]; then
  log "CRITICAL ERROR: failed to download climate data"
  abort_duetoerror_cleanup $VSERR_NO_CLIMATE
fi

save_dataset_locally wc2.1_30s_prec_tavg.zip
unzip wc2.1_30s_prec_tavg.zip

log "Processing climate data"

log "Reprojecting"

gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -te $LON_MIN_FINAL $LAT_MIN_FINAL $LON_MAX_FINAL $LAT_MAX_FINAL $output_projection -r cubicspline -te_srs $bbox_srs -co COMPRESS=lzw -co predictor=2 -co BIGTIFF=YES -ot Int16 wc2.1_30s_prec_01.tif crop_prec.tif

gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -te $LON_MIN_FINAL $LAT_MIN_FINAL $LON_MAX_FINAL $LAT_MAX_FINAL $output_projection -r cubicspline -te_srs $bbox_srs -co COMPRESS=lzw -co predictor=2 -co BIGTIFF=YES -ot Float32 wc2.1_30s_tavg_01.tif crop_tavg.tif

log "Merging"

gdal raster fill-nodata --strategy nearest --max-distance 500 crop_prec.tif crop_prec_c.tif
gdal raster fill-nodata --strategy nearest --max-distance 500 crop_tavg.tif crop_tavg_c.tif

gdal_translate crop_prec_c.tif -scale 0 255 0 255 -ot Byte crop_prec_f_0.tif
gdal_translate crop_tavg_c.tif -scale -46.1 34.1 0 255 -ot Byte crop_tavg_f.tif

# normalize for vs fertility
# low is what we keep intact (<10 typically is desert)
# high is what we normalize values between low/high to
# ~25% rain (64/255) is where sand starts to format
# 100 is a good general value for infertile land
# vs doesnt really have a concept of sandy soil, so
# parts of the world just look like a desert even though they
# should look more like a steppe
c_normal_low=10
c_normal_high=100
gdal_calc.py -A crop_prec_f_0.tif --co="COMPRESS=lzw" --co="predictor=2" --NoDataValue=-32768 --co="BIGTIFF=YES" --format="gtiff" --calc="(A*(A<$c_normal_low)) + (A*(A>$c_normal_high)) + ((A>$c_normal_low)*(A<=$c_normal_high)*$c_normal_high)" --outfile="crop_prec_f.tif"

gdal_create -bands 1 -burn 0 -if crop_prec_f.tif dummy_b.tif
gdal_merge.py -separate -o $WORK_DIR/climate.tif -co PHOTOMETRIC=RGB ./crop_tavg_f.tif ./crop_prec_f.tif ./dummy_b.tif

log "Climate data DONE" 
