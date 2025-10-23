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

# --- Main Conversions ---

# 1. Bathymetry (Oceans and Lakebeds)
echo "Translating final bathymetry to bathymetry_heightmap.bmp..."
eval $GDAL_TRANSLATE -ot Byte bathymetry.tif $BUILD_DIR/bathymetry_heightmap.png

# 2. Complete Topography (Ground and Dry Lakebeds)
echo "Translating complete topography to complete_topo.bmp..."
eval $GDAL_TRANSLATE -scale 0 65535 0 255 -ot Byte complete_topo.tif $BUILD_DIR/complete_topo.png

# 3. Lake Surfaces (Final Land Heightmap for Water Level)
echo "Translating lake surface map to heightmap.bmp..."
eval $GDAL_TRANSLATE -scale 0 65535 0 255 -ot Byte cropped_dem.tif $BUILD_DIR/heightmap.png

# --- Auxiliary Conversions ---

# Trimmed Lake Mask
echo "Translating trimmed lake mask..."
eval $GDAL_TRANSLATE -scale 0 1 0 255 -ot Byte lakes_mask.tif $BUILD_DIR/lake_mask.png

# Land Mask (for oceans)
echo "Translating land mask..."
eval $GDAL_TRANSLATE -ot Byte land_osm_mask.tif $BUILD_DIR/landmask.png

# Climate, Tree, and River maps
echo "Translating climate, tree, and river maps..."
eval $GDAL_TRANSLATE -ot Byte climate.tif $BUILD_DIR/climate.png
eval $GDAL_TRANSLATE -ot Byte tree.tif $BUILD_DIR/tree.png
eval $GDAL_TRANSLATE -b 1 -ot Byte rivers.tif $BUILD_DIR/river.png
# default command
magick $BUILD_DIR/river.png -background black -alpha remove -alpha off -threshold 90% -blur 0x5 -posterize 10 -level 0%,100%,1.0 $BUILD_DIR/river.png
# erode command for thinnening rivers
# magick $BUILD_DIR/river.png -background black -alpha remove -alpha off -morphology Erode Diamond:3 -threshold 90% -blur 0x5 -posterize 10 -level 0%,100%,1.0 $BUILD_DIR/river.png

echo "All translations complete."