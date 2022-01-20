model Loggers
import "./clustering.gaml"



global {
	map<string, string> filenames <- []; //Maps log types to filenames
	
	action registerLogFile(string filename) {
		filenames[filename] <- './../data/' + string(logDate, 'yyyy-MM-dd hh.mm.ss','en') + '/' + filename + '.csv';
	}
	
	action log(string filename, int level, list data, list<string> columns) {
		if not(filename in filenames.keys) {
			do registerLogFile(filename);
			save ["Cycle", "Time","Agent"] + columns to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		
		if level <= loggingLevel {
			save [cycle, date(current_date)] + data to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		if level <= printLevel {
			write [cycle, date(current_date)] + data;
		}
	}
	
	action logForSetUp (list<string> parameters) {
		loop param over: parameters {
			save (param) to: './../data/' + string(logDate, 'yyyy-MM-dd hh.mm.ss','en') + '/' + 'setUp' + '.txt' type: "text" rewrite: false header: false;}
	}
	
	action logSetUp { //TODO: To complete with the rest of parameters
		list<string> parameters <- [
		"------------------------------SIMULATION PARAMETERS------------------------------",
		"Step: "+string(step),
		"Starting Date: "+string(starting_date),
		"Number of Days of Simulation: "+string(numberOfDays),
		"------------------------------LOGGING PARAMETERS------------------------------",
		"Logging Level: "+string(loggingLevel),
		"Print Level: "+string(printLevel),
		"Bike Logs: "+string(bikeLogs),
		"People Logs: "+string(peopleLogs),
		"People File: "+string(peopleFile),
		"Station Logs: "+string(stationLogs),
		"Station File: "+string(stationFile),
		"Pheromone Logs: "+string(pheromoneLogs),
		"------------------------------PHEROMONE PARAMETERS------------------------------",
		"Single Pheromone Mark: "+string(singlePheromoneMark),
		"Exploitation Rate: "+string(exploitationRate),
		"Diffusion Rate: "+string(diffusion),
		"Max Pheromone Level: "+string(maxPheromoneLevel),
		"Min Pheromone Level: "+string(minPheromoneLevel),
		"Pheromone Threshold Index:"+string(chargingPheromoneThreshold/singlePheromoneMark),
		"Probability Low Pheromone Charge"+string(pLowPheromoneCharge),
		"------------------------------BIKE PARAMETERS------------------------------",
		"Number of Bikes to Generate: "+string(numBikes),
		"Max Battery Life of Bikes [m]: "+string(maxBatteryLife),
		"Wandering speed [m/s]: "+string(WanderingSpeed),
		"Pick-up speed [m/s]: "+string(PickUpSpeed),
		"Riding speed [m/s]: "+string(RidingSpeed),
		"Cluster Distance (Radius in which we look for bikes to cluster with) [m]: "+string(clusterDistance),
		"Cluster Threshold (the charge a follower must be able to give the leader in order to cluster) [m]: "+string(clusterThreshold),
		"Follow Distance [m]: "+string(followDistance),
		"V2V Charging Rate [m/s]: "+string(V2VChargingRate),
		"Charging Pheromone Threshold (disables charge-seeking when low pheromone): "+string(chargingPheromoneThreshold),
		"MinSafeBattery (amount of battery always reserved when charging another bike, also at which we seek battery) [m]: "+string(minSafeBattery),
		"maxDistance [m]: "+string(maxDistance),
		"------------------------------STATION PARAMETERS------------------------------",
		"numChargingStations: "+string(numChargingStations),
		"V2IChargingRate: "+string(V2IChargingRate),
		"chargingStationCapacity: "+string(chargingStationCapacity),
		"------------------------------PEOPLE PARAMETERS------------------------------",
		//"numPeople: "+string(numPeople),
		"maxWaitTime: "+string(maxWaitTime),
		"peopleSpeed: "+string(peopleSpeed),
		"bikeCostBatteryCoef: "+string(bikeCostBatteryCoef),
		"------------------------------MAP PARAMETERS------------------------------",
		"cityScopeCity: "+string(cityScopeCity),
		"Redisence: "+string(residence),
		"Office: "+string(office),
		"Usage: "+string(usage),
		"Color Map: "+string(color_map)
		];
		do logForSetUp(parameters);
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
			} //TODO: fix the string so that it doesn't say bike(3) but only 3 
		}
	}
	
}


species pheromoneLogger parent: Logger mirrors: tagRFID {
	string filename <- "pheromones";
	list<string> columns <- [
		"Tag [lat]",
		"Tag [lon]",
		"AveragePheromones"
	];
	
	bool logPredicate { return pheromoneLogs; }
	tagRFID tagtarget;
	
	init {
		tagtarget <- tagRFID(target);
		loggingAgent <- tagtarget;
	}
	
	reflex saveState {
		float average <- tagtarget.pheromoneMap.pairs sum_of (each.value);
		do log(1, [int(tagtarget.location.x),int(tagtarget.location.y),int(100*average/length(tagtarget.pheromoneMap.pairs))]);
	}
	
}


species peopleLogger_trip parent: Logger mirrors: people {
	string filename <- "people_trips";
	list<string> columns <- [
		"Trip Served",
		"Trip Type",
		"Wait Time (min)",
		"Departure Time (min)",
		"Duration (min)",
		"Home [lat]",
		"Home [lon]",
		"Work [lat]",
		"Work [lon]",
		"Distance (m)",
		"Duration (estimated)"
	];
	
	bool logPredicate { return peopleLogs; }
	people persontarget;
	
	init {
		persontarget <- people(target);
		persontarget.tripLogger <- self;
		loggingAgent <- persontarget;
	}
	
	action logTrip(bool served, string type, int waitTime, int departure, int tripduration, point home, point work, float distance) {
		do log(1, [served, type, waitTime/60, departure/60, tripduration/60, int(home.x), int(home.y), int(work.x), int(work.y), distance, string(int(distance/WanderingSpeed))]);
	}
	
}
species peopleLogger parent: Logger mirrors: people {
	string filename <- "people_event";
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time (min)",
		"End Time (min)",
		"Duration (min)",
		"Distance (m)"
	];
	
	bool logPredicate { return peopleLogs; }
	people persontarget;
	
	init {
		persontarget <- people(target);
		persontarget.logger <- self;
		loggingAgent <- persontarget;
	}
	
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
			match "wander" {
				//trip has ended
				if tripdistance = 0 {
					tripdistance <- topology(roadNetwork) distance_between [persontarget.start_point, persontarget.target_point];
				}
				
				if cycle != 0 {
					ask persontarget.tripLogger {
						do logTrip(
							myself.served,
							current_date.hour > 12 ? "Evening":"Morning",
							int(myself.waitTime),
							int(myself.departureTime),
							int(time - myself.departureTime),
							persontarget.start_point.location,
							persontarget.target_point.location,
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
		do log(1, ['END: ' + currentState, logmessage, cycleStartActivity*step/60, cycle*step/60, (cycle*step - cycleStartActivity*step)/60, locationStartActivity distance_to persontarget.location]);
	}
	action logEvent(string event) {
		do log(1, [event]);
	}
}

species bikeLogger_chargeEvents parent: Logger mirrors: bike { //Station Charging
	string filename <- 'bike_chargeevents';
	list<string> columns <- [
		"Station",
		"Start Time (min)",
		"End Time (min)",
		"Duration (min)",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %",
		"Low Pheromone"
	];
	bool logPredicate { return bikeLogs; }
	bike biketarget;
	
	init {
		biketarget <- bike(target);
		biketarget.chargeLogger <- self;
		loggingAgent <- biketarget;
	}
	
	action logCharge(chargingStation station, int startTime, int endTime, int chargeDuration, int startBattery, int endBattery, int batteryGain, string lowPass) {
		do log(1, [station, startTime, endTime, chargeDuration, startBattery, endBattery, batteryGain, lowPass]);
	}
}

species bikeLogger_ReceiveChargeEvents parent: Logger mirrors: bike { // Cluster charging
	string filename <- 'bike_receiveChargeEvents';
	list<string> columns <- [
		"Start Time (min)",
		"End Time (min)",
		"Duration (min)",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %"
	];
	bool logPredicate { return bikeLogs; }
	bike biketarget;
	float batteryStartReceiving;
	
	init {
		biketarget <- bike(target);
		biketarget.receiveChargeLogger <- self;
		loggingAgent <- biketarget;
	}
	
	action logReceivedCharge(agent leader, int startTime, int endTime, int chargeDuration, int startBattery, int endBattery, int batteryGain) {
		do log(1, [leader, startTime, endTime, chargeDuration, startBattery, endBattery, batteryGain]);
	}
}

species bikeLogger_fullState parent: Logger mirrors: bike {
	string filename <- 'bike_fullState';
	list<string> columns <- [
		"State",
		"Rider",
		"Follower",
		"Leader",
		"Battery Life %",
		//"Max Battery Life",
		"Has Target",
		"Last Tag",
		"Next Tag",
		"Read Pheromones",
		"Pheromone To Diffuse",
		"Pheromone Mark"
	];
	bool logPredicate { return bikeLogs; }
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
			int(biketarget.batteryLife/maxBatteryLife*100),
			//int(maxBatteryLife),
			biketarget.target != nil,
			biketarget.lastTag,
			biketarget.nextTag,
			int(100*biketarget.readPheromones),
			int(100*biketarget.pheromoneToDiffuse),
			int(100*biketarget.pheromoneMark)
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
		"Start Time (min)",
		"End Time (min)",
		"Duration (min)",
		"Distance Traveled",
		"Duration (estimated)",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %",
		"Low Pheromone Levels"
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
	
	int cycleStartActivity;
	point locationStartActivity;
	float distanceStartActivity;
	float batteryStartActivity;
	string currentState;
	
	string lowPass;
	
	action logEnterState { do logEnterState(""); }
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		batteryStartActivity <- biketarget.batteryLife;
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
			int(cycleStartActivity*step/(60)),
			int(cycle*step/(60)),
			int((cycle*step - cycleStartActivity*step)/(60)),
			int(d),
			int(d/WanderingSpeed), //TODO: Change this, as wandering speed does not apply for every state
			int(batteryStartActivity/maxBatteryLife*100),
			int(biketarget.batteryLife/maxBatteryLife*100),
			int((biketarget.batteryLife-batteryStartActivity)/maxBatteryLife*100),
			biketarget.lowPass
		]);
		
		
		if currentState = "getting_charge" {
			//just finished a charge
			ask biketarget.chargeLogger {
				do logCharge(
					chargingStation closest_to biketarget,
					int(myself.cycleStartActivity*step/(60)),
					int(cycle*step/(60)),
					//TODO: make charge time dependent on initial battery and charging rate
					int((cycle*step - myself.cycleStartActivity*step)/(60)),
					int(myself.batteryStartActivity/maxBatteryLife*100),
					int(biketarget.batteryLife/maxBatteryLife*100),
					int((biketarget.batteryLife-myself.batteryStartActivity)/maxBatteryLife*100),
					myself.lowPass
				);
			}
		}
		
		if currentState = "following" {
			//just finished a charge
			ask biketarget.receiveChargeLogger {
				do logReceivedCharge(
					biketarget.leader,
					int(myself.cycleStartActivity*step/(60)),
					int(cycle*step/(60)),
					int((cycle*step - myself.cycleStartActivity*step)/(60)),
					int(batteryStartReceiving/maxBatteryLife*100),
					int(biketarget.leader.batteryLife/maxBatteryLife*100),
					int((biketarget.leader.batteryLife-batteryStartReceiving)/maxBatteryLife*100)
				);
			}
		}
		
	}
	
	
}

species bikeLogger_tangible parent: Logger mirrors: bike{
	bool logPredicate { return tangibleLogs; }
	list<string> columns <- [
		"State",
		"Lat",
		"Lon",
		"Heading",
		"Battery"
	];

	
	string filename <- "bike_tangible";
	bike biketarget;
	init {
		biketarget <- bike(target);
		biketarget.tangibleBikeLogger <- self;
		loggingAgent <- biketarget;
	}

	
	reflex saveState {
	
		do log(1,[biketarget.state,biketarget.location.x,biketarget.location.y,biketarget.heading,biketarget.batteryLife/maxBatteryLife*100]);

	}

}

species peopleLogger_tangible parent: Logger mirrors: people {
	string filename <- "people_tangible";
	list<string> columns <- [
		"State",
		"Lat",
		"Lon",
		"Heading"
	];
	
	bool logPredicate { return tangibleLogs; }
	people persontarget;
	
	init {
		
		persontarget <- people(target);
		persontarget.tangiblePeopleLogger <- self;
		loggingAgent <- persontarget;
	}
	
	
	reflex saveState {
	
		do log(1,[persontarget.state,persontarget.location.x,persontarget.location.y,persontarget.heading]);

	}
	
}


