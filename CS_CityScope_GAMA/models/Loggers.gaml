model Loggers
import "./clustering.gaml"



global {
	map<string, string> filenames <- []; //Maps log types to filenames
	
	action registerLogFile(string filename) {
		filenames[filename] <- './../data/' + string(logDate, 'yyyy-MM-dd hh.mm.ss','en') + '/' + filename + '.csv';
	}
	
	//action log(string filename, int level, list data, list<string> columns) {
	action log(string filename, list data, list<string> columns) {
		if not(filename in filenames.keys) {
			do registerLogFile(filename);
			save ["Cycle", "Time","Agent"] + columns to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		
		//if level <= loggingLevel {
		if loggingEnabled {
			save [cycle, string(current_date, "HH:mm:ss")] + data to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		if  printsEnabled {
			write [cycle, string(current_date,"HH:mm:ss")] + data;
		} 
	}
	
	action logForSetUp (list<string> parameters) {
		loop param over: parameters {
			save (param) to: './../data/' + string(logDate, 'yyyy-MM-dd hh.mm.ss','en') + '/' + 'setUp' + '.txt' type: "text" rewrite: false header: false;}
	}
	
	action logSetUp { 
		list<string> parameters <- [
		"Nbikes: "+string(numBikes),
		"MaxWait: "+string(maxWaitTime/60),
		"WanderSpeed: "+string(WanderingSpeed*3.6),
		"Evap: "+string(evaporation),
		"Expol: "+string(exploitationRate),
		"------------------------------SIMULATION PARAMETERS------------------------------",
		"Step: "+string(step),
		"Starting Date: "+string(starting_date),
		"Number of Days of Simulation: "+string(numberOfDays),
		"Number ot Hours of Simulation (if less than one day): "+string(numberOfHours),

		"------------------------------BIKE PARAMETERS------------------------------",
		"Number of Bikes: "+string(numBikes),
		"Max Battery Life of Bikes [km]: "+string(maxBatteryLife/1000 with_precision 2),
		"Wandering speed [km/h]: "+string(WanderingSpeed*3.6),
		"Pick-up speed [km/h]: "+string(PickUpSpeed*3.6),
		"Minimum Battery [%]: "+string(minSafeBattery/maxBatteryLife*100),
		
		"------------------------------PEOPLE PARAMETERS------------------------------",
		//"numPeople: "+string(numPeople),
		"Maximum Wait Time [min]: "+string(maxWaitTime/60),
		"Walking Speed [km/h]: "+string(peopleSpeed*3.6),
		"Riding speed [km/h]: "+string(RidingSpeed*3.6),
		"Bike Selection Cost Coefficient: "+string(bikeCostBatteryCoef),
		
		"------------------------------PHEROMONE PARAMETERS------------------------------",
		"Pheromones Enabled: "+string(pheromonesEnabled),
		"Wandering Enabled: "+string(wanderingEnabled),
		"Single Pheromone Mark: "+string(singlePheromoneMark),
		"Exploitation Rate: "+string(exploitationRate),
		"Evaporation Rate: "+string(evaporation),
		"Max Pheromone Level: "+string(maxPheromoneLevel),
		"Min Pheromone Level: "+string(minPheromoneLevel),
		
		"------------------------------CLUSTERING PARAMETERS------------------------------",
		"Clustering Enabled: "+string(clusteringEnabled),
		"Max Radius form Cluster [m]: "+string(clusterDistance),
		"Cluster Threshold Min Battery[m]: "+string(clusterThreshold),
		"Follow Distance [m]: "+string(followDistance),
		"V2V Charging Rate [m/s]: "+string(V2VChargingRate with_precision 2),
		
		"------------------------------STATION PARAMETERS------------------------------",
		"Number of Charging Stations: "+string(numChargingStations),
		"V2I Charging Rate: "+string(V2IChargingRate  with_precision 2),
		"Charging Station Capacity: "+string(chargingStationCapacity),
		
		
		"------------------------------TASK SWITCH PARAMETERS------------------------------",
		"Task Switch Enabled: "+ string(taskSwitchEnabled),
		"Low-Pheromone Threshold to Switch to Charging: "+string(chargingPheromoneThreshold),
		"Probabiliy of Switching if Low Pheromones: "+string(pLowPheromoneCharge),
		"Reading Update Rate: "+string(readUpdateRate),

		"------------------------------MAP PARAMETERS------------------------------",
		"City Map Name: "+string(cityScopeCity),
		"Redisence: "+string(residence),
		"Office: "+string(office),
		"Usage: "+string(usage),
		"Color Map: "+string(color_map),
		
		"------------------------------LOGGING PARAMETERS------------------------------",
		"Print Enabled: "+string(printsEnabled),
		"Bike Event/Trip Log: " +string(bikeEventLog),
		"Bike Full State Log: " + string(bikeStateLog),
		"People Trip Log: " + string(peopleTripLog),
		"People Event Log: " + string(peopleEventLog),
		"Station Charge Log: "+ string(stationChargeLogs),
		"Clustering Charge Log: "+string(clusteringLogs),
		"Pheromone Logs: "+string(pheromoneLogs),
		"Roads Traveled Log: " + string(roadsTraveledLog),
		"Tangible Logs: "+string(tangibleLogs)
		];
		do logForSetUp(parameters);
		}
}



species Logger {
	
	action logPredicate virtual: true type: bool;
	string filename;
	list<string> columns;
	
	agent loggingAgent;
	
	//action log(int level, list data) {
	action log(list data) {
		if logPredicate() {
			ask host {
				do log(myself.filename, [string(myself.loggingAgent.name)] + data, myself.columns);
			} 
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
	
	reflex saveState when: pheromoneLogs {
		float average <- tagtarget.pheromoneMap.pairs sum_of (each.value);
		point tagtarget_WGS84 <- CRS_transform(tagtarget.location,"EPSG:4326").location;
		do log([tagtarget_WGS84.x,tagtarget_WGS84.y,average/length(tagtarget.pheromoneMap.pairs)]); //TODO rev: removed 100*
	}
	
}


species peopleLogger_trip parent: Logger mirrors: people {
	string filename <- "people_trips";
	list<string> columns <- [
		"Trip Served",
		//"Trip Type",
		"Wait Time (min)",
		"Departure Time",
		"Arrival Time",
		"Duration (min)",
		"Home [lat]",
		"Home [lon]",
		"Work [lat]",
		"Work [lon]",
		"Distance (m)"
	];
	
	bool logPredicate { return peopleTripLog; }
	people persontarget;
	
	init {
		persontarget <- people(target);
		persontarget.tripLogger <- self;
		loggingAgent <- persontarget;
	}
	
	action logTrip(bool served, float waitTime, date departure, date arrival, float tripduration, point origin, point destination, float distance) {
		
		point origin_WGS84 <- CRS_transform(origin, "EPSG:4326").location; //project the point to WGS84 CRS
		point destination_WGS84 <- CRS_transform(destination, "EPSG:4326").location; //project the point to WGS84 CRS
		string dep;
		string des;
		
		if departure= nil {dep <- nil;}else{dep <- string(departure,"HH:mm:ss");}
		
		if arrival = nil {des <- nil;} else {des <- string(arrival,"HH:mm:ss");}
		
		do log([served, waitTime,dep ,des, tripduration, origin_WGS84.x, origin_WGS84.y, destination_WGS84.x, destination_WGS84.y, distance]);
	} 
	
}
species peopleLogger parent: Logger mirrors: people {
	string filename <- "people_event";
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Distance (m)"
	];
	
	bool logPredicate { return peopleEventLog; }
	people persontarget;
	
	init {
		persontarget <- people(target);
		persontarget.logger <- self;
		loggingAgent <- persontarget;
	}
	
	float tripdistance <- 0.0;
	
	date departureTime;
	int departureCycle;
    int cycleBikeRequested;
    float waitTime;
    int cycleStartActivity;
    date timeStartActivity;
    point locationStartActivity;
    string currentState;
    bool served;
    
    string timeStartstr;
    string currentstr;
	
	action logEnterState { do logEnterState(""); }
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		timeStartActivity <- current_date;
		locationStartActivity <- persontarget.location;
		currentState <- persontarget.state;
		if peopleEventLog {do log(['START: ' + currentState] + [logmessage]);}
		
		if peopleTripLog{ //because trips are logged by the eventLogger
		switch currentState {
			match "requesting_bike" {
				//trip starts
				cycleBikeRequested <- cycle;
				served <- false;
			}
			match "riding" {
				//trip is served
				waitTime <- (cycle*step- cycleBikeRequested*step)/60;
				departureTime <- current_date;
				departureCycle <- cycle;
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
							myself.waitTime,
							myself.departureTime,
							current_date,
							(cycle*step - myself.departureCycle*step)/60,
							persontarget.start_point.location,
							persontarget.target_point.location,
							myself.tripdistance
						);
					}
				}
			}
		}}
		
	}
	action logExitState {
		do logExitState("");
	}
	action logExitState(string logmessage) {
		
		if timeStartActivity= nil {timeStartstr <- nil;}else{timeStartstr <- string(timeStartActivity,"HH:mm:ss");}
		if current_date = nil {currentstr <- nil;} else {currentstr <- string(current_date,"HH:mm:ss");}
		
		do log(['END: ' + currentState, logmessage, timeStartstr, currentstr, (cycle*step - cycleStartActivity*step)/60, locationStartActivity distance_to persontarget.location]);
	}
	action logEvent(string event) {
		do log([event]);
	}
}

species bikeLogger_chargeEvents parent: Logger mirrors: bike { //Station Charging
	string filename <- 'bike_station_charge';
	list<string> columns <- [
		"Station",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %",
		"Low Pheromone"
	];
	bool logPredicate { return stationChargeLogs; }
	bike biketarget;
	string startstr;
	string endstr;
	
	init {
		biketarget <- bike(target);
		biketarget.chargeLogger <- self;
		loggingAgent <- biketarget;
	}
	
	action logCharge(chargingStation station, date startTime, date endTime, float chargeDuration, float startBattery, float endBattery, float batteryGain, bool lowPass) {
				
		if startTime= nil {startstr <- nil;}else{startstr <- string(startTime,"HH:mm:ss");}
		if endTime = nil {endstr <- nil;} else {endstr <- string(endTime,"HH:mm:ss");}
		
		
		
		do log([station, startstr, endstr, chargeDuration, startBattery, endBattery, batteryGain, lowPass]);
	}
}

species bikeLogger_ReceiveChargeEvents parent: Logger mirrors: bike { // Cluster charging
	string filename <- 'bike_clustering_charge';
	list<string> columns <- [
		"Other Agent",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %"
	];
	bool logPredicate { return clusteringLogs; }
	bike biketarget;
	float batteryStartReceiving;
	string startstr;
	string endstr;
	
	init {
		biketarget <- bike(target);
		biketarget.receiveChargeLogger <- self;
		loggingAgent <- biketarget;
	}
	
	action logReceivedCharge(agent leader, date startTime, date endTime, float chargeDuration, float startBattery, float endBattery, float batteryGain) {
		
		
		if startTime= nil {startstr <- nil;}else{startstr <- string(startTime,"HH:mm:ss");}
		if endTime = nil {endstr <- nil;} else {endstr <- string(endTime,"HH:mm:ss");}
		
		
		do log([leader.name, startstr, endstr, chargeDuration, startBattery, endBattery, batteryGain]);
	}
}

species bikeLogger_fullState parent: Logger mirrors: bike {
	string filename <- 'bike_full_state';
	list<string> columns <- [
		"State",
		"Rider",
		"Follower",
		"Leader",
		"Battery Level %",
		//"Max Battery Life",
		"Has Target",
		"Last Tag",
		"Next Tag",
		"Read Pheromones",
		"Pheromone To Diffuse",
		"Pheromone Mark"
	];
	bool logPredicate { return bikeStateLog; }
	bike biketarget;
	
	
	init {
		biketarget <- bike(target);
		loggingAgent <- biketarget;
	}
	
	reflex logFullState when: bikeStateLog {
		do log([
			biketarget.state,
			biketarget.rider,
			biketarget.follower,
			biketarget.leader,
			(biketarget.batteryLife/maxBatteryLife*100),
			//int(maxBatteryLife),
			biketarget.target != nil,
			biketarget.lastTag,
			biketarget.nextTag,
			//int(100*biketarget.readPheromones),
			//int(100*biketarget.pheromoneToDiffuse),
			//int(100*biketarget.pheromoneMark)
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
	bool logPredicate { return roadsTraveledLog; }
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
		
		do log( [distanceTraveled, numIntersections]);
	}
	
	/*float avgRoadLength {
		float overallD <- bikeLogger_roadsTraveled sum_of (each.totalDistance);
		int overallI <- bikeLogger_roadsTraveled sum_of (each.totalIntersections);
		
		return overallD / overallI;
	}*/
}

species bikeLogger_event parent: Logger mirrors: bike {
	//`target` is the bike we mirror
	string filename <- 'bike_trip_event';
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Distance Traveled",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %",
		"Low Pheromone"
	];
	
	
	bool logPredicate { return bikeEventLog; }
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
	date timeStartActivity;
	point locationStartActivity;
	float distanceStartActivity;
	float batteryStartActivity;
	string currentState;
	
	//string lowPass;
	
	action logEnterState { do logEnterState(""); }
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		timeStartActivity <- current_date;
		batteryStartActivity <- biketarget.batteryLife;
		locationStartActivity <- biketarget.location;
		
		distanceStartActivity <- biketarget.travelLogger.totalDistance;
		
		currentState <- biketarget.state;
		do log( ['START: ' + biketarget.state] + [logmessage]);
	}
	action logExitState { do logExitState(""); }
	action logExitState(string logmessage) {
		float d <- biketarget.travelLogger.totalDistance - distanceStartActivity;
		string timeStartstr;
		string currentstr;
		
		if timeStartActivity= nil {timeStartstr <- nil;}else{timeStartstr <- string(timeStartActivity,"HH:mm:ss");}
		if current_date = nil {currentstr <- nil;} else {currentstr <- string(current_date,"HH:mm:ss");}
		
		
		do log( [
			'END: ' + currentState,
			logmessage,
			timeStartstr,
			currentstr,
			(cycle*step - cycleStartActivity*step)/(60),
			d,
			batteryStartActivity/maxBatteryLife*100,
			biketarget.batteryLife/maxBatteryLife*100,
			(biketarget.batteryLife-batteryStartActivity)/maxBatteryLife*100,
			biketarget.lowPass
		]);
		
		
		if currentState = "getting_charge" {
			//just finished a charge
			ask biketarget.chargeLogger {
				do logCharge(
					chargingStation closest_to biketarget,
					myself.timeStartActivity,
					current_date,
					(cycle*step - myself.cycleStartActivity*step)/(60),
					myself.batteryStartActivity/maxBatteryLife*100,
					biketarget.batteryLife/maxBatteryLife*100,
					(biketarget.batteryLife-myself.batteryStartActivity)/maxBatteryLife*100,
					biketarget.lowPass
				);
			}
		}
		
		if currentState = "following" {
			//just finished a charge
			ask biketarget.receiveChargeLogger {
				do logReceivedCharge(
					biketarget.leader,
					myself.timeStartActivity,
					current_date,
					(cycle*step - myself.cycleStartActivity*step)/(60),
					batteryStartReceiving/maxBatteryLife*100,
					(biketarget.leader.batteryLife/maxBatteryLife*100),
					((biketarget.leader.batteryLife-batteryStartReceiving)/maxBatteryLife*100)
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

	
	reflex saveState when: tangibleLogs {
	
		do log([biketarget.state,biketarget.location.x,biketarget.location.y,biketarget.heading,biketarget.batteryLife/maxBatteryLife*100]);

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
	
	
	reflex saveState when: tangibleLogs {
	
		do log([persontarget.state,persontarget.location.x,persontarget.location.y,persontarget.heading]);

	}
	
}


