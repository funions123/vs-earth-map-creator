RESIZE_MAP=1
FINAL_WIDTH=2048
FINAL_LENGTH=2048

# Great Lakes
LAT_MIN_4326="35.013755"
LAT_MAX_4326="50.627996"
LON_MIN_4326="-90.084961"
LON_MAX_4326="-75.350586"

# Ireland
#LAT_MIN_4326="51.013755"
#LAT_MAX_4326="55.627996"
#LON_MIN_4326="-12.084961"
#LON_MAX_4326="-4.350586"

#Crimea
#LAT_MIN_4326="41.112469"
#LAT_MAX_4326="48.69096"
#LON_MIN_4326="28.564453"
#LON_MAX_4326="39.287109"

# Italy
#LAT_MIN_4326="34.452218"
#LAT_MAX_4326="46.316584"
#LON_MIN_4326="4.218750"
#LON_MAX_4326="19.863281"

# Full planet
# LAT_MIN_4326="-84.0"
# LAT_MAX_4326="84.0"
# LON_MIN_4326="-179.0"
# LON_MAX_4326="179.0"
# Great Britain
#LAT_MIN_4326="50.0"
#LAT_MAX_4326="60.0"
#LON_MIN_4326="-15.0"
#LON_MAX_4326="2.0"
# Europe small
#LAT_MIN_4326="42"
#LAT_MAX_4326="60"
#LON_MIN_4326="-13"
#LON_MAX_4326="29"
# Europe large
#LAT_MIN_4326="22"
#LAT_MAX_4326="70"
#LON_MIN_4326="-25"
#LON_MAX_4326="51"
# France
# LAT_MIN_4326="42"
# LAT_MAX_4326="50"
# LON_MIN_4326="-5"
# LON_MAX_4326="8"
LAT_MIN_FINAL=$LAT_MIN_4326
LAT_MAX_FINAL=$LAT_MAX_4326
LON_MIN_FINAL=$LON_MIN_4326
LON_MAX_FINAL=$LON_MAX_4326


FINAL_RES="300"
FORCE_FINAL_PROJ="ESRI:54080"
vertical_terrain_exaggeration="1"
bathymetry="1" # TODO
download_datasets_locally="1"
force_local_datasets_update="0"

# --- Custom Bathymetry Scaling ---
# Set to 1 to enable custom scaling, 0 to use the default full range (0-255).
ENABLE_BATHY_CUSTOM_SCALE=1

# Vintage story sea level (default 110) (max 255)
BATHY_SCALE_SEALEVEL=110

# Vintage story maximum ocean depth (default 50?)
BATHY_SCALE_MAXDEPTH=50

# in pixels (blocks)
major_river_width=5
