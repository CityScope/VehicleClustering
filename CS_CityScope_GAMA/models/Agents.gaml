model Agents

import "./clustering.gaml"


global {
	float distanceInGraph (point origin, point destination) {
		using topology(roadNetwork) {
			return (origin distance_to destination);
		}
	}
	list<bike> availableBikes(people person) {
		return bike where (each.availableForRide() and (each distance_to person) <= maxDistance);
	}


	bool requestBike(people person, point destination) { //returns true if there is any bike available

		list<bike> candidates <- availableBikes(person);
		if empty(candidates) {
			return false;
		}
		map<bike, float> costs <- map( candidates collect(each::bikeCost(person, each)));
		float minCost <- min(costs.values);
		bike b <- costs.keys[ costs.values index_of minCost ];
		
		//Ask for pickup
		ask b {
			do pickUp(person);
		}
		ask person {
			do ride(b);
		}
		
		return true;
	}
	
	float bikeCost(people person, bike b) {
		//We like the bike less if its far, more if it has power + it's BatteryLife normalized to make this system agnostic to maxBatteryLife
		return (person distance_to b) - bikeCostBatteryCoef*(b.batteryLife / maxBatteryLife);
	}
}

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
		ask chargingStationCapacity first bikesToCharge {
			batteryLife <- batteryLife + step*V2IChargingRate;
		}
	}
}

species tagRFID {
	int id;
	
	map<tagRFID,float> pheromoneMap;
	
	int lastUpdate; //Cycle
	
	chargingStation nearestChargingStation;
	int distanceToChargingStation;
	rgb tag_color;
	
	//easy access to neighbors
	list<tagRFID> neighbors { return pheromoneMap.keys;	}
	
	//Pheromone colors
	float average {
		float sum <- 0.0;
		float length <- 0.0;
		loop k over: neighbors(){
			sum <- sum + pheromoneMap[k];
			length <- length + 1;
			
		}
		float avg <- sum/length;
		return avg;
	}
	
	//list<string> var0 <- list<string> palettes <- brewer_palettes(3);
	aspect base {
		
		float avg <- average();
		
		
		rgb color_1 <- rgb(254,235,226); 
		rgb color_2 <- rgb(252,197,192);
		rgb color_3 <- rgb(250,159,181);
		rgb color_4 <- rgb(247,104,161);
		rgb color_5 <- rgb(197,27,138); 
		rgb color_6 <- rgb(122,1,119);
		
		
		float q1<- minPheromoneLevel+singlePheromoneMark/5;
		float q2<- minPheromoneLevel+2*singlePheromoneMark/5;
		float q3<- minPheromoneLevel+3*singlePheromoneMark/5;
		float q4<- minPheromoneLevel+4*singlePheromoneMark/5;
		float q5<- minPheromoneLevel+5*singlePheromoneMark/5;
		
		if avg < q1 {tag_color <- color_1;}
		else if avg < q2 {tag_color <-  color_2;}
		else if avg < q3 {tag_color <- color_3;}
		else if avg < q4 {tag_color <-  color_4;}
		else if avg < q5 {tag_color <-  color_5;}
		else {tag_color <-  color_6;}
	
		draw circle(10) color:tag_color;
	}
	
}


species people control: fsm skills: [moving] {

	rgb color;
	
    map<string, rgb> color_map <- [
		"idle"::#lavender,
		"requesting_bike":: #springgreen,
		"awaiting_bike":: #springgreen,
		"riding":: #gamagreen,
		"walking":: #magenta

	];
	
	//loggers
    peopleLogger logger;
    peopleLogger_trip tripLogger;
    peopleLogger_tangible tangiblePeopleLogger;
    
	//raw
	date start_hour; //datetime
	float start_lat; 
	float start_lon;
	float target_lat;
	float target_lon;
	 
	//adapted
	point start_point;
	point target_point;
	int start_h; //just hour
	int start_min; //just minute
    
    bike bikeToRide;
    
    point final_destination; //Final destination for the trip
    point target; //Interim destination; the point we are currently moving toward
    point closestIntersection;
    float waitTime;
    
    aspect base {
    	color <- color_map[state];
    	draw circle(10) color: color border: #black;
    }
    
    //----------------PUBLIC FUNCTIONS-----------------
	// these are how other agents interact with this one. Not used by self
	
    action ride(bike b) {
    	bikeToRide <- b;
    }	

    bool timeToTravel { return (current_date.hour = start_h and current_date.minute >= start_min) and !(self overlaps target_point); }
    	//Should we leave for work/home? Only if it is time, and we are not already there
    
    state wander initial: true {
    	//Watch netflix at home (and/or work)
    	enter {
    		ask logger { do logEnterState; }
    		target <- nil;
    	}
    	transition to: requesting_bike when: timeToTravel() {
    		write "cycle: " + cycle + ", current time "+ current_date.hour +':' + current_date.minute + 'agent' +string(self) + " time " + self.start_h + ":"+self.start_min;
    		final_destination <- target_point;
    	}
    	exit {
			ask logger { do logExitState; }
		}
    }
	state requesting_bike {
		//Ask the system for a bike, teleport (use another transportation mode) if wait is too long
		enter {
			ask logger { do logEnterState; }
			closestIntersection <- (tagRFID closest_to(self)).location;
		}
		
		transition to: walking when: host.requestBike(self, final_destination) {
			target <- closestIntersection;
		}
		transition to: wander {
			ask logger { do logEvent( "Used another mode, wait too long" ); }
			location <- final_destination;
		}
		exit {
			ask logger { do logExitState("Requested Bike " + myself.bikeToRide); }
		}
	}
	state awaiting_bike {
		//Sit at the intersection and wait for your bike
		enter {
			ask logger { do logEnterState( "awaiting " + string(myself.bikeToRide) ); }
			target <- nil;
		}
		transition to: riding when: bikeToRide.state = "in_use" {}
		exit {
			ask logger { do logExitState; }
		}
	}
	state riding {
		//Follow the bike around (i.e., ride it) until it drops you off 
		enter {
			ask logger { do logEnterState( "riding " + string(myself.bikeToRide) ); }
		}
		transition to: walking when: bikeToRide.state != "in_use" {
			target <- final_destination;
		}
		exit {
			ask logger { do logExitState; }
			bikeToRide <- nil;
		}

		location <- bikeToRide.location; //Always be at the same place as the bike
	}
	state walking {
		//go to your destination or nearest intersection, then wait
		enter {
			ask logger { do logEnterState; }
		}
		transition to: wander when: location = final_destination {}
		transition to: awaiting_bike when: location = target {}
		exit {
			ask logger { do logExitState; }
		}
		
		
		do goto target: target on: roadNetwork;
	}
}

species bike control: fsm skills: [moving] {
	
	//----------------Display-----------------
	rgb color;
	
	map<string, rgb> color_map <- [
		"wander"::#purple,
		
		"low_battery":: #red,
		"getting_charge":: #pink,
		
		"awaiting_follower"::#lightcyan,
		"seeking_leader"::#lightcyan,
		"following"::#skyblue,
		
		"picking_up"::#springgreen,
		"in_use"::#gamagreen
	];
	
	aspect realistic {
		color <- color_map[state];
		draw triangle(25) color:color border:color rotate: heading + 90 ;

	} 

	
	//loggers
	bikeLogger_roadsTraveled travelLogger;
	bikeLogger_chargeEvents chargeLogger;
	bikeLogger_ReceiveChargeEvents receiveChargeLogger;
	bikeLogger_event eventLogger;
	bikeLogger_tangible tangibleBikeLogger;
	
	    
	/* ========================================== PUBLIC FUNCTIONS ========================================= */
	// these are how other agents interact with this one. Not used by self
	bike leader;
	bike follower;
	people rider;
	
	list<string> rideStates <- ["wander", "following"];
	bool lowPass <- false;

	bool availableForRide {
		return (state in rideStates) and !setLowBattery() and rider = nil;
	}
	list<string> platoonStates <- ["wander"]; 
	bool availableForPlatoon {
		return (state in platoonStates) and follower = nil and !setLowBattery(); //this would be different with 'megaclusters'
	}
	
	action pickUp(people person) { 
		//transition from wander to picking_up. Called by the global scheduler
		rider <- person;
	}
	
	action waitFor(bike other) {
		follower <- other;
	}
	
	
	/* ========================================== PRIVATE FUNCTIONS ========================================= */
	// no other species should touch these
	
	//----------------Clustering-----------------
	//These are our cost functions, and will be the basis of how we decide to form clusters
	
	float clusterCost(bike other) {
		return clusterThreshold - chargeToGive(other); //they need to be able to share a min amount of battery 
	}
	
	bool shouldDecluster(bike other) {
		//Don't decluster until you need to or you've nothing left to give
		if other.state = "in_use" { return true; } //they can do the pickup together but then they decluster for the ride
		if setLowBattery() { return true; }
		if chargeToGive(other) <= 0 { return true; }
		
		return false;
	}
	
	//decide to follow another bike
	bool evaluateclusters {
		//create a map of every available bike within a certain distance and their clustering costs
		map<bike, float> costs <- map(((bike where (each.availableForPlatoon())) at_distance clusterDistance) collect(each::clusterCost(each)));
		
		if empty(costs) { return false; }
		
		float minCost <- min(costs.values);
		if minCost < 0 {
			leader <- costs.keys[ costs.values index_of minCost ];
			return true;
		}
		
		return false;
	}
	
	//determines how much charge we could give another bike
	float chargeToGive(bike other) {	
		float chargeDifferenceHalved <- (batteryLife - other.batteryLife)/2; //never charge leader to have more power than you
		float chargeToSpare <- batteryLife - minSafeBattery; //never go less than some minimum battery level
		float chargeToGain <- maxBatteryLife - other.batteryLife;
		return min(chargeDifferenceHalved, chargeToSpare, chargeToGain);
		//TODO: tweak these hypotheses so that the fleet behavior makes sense
	}
	action chargeBike(bike other) {
		float transfer <- min( step*V2VChargingRate, chargeToGive(other));
		
		leader.batteryLife <- leader.batteryLife + transfer;
		batteryLife <- batteryLife - transfer;
	}
	
	//----------------BATTERY-----------------
	
	
	bool setLowBattery { //Determines when to move into the low_battery state
		
		if batteryLife < minSafeBattery { return true; } 
		else {
			return false;
		}

	}
	float energyCost(float distance) {
		//if state = "in_use" { return 0; } //if use phase does not consmue battery
		return distance;
	}
	action reduceBattery(float distance) {
		batteryLife <- batteryLife - energyCost(distance);
    
		if follower != nil and follower.state = "following" {
			ask follower {
				do reduceBattery(distance);
			}
		}
	}
	
	
	//----------------MOVEMENT-----------------
	point target;
	
	float batteryLife min: 0.0 max: maxBatteryLife; //Number of meters we can travel on current battery
	float distancePerCycle;
	
	path travelledPath; //preallocation. Only used within the moveTowardTarget reflex
	
	list<tagRFID> lastIntersections;
	
	tagRFID lastTag; //last RFID tag we passed. Useful for wander function
	tagRFID nextTag; //tag we ended on OR the next tag we will reach
	tagRFID lastTagOI; //last RFID tag we passed in previous cycle. Useful for deposit pheromones.
	
	bool canMove {
		return state != "awaiting_follower" and ((target != nil and target != location) or state="wander") and batteryLife > 0;
	}
	
	
	path moveTowardTarget {
		if (state="in_use"){return goto(on:roadNetwork, target:target, return_path: true, speed:RidingSpeed);}
		return goto(on:roadNetwork, target:target, return_path: true, speed:PickUpSpeed);
	}
	path wander {
		//construct a plan, so we don't waste time: Where will we turn from the next intersection? If we have time left in the cycle, where will we turn from there? And from the intersection after that?
		 
	 	/***NOTE:*** This part is a fix to have a good performance with large time steps during testing but for the final experiments we will use a small time step
		Technically, the bike would pause at each intersection to read the direction to the nearest charging station
		This wastes a lot of time in simulation, so we are cheating
		The path the bike follows is identical.*/
			
		list<point> plan <- [location, nextTag.location];
		float distancePlan <- host.distanceInGraph(location, nextTag.location);
		
		loop while: distancePlan < distancePerCycle {
			tagRFID newTag <- chooseWanderTarget(nextTag, lastTag); 
			//TODO: This call updates the nextTag
			
			lastTag <- nextTag;
			nextTag <- newTag;
			plan <- plan + newTag.location;
			distancePlan <- host.distanceInGraph(location, newTag.location);
		}
		
		// TODO: using follow can result in some drift when the road is curved (follow will use straight lines, and not respect topology)
		return follow(path:path(plan), return_path: true);
	}
	
	reflex move when: canMove() {
		
		lastTagOI <- lastTag;
		
		travelledPath <- (state = "wander") ? wander() : moveTowardTarget();
		//do goto or, in the case of wandering, follow the predicted path for the full step (see path wander)
		
		float distanceTraveled <- host.distanceInGraph(travelledPath.source,travelledPath.target);
		
		do reduceBattery(distanceTraveled);
			
		if !empty(travelledPath) {
			/* update pheromones exactly once, when we cross a new intersection
			 * we could have crossed multiple intersections over the last move, depending on the time step. 
			 * The location of each intersection will show up in `vertices`, as they are the boundaries between new edges
			 * simply casting the points to intersections is incorrect though, as we may get intersections that are close to
			 * the points in question, but not actually on the path. We may also get duplicates. The filter removes both of these.
			 */
			
			//oldest intersection is first in the list
			list<tagRFID> newIntersections <- travelledPath.vertices where (tagRFID(each).location = each);
			int num <- length(newIntersections);			
			
			//update lastTag, nextTag. 
			if (!empty(newIntersections)) {
				tagRFID mostRecentTag <- last(newIntersections);
				tagRFID penultimateTag <- num = 1 ? last(lastIntersections) : newIntersections[num - 2];
				
				if location = mostRecentTag.location { //we have stopped at an intersection
				
					//If stucked on an intersection, both lastTag and nextTag are the same.
					nextTag <- mostRecentTag;
					lastTag <- penultimateTag = nil? nextTag:penultimateTag;
						
					newIntersections <- copy_between( newIntersections, 0, num-1); 
					//Since we landed on nextTag, remove it from the list we'll process it next iteration
					//(We should always read the data _before_ we overwrite it. We have not yet read this tag, so we push writing over it to the future)
					//Also prevents overlap between new and last intersection lists
					
				} else { //we have stopped in the middle of a road
				
					//current edge will have two points on it, one is lastTag, the other is nextTag
					lastTag <- mostRecentTag;
					nextTag <- tagRFID( (current_edge.points where (each != lastTag.location))[0] );
				}
			}
			
			//remember read pheromones without looking at what we have added to them
			do rememberPheromones(newIntersections);
			
			//add pheromones
			loop tag over: newIntersections {
				do depositPheromones(tag, lastTagOI); 
				lastTagOI <- tag;
			}
			
			//the future is now old man (overwrite old saved data)
			lastIntersections <- newIntersections;
			
			ask travelLogger { do logRoads(distanceTraveled, num); }
			if (follower != nil) {
				ask follower {
					ask travelLogger {
						do logRoads(distanceTraveled, num);
					}
				}
			}
		}
		
	}
	
	//Low-pass filter average!
	//The idea is that if there's low pheromone levels it means that it's a low demand period
	//so some vehicles could go for a charge even if they don't need it to get charged and be ready for the period of higher demand
	
	float readPheromones <- 0.0; //we don't imediately go to charge because there is a pLowPheromoneCharge which is a probability of going for a charge when reading low pheromone levels
	
	action rememberPheromones(list<tagRFID> tags) { //For low -pass filter average
		loop tag over: tags {
			readPheromones <- (1-readUpdateRate)*readPheromones + readUpdateRate*mean(tag.pheromoneMap); 
		}
	}
	
	
	tagRFID chooseWanderTarget(tagRFID fromTag, tagRFID previousTag) { 
		
		do updatePheromones(fromTag);
		
		//c.f. rnd_choice alters probability based on values, may be useful
		map<tagRFID,float> pmap <- fromTag.pheromoneMap;

		//only one road out of here, take it
		if length(pmap) = 1 { return pmap.keys[0]; }

		//no pheromones to read, choose randomly.
		if sum(pmap.values) <= 0 { return one_of( pmap.keys ); }

		
		//if the strongest pheromone is behind us, keep pheromone level with p=exploitation rate 
		if pmap[previousTag] = max(pmap) and not flip(exploitationRate) { //if max is behind and we dont exploit because of probability
			pmap[previousTag] <- 0.0; //alters local copy only :) it means it won't go back with a certain probability
		}
		
		//head toward (possibly new) strongest pheromone, or choose randomly
		if flip(exploitationRate) { //p=expoliation rate of choosing max
			return pmap index_of max(pmap);
		} else {
			return one_of( pmap.keys ); //otherwise random
		}
	}
	
	//----------------PHEROMONES-----------------
	float pheromoneToDiffuse;  //This is the amount pheromone that the vehicle difuses to the next RFID tag (in all directions)
	
	float pheromoneMark <- singlePheromoneMark; // This is the amout of pheromone that the vehicle leaves to mark a trail (in the direction where it's coming from)
	//NOTE: This took in account the amount of waste found. myself.pheromoneMark <- (singlePheromoneMark * int(self.trash/carriableTrashAmount));	
	//Since the vehicle always picks up just one person we don't adjust it anymore

	action updatePheromones(tagRFID tag) { 
		loop k over: tag.pheromoneMap.keys {
			
			//evaporation
			tag.pheromoneMap[k] <- tag.pheromoneMap[k] - (singlePheromoneMark * evaporation * step*(cycle - tag.lastUpdate)); 
			
			//saturation
			if (tag.pheromoneMap[k]<minPheromoneLevel){
				tag.pheromoneMap[k] <- minPheromoneLevel;
			}
			if (tag.pheromoneMap[k]>maxPheromoneLevel){
				tag.pheromoneMap[k] <- maxPheromoneLevel;
			}	

		}
		
		tag.lastUpdate <- cycle; //we save when it was last updated because the evaporation will be proportional to the time that passed
	}
	
	action depositPheromones(tagRFID tag, tagRFID previousTag) {
		do updatePheromones(tag);  // Saturation, Evaporation
		//TODO: Moved from the end of this function, I think we should update before marking, otherwise we might be evaporating the mark 
		
		bool depositPheromone <- state = "picking_up" or state = "in_use";
		
		loop k over: tag.pheromoneMap.keys {
			tag.pheromoneMap[k] <- tag.pheromoneMap[k] + pheromoneToDiffuse; // We diffuse to all of them
			if k = previousTag and depositPheromone {
				tag.pheromoneMap[k] <- tag.pheromoneMap[k] + pheromoneMark; // We mark the direction that we come from, add _all_ of my pheremone 
			}
		}
		
		pheromoneToDiffuse <- max(tag.pheromoneMap)*diffusion; // This is what we will diffuse in the next RFID
		//NOTE: we need to use tag. instead of self. because the vehicle is doing this action
		
	}
	
	
	/* ========================================== STATE MACHINE ========================================= */
	state wander initial: true {
		//wander the map, follow pheromones. Same as the old searching reflex
		enter {
			ask eventLogger { do logEnterState; }
			target <- nil;
		}
		transition to: picking_up when: rider != nil {}
		transition to: awaiting_follower when: follower != nil and follower.state = "seeking_leader" {}
		transition to: seeking_leader when: follower = nil and evaluateclusters() {
			//Don't form cluster if you're already a leader
			ask leader {
				do waitFor(myself);
			}
		}
		transition to: low_battery when: setLowBattery() or (readPheromones < chargingPheromoneThreshold and flip(pLowPheromoneCharge) and batteryLife < 0.75*maxBatteryLife) {
			//The low-pass filter also considers that the battery shouldn't be more than a 75% full and with a certain (low) probability so that
			// in low pheromone stages there's only a few bikes going for a charge at each time
			
			if readPheromones < chargingPheromoneThreshold {
				lowPass <- true;
			}
			else{
				lowPass <- false;
			}
		 //write "cycle: " + cycle + ","+ current_date.hour +':' + current_date.minute + ' agent ' +string(self) + ", battery life " + self.batteryLife + ' low-pass: '+ lowPass ;
		}
		exit {
			ask eventLogger { do logExitState; }
		}
		
		//Wandering is handled by the move reflex
	}
	
	state low_battery {
		//seek either a charging station or another vehicle
		enter{
			ask eventLogger { do logEnterState(myself.state); }
			target <- lastTag.nearestChargingStation.location;
		}
		transition to: getting_charge when: self.location = target {}
		exit {
			ask eventLogger { do logExitState; }
		}
		
		//Movement is handled by the move reflex
	}
	
	state getting_charge {
		//sit at a charging station until charged
		enter {
			target <- nil;
			ask eventLogger { do logEnterState("Charging at " + (chargingStation closest_to myself)); }			
			
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge + myself;
			}
		}
		transition to: wander when: batteryLife >= maxBatteryLife {}
		exit {
			ask eventLogger { do logExitState("Charged at " + (chargingStation closest_to myself)); }
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge - myself;
			}
		}
		
		//charging station will reflexively add power to this bike
	}
	
	state awaiting_follower {
		//sit at an intersection until a follower joins the cluster
		enter {
			ask eventLogger { do logEnterState("Awaiting Follower " + myself.follower); }
		}
		transition to: wander when: follower.state = "following" {}
		exit {
			ask eventLogger { do logExitState("Awaited Follower " + myself.follower); }
		}
		
		//Move reflex does not fire when in this state (see canMove)
	}
	state seeking_leader {
		//when two bikes form a cluster, one will await_follower, the other will seek_leader
		enter {
			ask eventLogger { do logEnterState("Seeking Leader " + myself.leader); }
		}
		transition to: following when: (self distance_to leader) <= followDistance {receiveChargeLogger.batteryStartReceiving <- leader.batteryLife;}
		exit {
			ask eventLogger { do logExitState("Sought Leader " + myself.leader); }
			target <- nil;
		}
		
		//best to repeat this, in case the leader moves after we save its location
		target <- leader.location;
	}
	state following {
		//transfer charge to host, follow them around the map
		enter {
			ask eventLogger { do logEnterState("Following " + myself.leader); }
		}
		transition to: wander when: shouldDecluster(leader) {}
		transition to: picking_up when: rider != nil {}
		exit {
			ask eventLogger { do logExitState("Followed " + myself.leader); }
			ask leader {
				follower <- nil;
			}
			leader <- nil;
		}
		
		location <- leader.location;
		do chargeBike(leader); //leader will update our charge level as we move along (see reduceBattery)
	}
	
		
	//BIKE - PEOPLE
	state picking_up {
		//go to rider's location, pick them up
		enter {
			self.pheromoneMark <- singlePheromoneMark;  //Here we start leaving a pheromone trail
			ask eventLogger { do logEnterState("Picking up " + myself.rider); }
			target <- rider.closestIntersection; //Go to the rider's closest intersection
		}
		
		transition to: in_use when: location=target and rider.location=target {}
		exit{
			ask eventLogger { do logExitState("Picked up " + myself.rider); }
		}
	}
	
	state in_use {
		//go to rider's destination, In Use will use it
		enter {
			ask eventLogger { do logEnterState("In Use " + myself.rider); }
			target <- (tagRFID closest_to rider.final_destination).location;
		}
		
		transition to: wander when: location=target {
			rider <- nil;
		}
		exit {
			self.pheromoneMark <- 0.0; // Here we stop leaving a pheromone trail
			ask eventLogger { do logExitState("Used" + myself.rider); }
		}
	}
}
