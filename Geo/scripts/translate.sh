cd $WORK_DIR

BUILD_DIR=$WORK_DIR/build

mkdir -p $BUILD_DIR

#land_osm_mask.tif
#cropped_dem.tif

GDAL_TRANSLATE="gdal_translate"

if [ $RESIZE_MAP -eq 1 ]; then
  echo "Resizing map"
  GDAL_TRANSLATE="$GDAL_TRANSLATE -outsize $FINAL_WIDTH $FINAL_LENGTH"
fi

# land mask
eval $GDAL_TRANSLATE -ot Byte land_osm_mask.tif $BUILD_DIR/landmask.bmp

# dem
MAX_HM_V=$(gdalinfo -mm cropped_dem.tif | grep "Computed Min/Max" | cut -d ","  -f2-)
echo $MAX_HM_V
# real max is 8718
eval $GDAL_TRANSLATE -scale 0.0 8718.0 0 255 -ot Byte cropped_dem.tif $BUILD_DIR/heightmap.bmp

# climate
eval $GDAL_TRANSLATE -ot Byte climate.tif $BUILD_DIR/climate.bmp

# tree
eval $GDAL_TRANSLATE -ot Byte tree.tif $BUILD_DIR/tree.bmp

# river
eval $GDAL_TRANSLATE -ot Byte rivers.tif $WORK_DIR/river.bmp
magick $WORK_DIR/river.bmp -channel RGB -threshold 90% -blur 0x5 -posterize 10 -level 0%,100%,1.0 $BUILD_DIR/river.bmp
