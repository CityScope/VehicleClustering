/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Agents

import "./clustering.gaml"


species road {
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
	rgb color <- #green;
	aspect base {
		draw circle(10) color:color;		
	}
	//debug stuff
	reflex coloring {
		color <- #green;
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
    	}
    	transition to: requesting_bike when: timeToSleep() {
    		final_destination <- any_location_in (living_place);
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
//			write "getting a ride from " + bikeToRide;
		}
		transition to: idle {
			//teleport home
			location <- final_destination;
			write "wait too long, teleported to destination";
		}
	}
	state awaiting_bike {
		//Sit at the intersection and wait for your bike
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
		
		//Always be at the same place as the bike
		location <- bikeToRide.location;
	}
	state walking {
		//go to your destination or nearest intersection, then wait
		transition to: idle when: location = final_destination {}
		transition to: awaiting_bike when: location = target {}
		
		do goto target: target on: roadNetwork;
	}
}


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
	path wanderPath;
	path myPath;
	point source;
	
	
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	float batteryLife; //Number of meters we can travel on current battery
	float distancePerCycle;
	
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
	
	//Determines when to move into the low_battery state
	bool setLowBattery {
		return batteryLife < lastDistanceToChargingStation/speed;
	}
	float energyCost(float distance) { //This function will let us alter the efficiency of our bikes, if we decide to look into that
		return 0*distance; //debug stuff, don't have charging implemented yet
	}
	float pathLength(path p) {
		if empty(p) { return 0; }
		return p.shape.perimeter;
	}
	list<tagRFID> lastIntersections;
	tagRFID lastTag; //last RFID tag we crossed. Useful for wander function
	reflex moveTowardTarget when: target != location and (target != nil or wanderPath != nil) and batteryLife > 0 {
		//do goto (or follow in the case of wandering, where we've prepared a possibly-suboptimal rout)
		if (target != nil) {
			myPath <- goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		} else {
			myPath <- follow(path: wanderPath, return_path: true);
		}
		//determine distance
		float distanceTraveled <- pathLength(myPath);
		batteryLife <- batteryLife - energyCost(distanceTraveled);
		
		if !empty(myPath) {
			//update pheromones exactly once, when we cross a new intersection
			//we could (should) have crossed multiple intersections over the last move. The location of each intersection
			//will show up in `vertices`, as they are the boundaries between new edges
			//simply casting the points to intersections is incorrect though, as we may get intersections that are close
			//to the points in question, but not actually on the path. We may also get duplicates. The filter removes both of these.
			//reverse it to make the oldest intersection first in the list
			list<tagRFID> newIntersections <- reverse( myPath.vertices where (tagRFID(each).location = each) );
			
			//update pheromones from first traveled to last traveled, ignoring those that were updated last cycle
			loop tag over: newIntersections {
				if not(tag in lastIntersections) { do updatePheromones(tag); }
			}
			
			//the future is now old man
			lastIntersections <- newIntersections;
			if (!empty(newIntersections)) { lastTag <- newIntersections[0]; }
		}
	}
	
	point chooseWanderTarget(tagRFID fromTag, tagRFID previousTag) {
		
		lastDistanceToChargingStation <- fromTag.distanceToChargingStation;
		
		list<float> edgesPheromones <- fromTag.pheromones;
		
		if(sum(edgesPheromones)=0) {
			// No pheromones,choose a random direction
			return point(fromTag.pheromonesToward[rnd(length(fromTag.pheromonesToward)-1)]);
		} else{
			// Follow strongest pheremone trail with p=exploratoryRate^2 if we just came from this direction, or p=exploratoryRate if not. Else, chose random direction
			// TODO: this random probability function can be better weighted by relative pheremone levels
			
			// Pick strongest pheromone trail (with exploratoryRate Probability if the last path has the strongest pheromone)
			float maxPheromone <- max(edgesPheromones);
			loop j from:0 to:(length(fromTag.pheromonesToward)-1) {
				if (maxPheromone = edgesPheromones[j]) and (previousTag = fromTag.pheromonesToward[j]){
					edgesPheromones[j]<- flip(exploratoryRate)? edgesPheromones[j] : 0.0;					
				}
			}
			maxPheromone <- max(edgesPheromones);	

			// Follow strongest pheromone trail (with exploratoryRate Probability in any case)
			loop j from:0 to:(length(fromTag.pheromonesToward)-1) {
				if (maxPheromone = edgesPheromones[j]){
					if flip(exploratoryRate){
						return point(fromTag.pheromonesToward[j]);
					} else {
						return point(fromTag.pheromonesToward[rnd(length(fromTag.pheromonesToward)-1)]);
					}
				}
			}
		}
		return nil; //We should not get here
	}
	
	//TODO: make proportional to time, not cycles.
	action evaporatePheromones(tagRFID tag) {
		loop j from:0 to: length(tag.pheromonesToward)-1 {
			tag.pheromones[j] <- tag.pheromones[j] - (singlePheromoneMark * evaporation * (cycle - tag.lastUpdate));
		}
	}
	//Cap the tag's pheromones at acceptable min and max levels
	//TODO: parametrize this - min and max should be set in parameters file
	action saturatePheromones(tagRFID tag) {
		loop j from:0 to: length(tag.pheromonesToward)-1 {
			if (tag.pheromones[j]<0.001){
				tag.pheromones[j] <- 0;
			}
			if (tag.pheromones[j]>50*singlePheromoneMark){
				tag.pheromones[j] <- 50*singlePheromoneMark;
			}
		}
	}
	
	//Dump my pheremone at the nearest tag, pick up some from same tag via diffusion, add more pheromone to a random endpoint of the road I'm on
	action updatePheromones(tagRFID tag) {
		// ask the nearest tag to: add _all_ of my pheremone to it, update evaporation, and cap at (0, 50). If I am picking someone up, add 0 to pheremone tag (???). Set my pheremone levels to whatever the tag has diffused to me
		do evaporatePheromones(tag);
		loop j from:0 to: (length(tag.pheromonesToward)-1) {	
			tag.pheromones[j] <- tag.pheromones[j] + pheromoneToDiffuse;
			
			if(state = "picking_up" or state = "dropping_off") {
				if (tag.pheromonesToward[j]=lastTag){
					tag.pheromones[j] <- tag.pheromones[j] + pheromoneMark ;
				}
			}
		}
		
		// Saturation
		do saturatePheromones(tag);
		// Update tagRFID and pheromoneToDiffuse
		tag.lastUpdate <- cycle;
		pheromoneToDiffuse <- max(tag.pheromones)*diffusion;
	}
	
	
	state idle initial: true {
		//wander the map, follow pheromones. Same as the old searching reflex
		enter {
			target <- nil;
		}
		//TODO: Why divide by speed??
		transition to: low_battery when: setLowBattery() {}
		transition to: picking_up when: rider != nil {}
		transition to: following when: false {} //TODO
		
		exit {
			wanderPath <- nil;
		}
		
		
		//construct a plan, so we don't waste motion: Where will we turn from the next intersection? If we have time left in the cycle, where will we turn from there? And from the intersection after that?
		tagRFID tagWereAboutToHit <- tagRFID closest_to self; //TODO: this is incorrect. Use the road we're currently on, compare the two intersections with the one we know we just crossed
		wanderPath <- path([tagWereAboutToHit, chooseWanderTarget(tagWereAboutToHit, lastTag)]);
		loop while: pathLength(wanderPath) < distancePerCycle {
			int i <- length(wanderPath.vertices) - 1;
			tagRFID finalTag <- wanderPath.vertices[i];
			tagRFID penultimate <- wanderPath.vertices[i-1];
			wanderPath <- path( wanderPath.vertices + chooseWanderTarget(finalTag, penultimate) );
		}
		
		
	}
	
	//TODO: we need to plan ahead somehow, or we waste quite a bit of movement. Currently we move exactly 1 intersection per cycle
	state low_battery {
		//seek either a charging station or another vehicle
		transition to: getting_charge when: false {} //TODO
		transition to: awaiting_follower when: false {} //TODO
		
		ask tagRFID closest_to(self) {
			// Update direction and distance from closest Docking station
			myself.target <- point(self.towardChargingStation);
			myself.lastDistanceToChargingStation <- self.distanceToChargingStation;		
		}
		source <- location;
		// Recover wandering status, delete pheromones over Deposits
		loop i from: 0 to: length(chargingStationLocation) - 1 {
			if(location = point(roadNetwork.vertices[chargingStationLocation[]])){
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
			target <- (intersection closest_to(rider.final_destination)).location;
		}
		
		transition to: idle when: location=target {
			rider <- nil;
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
