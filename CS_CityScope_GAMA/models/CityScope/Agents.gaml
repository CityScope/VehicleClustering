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


species building {
    aspect type {
		draw shape color: color_map[type];
	}
	string type; 
}

species chargingStation {
	list<bike> bikesToCharge;
	
	aspect base {
		draw circle(10) color:#blue;		
	}
	
	reflex chargeBikes {
		ask 10 first bikesToCharge {
			batteryLife <- batteryLife + step*V2IChargingRate;
		}
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
	
	rgb color;
	reflex set_color {
		color <- #purple;
	}
	aspect base{
		draw circle(10) color:color border: #black;
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
			closestIntersection <- (tagRFID closest_to(self)).location;
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
	rgb color;
	map<string, rgb> color_map <- [
		"idle"::#lime,
		
		"low_battery":: #red,
		"getting_charge":: #pink,
		
		"awaiting_follower"::#magenta,
		"seeking_leader"::#magenta,
		"following"::#yellow,
		
		"picking_up"::rgb(175*1.1,175*1.6,200),
		"dropping_off"::#gamagreen
	];
	aspect realistic {
		color <- color_map[state];

		draw triangle(25) color:color border: #red rotate: heading + 90;
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
	
	
	bike leader;
	bike follower;
	//These are our cost functions, and will be the basis of how we decide to form clusters
	float clusterCost(bike other) {
		return 0; //always cluster
	}
	float declusterCost(bike other) {
		//Don't decluster until you need to
		//Does not account for megacluster - You don't really need to leave if someone else is charging you
		if setLowBattery() { return 0; }
		
		return 10;
	}
	//decide to follow another bike
	bool evaluateclusters {
		//create a map of every idle bike within a certain distance and their clustering costs
		//perhaps we want to cluster with following bikes in the future. Megacluster
		map<bike, float> costs <- map(((bike where (each.state="idle" and each.rider = nil)) at_distance clusterDistance) collect(each::clusterCost(each)));
		
		if empty(costs) { return false; }
		
		float minCost <- min(costs.values);
		if minCost < clusterThreshold {
			leader <- costs.keys[ costs.values index_of minCost ];
			return true;
		}
		
		return false;
	}
	action chargeBike(bike other) {
		//never go less than some minimum battery level
		//never charge leader to have more power than you
	}
	action waitFor(bike other) {
		follower <- other;
	}
	
	//Determines when to move into the low_battery state
	reflex saturateBattery {
		if batteryLife < 0 {batteryLife <- 0.0;}
		if batteryLife > maxBatteryLife {batteryLife <- maxBatteryLife;}
	}
	
	//TODO: why is this divided by speed?
	bool setLowBattery {
		if batteryLife < 5*distancePerCycle { return true; }
		return batteryLife < 5*lastDistanceToChargingStation; //safety factor
	}
	float energyCost(float distance) { //This function will let us alter the efficiency of our bikes, if we decide to look into that
		if state = "dropping_off" { return 0; } //user will pedal
		return distance;
	}
	action reduceBattery(float distance) {
		batteryLife <- batteryLife - energyCost(distance);
		if follower != nil {
			ask follower {
				do reduceBattery(distance);
			}
		}
	}
	
	float pathLength(path p) {
		if empty(p) { return 0; }
		return p.shape.perimeter; //TODO: may be accidentally doubled
	}
	list<tagRFID> lastIntersections;
	tagRFID lastTag; //last RFID tag we crossed. Useful for wander function
	
	bool canMove {
		return state != "awaiting_follower" and target != location and (target != nil or wanderPath != nil) and batteryLife > 0;
	}
	reflex moveTowardTarget when: canMove() {
		//do goto (or follow in the case of wandering, where we've prepared a possibly-suboptimal rout)
		if (target != nil) {
			myPath <- goto(on:roadNetwork, target:target, speed:speed, return_path: true);
		} else {
			myPath <- follow(path: wanderPath, return_path: true);
		}
		//determine distance
		float distanceTraveled <- pathLength(myPath);
		do reduceBattery(distanceTraveled);
		
		if !empty(myPath) {
			//update pheromones exactly once, when we cross a new intersection
			//we could (should) have crossed multiple intersections over the last move. The location of each intersection
			//will show up in `vertices`, as they are the boundaries between new edges
			//simply casting the points to intersections is incorrect though, as we may get intersections that are close
			//to the points in question, but not actually on the path. We may also get duplicates. The filter removes both of these.
			//reverse it to make the oldest intersection first in the list
			list<tagRFID> newIntersections <- reverse( myPath.vertices where (tagRFID(each).location = each) );
//			ask newIntersections {
//				color <- #yellow;
//			}
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
			if (tag.pheromones[j]<minPheromoneLevel){
				tag.pheromones[j] <- minPheromoneLevel;
			}
			if (tag.pheromones[j]>maxPheromoneLevel){
				tag.pheromones[j] <- maxPheromoneLevel;
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
		transition to: awaiting_follower when: follower != nil and follower.state = "seeking_leader" {}
		transition to: seeking_leader when: evaluateclusters() {
			write string(self) + " is following " + leader;
			ask leader {
				do waitFor(myself);
			}
			ask host {
				do pause;
			}
		}
		
		
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
		transition to: getting_charge when: self.location = (chargingStation closest_to self).location {} //TODO
		
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
			target <- nil;
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge + myself;
			}
		}
		transition to: idle when: batteryLife = maxBatteryLife {}
		exit {
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge - myself;
			}
		}
	}
	
	state awaiting_follower {
		//sit at an intersection until a follower joins the cluster
		
		transition to: idle when: follower.state = "following" {}
	}
	state seeking_leader {
		//catch up to the leader
		//(when two bikes form a cluster, one will await_folloower, the other will seek leader)
		enter {
			target <- leader.location;
		}
		transition to: following when: (self distance_to leader) <= followDistance {}
		
		exit {
			target <- nil;
		}
	}
	state following {
		//transfer charge to host, follow them around the map
		location <- leader.location;
		leader.batteryLife <- leader.batteryLife + step*V2VChargingRate;
		batteryLife <- batteryLife - step*V2VChargingRate;
		//leader will update our charge level as we move along (see reduceBattery)
		
		transition to: idle when: declusterCost(leader) < declusterThreshold {
			ask leader {
				follower <- nil;
			}
			leader <- nil;
		}
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
			target <- (tagRFID closest_to rider.final_destination).location;
		}
		
		transition to: idle when: location=target {
			rider <- nil;
		}
	}
}
