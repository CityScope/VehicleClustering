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

	
	int nb_people <-0;
	float sum_wait <-0;
	float avg_wait;
	
    // ---------------------------------------Agent Creation----------------------------------------------
    init {
    	// ---------------------------------------Buildings-----------------------------i----------------
		do logSetUp;
	    create building from: buildings_shapefile;
	    //with: [type:string(read (usage))] {
		 	//if(type!=office and type!=residence){ type <- "Other"; }
		//}
	        
	   // list<building> residentialBuildings <- building where (each.type=residence);
	   // list<building> officeBuildings <- building where (each.type=office);
	    
		// ---------------------------------------The Road Network----------------------------------------------
		//create road from: roads_shapefile;
		//roadNetwork <- as_edge_graph(road);  
		 
		//graph g;
		//g <- graphml_file("./../includes/City/Boston/greater_boston_walk.graphml").contents;
		
		//roadNetwork <- as_edge_graph(g);  
		
		//create road from: file("./../includes/City/Boston/greater_boston_walk.graphml");
		// Next move to the shortest path between each point in the graph
		//matrix allPairs <- all_pairs_shortest_path (roadNetwork);   TODO: Not used now 
	    
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
				//write location;
			}
		}
		
	    
	    
		// -------------------------------------------The Bikes -----------------------------------------
		create bike number:numBikes{						
			location <- point(one_of(roadNetwork.vertices));
			
			batteryLife <- rnd(minSafeBattery,maxBatteryLife); 	//Battery life random bewteen max and min
	
			if wanderingEnabled{speed <- WanderingSpeed;}
			else{speed <- 0.0;}
			
			distancePerCycle <- step * speed; //Used to check pheromones in advance
			
			nextTag <- tagRFID( location );
			lastTag <- nextTag;
			pheromoneToDiffuse <- 0.0;
			pheromoneMark <- 0.0; //300/step*singlePheromoneMark; //Pheromone mark to remain 5 minutes TODO: WHY?

			//write "cycle: " + cycle + ", " + string(self) + " created with batteryLife " + self.batteryLife;
		}
	    
		// -------------------------------------------The People -----------------------------------------
	    
	    create people from: demand_csv with:
		[start_hour::date(get("starttime")), //'yyyy-MM-dd hh:mm:s'
				start_lat::float(get("start_lat")),
				start_lon::float(get("start_lon")),
				target_lat::float(get("target_lat")),
				target_lon::float(get("target_lon"))
				/*start_lat::float(42.369732),
				start_lon::float(-71.090101),
				target_lat::float(42.368263),
				target_lon::float(-71.080622)*/
				
			]{

				
	        speed <- peopleSpeed;
	        start_point  <- to_GAMA_CRS({start_lon,start_lat},"EPSG:4326").location; // (lon, lat) var0 equals a geometry corresponding to the agent geometry transformed into the GAMA CRS
			target_point <- to_GAMA_CRS({target_lon,target_lat},"EPSG:4326").location;
			location <- start_point;
			
			string start_h_str <- string(start_hour,'kk');
			start_h <- int(start_h_str);
			string start_min_str <- string(start_hour,'mm');
			start_min <- int(start_min_str);
			
			
			//write "cycle: " + cycle + ", time "+ self.start_h + ":" + self.start_min + ", "+ string(self) + " will travel from " + self.start_point + " to "+ self.target_point;

			
			}
						
	 	// ----------------------------------The RFIDs tag on each road intersection------------------------
		
	ask tagRFID {
			location <- point(roadNetwork.vertices[id]); 
			pheromoneMap <- map( neighbors_of(roadNetwork,roadNetwork.vertices[id]) collect (each::0.0) );  //to know what edge is related to that amount of pheromone
			
			// Find the closest chargingPoint and set towardChargingStation and distanceToChargingStation
			nearestChargingStation <- chargingStation closest_to self;
			distanceToChargingStation <- int( self distance_to nearestChargingStation );
		}
		
		//write "Maximum Wait Time: " +maxWaitTime;
		//write "Max trip distance"+maxDistance;
		
		write "FINISH INITIALIZATION";
    }

reflex stop_simulation when: cycle >= numberOfDays * numberOfHours * 3600 / step {
	do pause ;
}

}



experiment pheromone_genetic_300_1 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 300;
	parameter var: WanderingSpeed init: 1/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_300_1.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


experiment pheromone_genetic_300_3 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 300;
	parameter var: WanderingSpeed init: 3/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_300_3.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


experiment pheromone_genetic_300_5 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 300;
	parameter var: WanderingSpeed init: 5/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_300_5.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}

experiment pheromone_genetic_900_1 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 900;
	parameter var: WanderingSpeed init: 1/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_900_1.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


experiment pheromone_genetic_900_3 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 900;
	parameter var: WanderingSpeed init: 3/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_900_3.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


experiment pheromone_genetic_900_5 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 900;
	parameter var: WanderingSpeed init: 5/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_900_5.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}

experiment pheromone_genetic_1500_1 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 1500;
	parameter var: WanderingSpeed init: 1/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_1500_1.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


experiment pheromone_genetic_1500_3 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 1500;
	parameter var: WanderingSpeed init: 3/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_1500_3.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


experiment pheromone_genetic_1500_5 type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numBikes init: 1500;
	parameter var: WanderingSpeed init: 5/3.6#m/#s;
	
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	parameter var: exploitationRate among: [0.6,0.65,0.7,0.75,0.8];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  minimize: avg_wait;
	
	reflex save_results {
		ask simulations {
			save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_1500_5.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}


