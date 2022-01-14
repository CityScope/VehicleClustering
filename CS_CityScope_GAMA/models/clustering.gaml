/**
* Name: clustering
* Based on the internal empty template. 
* Author: Juan Múgica
* Tags: 
*/


model clustering

import "./Agents.gaml"
import "./Loggers.gaml"
import "./Parameters.gaml"

global {
	//---------------------------------------------------------Performance Measures-----------------------------------------------------------------------------
	//-------------------------------------------------------------------Necessary Variables--------------------------------------------------------------------------------------------------

	// GIS FILES
	geometry shape <- envelope(bound_shapefile);
	graph roadNetwork;
	list<int> chargingStationLocation;

	
	
    // ---------------------------------------Agent Creation----------------------------------------------
    init {
    	// ---------------------------------------Buildings----------------------------------------------
		do logSetUp;
	    create building from: buildings_shapefile with: [type:string(read (usage))] {
		 	if(type!=office and type!=residence){ type <- "Other"; }
		}
	        
	    list<building> residentialBuildings <- building where (each.type=residence);
	    list<building> officeBuildings <- building where (each.type=office);
	    
		// ---------------------------------------The Road Network----------------------------------------------
		create road from: roads_shapefile;
		
		roadNetwork <- as_edge_graph(road) ;   
		// Next move to the shortest path between each point in the graph
		matrix allPairs <- all_pairs_shortest_path (roadNetwork);    
	    
		// -------------------------------------Location of the charging stations----------------------------------------   
	    //from charging locations to closest intersection
	    list<int> tmpDist;

		loop vertex over: roadNetwork.vertices {
			create tagRFID {
				id <- roadNetwork.vertices index_of vertex;
				location <- point(vertex);
			}
		}

		//K-Means		
		//Create a list of x,y coordinate for each intersection
		list<list> instances <- tagRFID collect ([each.location.x, each.location.y]);

		//from the vertices list, create k groups  with the Kmeans algorithm (https://en.wikipedia.org/wiki/K-means_clustering)
		list<list<int>> kmeansClusters <- list<list<int>>(kmeans(instances, numChargingStations));

		//from clustered vertices to centroids locations
		int groupIndex <- 0;
		list<point> coordinatesCentroids <- [];
		loop cluster over: kmeansClusters {
			groupIndex <- groupIndex + 1;
			list<point> coordinatesVertices <- [];
			loop i over: cluster {
				add point (roadNetwork.vertices[i]) to: coordinatesVertices; 
			}
			add mean(coordinatesVertices) to: coordinatesCentroids;
		}    
	    
		loop centroid from:0 to:length(coordinatesCentroids)-1 {
			tmpDist <- [];
			loop vertices from:0 to:length(roadNetwork.vertices)-1{
				add (point(roadNetwork.vertices[vertices]) distance_to coordinatesCentroids[centroid]) to: tmpDist;
			}	
			loop vertices from:0 to: length(tmpDist)-1{
				if(min(tmpDist)=tmpDist[vertices]){
					add vertices to: chargingStationLocation;
					break;
				}
			}	
		}
	    

	    loop i from: 0 to: length(chargingStationLocation) - 1 {
			create chargingStation{
				location <- point(roadNetwork.vertices[chargingStationLocation[i]]);
			}
		}
		
	    
		// -------------------------------------------The Bikes -----------------------------------------
		create bike number:numBikes{						
			location <- point(one_of(roadNetwork.vertices));
			
			batteryLife <- rnd(minSafeBattery,maxBatteryLife); 	//Battery life random bewteen max and min
			speed <- WanderingSpeed;
			distancePerCycle <- step * speed; //Used to check pheromones in advance
			
			nextTag <- tagRFID( location );
			lastTag <- nextTag;
			pheromoneToDiffuse <- 0.0;
			pheromoneMark <- 300/step*singlePheromoneMark; //Pheromone mark to remain 5 minutes TODO: WHY?
			/*/They do if (self.trash > carriableTrashAmount){
			//self.trash <- self.trash - carriableTrashAmount;	
						//self.decreaseTrashAmount<-true;
						//myself.pheromoneMark <- (singlePheromoneMark * int(self.trash/carriableTrashAmount));		
						//myself.carrying <- true;
						
			//ask deposit closest_to(self){
							if(myself.carrying){
								self.trash <- self.trash + carriableTrashAmount;
								myself.carrying <- false;
								myself.pheromoneMark <- 0.0;
							}*/

			//write "cycle: " + cycle + ", " + string(self) + " created with batteryLife " + self.batteryLife;
		}
	    
		// -------------------------------------------The People -----------------------------------------
	    /*OLD: create people number: numPeople {
	    	
	        start_work_hour <- rnd (workStartMin, workStartMax-1); // we need to -1 because otherwise we will create agents until workStartMax:59 (eg. 8.59 with 8 as max)
	        start_work_minute <- rnd(0,59);
	        
	        end_work_hour <- rnd(workEndMin, workEndMax-1);
	        end_work_minute <- rnd(0,59);
	        
	        living_place <- one_of(residentialBuildings) ;
	        working_place <- one_of(officeBuildings) ;
	        location <- any_location_in(living_place);
	        
	        speed <- peopleSpeed;
	        
	        //write "cycle: " + cycle + ", " + string(self) + " created at " + self.start_work_hour + ":"+self.start_work_minute;
	    }*/
	    
	    //New demand
	    
	    create people from: demand_csv with:
			[start_hour::date(get("starttime")),  //'yyyy-MM-dd hh:mm:s'
				start_lat::float(get("start_lat")),
				start_lon::float(get("start_lon")),
				target_lat::float(get("target_lat")),
				target_lon::float(get("target_lon"))
			]{
				
			//location  <- to_GAMA_CRS({start_lon,start_lat},"EPSG:4326").location; // (lon, lat) var0 equals a geometry corresponding to the agent geometry transformed into the GAMA CRS
	        
	        speed <- peopleSpeed;
	        start_point  <- to_GAMA_CRS({start_lon,start_lat},"EPSG:4326").location; // (lon, lat) var0 equals a geometry corresponding to the agent geometry transformed into the GAMA CRS
			target_point <- to_GAMA_CRS({target_lon,target_lat},"EPSG:4326").location;
			location <- start_point;
			
			string start_h_str <- string(start_hour,'kk');
			start_h <- int(start_h_str);
			string start_min_str <- string(start_hour,'mm');
			start_min <- int(start_min_str);
			
			
			write "cycle: " + cycle + ", time "+ self.start_h + ":" + self.start_min + ", "+ string(self) + " will travel from " + self.start_point + " to "+ self.target_point;
			
			}
						
	 	// ----------------------------------The RFIDs tag on each road intersection------------------------
		
		ask tagRFID {
			location <- point(roadNetwork.vertices[id]); 
			pheromoneMap <- map( neighbors_of(roadNetwork,roadNetwork.vertices[id]) collect (each::0.0) );  //to know what edge is related to that amount of pheromone
			
			// Find the closest chargingPoint and set towardChargingStation and distanceToChargingStation
			nearestChargingStation <- chargingStation closest_to self;
			distanceToChargingStation <- int( self distance_to nearestChargingStation );
		}
		
		
		write "FINISH INITIALIZATION";
    }

reflex stop_simulation when: cycle >= numberOfDays * numberOfHours * 3600 / step {
	do pause ;
}

}

/*//TODO: fill this out with tests to verify that all functions work properly
//Also, figure out how to even use tests
species Tester {
	setup {	
	}
	
	test  test1 {	
	}
}
//TODO fill this out with benchmarks for each function, to be evaluated at different populations
experiment benchmarks { 
	init {
		benchmark message: 'arithmetic operation' repeat: 5 {
			//benchmark code will be run 'repeat' times, and report min,max,avg runtime
			int a <- int(1*54.2);
		}
	}
}*/



experiment batch_experiments_headless type: batch until: (cycle = 300) {
	parameter var: evaporation among: [0.05, 0.15, 0.3];
	parameter var: exploitationRate among: [0.6, 0.75, 0.9];
	parameter var: numBikes among: [40, 50, 60];
}

experiment clustering type: gui {
	parameter var: numBikes init: 50;
	//parameter var: numPeople init: 250;
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base trace: 10;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
	
    }
}

experiment clustering_headless {
	parameter var: numBikes init: 50;
	//parameter var: numPeople init: 250;
}


experiment one_person type: gui {
	parameter var: numBikes init: 0;
	//parameter var: numPeople init: 1;
	
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}

experiment one_each type: gui {
	parameter var: numBikes init: 1;
	//parameter var: numPeople init: 1;
    output {
		display city_display type:opengl background: #white draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}

experiment one_bike type: gui {
	
	parameter var: numBikes init: 1;
	//parameter var: numPeople init: 0;
	
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base ;
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic ;
			
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}

experiment just_a_lot_of_bikes type: gui {
	parameter var: numBikes init: 20;
	//parameter var: numPeople init: 0;
	
    output {
		display city_display type:opengl background: #black draw_env: false{	
//			species tagRFID aspect: base;
			species building aspect: type;
			species road aspect: base;
			species people aspect: base;
			species chargingStation aspect: base;
			species bike aspect: realistic;
			
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
    }
}
experiment one_each_headless {
	parameter var: numBikes init: 1;
	//parameter var: numPeople init: 1;
}
experiment one_bike_headless {
	parameter var: numBikes init: 1;
	//parameter var: numPeople init: 0;
}
