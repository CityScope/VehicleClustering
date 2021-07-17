/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Agents

import "./clustering.gaml"


species pheromoneRoad {
	aspect base {
		draw shape color: rgb(125, 125, 125);
	}
}

species dockingStation {
	aspect base {
		draw circle(10) color:#blue;		
	}
	
	reflex chargeBikes {}
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


species people control: fsm skills: [moving] {
	
	rgb color <- #yellow ;
    building living_place;
    building working_place;
    int start_work;
    int end_work;
    
    point final_destination; //Final destination for the trip
    point target; //Interim destination; the thing we are currently moving toward
    point closestIntersection;
    float waitTime;
    
    bike bikeToRide;
    
    
    aspect base {
		if state != "riding" {
			draw circle(10) color: color border: #black;
		}
    }
    
    //Should we leave for work/home? Only if it is time, and we are not already there
    bool timeToWork { return (current_date.hour = start_work) and !(self overlaps working_place); }
    bool timeToSleep { return (current_date.hour = end_work) and !(self overlaps living_place); }
    
    state idle initial: true {
    	//Watch netflix at home or something
    	enter { target <- nil; }
    	
    	transition to: requesting_bike when: timeToWork() {
    		final_destination <- any_location_in (working_place);
//    		write "going to work";
    	}
    	transition to: requesting_bike when: timeToSleep() {
    		final_destination <- any_location_in (living_place);
//    		write "going home";
    	}
    }
	state requesting_bike {
		//Ask the system for a bike, teleport home if wait is too long
		
		enter {
			closestIntersection <- (intersection closest_to(self)).location;
		}
		
		transition to: walking when: host.waitTime(self) <= maxWaitTime {
			//Walk to closest intersection, ask a bike to meet me there
			target <- closestIntersection;
			bikeToRide <- host.requestBike(self);
			write "getting a ride from " + bikeToRide;
		}
		transition to: idle {
			//teleport home
			location <- final_destination;
			write "wait too long, teleported";
		}
	}
	state awaiting_bike {
		//Go to an intersection and wait for your bike
		enter {
			target <- nil;
		}
		
		transition to: riding when: bikeToRide.state = "dropping_off" {}
	}
	state riding {
		//do nothing, follow the bike around until it drops you off and you have to walk
		transition to: walking when: bikeToRide.state != "dropping_off" {
			target <- final_destination;
		}
		exit { bikeToRide <- nil; }
		
		location <- bikeToRide.location;
	}
	state walking {
		//go to your destination or nearest intersection, then wait
		transition to: idle when: location = final_destination {}
		transition to: awaiting_bike when: location = target {}
		
		do goto target: target on: roadNetwork;
	}
}


/*species people skills:[moving] {
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
*/

species bike control: fsm skills: [moving] {
	aspect realistic {
		switch state {
			match "low_battery" {
				draw triangle(15) color: #darkred rotate: heading + 90;
			}
			match "picking_up" {
				draw triangle(15) color: rgb(175*1.1,175*1.6,200) rotate: heading + 90;
			}
			match "dropping_off" {
				draw triangle(15)  color: #gamagreen rotate: heading + 90;
			}
			default {
				draw triangle(15)  color: rgb(25*1.1,25*1.6,200) rotate: heading + 90;
			}
		}
	}
	
	point target;
	point targetIntersection;
	path myPath;
	path totalPath; 
	point source;
	
	int pathIndex;
	
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	int batteryLife; //Number of meters we can travel on current battery
	
	int lastDistanceToChargingStation;
	
    
	
	
	//transition from idle to picking_up. Called by the global scheduler
	people rider <- nil;	
	action pickUp(people person) {
		rider <- person;
	}
	
	
	
	//These are our cost functions, and will be the basis of how we decide to form platoons
	float platooningCost(bike other) {
		return 0;
	}
	float deplatooningCost(bike other) {
		return 0;
	}
	action evaluatePlatoons {}
	
	
	action reduceBattery {}
	float energyCost(float distance) { //This function will let us alter the efficiency of our bikes, if we decide to look into that
		return distance;
	}
	
	intersection lastIntersection;
	reflex moveTowardTarget when: target != nil {
		//do goto
		myPath <- goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		//determine distance
		//reduce battery
		//determine most recent RIFD tag
		
		//TODO: this doesnt make sense, we could (should) have crossed multiple intersections over the last move
		//update pheromones exactly once, when we cross a new intersection
		if lastIntersection != myPath.vertices[0] {
			lastIntersection <- myPath.vertices[0];
			do updatePheromones(lastIntersection);
			
			write "updating intersection " + lastIntersection;
		}
	}
	
	point chooseWanderTarget {
		return nil;
	}
	action evaporatePheromones(tagRFID tag) {}
	//Dump my pheremone at the nearest tag, pick up some from same tag via diffusion, add more pheremone to a random endpoint of the road I'm on
	action updatePheromones(intersection IntersectionToUpdate) {
		// ask the nearest tag to: add _all_ of my pheremone to it, update evaporation, and cap at (0, 50). If I am picking someone up, add 0 to pheremone tag (???). Set my pheremone levels to whatever the tag has diffused to me
		ask tagRFID closest_to(self){
			loop j from:0 to: (length(self.pheromonesToward)-1) {					
							
				self.pheromones[j] <- self.pheromones[j] + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
				
				if (self.pheromones[j]<0.001){
					self.pheromones[j] <- 0;
				}
				
				
				if(myself.state = "picking_up" or myself.state = "dropping_off") {
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
	}
	
	
	
	state idle initial: true {
		//wander the map, follow pheromones. Same as the old searching reflex
		
		//TODO: Why divide by speed??
		transition to: low_battery when: batteryLife < lastDistanceToChargingStation/speed {}
		transition to: picking_up when: rider != nil {}
		transition to: following when: false {} //TODO
		
		
		myPath <- self.goto(on:roadNetwork, target:target, speed:speed, return_path: true); 
		
		if (target = location) {
			ask tagRFID closest_to(self){
				myself.lastDistanceToChargingStation <- self.distanceToChargingStation;
				
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
			source <- location;
		}
		
		do updatePheromones;
	}
	
	state low_battery {
		//seek either a charging station or another vehicle
		transition to: getting_charge when: false {} //TODO
		transition to: awaiting_follower when: false {} //TODO
		
		
		myPath <- goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		do updatePheromones;
						
		ask tagRFID closest_to(self) {
			// Update direction and distance from closest Docking station
			myself.target <- point(self.towardChargingStation);
			myself.lastDistanceToChargingStation <- self.distanceToChargingStation;		
		}
		source <- location;
		// Recover wandering status, delete pheromones over Deposits
		loop i from: 0 to: length(chargingStationLocation) - 1 {
			if(location = point(roadNetwork.vertices[chargingStationLocation[i]])){
				ask tagRFID closest_to(self){
					self.pheromones <- [0.0,0.0,0.0,0.0,0.0];
				}
			}
		}
	}
	
	state getting_charge {
		//sit at a charging station until charged
		enter {
			ask chargingStation closest_to(self) {
				self.bikes <- self.bikes + 1;
			}
		}
		transition to: idle when: batteryLife = maxBatteryLife {}
		exit {
			ask chargingStation closest_to(self) {
				self.bikes <- self.bikes - 1;
			}
		}
	}
	
	state awaiting_follower {
		//sit at an intersection until a follower joins the platoon
		
		transition to: idle when: false {} //TODO
	}
	
	state following {
		//transfer charge to host, follow them around the map
		
		transition to: idle when: false {} //TODO
	}
	
	state picking_up {
		//go to rider's location, pick them up
		enter {
			target <- rider.closestIntersection; //Go to the rider's closest intersection
		}
		
		transition to: dropping_off when: location=target {}
	}
	
	state dropping_off {
		//go to rider's destination, drop them off
		enter {
			targetIntersection <- (intersection closest_to(rider.final_destination)).location;
	        totalPath <- path_between(roadNetwork, location, targetIntersection);
	        pathIndex <- 0;
	        target <- totalPath.vertices[pathIndex];
		}
		transition to: idle when: location=targetIntersection {
			rider <- nil;
		}
		
		//Weird pheromone stuff. I'm working on it.
		if location=target and target != targetIntersection {
			pathIndex <- pathIndex +1;
			source <- location;
			target <- point(totalPath.vertices[pathIndex]);
		}
		
	}
}


/*species bike skills:[moving] {
	point target;
	point targetIntersection;
	path myPath;
	path totalPath; 
	point source;
	
	int pathIndex;
	
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	int batteryLife; //Number of meters we can travel on current battery
	//float speed;
	
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
}*/
