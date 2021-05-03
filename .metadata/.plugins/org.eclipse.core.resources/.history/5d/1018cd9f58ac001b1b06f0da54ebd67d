/**
* Name: clustering
* Based on the internal empty template. 
* Author: Juan Múgica
* Tags: 
*/


model clustering

import "./Agents.gaml"
import "./Parameters.gaml"

global {
	date starting_date <- #now;
	//---------------------------------------------------------Performance Measures-----------------------------------------------------------------------------
	int randomID;
	//-------------------------------------------------------------------Necessary Variables--------------------------------------------------------------------------------------------------

    float step <- 10 #mn;
    int current_hour update: (time / #hour) mod 24;
	//Implement a reflex to update current day. See City Scope Main. TBD
	int current_day <- 0;
	
	
 	string cityScopeCity<-"clustering";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	// GIS FILES
	file bound_shapefile <- file(cityGISFolder + "/BOUNDARY_CityBoundary.shp");
	file buildings_shapefile <- file(cityGISFolder + "/CDD_LandUse.shp");
	file roads_shapefile <- file(cityGISFolder + "/BASEMAP_Roads.shp");
	file imageRaster <- file('./../../images/gama_black.png');
	geometry shape <- envelope(bound_shapefile);
	file dockingStations <- file(cityGISFolder + "/dockingStations.shp");
    int nb_people <- 100;
    int nb_docking;
    int min_work_start <- 6;
    int max_work_start <- 8;
    int min_work_end <- 16; 
    int max_work_end <- 20; 
    float min_speed <- 1.0 #km / #h;
    float max_speed <- 5.0 #km / #h; 
    graph the_graph;
    //rgb backgroundColor<-#white;
    map<string, rgb>
    color_map <- ["Residential"::#white, "Office"::#gray, "Other"::#black];


	//-------------------------------------Species Creation-----------------------------------------------------------------------------------------------------------------------
    
    init {
		//---------------------------------------------------PERFORMANCE-----------------------------------------------    	
		randomID <- rnd (10000);
	    create building from: buildings_shapefile with: [type::string(read ("Category"))] {
	    		if(type!="Office" and type!="Residential"){
	    			type <- "Other";
	    		}
	        }
	    
	    create road from: roads_shapefile ; 
	    the_graph <- as_edge_graph(road);
	    
		//------------------------------------------BIKE SPECIES-------------------------------------------------------------			
	    
	 
		// ---------------------------------------The Road Network----------------------------------------------
		create pheromoneRoad from: roads_shapefile{
			pheromone <- 0.0;
		}
		//Juan: is this roadNetwork necessary? Having already the_graph
		roadNetwork <- as_edge_graph(pheromoneRoad) ;   
		
		// Next move to the shortest path between each point in the graph
		matrix allPairs <- all_pairs_shortest_path (roadNetwork);    
	    
		// -------------------------------------Location of the charging stations----------------------------------------   
	    create docking from: dockingStations ;
	    
	    //from docking locations to closest intersection
	    list<int> dockingLocation;
	    list<int> tmpDist;
	    
	    loop station from:0 to:length(docking)-1 {
	    	tmpDist <- [];
	    	loop vertice from:0 to:length(roadNetwork.vertices)-1{
	    		add (point(roadNetwork.vertices[vertice])) distance_to docking[station].location to: tmpDist;
	    	}
	    	loop vertice from:0 to: length(tmpDist)-1{
	    		if(min(tmpDist)=tmpDist[vertice]){
	    			add vertice to: dockingLocation;
	    			break;
	    		}
	    	}
	    }
	    
	    //Asign docking locations the new locations
	    loop station from:0 to:length(docking)-1 {
	    	docking[station].location <- roadNetwork.vertices[dockingLocation[station]];
	    }
	    
		// -------------------------------------------The Bikes -----------------------------------------
		create bike number:bikeNum{						
					location <- point(one_of(roadNetwork.vertices)); 
					target <- location; 
					source <- location;
					//Juan: Modify so it is carrying one person and not trash.				
					//carrying <- false;
					lowBattery <- false;
					speedDist <- 1.0;
					pheromoneToDiffuse <- 0.0;
					pheromoneMark <- 0.0;
					batteryLife <- rnd(maxBatteryLife);
					speedDist <- maxSpeedDist;
				}
	    
	    list<building> residential_buildings <- building where (each.type="Residential");
	    list<building> office_buildings <- building where (each.type="Residential");
	    create people number: nb_people {
	        speed <- rnd(min_speed, max_speed);
	        start_work <- rnd (min_work_start, max_work_start);
	        end_work <- rnd(min_work_end, max_work_end);
	        living_place <- one_of(residential_buildings) ;
	        working_place <- one_of(office_buildings) ;
	        objective <- "resting";
	        location <- any_location_in (one_of (residential_buildings));
	    }
	 	// ----------------------------------The RFIDs tag on each road intersection------------------------
		loop i from: 0 to: length(roadNetwork.vertices) - 1 {
			create tagRFID{ 								
				id <- i;
				checked <- false;					
				location <- point(roadNetwork.vertices[i]); 
				pheromones <- [0.0,0.0,0.0,0.0,0.0];
				pheromonesToward <- neighbors_of(roadNetwork,roadNetwork.vertices[i]);  //to know what edge is related  to that amount of pheromone
				
				// Find the closest charginPoint and set torwardDocking and distanceToDocking
				//Juan: CHECK this part of the code
				ask docking closest_to self {
					myself.distanceToDocking <- int(point(roadNetwork.vertices[i]) distance_to self.location);
					loop y from: 0 to: length(dockingLocation) - 1 {
						if (point(roadNetwork.vertices[dockingLocation[y]]) = self.location){
							myself.towardDocking <- point(roadNetwork.vertices[allPairs[dockingLocation[y],i]]);
							if (myself.towardDocking=point(roadNetwork.vertices[i])){
								myself.towardDocking <- point(roadNetwork.vertices[dockingLocation[y]]);
							}
							break;
						}				
					}					
				}				
				type <- 'roadIntersection';				
				loop y from: 0 to: length(dockingLocation) - 1 {
					if (i=dockingLocation[y]){
						type <- 'Deposit&roadIntersection';
					}
				}	
								
			}
		}	 



	        
    }
}

species building {
    string type; 
    rgb color <- #black  ;
    
    aspect base {
    draw shape color: color ;
    }
    
    aspect default {
		draw shape color: rgb(50, 50, 50, 125);
	}
    
    aspect type{
		draw shape color: color_map[type];
	}
}

species road  {
    rgb color <- #black ;
    aspect base {
       draw shape color: rgb(125, 125, 125);
    }
}


species people skills:[moving]{
    rgb color <- #yellow ;
    building living_place <- nil ;
    building working_place <- nil ;
    int start_work ;
    int end_work  ;
    string objective ;
    point the_target <- nil ;
    
    reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
    objective <- "working" ;
    the_target <- any_location_in (working_place);
    }
    
    reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
    objective <- "resting" ;
    the_target <- any_location_in (living_place); 
    }
    
    reflex move when: the_target != nil {
    do goto target: the_target on: the_graph ; 
    if the_target = location {
        the_target <- nil ;
    }
    }
    
    aspect base {
    draw circle(10) color: color border: #black;
    }
}

experiment clustering type: gui {
    parameter "Shapefile for the buildings:" var: buildings_shapefile category: "GIS" ;
    parameter "Shapefile for the roads:" var: roads_shapefile category: "GIS" ;
    parameter "Shapefile for the bounds:" var: bound_shapefile category: "GIS" ;
    parameter "Number of people agents:" var: nb_people category: "People" ;
    parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
    parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
    parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
        
    output {
    display city_display type:opengl background: #black draw_env: false{
    //display city_display type:opengl draw_env: false{	
        species building aspect: type ;
        species road aspect: base ;
        species people aspect: base ;
        species docking aspect: base ;
        graphics "text" {
				draw "day" + string(current_day) + " - " + string(current_hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.95, world.shape.height * 0.95};
			}
    }
    }
}