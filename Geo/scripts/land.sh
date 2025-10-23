OSM_DIR="$WORK_DIR/osm_processing"
OSM_LAT_MIN=$(echo "$LAT_MIN_FINAL_4326 - 0" | bc | sed "s|^\.|0\.|g" | sed "s|^\-\.|-0\.|g")
OSM_LON_MIN=$(echo "$LON_MIN_FINAL_4326 - 0" | bc | sed "s|^\.|0\.|g" | sed "s|^\-\.|-0\.|g")
OSM_LAT_MAX=$(echo "$LAT_MAX_FINAL_4326 + 0" | bc | sed "s|^\.|0\.|g" | sed "s|^\-\.|-0\.|g")
OSM_LON_MAX=$(echo "$LON_MAX_FINAL_4326 + 0" | bc | sed "s|^\.|0\.|g" | sed "s|^\-\.|-0\.|g")

echo $OSM_LAT_MIN

mkdir -p $OSM_DIR
cd $OSM_DIR

if [[ ! -f $OSM_DIR/land_polygons.shp ]]; then
  log "Downloading OpenStreetMap Land Polygons data, searching for them locally if already downloaded"
rm -rf land-polygons-complete-4326.zip
get_local_dataset land-polygons-complete-4326.zip .
if [[ ! -f land-polygons-complete-4326.zip ]]; then
  curl -C - --connect-timeout 10 --retry 60 --retry-delay 10 --retry-all-errors -L -n $osm_landpolygons_url -o land-polygons-complete-4326.zip
fi
try=0
if [[ ! -f land-polygons-complete-4326.zip ]]; then
  while [[ $try -le 5 ]]; do
    ((try+=1))
    log "OSM Land Polygons Download Failed, waiting one minute and retrying (Try $try/5)"
    rm land-polygons-complete-4326.zip
    sleep 60
    if [[ ! -f land-polygons-complete-4326.zip ]]; then
      curl -C - --connect-timeout 10 --retry 60 --retry-delay 10 --retry-all-errors -L -n $osm_landpolygons_url -o land-polygons-complete-4326.zip
    fi
    if [[ -f land-polygons-complete-4326.zip ]]; then break; fi
  done
fi &&
if [[ ! -f land-polygons-complete-4326.zip ]]; then
  log "CRITICAL ERROR: OSM Land Polygons download failed, please retry again later."
  abort_duetoerror_cleanup 8
fi
fi

if [[ $download_datasets_locally -eq 1 ]]; then log "Saving OSM Land Polygons data locally for future generations, if not already downloaded";fi
save_dataset_locally land-polygons-complete-4326.zip

unzip land-polygons-complete-4326.zip
mv land-polygons-complete-4326/land_polygons.* .
rm -rf land-polygons-complete-4326*

log "Generating land mask from OpenStreetMap data"
cd $WORK_DIR
cp $WORK_DIR/dummy.tif $WORK_DIR/land_osm_mask.tif
ogr2ogr -clipsrc $OSM_LON_MIN $OSM_LAT_MIN $OSM_LON_MAX $OSM_LAT_MAX -f GPKG $WORK_DIR/landosm.gpkg $OSM_DIR/land_polygons.shp land_polygons
gdal_rasterize -l land_polygons -burn 255.0 $WORK_DIR/landosm.gpkg $WORK_DIR/land_osm_mask.tif
gdal_edit.py -unsetnodata $WORK_DIR/land_osm_mask.tif

log "Getting river data"
cd $OSM_DIR
get_local_dataset ne_10m_rivers_lake_centerlines.zip .
unzip ne_10m_rivers_lake_centerlines.zip

log "Processing rivers"
osmconvert $OSM_DIR/ne_10m_rivers_lake_centerlines.osm --drop-author -b=$OSM_LON_MIN,$OSM_LAT_MIN,$OSM_LON_MAX,$OSM_LAT_MAX -o=crop_rivers.osm
waterways_drop="intermittent=yes"

# --- Step 1: Define river_width ---
log "Calculating river width..."
river_width=$(echo "$major_river_width/$FINAL_RES" | bc -l)

# --- Step 2: Build the SQL filter list ---
log "Building SQL filter for major rivers..."
river_list=$(awk '{printf "\047%s\047,", $0}' $MAIN_DIR/config/major_rivers.txt | sed 's/,$//')

# --- Step 3a: Filter rivers into an intermediate file (without buffering) ---
log "Filtering rivers into an intermediate GeoPackage..."
ogr2ogr -clipsrc $OSM_LON_MIN $OSM_LAT_MIN $OSM_LON_MAX $OSM_LAT_MAX \
    -dialect SQLite \
    -sql "SELECT geometry FROM lines WHERE name IN ($river_list) UNION ALL SELECT geometry FROM multilinestrings WHERE name IN ($river_list)" \
    -f GPKG -nln rivers $WORK_DIR/filtered_rivers.gpkg $OSM_DIR/crop_rivers.osm

# --- Step 3b: Buffer the filtered rivers from the intermediate file ---
log "Buffering (expanding) the filtered rivers..."
ogr2ogr \
    -dialect SQLite \
    -sql "SELECT ST_Buffer(geometry, $river_width) FROM rivers" \
    -f GPKG -nln buffered_rivers $WORK_DIR/crop_rivers.gpkg $WORK_DIR/filtered_rivers.gpkg

# --- Step 4: Rasterize the result ---
log "Rasterizing rivers to the final mask..."
cp $WORK_DIR/dummy.tif $WORK_DIR/rivers.tif
gdal_rasterize -l buffered_rivers -at -burn 255 -burn 255 -burn 255 -burn 255 $WORK_DIR/crop_rivers.gpkg $WORK_DIR/rivers.tif
gdal_edit.py -unsetnodata $WORK_DIR/rivers.tif

log "Done with rivers"

cd $OSM_DIR
log "Getting lake data"
get_local_dataset ne_10m_lakes.zip .
unzip ne_10m_lakes.zip

log "Processing lakes"
ogr2ogr -clipsrc $OSM_LON_MIN $OSM_LAT_MIN $OSM_LON_MAX $OSM_LAT_MAX -f GPKG $WORK_DIR/crop_lakes.gpkg $OSM_DIR/ne_10m_lakes.shp ne_10m_lakes

log "Done with lakes"
log "DONE processing osm data"


