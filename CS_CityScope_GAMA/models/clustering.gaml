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

experiment repeat100 type: batch repeat: 100 until:  (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: evaporation init: 0.15;
	parameter var: exploitationRate init: 0.95;
	parameter var: numBikes init: 100;
	parameter var: WanderingSpeed init: 3/3.6#m/#s;
}

//experiment batch_experiments_headless type: batch until: (cycle = 300) {
experiment batch_experiments_headless type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	//parameter var: evaporation among: [0.05, 0.15, 0.3];
	parameter var: evaporation among: [0.05, 0.1, 0.15, 0.2,0.25,0.3];
	//parameter var: evaporation among: [0.15, 0.2,0.25];
	//parameter var: exploitationRate among: [0.6, 0.75, 0.9];
	parameter var: exploitationRate among: [0.6,0.75,0.9, 0.95, 0.98];
	//parameter var: numBikes among: [25, 50, 75, 100, 125];
	parameter var: numBikes among: [300, 900, 1500];
	//parameter var: PickUpSpeed among: [4/3.6#m/#s,8/3.6#m/#s,12/3.6#m/#s];
	parameter var: WanderingSpeed among: [1/3.6#m/#s,3/3.6#m/#s,5/3.6#m/#s];
	//parameter var: maxWaitTime among: [5#mn,10#mn,15#mn];
}

experiment batch_fine_grane type: batch repeat: 3 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: evaporation among: [0.05,0.10, 0.15,0.2, 0.25, 0.3,0.5,0.75];
	parameter var: exploitationRate among: [0,0.25,0.6,0.65,0.7, 0.75,0.8,0.85, 0.9, 0.95];
}

experiment batch_demand_p type: batch repeat: 5 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: evaporation among: [0.05, 0.15, 0.3];
	parameter var: exploitationRate among: [0.6, 0.75, 0.9];
}

experiment batch_demand_r type: batch repeat: 5 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: exploitationRate init: 0.0;
}

experiment batch_experiments_ref type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	//parameter var: numBikes among: [25, 50, 75,100, 125, 150];
	//parameter var: numBikes among: [25, 50, 75, 100, 125];
	//parameter var: numBikes among: [300, 600, 900, 1200, 1500];
	parameter var: numBikes among: [300, 900, 1500];

}

experiment batch_experiments_random type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	//parameter var: numBikes among: [25, 50, 75,100, 125, 150];
	parameter var: WanderingSpeed among: [1/3.6#m/#s,3/3.6#m/#s,5/3.6#m/#s];
	//parameter var: numBikes among: [25, 50, 75, 100, 125];
	parameter var: numBikes among: [300, 900, 1500];
	//*********////parameter var: WanderingSpeed among: [1/3.6#m/#s,3/3.6#m/#s,5/3.6#m/#s];
	parameter var: exploitationRate init: 0.0;
}


experiment batch_task_switch type: batch repeat: 5 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: chargingPheromoneThreshold among:[0.0000001,0.000001,0.00001,0.01];
	parameter var: pLowPheromoneCharge among: [0.001,0.01,0.02,0.05];
	parameter var: readUpdateRate among: [0.1, 0.3, 0.5, 0.8];
	
}

//If we do 3^5=243 experiments each 3 times = 749 sims * 12.3 min that's 6 days with step 1s and 3 days with step 2s

experiment clustering type: gui {
	parameter var: numBikes init: numBikes;
	//parameter var: numPeople init: 250;
    output {
		display city_display type:opengl background: #black draw_env: false{	
			species tagRFID aspect: base; 
			species building aspect: type ;
			species road aspect: base ;
			species people aspect: base ;
			species chargingStation aspect: base ;
			species bike aspect: realistic trace: 10 ; //TODO: make proportional to pheromone
			graphics "text" {
				draw "day" + string(current_date.day) + " - " + string(current_date.hour) + "h" color: #white font: font("Helvetica", 25, #italic) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
				draw imageRaster size: 40 #px at: {world.shape.width * 0.98, world.shape.height * 0.95};
			}
		}
	
    }
}

experiment clustering_headless {
	parameter var: numBikes init: numBikes;
	//parameter var: numPeople init: 250;
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



