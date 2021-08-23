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
		ask dockingStationCapacity first bikesToCharge {
			batteryLife <- batteryLife + step*V2IChargingRate;
		}
		//save ["Question2", string(self),length(bikesToCharge)] to: "vkt_NoBikesSimultCharged.csv" type: "csv" rewrite: false;
	}
}

species tagRFID {
	int id;
	string type;
	
	map<tagRFID,float> pheromoneMap;
	
	
	
	int lastUpdate; //Cycle
	
	chargingStation nearestChargingStation;
	geometry towardChargingStation;
	int distanceToChargingStation;
	
	//easy access to neighbors
	list<tagRFID> neighbors {
		return pheromoneMap.keys;
	}
	
	
	rgb color;
	reflex set_color {
		color <- #purple;
	}
	aspect base {
		draw circle(10) color:color border: #black;
	}
	
	aspect realistic {
		draw circle(1+5*max(pheromoneMap)) color:rgb(107,171,158);
	}
}

species people control: fsm skills: [moving] {
	
	rgb color <- #yellow ;
    building living_place; //Home [lat,lon]
    building working_place; //Work [lat, lon]
    int start_work;
    int end_work;
    
    // Variables for people's CSVs
    float morning_wait_time; //Morning wait time [s]
    float evening_wait_time; //Evening wait time [s]
    float morning_ride_duration; //Morning ride duration [s]
    float evening_ride_duration; //Evening ride duration [s]
    float morning_ride_distance; //Morning ride distance [m]
    float evening_ride_distance; //Evening ride distance [m]
    float morning_total_trip_duration; //Morning total trip duration [s]
    float evening_total_trip_duration; //Evening total trip duration [s]
    float home_departure_time; //Home departure time [s]
    float work_departure_time; //Work departure time [s]
    bool morning_trip_served;
    bool evening_trip_served;
    float time_start_ride;
    point location_start_ride;
    float timeBikeRequested;
        
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
    
    //----------------PUBLIC FUNCTIONS-----------------
	// these are how other agents interact with this one. Not used by self
    action ride(bike b) {
    	bikeToRide <- b;
    }
    
    
    //----------------PRIVATE FUNCTIONS-----------------
	// no other species should touch these
	
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
			write "cycle: " + cycle + ", "+ string(self) + " is requesting bike";
			closestIntersection <- (tagRFID closest_to(self)).location;
		}
		
		transition to: walking when: host.requestBike(self) {
			//Walk to closest intersection, ask a bike to meet me there
			//save ["Question1and2", 1] to: "vkt_percentageServed.csv" type: "csv" rewrite: false;
			if timeToWork() {home_departure_time <- time; morning_trip_served <- true;}
			if timeToSleep() {work_departure_time <- time; evening_trip_served <- true;}
			//bikeToRide <- host.requestBike(self);
			//bikeToRide.rider <- self;
			timeBikeRequested <- time #s;
			target <- closestIntersection;
		}
		transition to: idle {
			//teleport home
			//save ["Question1", 0] to: "vkt_percentageServed.csv" type: "csv" rewrite: false;
			if timeToWork() {home_departure_time <- time; morning_trip_served <- false; morning_wait_time <- nil; morning_ride_distance <- nil; morning_total_trip_duration <- nil;}
			if timeToSleep() {
				work_departure_time <- time; evening_trip_served <- false; evening_wait_time <- nil; evening_ride_distance <- nil; evening_total_trip_duration <- nil;
				save [string(self),living_place.location,working_place.location,home_departure_time,morning_trip_served,morning_wait_time,morning_ride_duration,morning_ride_distance,morning_total_trip_duration,work_departure_time,evening_trip_served,evening_wait_time,evening_ride_duration,evening_ride_distance,evening_total_trip_duration] to: "People.csv" type: "csv" rewrite: false;
			}
			location <- final_destination;
			write "wait too long, teleported to destination";
		}
	}
	state awaiting_bike {
		//Sit at the intersection and wait for your bike
		enter {
			write "cycle: " + cycle + ", "+ string(self) + " is awaiting bike";
			target <- nil;
		}
		
		transition to: riding when: bikeToRide.state = "dropping_off" {
			//save ["Question1", time - timeBikeRequested] to: "vkt_averageWaitingTime.csv" type: "csv";
			location_start_ride <- self.location;
			time_start_ride <- time;
			if timeToWork() {morning_wait_time <- time - home_departure_time;}
			if timeToSleep() {evening_wait_time <- time - work_departure_time;}
		}
	}
	state riding {
		//do nothing, follow the bike around until it drops you off and you have to walk
		transition to: walking when: bikeToRide.state != "dropping_off" {
			if timeToWork() {morning_ride_duration <- time - time_start_ride; morning_ride_distance <- location_start_ride distance_to self.location;}
			if timeToSleep() {evening_ride_duration <- time - time_start_ride; evening_ride_distance <- location_start_ride distance_to self.location;}
			target <- final_destination;
		}
		enter {
			write "cycle: " + cycle + ", "+ string(self) + " is riding" + string(bikeToRide);
		}
		exit { bikeToRide <- nil; }
		
		//Always be at the same place as the bike
		location <- bikeToRide.location;
	}
	state walking {
		//go to your destination or nearest intersection, then wait
		transition to: idle when: location = final_destination {
			if timeToWork() {morning_total_trip_duration <- time - home_departure_time;}
			if timeToSleep() {
				evening_total_trip_duration <- time - work_departure_time;
				save [string(self),living_place.location,working_place.location,home_departure_time,morning_trip_served,morning_wait_time,morning_ride_duration,morning_ride_distance,morning_total_trip_duration,work_departure_time,evening_trip_served,evening_wait_time,evening_ride_duration,evening_ride_distance,evening_total_trip_duration] to: "People.csv" type: "csv" rewrite: false;
			}
		}
		transition to: awaiting_bike when: location = target {}
		enter {
			write "cycle: " + cycle + string(self) + "is walking";
		}
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

		draw circle(10) color:color;
	}
	
	point target;
//	path wanderPath;
//	point source;
	
	float pheromoneToDiffuse; //represents a store of pheremone (a bike can't expend more than this amount). Pheremone is restored by ___
	float pheromoneMark; //initialized to 0, never updated. Unsure what this represents
	
	//this should be affected by how many bikes there are in a cluster
		//[Q] Nah. Instead, see the energy_cost function
	float batteryLife; //Number of meters we can travel on current battery
	float distancePerCycle;
	
	int lastDistanceToChargingStation;
	
	bike leader;
	//bike follower;
	
	list<bike> followers;
	
	bool any_awaiting <- true; //checks if a bike has any followers that are awaiting_leader
	bool every_follower_following <- false; //checks if all of a bike's followers are actually following
	
	chargingStation stationCharging; //Station where being charged [id]
	float chargingStartTime; //Charge start time [s]
	float batteryLifeBeginningCharge; //Battery when beginning charge [%]
	
	/*//Activities' start times
	float timeStartWandering;
	float timeStartPickingUp;
	float timeStartDroppingOff;
	float timeStartSeekingLeader;
	float timeStartAwaitingFollower;
	float timeStartFollowing;
	float timeStartGoingForACharge;
	
	//Activities' distances variables
	float distanceWandering;
	point locationStartPickingUp;
	point locationStartDroppingOff;
	point locationStartSeekingLeader;
	point locationStartAwaitingFollower;
	point locationStartFollowing;
	point locationStartGoingForACharge;
	
	//Battery when beggining activity
	float batteryStartWandering;
	float batteryStartPickingUp;
	float batteryStartDroppingOff;
	float batteryStartSeekingLeader;
	float batteryStartAwaitingFollower;
	float batteryStartFollowing;
	float batteryStartGoingForACharge;*/
	int cycleStartActivity;	
	point locationStartActivity;
	float batteryStartActivity;
	
	//----------------PUBLIC FUNCTIONS-----------------
	// these are how other agents interact with this one. Not used by self
	bool availableForRide {
		return (state = "idle" or state = "following") and !setLowBattery();
	}
	bool availableForPlatoon {
		// Bike must either be idle, or awaiting another follower, have no followers
		//TODO: may need more filters. Must exclude dropping_off, for example
		return (state = "idle" or state = "awaiting_follower" or length(followers) = 0) and leader = nil and !setLowBattery();
	}
	//transition from idle to picking_up. Called by the global scheduler
	people rider <- nil;	
	action pickUp(people person) {
		rider <- person;
	}
	action waitFor(bike other) {
		// other is the follower bike
		if self.followers index_of other = -1{
			self.any_awaiting <- true; // makes sure that the leader will wait for any followers
			self.followers <- self.followers + other;
		}
	}
	action notFollowing(bike other) {
		// other is the follower bike
		if self.followers index_of other != -1{
			self.followers <- self.followers - other;
		}
	}
	
	
	//OVERALL TASK
	// A function that would simulate what happens when vehicles cluster in terms of energy sharing and aerodynamics as a function of the number, type of vehicles, and speed
	
	
	//----------------PRIVATE FUNCTIONS-----------------
	// no other species should touch these
	
	
	//-----CLUSTERING
	//These are our cost functions, and will be the basis of how we decide to form clusters
	float clusterCost(bike other) {
		if length(other.followers) > 0{
			float total_to_give <- 0.0;
			loop i from: 0 to: length(other.followers) - 1{
				total_to_give <- total_to_give + chargeToGive(other.followers at i);
			}
			//write "total to give: " + total_to_give;
			return 10000 - total_to_give;
		}
		else {
			//write "single charge to give: " + chargeToGive(other);
			return 10000 - chargeToGive(other);
		}
	}
	float declusterCost(bike other) {
		//Don't decluster until you need to or you've nothing left to give
		if other.state = "dropping_off" { return -10.0; }
		if setLowBattery() { return -10.0; }
		if chargeToGive(other) <= 0 { return -10.0; }
		// other will be the leader of a swarm
		if length(other.followers) >= 5 { return -10.0; }
		return 100.0;
	}
	
	//decide to follow another bike
	bool evaluateclusters {
		//create a map of every available bike within a certain distance and their clustering costs
		//perhaps we want to cluster with following bikes in the future. Megacluster
		map<bike, float> costs <- map(((bike where (each.availableForPlatoon())) at_distance clusterDistance) collect(each::clusterCost(each)));
		
		if empty(costs) { return false; }
		
		float minCost <- min(costs.values);
		if minCost < clusterThreshold {
			leader <- costs.keys[ costs.values index_of minCost ];
			return true;
		}
		
		return false;
	}
	
	//TODO: make this take into account speed and number of bikes in cluster
	//determines how much charge we could give another bike
	float chargeToGive(bike other) {
		//never go less than some minimum battery level
		//never charge leader to have more power than you
		float chargeDifference <- batteryLife - other.batteryLife;
		float chargeToSpare <- batteryLife - minSafeBattery;
		float batteryToSpare <- maxBatteryLife - other.batteryLife;
		return min(chargeDifference/2, chargeToSpare, batteryToSpare);
	}
	action chargeBike(bike other) {
		float transfer <- min( step*V2VChargingRate, chargeToGive(other));
		
		leader.batteryLife <- leader.batteryLife + transfer;
		batteryLife <- batteryLife - transfer;
	}
	
	
	
	//-----BATTERY
	float saturateBattery(float value) {
		if value < 0.0 { return 0.0;}
		if value > maxBatteryLife { return maxBatteryLife;}
		
		return value;
	}
	//Determines when to move into the low_battery state
	bool setLowBattery {
		//TODO: perhaps all these minimum values should be merged into one, to be respected here and in cluster-charging
		if batteryLife < 3*distancePerCycle { return true; } //leave 3 simulation-steps worth of movement
		if batteryLife < minSafeBattery { return true; } //we have a minSafeBattery value, might as well respect it
		return batteryLife < 10*lastDistanceToChargingStation; //safety factor
	}
	float energyCost(float distance) { //This function will let us alter the efficiency of our bikes, if we decide to look into that
		if state = "dropping_off" { return 0.0; } //user will pedal
		return distance;
	}
	action reduceBattery(float distance) {
		save ["Question2", energyCost(distance)] to: "vkt_energyConsumption.csv" type: "csv" rewrite: false;
		batteryLife <- batteryLife - energyCost(distance);
		batteryLife <- saturateBattery( batteryLife - energyCost(distance) );
		if length(followers) != 0 {
			loop i from: 0 to: length(followers) - 1{
				bike follower <- followers at i;
				ask follower {
					do reduceBattery(distance);
				}
			}
		}
	}
	
	reflex checkAwaiting {
		if length(followers) != 0 and (self.state = "idle" or self.state = "awaiting_follower"){
			bool any_awaiting_here <- false;
			loop i from: 0 to: length(followers) - 1{
				bike follower <- followers at i;
				//write "follower " + string(follower) + " has leader " + string(self) + " and is currently " + follower.state;
				any_awaiting_here <- any_awaiting_here or follower.state = "seeking_leader";
			}
			if any_awaiting_here != any_awaiting{
				if any_awaiting_here {
					write string(self) + " is awaiting followers";
					write self.followers;
				}
				any_awaiting <- any_awaiting_here;				
			}
		}
	}
	
	reflex checkFollowers {
		if length(followers) != 0 {
			bool all_following <- true;
			loop i from: 0 to: length(followers) - 1{
				bike follower <- followers at i;
				all_following <- all_following and follower.state = "following";
			}
			if all_following != every_follower_following{
				//write "all of " + string(self) +"'s followers are following: " + all_following;
				every_follower_following <- all_following;
			}
		}
	}

	reflex deathWarning when: batteryLife = 0 {
		write "NO POWER!";
//		ask host {
//			do pause;
//		}
	}
	
	
	//-----MOVEMENT
	path travelledPath; //preallocation. Only used within the moveTowardTarget reflex
	
	float pathLength(path p) {
		if empty(p) or p.shape = nil { return 0; }
		return p.shape.perimeter; //TODO: may be accidentally doubled
	}
	list<tagRFID> lastIntersections;
	
	tagRFID lastTag; //last RFID tag we passed. Useful for wander function
	tagRFID nextTag; //tag we ended on OR the next tag we will reach
	
	bool canMove {
		return state != "awaiting_follower" and target != location and (target != nil or state="idle") and batteryLife > 0;
	}
	
	
	path moveTowardTarget {
		//TODO: Think about redefining this save thing once we implement charging btw vehicles also with low charge
		if state = "low_battery" {
			save ["Question2", self.location distance_to target] to: "vkt_forCharge.csv" type: "csv" rewrite: false;
		}
		return goto(on:roadNetwork, target:target, return_path: true);
	}
	path wander {
		//construct a plan, so we don't waste motion: Where will we turn from the next intersection? If we have time left in the cycle, where will we turn from there? And from the intersection after that?
		list<point> plan <- [location, nextTag.location];
		
		
		loop while: pathLength(path(plan)) < distancePerCycle {
			tagRFID newTag <- chooseWanderTarget(nextTag, lastTag);
			
			lastTag <- nextTag;
			nextTag <- newTag;
			plan <- plan + newTag.location;
		}
		
		//using follow can result in some drift when the road is curved (follow will use straight lines). I have not found a solution to this
		return follow(path:path(plan), return_path: true);
	}
	
	reflex move when: canMove() {
		//do goto (or follow in the case of wandering, where we've prepared a probably-suboptimal route)
		travelledPath <- (state = "idle") ? wander() : moveTowardTarget();
		float distanceTraveled <- pathLength(travelledPath);
		
		do reduceBattery(distanceTraveled);
		
		if state = "idle" {
			save ["Question1", string(self), distanceTraveled] to: "vkt_rebalancing.csv" type: "csv" rewrite: false;
		}
		
			
		if !empty(travelledPath) {
			/* update pheromones exactly once, when we cross a new intersection
			 * we could (should) have crossed multiple intersections over the last move. The location of each intersection
			 * will show up in `vertices`, as they are the boundaries between new edges
			 * simply casting the points to intersections is incorrect though, as we may get intersections that are close to
			 * the points in question, but not actually on the path. We may also get duplicates. The filter removes both of these.
			 */
			
			//oldest intersection is first in the list
			
			list<tagRFID> newIntersections <- travelledPath.vertices where (tagRFID(each).location = each);
			int num <- length(newIntersections);
			
			
			//update pheromones from first traveled to last traveled, ignoring those that were updated last cycle
			
			
			//update lastTag, nextTag. If we landed on nextTag, remove it from the list
			if (!empty(newIntersections)) {
				tagRFID mostRecentTag <- last(newIntersections);
				tagRFID penultimateTag <- num = 1 ? last(lastIntersections) : newIntersections[num - 2];
				
				if location = mostRecentTag.location {
					//we have stopped at an intersection
					nextTag <- mostRecentTag;
					lastTag <- penultimateTag;
					newIntersections <- copy_between( newIntersections, 0, num-1); 
					//pop the last intersection off the end, we'll process it next iteration
					//(We should always read the data _before_ we overwrite it. We have not yet read this tag, so we push writing over it to the future)
					//Also prevents overlap between new and last intersection lists
				} else {
					//we have stopped in the middle of a road
					lastTag <- mostRecentTag;
					
					//current edge will have two points on it, one is lastTag, the otherr is nextTag
					nextTag <- tagRFID( (current_edge.points where (each != lastTag.location))[0] );
				}
			}
			
			//remember read pheromones without looking at what we have added to them
			do rememberPheromones(newIntersections);
			//add pheromones
			loop tag over: newIntersections {
				do depositPheromones(tag);
//				tag.color <- #yellow;
			}
			
			//the future is now old man (overwrite old saved data)
			lastIntersections <- newIntersections;
		}
		
		lastDistanceToChargingStation <- lastTag.distanceToChargingStation;
	}
	
	//Low-pass filter average!
	float readPheromones <- 2*chargingPheromoneThreshold; //init above the threshold so we don't imediately go to charge
	float alpha <- 0.2; //tune this so our average updates at desired speed
	action rememberPheromones(list<tagRFID> tags) {
		loop tag over: tags {
			readPheromones <- (1-alpha)*readPheromones + alpha*mean(tag.pheromoneMap);
		}
	}
	
	
	tagRFID chooseWanderTarget(tagRFID fromTag, tagRFID previousTag) {
		do updatePheromones(fromTag);
		
		
		//c.f. rnd_choice alters probability based on values, but we have determined they are all 0, so this should be uniform
		//may be useful
		
		map<tagRFID,float> pmap <- fromTag.pheromoneMap;

		if length(pmap) = 1 { //only one road out of here, take it
			return pmap.keys[0];
		}

		if sum(pmap.values) <= 0 {
			return one_of( pmap.keys ); //choose randomly.
		}

		
		//if the strongest pheromone is behind us, keep pheromone level with p=exploratory rate
		if pmap[previousTag] = max(pmap) and not flip(exploratoryRate) {
			pmap[previousTag] <- 0.0; //alters local copy only :)
		}
		
		if flip(exploratoryRate) {
			return pmap index_of max(pmap);
		} else {
			return one_of( pmap.keys );
		}
	}
	
	
	//-----PHEROMONES
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
		
		
		tag.lastUpdate <- cycle;
	}
	
	
	action depositPheromones(tagRFID tag) {
		
		// add _all_ of my pheremone to nearest tag. If I am picking someone up, add 0 to pheremone tag (???). Set my pheremone levels to whatever the tag has diffused to me
		bool depositPheromone <- state = "picking_up" or state = "dropping_off";
		loop k over: tag.pheromoneMap.keys {
			tag.pheromoneMap[k] <- tag.pheromoneMap[k] + pheromoneToDiffuse; //Why do we add pheromone to all of them?
			if k = lastTag and depositPheromone {
				tag.pheromoneMap[k] <- tag.pheromoneMap[k] + pheromoneMark; //This line does nothing and I don't understand why
			}
		}
		
		
		// Saturation, Evaporation
		do updatePheromones(tag);
		
		pheromoneToDiffuse <- max(tag.pheromoneMap)*diffusion;
	}
	
	//-----LOG TO CSV
	//Save activity information into CSV BikeTrips.csv
	action logActivity(bike main, string activity, string otherInvolved){
		if csvs {
			if state = "wandering" {
			save [string(main), activity, otherInvolved, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, (cycle-cycleStartActivity)*distancePerCycle, batteryStartActivity, main.batteryLife/maxBatteryLife * 100] to: "BikeTrips.csv" type: "csv" rewrite: false;			
			}
			else {
				save [string(main), activity, otherInvolved, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, locationStartActivity distance_to main.location, batteryStartActivity, main.batteryLife/maxBatteryLife * 100] to: "BikeTrips.csv" type: "csv" rewrite: false;		
			}
		}
	}
	
	//-----STATE MACHINE
	state idle initial: true {
		//wander the map, follow pheromones. Same as the old searching reflex
		enter {
			target <- nil;
			cycleStartActivity <- cycle;
			batteryStartActivity <- self.batteryLife/maxBatteryLife * 100;
		    if length(followers) = 0{
		    	write "cycle: " + cycle + ", " + string(self) + " is wandering";	
		    }
		    else {
		    	write "cycle: " + cycle + ", " + string(self) + " is wandering with followers " + followers;
		    }
			target <- nil;
		}
		
		transition to: awaiting_follower when: length(followers) != 0 and any_awaiting {}
		transition to: seeking_leader when: length(followers) = 0 and evaluateclusters() {
			write string(self) + " is now going to follow " + leader;
			ask leader {
				// self is leading bike
				// myself is following bike
				write string(self) + " is now a leader";
				do waitFor(myself);
			}
		}
		transition to: low_battery when: setLowBattery() or readPheromones < chargingPheromoneThreshold {}
		transition to: picking_up when: rider != nil {}
		
		exit {
//			wanderPath <- nil;
		}
		
		//Wandering is handled by the move reflex
	}
	
	state low_battery {
		//seek either a charging station or another vehicle
		enter{
			//write "cycle: " + cycle + ", " + string(self) + " has low battery";
			
			//Technically, the bike would pause at each intersection to read the direction to the nearest charging station
			//This wastes a lot of time in simulation, so we are cheating
			//The path the bike follows is identical.
			target <- lastTag.nearestChargingStation.location;
		}
		transition to: getting_charge when: self.location = target {}
		
		
//		source <- location;
	}
	
	state getting_charge {
		//sit at a charging station until charged
		enter {
			write "cycle: " + cycle + ", " + string(self) + " is getting charged in station";
			target <- nil;
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge + myself;
				myself.chargingStartTime <- time;
				myself.stationCharging <- self;
				myself.batteryLifeBeginningCharge <- myself.batteryLife/maxBatteryLife * 100;
			}
		}
		transition to: idle when: batteryLife >= maxBatteryLife {}
		exit {
			//TODO: If possible, refine this so that bikes are not overcharged and we use that time.
			batteryLife <- maxBatteryLife;
			save [string(self), string(self.stationCharging), self.chargingStartTime, time - self.chargingStartTime, time, self.batteryLifeBeginningCharge, self.batteryLife/maxBatteryLife * 100] to: "ChargeInstances.csv" type: "csv" rewrite: false;
			ask chargingStation closest_to(self) {
				bikesToCharge <- bikesToCharge - myself;
			}
		}
	}
	
	state awaiting_follower {
		//sit at an intersection until a follower joins the cluster
		enter {
			cycleStartActivity <- cycle;
			locationStartActivity <- self.location;
			batteryStartActivity <- self.batteryLife/maxBatteryLife * 100;
			write "cycle: " + cycle + ", " + string(self) + " is awaiting follower " + string(followers);
		}
		transition to: idle when: every_follower_following {}
	}
	state seeking_leader {
		//catch up to the leader
		//(when two bikes form a cluster, one will await_follower, the other will seek_leader)
		enter {
			cycleStartActivity <- cycle;
			locationStartActivity <- self.location;
			batteryStartActivity <- self.batteryLife/maxBatteryLife * 100;
			write "cycle: " + cycle + ", " + string(self) + " is seeking " + leader;
		}
		transition to: following when: (self distance_to leader) <= followDistance {}
		exit {
			do logActivity(self, "seekingLeader", string(leader));
			target <- nil;
		}
		
		//best to repeat this, in case the leader moves after we save its location
		target <- leader.location;
	}
	state following {
		//transfer charge to host, follow them around the map
		location <- leader.location;
		do chargeBike(leader);
		//leader will update our charge level as we move along (see reduceBattery)
		//TODO: While getting charged, if there is a request for picking up, charging vehicle must leave
		enter {
			cycleStartActivity <- cycle;
			locationStartActivity <- self.location;
			batteryStartActivity <- self.batteryLife/maxBatteryLife * 100;
			write "cycle: " + cycle + ", " + string(self) + " is following " + leader;
		}
		transition to: idle when: declusterCost(leader) < declusterThreshold {}
		transition to: picking_up when: rider != nil {}
		exit {
			do logActivity(self, "following", string(leader));
			ask leader {
				// self is leading bike
				// myself is following bike
				write "cycle: " + cycle + ", " + string(myself) + " has stopped following " + string(self);
				do notFollowing(myself);
			}
			leader <- nil;
		}
	}
	
	//BIKE - PEOPLE
	state picking_up {
		//go to rider's location, pick them up
		enter {
			cycleStartActivity <- cycle;
			locationStartActivity <- self.location;
			batteryStartActivity <- self.batteryLife/maxBatteryLife * 100;
			write "cycle: " + cycle + ", " + string(self) + " is picking up "+string(rider);
			target <- rider.closestIntersection; //Go to the rider's closest intersection
			//save ["Question1", string(self), self.location distance_to target] to: "vkt_pickingUp.csv" type: "csv" rewrite: false;
		}
		
		transition to: dropping_off when: location=target and rider.location=target{			}
		exit{
			do logActivity(self, "pickingUp", string(rider));	
		}
	}
	
	state dropping_off {
		//go to rider's destination, drop them off
		enter {
			cycleStartActivity <- cycle;
			locationStartActivity <- self.location;
			batteryStartActivity <- self.batteryLife/maxBatteryLife * 100;
			write "cycle: " + cycle + ", " + string(self) + " is dropping off "+string(rider);
			target <- (tagRFID closest_to rider.final_destination).location;
		}
		
		transition to: idle when: location=target {
			rider <- nil;
		}
		exit {
			do logActivity(self, "droppingOff", string(rider));	
		}
	}
}

