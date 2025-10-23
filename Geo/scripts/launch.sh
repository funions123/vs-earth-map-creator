#!/bin/bash
PGID=$(ps -o pgid= $$ | grep -o [0-9]*)
MAIN_DIR=$PWD
SCRIPTS=$MAIN_DIR/scripts
WORK_DIR=$PWD/work
mkdir -p $WORK_DIR
LOCAL_DATASETS_DIR=$MAIN_DIR/datasets
rm $MAIN_DIR/log.txt

# Errors
VSERR_NO_OSMLANDPOLYGONS="10"
VSERR_NO_NE_LAKERIVERCENTERLINES="11"
VSERR_NO_NE_LAKES="12"
VSERR_NO_DEM="20"
VSERR_NO_TREECANOPY="30"
VSERR_NO_CLIMATE="40"

log() {
	logfile=$MAIN_DIR/log.txt
	echo -e "LOG [`date +%Y-%m-%d_%H:%M:%S`] "$1" "
	echo -e "LOG [`date +%Y-%m-%d_%H:%M:%S`] "$1" " >> $logfile
}

download_file() {
  curl -C - --connect-timeout 10 --retry 60 --retry-delay 10 --retry-all-errors -L -n $1 -o $2
}

abort_duetoerror_cleanup() {
	log "Aborting due to error code $1"
	trap - SIGTERM
	sleep 5
  log "Working directory files at failure point:"
	ls -lR $WORK_DIR/ >> $MAIN_DIR/log.txt
	cd $DATA_DIR/$MAP_CODENAME/
	kill -TERM -$PGID
	exit 0
}

save_dataset_locally() {
	if [[ ! -f $LOCAL_DATASETS_DIR/"$1" ]] && [[ $download_datasets_locally -eq 1 ]]; then
		filesize=$(du "$1" | cut -f 1)
    mkdir -p $LOCAL_DATASETS_DIR
    cp "$1" $LOCAL_DATASETS_DIR/.
	fi
	
	if [[ $force_local_datasets_update -eq 1 && $2 -eq 1 ]] && [[ $download_datasets_locally -eq 1 ]] && [[ -f $LOCAL_DATASETS_DIR/"$1" ]]; then
		filesize=$(du "$1" | cut -f 1)
    echo "Forcing the update of locally available file $1"
    mkdir -p $LOCAL_DATASETS_DIR
    cp "$1" $LOCAL_DATASETS_DIR/.
	fi
}

get_local_dataset() {
	if [[ -f "$LOCAL_DATASETS_DIR"/"$1" ]] && [[ $get_datasets_locally -eq 1 ]]; then
		log "Skipping "$1" file download, getting it from locally downloaded datasets"
		cp "$LOCAL_DATASETS_DIR"/"$1" "$2"
		log "get_local_dataset $1 $2 done"
	fi
}


source $SCRIPTS/config_exec.sh
source $SCRIPTS/config_performance.sh
source $SCRIPTS/config_map.sh

export FINAL_PROJ=$(python $SCRIPTS/python/getutm_epsg.py $LAT_MIN_4326 $LAT_MAX_4326 $LON_MIN_4326 $LON_MAX_4326)
output_projection="-tr $FINAL_RES -$FINAL_RES -t_srs $FINAL_PROJ"
bbox_srs="EPSG:4326"

export vertical_terrain_multiplier_decimalprecision=4
if [[ $(echo "$FINAL_RES < 0.25" | bc -l) -eq 1 ]]; then
	export vertical_terrain_multiplier_decimalprecision=$(echo "(1 / $FINAL_RES) + 1" | bc -l)
	export vertical_terrain_multiplier_decimalprecision=$(printf "%.0f" $vertical_terrain_multiplier_decimalprecision)
fi

cp $SCRIPTS/config_map.sh $WORK_DIR/.

if [[ ! -f $WORK_DIR/dummy.tif ]] || [[ ! -f $WORK_DIR/dummy_int16.tif ]]; then
  log "Processing dummy tiff files to be used later in the generation"
  gdalwarp -multi -co NUM_THREADS=ALL_CPUS -wo NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX -wm $GDAL_WM -of GTiff -ot Byte -te $LON_MIN_4326 $LAT_MIN_4326 $LON_MAX_4326 $LAT_MAX_4326 $output_projection -te_srs $bbox_srs -co COMPRESS=LZW $SCRIPTS/dummy.tif $WORK_DIR/dummy.tif
  gdal_calc.py -A $WORK_DIR/dummy.tif --outfile=$WORK_DIR/dummy2.tif --calc="A*0" --co="compress=lzw"
  mv $WORK_DIR/dummy2.tif $WORK_DIR/dummy.tif
  gdalwarp -co COMPRESS=LZW -of GTiff -ot Byte -t_srs EPSG:4326 $WORK_DIR/dummy.tif $WORK_DIR/dummy_4326.tif
  gdal_translate -co NUM_THREADS=ALL_CPUS --config GDAL_CACHEMAX $GDAL_CACHEMAX  -co COMPRESS=LZW -of GTiff -ot Int16 $WORK_DIR/dummy.tif $WORK_DIR/dummy_int16.tif
fi

info4326=$(python $SCRIPTS/python/getbbox_nativeproj_fromraster.py $WORK_DIR/dummy_4326.tif)
LAT_MAX_FINAL_4326=$(echo $info4326 | cut -d " " -f 6)
LON_MIN_FINAL_4326=$(echo $info4326 | cut -d " " -f 3)
LAT_MIN_FINAL_4326=$(echo $info4326 | cut -d " " -f 4)
LON_MAX_FINAL_4326=$(echo $info4326 | cut -d " " -f 5)

# START
source $SCRIPTS/topography.sh
source $SCRIPTS/land.sh
source $SCRIPTS/climate.sh
source $SCRIPTS/tree.sh
source $SCRIPTS/translate.sh

