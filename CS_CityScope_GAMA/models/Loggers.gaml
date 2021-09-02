/**
* Name: Loggers
* Based on the internal empty template. 
* Author: qbowe
* Tags: 
*/


model Loggers
import "./clustering.gaml"



global {
	map<string, string> filenames <- []; //Maps log types to filenames
	
	action registerLogFile(string filename) {
		filenames[filename] <- './../data/' + string(starting_date, 'yyyy-MM-dd hh.mm.ss','en') + '/' + filename + '.csv';
	}
	
	action log(string filename, int level, list data, list<string> columns) {
		if not(filename in filenames.keys) {
			do registerLogFile(filename);
			save ["Cycle","Time (real)", "Time (simulation)","Agent"] + columns to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		
		if level <= loggingLevel {
			save [cycle, string(#now), time] + data to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		if level <= printLevel {
			write [cycle, string(#now), time] + data;
		}
	}
}



species Logger {
	
	action logPredicate virtual: true type: bool;
	string filename;
	list<string> columns;
	
	agent loggingAgent;
	
	action log(int level, list data) {
		if logPredicate() {
			ask host {
				do log(myself.filename, level, [string(myself.loggingAgent.name)] + data, myself.columns);
			}
		}
	}
	
}


species pheromoneLogger parent: Logger mirrors: tagRFID {
	string filename <- "pheromones";
	list<string> columns <- [
//		"Trip Served",
//		"Trip Type",
//		"Wait Time",
//		"Departure Time",
//		"Duration",
//		"Home [lat]",
//		"Home [long]",
//		"Work [lat]",
//		"Work [long]",
//		"Distance (straight Line)",
//		"Duration (estimated)"
	];
	
	bool logPredicate { return pheromoneLogs; }
	tagRFID tagtarget;
	
	init {
		tagtarget <- tagRFID(target);
		loggingAgent <- tagtarget;
	}
	
	reflex saveState {
		do log(1, tagtarget.pheromoneMap.pairs);
	}
	
}

// NOTE: Because people is now a parent class, mirroring no longer works. This is a GAMA bug and there's nothing I can do about it.
//       As a workaround, people objects now manually create their loggers
species peopleLogger_trip parent: Logger {
	string filename <- "people_trips";
	list<string> columns <- [
		"Trip Served",
		"Trip Type",
		"Wait Time",
		"Departure Time",
		"Duration",
		"Home [lat]",
		"Home [long]",
		"Work [lat]",
		"Work [long]",
		"Distance",
		"Duration (estimated)"
	];
	
	bool logPredicate { return peopleLogs; }
	people persontarget;
	
//	init {
//		persontarget <- people(target);
//		persontarget.tripLogger <- self;
//		loggingAgent <- persontarget;
//	}
	
	action logTrip(bool served, string type, float waitTime, float departure, float tripduration, point home, point work, float distance) {
		do log(1, [served, type, waitTime, departure, tripduration, home.x, home.y, work.x, work.y, distance, distance/BikeSpeed]);
	}
	
}
species peopleLogger parent: Logger {
	string filename <- "people_event";
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time",
		"End Time",
		"Duration",
		"Distance"
	];
	
	bool logPredicate { return peopleLogs; }
	people persontarget;
	
//	init {
//		persontarget <- people(target);
//		persontarget.logger <- self;
//		loggingAgent <- persontarget;
//	}
	
	
	// Variables for people's CSVs
//    float morning_wait_time; //Morning wait time [s]
//    float evening_wait_time; //Evening wait time [s]
//    float morning_ride_duration; //Morning ride duration [s]
//    float evening_ride_duration; //Evening ride duration [s]
//    float morning_ride_distance; //Morning ride distance [m]
//    float evening_ride_distance; //Evening ride distance [m]
//    float morning_total_trip_duration; //Morning total trip duration [s]
//    float evening_total_trip_duration; //Evening total trip duration [s]
//    float home_departure_time; //Home departure time [s]
//    float work_departure_time; //Work departure time [s]
//    bool morning_trip_served;
//    bool evening_trip_served;
//    
//    point location_start_ride;
	
	float tripdistance <- 0.0;
	
	float departureTime;
    float timeBikeRequested;
    float waitTime;
    
    
    int cycleStartActivity;
    point locationStartActivity;
    string currentState;
    bool served;
	
	action logEnterState { do logEnterState(""); }
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		locationStartActivity <- persontarget.location;
		currentState <- persontarget.state;
		do log(1, ['START: ' + currentState] + [logmessage]);
		
		
		switch currentState {
			match "requesting_bike" {
				//trip starts
				timeBikeRequested <- time;
				served <- false;
			}
			match "riding" {
				//trip is served
				waitTime <- time - timeBikeRequested;
				departureTime <- time;
				served <- true;
			}
			match "idle" {
				//trip has ended
				if tripdistance = 0 {
					tripdistance <- topology(roadNetwork) distance_between [persontarget.beginning_location, persontarget.final_destination];
				}
				
				if cycle != 0 {
					ask persontarget.tripLogger {
						do logTrip(
							myself.served,
							current_date.hour > 12 ? "Evening":"Morning",
							myself.waitTime,
							myself.departureTime,
							time - myself.departureTime,
							persontarget.beginning_location,
							persontarget.final_destination,
							myself.tripdistance
						);
					}
				}
			}
		}
		
	}
	action logExitState {
		do logExitState("");
	}
	action logExitState(string logmessage) {
		do log(1, ['END: ' + currentState, logmessage, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, locationStartActivity distance_to persontarget.location]);
	}
	action logEvent(string event) {
		do log(1, [event]);
	}
}

species bikeLogger_chargeEvents parent: Logger mirrors: bike {
	string filename <- 'bike_chargeevents';
	list<string> columns <- [
		"Station",
		"Start Time",
		"End Time",
		"Duration",
		"Start Battery",
		"End Battery"
	];
	bool logPredicate { return bikeLogs; }
	bike biketarget;
	
	init {
		biketarget <- bike(target);
		biketarget.chargeLogger <- self;
		loggingAgent <- biketarget;
	}
	
	action logCharge(chargingStation station, float startTime, float endTime, float chargeDuration, float startBattery, float endBattery) {
		do log(1, [station, startTime, endTime, chargeDuration, startBattery, endBattery]);
	}
}


species bikeLogger_fullState parent: Logger mirrors: bike {
	string filename <- 'bike_fullState';
	list<string> columns <- [
		"State",
		"Rider",
		"Follower",
		"Leader",
		"Battery Life",
		"Has Target",
		"Last Tag",
		"Next Tag",
		"Read Pheromones",
		"Pheromone To Diffuse",
		"Pheromone Mark"
	];
	bool logPredicate { return fullStateLogs; }
	bike biketarget;
	
	
	init {
		biketarget <- bike(target);
		loggingAgent <- biketarget;
	}
	
	reflex logFullState {
		do log(2, [
			biketarget.state,
			biketarget.rider,
			biketarget.follower,
			biketarget.leader,
			biketarget.batteryLife,
			biketarget.target != nil,
			biketarget.lastTag,
			biketarget.nextTag,
			biketarget.readPheromones,
			biketarget.pheromoneToDiffuse,
			biketarget.pheromoneMark
		]);
	}
}

species bikeLogger_roadsTraveled parent: Logger mirrors: bike {
	//`target` is the bike we mirror
	string filename <- 'bike_roadstraveled';
	list<string> columns <- [
		"Distance Traveled",
		"Num Intersections"
	];
	bool logPredicate { return bikeLogs; }
	bike biketarget;
	
	
	float totalDistance <- 0.0;
	int totalIntersections <- 0;
	
	
	init {
		biketarget <- bike(target);
		biketarget.travelLogger <- self;
		loggingAgent <- biketarget;
	}
	
	
	action logRoads(float distanceTraveled, int numIntersections) {
		totalDistance <- totalDistance + distanceTraveled;
		totalIntersections <- totalIntersections + numIntersections;
		
		do log(2, [distanceTraveled, numIntersections]);
	}
	
	float avgRoadLength {
		float overallD <- bikeLogger_roadsTraveled sum_of (each.totalDistance);
		int overallI <- bikeLogger_roadsTraveled sum_of (each.totalIntersections);
		
		return overallD / overallI;
	}
}

species bikeLogger_event parent: Logger mirrors: bike {
	//`target` is the bike we mirror
	string filename <- 'bike_event';
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time (s)",
		"End Time (s)",
		"Duration (s)",
		"Distance Traveled",
		"Duration (estimated)",
		"Start Battery",
		"End Battery"
	];
	
	
	bool logPredicate { return bikeLogs; }
	bike biketarget;
	init {
		biketarget <- bike(target);
		biketarget.eventLogger <- self;
		loggingAgent <- biketarget;
	}
	
	
	
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
	float distanceStartActivity;
	float batteryStartActivity;
	string currentState;
	
//	action logActivity(bike main, string activity, string otherInvolved){
//		if bikeLogs {
//			if biketarget.state = "wandering" {
//				save [string(main), activity, otherInvolved, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, (cycle-cycleStartActivity)*biketarget.distancePerCycle, batteryStartActivity, main.batteryLife/maxBatteryLife * 100] to: "BikeTrips.csv" type: "csv" rewrite: false;			
//			} else {
//				save [string(main), activity, otherInvolved, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, locationStartActivity distance_to main.location, batteryStartActivity, main.batteryLife/maxBatteryLife * 100] to: "BikeTrips.csv" type: "csv" rewrite: false;		
//			}
//		}
//	}
	
	action logEnterState { do logEnterState(""); }
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		batteryStartActivity <- biketarget.batteryLife/maxBatteryLife * 100;
		locationStartActivity <- biketarget.location;
		
		distanceStartActivity <- biketarget.travelLogger.totalDistance;
		
		currentState <- biketarget.state;
		do log(1, ['START: ' + biketarget.state] + [logmessage]);
	}
	action logExitState { do logExitState(""); }
	action logExitState(string logmessage) {
		float d <- biketarget.travelLogger.totalDistance - distanceStartActivity;
		do log(1, [
			'END: ' + currentState,
			logmessage,
			cycleStartActivity*step,
			cycle*step,
			cycle*step - cycleStartActivity*step,
			d,
			d/BikeSpeed,
			batteryStartActivity,
			biketarget.batteryLife/maxBatteryLife * 100
		]);
		
		
		if currentState = "getting_charge" {
			//just finished a charge
			ask biketarget.chargeLogger {
				do logCharge(
					chargingStation closest_to biketarget,
					myself.cycleStartActivity*step,
					cycle*step,
					//TODO: make charge time dependent on initial battery and charging rate
					cycle*step - myself.cycleStartActivity*step,
					myself.batteryStartActivity,
					biketarget.batteryLife/maxBatteryLife * 100
				);
			}
		}
	}
	
	
}