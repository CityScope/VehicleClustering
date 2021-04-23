/**
* Name: clustering
* Based on the internal empty template. 
* Author: Juan Múgica
* Tags: 
*/


model clustering

global {
    float step <- 10 #mn;
 	string cityScopeCity<-"clustering";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	// GIS FILES
	file shape_file_bounds <- file(cityGISFolder + "/BOUNDARY_CityBoundary.shp");
	file shape_file_buildings <- file(cityGISFolder + "/CDD_LandUse.shp");
	file shape_file_roads <- file(cityGISFolder + "/BASEMAP_Roads.shp");
	file imageRaster <- file('./../../images/gama_black.png');
	geometry shape <- envelope(shape_file_bounds);
	date starting_date <- date("2021-04-23-00-00-00");
    int nb_people <- 100;
    int min_work_start <- 6;
    int max_work_start <- 8;
    int min_work_end <- 16; 
    int max_work_end <- 20; 
    float min_speed <- 1.0 #km / #h;
    float max_speed <- 5.0 #km / #h; 
    graph the_graph;
    
    init {
    create building from: shape_file_buildings with: [type::string(read ("Category"))] {
        if type="Office" {
        color <- #blue ;
        }
        if type="Residential" {
        color <- #green ;
        }
    }
    create road from: shape_file_roads ; 
    the_graph <- as_edge_graph(road);
    
    list<building> residential_buildings <- building where (each.type="Residential");
    list<building> office_buildings <- building where (each.type="Residential");
    create people number: nb_people {
        location <- any_location_in (one_of (residential_buildings));
    }
    }
}

species building {
    string type; 
    rgb color <- #black  ;
    
    aspect base {
    draw shape color: color ;
    }
}

species road  {
    rgb color <- #black ;
    aspect base {
    draw shape color: color ;
    }
}

species people {
    rgb color <- #yellow ;
    
    aspect base {
    draw circle(10) color: color border: #black;
    }
}

experiment road_traffic type: gui {
    parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
    parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
    parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;
    parameter "Number of people agents:" var: nb_people category: "People" ;
        
    output {
    display city_display type:opengl {
        species building aspect: base ;
        species road aspect: base ;
        species people aspect: base ;
    }
    }
}