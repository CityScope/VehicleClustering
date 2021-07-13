/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Agents

import "./clustering.gaml"


species pheromoneRoad {
	//stores road shapes and pheromone levels
	float pheromone <- 0.0; //probably should not store pheromone levels
	int lastUpdate;
	aspect base {
		draw shape color: rgb(125, 125, 125);
	}
}

species dockingStation {
	aspect base {
		draw circle(10) color:#blue;		
	}
}

species building {
    string type; 
    aspect type {
		draw shape color: color_map[type];
	}
}

species chargingStation {
	int bikes;
	aspect base {
		draw circle(10) color:#blue;		
	}
}

species intersection{
	aspect base {
		draw circle(10) color:#green;		
	}
}

species tagRFID {
	int id;
	//bool checked;
	string type;
	
	list<float> pheromones;
	list<geometry> pheromonesToward;
	
	int lastUpdate;
	
	geometry towardChargingStation;
	int distanceToChargingStation;

	aspect base{
		draw circle(10) color:#purple border: #black;
	}
	
	aspect realistic{
		draw circle(1+5*max(pheromones)) color:rgb(107,171,158);
	}
}

species bike skills:[moving] {
	point target;
	point targetIntersection;
	path myPath;
	path totalPath; 
	point source;
	
	int pathIndex;
	
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	int batteryLife; //Number of meters we can travel on current battery
//	float speed;
	
	int lastDistanceToChargingStation;
	
	bool lowBattery;	
	bool picking <- false;
	bool carrying <- false;
	
	people rider <- nil;

    aspect realistic {
		if lowBattery {
			draw triangle(15) color: #darkred rotate: heading + 90;
		} else if picking {
			draw triangle(15) color: rgb(175*1.1,175*1.6,200) rotate: heading + 90;
		} else if carrying {
			draw triangle(15)  color: #gamagreen rotate: heading + 90;
		} else {
			draw triangle(15)  color: rgb(25*1.1,25*1.6,200) rotate: heading + 90;
		}
	}
	
	
	//Dump my pheremone at the nearest tag, pick up some from same tag via diffusion, add more pheremone to a random endpoint of the road I'm on
	action updatePheromones{
		
		list<tagRFID>closeTag <- tagRFID at_distance 1000;
		// ask the nearest tag to: add _all_ of my pheremone to it, update evaporation, and cap at (0, 50). If I am picking someone up, add 0 to pheremone tag (???). Set my pheremone levels to whatever the tag has diffused to me
		ask closeTag closest_to(self){
			loop j from:0 to: (length(self.pheromonesToward)-1) {					
							
				self.pheromones[j] <- self.pheromones[j] + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
				
				if (self.pheromones[j]<0.001){
					self.pheromones[j] <- 0;
				}
				
				
				if(myself.picking or myself.carrying){								
					if (self.pheromonesToward[j]=myself.source){
						self.pheromones[j] <- self.pheromones[j] + myself.pheromoneMark ;
					}
				}
				
				//Saturation
				if (self.pheromones[j]>50*singlePheromoneMark){
					self.pheromones[j] <- 50*singlePheromoneMark;
				}
			}
			// Update tagRFID and pheromoneToDiffuse
			self.lastUpdate <- cycle;				
			myself.pheromoneToDiffuse <- max(self.pheromones)*diffusion;
		}
		ask pheromoneRoad closest_to(self){	
			point p <- farthest_point_to (self , self.location);
			if (myself.location distance_to p < 1){			
				self.pheromone <- self.pheromone + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
								
				if (self.pheromone<0.01){
					self.pheromone <- 0.0;
				}	
								
				if(myself.carrying or myself.carrying){
					self.pheromone <- self.pheromone + myself.pheromoneMark;
				}	
				self.lastUpdate <- cycle;				
			}
		}
	}
	
	
	reflex searching when: (!picking and !lowBattery and !carrying){		
		myPath <- self.goto(on:roadNetwork, target:target, speed:speed, return_path: true);				
		if (target != location) { 
			do updatePheromones;
		} else {
			ask tagRFID closest_to(self){
				myself.lastDistanceToChargingStation <- self.distanceToChargingStation;

				// If enough batteryLife follow the pheromone 
				if(myself.batteryLife < myself.lastDistanceToChargingStation/myself.speed){ 
					myself.lowBattery <- true;
				} else {
				
					list<float> edgesPheromones <-self.pheromones;
					
					if(mean(edgesPheromones)=0){ 
						// No pheromones,choose a random direction
						myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
					} else{
						// Follow strongest pheremone trail with p=exploratoryRate^2 if we just came from this direction, or p=exploratoryRate if not. Else, chose random direction
						// TODO: this random probability function can be better weighted by relative pheremone levels
						
						
						// Pick strongest pheromone trail (with exploratoryRate Probability if the last path has the strongest pheromone)					
						float maxPheromone <- max(edgesPheromones);
						loop j from:0 to:(length(self.pheromonesToward)-1) {					
							if (maxPheromone = edgesPheromones[j]) and (myself.source = point(self.pheromonesToward[j])){
								edgesPheromones[j]<- flip(exploratoryRate)? edgesPheromones[j] : 0.0;					
							}											
						}
						maxPheromone <- max(edgesPheromones);	

						
						// Follow strongest pheromone trail (with exploratoryRate Probability in any case)			
						loop j from:0 to:(length(self.pheromonesToward)-1) {			
							if (maxPheromone = edgesPheromones[j]){
								if flip(exploratoryRate){	
									myself.target <- point(self.pheromonesToward[j]);
									break;	
								} else {
									myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
									break;
								}
							}											
						}
					}				
				}
			}
			do updatePheromones;
			source <- location;
		}
	}
	//Implement logic for charging
	reflex toCharge when: lowBattery{
		myPath <- self.goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		
		if (target != location) {
			//collision avoidance time
			do updatePheromones;
		} else {				
			ask tagRFID closest_to(self) {
				// Update direction and distance from closest Docking station
				myself.target <- point(self.towardChargingStation);
				myself.lastDistanceToChargingStation <- self.distanceToChargingStation;		
			}
			do updatePheromones;
			source <- location;
			// Recover wandering status, delete pheromones over Deposits
			loop i from: 0 to: length(chargingStationLocation) - 1 {
				if(location = point(roadNetwork.vertices[chargingStationLocation[i]])){
					ask tagRFID closest_to(self){
						self.pheromones <- [0.0,0.0,0.0,0.0,0.0];
					}
					
					ask chargingStation closest_to(self){
						if(myself.picking){
							//self.trash <- self.trash + carriableTrashAmount;
							myself.picking <- false;
							myself.pheromoneMark <- 0.0;
						}					
						if(myself.lowBattery){
							self.bikes <- self.bikes + 1;
							myself.lowBattery <- false;
							myself.batteryLife <- maxBatteryLife;
						}							
					}
				}
			}
		}
	}
	reflex pickUp when: picking {
		do goto target: target on: roadNetwork ; 
	    if target = location {
	        targetIntersection <- (intersection closest_to(rider.target)).location;
	        totalPath <- path_between(roadNetwork, location, targetIntersection);
	        pathIndex <- 0;
	        target <- totalPath.vertices[pathIndex];
	        
	        ask rider {
	        	state <- "captured";
	        	write("Picked up a rider");
	        }
	        picking <- false;
	        carrying <- true;
    	}
	}
	reflex carrying when: carrying {
		myPath <- goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		
		do updatePheromones;
		
		
		//TODO: we will sometimes skip this branch because we are _almost_ but not quite at targetIntersection. This breaks the program
		if(location=targetIntersection){
			write("Arrived at target intersection");
			ask rider {
				location <- myself.location;
				state <- "free";
				write("dropped off rider");
			}
			carrying <- false;
		} else if (target = location) {
			pathIndex <- pathIndex +1 ;			
			do updatePheromones;
			source <- location;
			target <- point(totalPath.vertices[pathIndex]);
		}
	}
}

species people skills:[moving] {
    rgb color <- #yellow ;
    building living_place;
    building working_place;
    int start_work;
    int end_work;
    string objective <- "resting" among: ["resting", "working"];
    point target;
    point closestIntersection;
    
    //bool call_bike <- false;
    
    string state <- "free" among: ["free", "captured"]; //This variable can only be one of a few values, like an Enum in other languages
	
	action callBike {
		closestIntersection <- (intersection closest_to(self)).location;
		
    	list<bike>avaliableBikes <- bike where (each.picking = false and each.lowBattery = false);
    	//If no avaliable bikes, automatic transport to destiny (walk home?)
    	if(!empty(avaliableBikes)){
	    	ask avaliableBikes closest_to(self){
	    		self.target <- myself.closestIntersection;
	    		self.rider <- myself;
	    		self.picking <- true;
	    	}
	    	do goto target: closestIntersection on: roadNetwork ; 		    	
    	} else {
    		location <- target; //teleport home??
    	}
    }
    
    reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
	    objective <- "working" ;
	    target <- any_location_in (working_place);
	    
	    do callBike;
	}
    
    reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
	    objective <- "resting" ;
	    target <- any_location_in (living_place);
	    
	    do callBike;
	}
    
    aspect base {
		if state != "captured" {
			draw circle(10) color: color border: #black;
		}
    }
}


