import geopandas as gpd

# Read in data
gdf = gpd.read_file('Roads.shp')
# Reproject to Lat/Long: http://epsg.io/4326
gdf_4326 = gdf.to_crs(epsg='4326')
# Write to file
gdf_4326.to_file('Roads.geojson', driver="GeoJSON")
