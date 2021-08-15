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
		filenames[filename] <- 'data/' + string(starting_date, 'yyyy-MM-dd hh.mm.ss','en') + '/' + filename + '.csv';
	}
	
	action log(string filename, int level, list data) {
		if not(filename in filenames.keys) {
			do registerLogFile(filename);
		}
		
		if level <= loggingLevel {
			save [cycle, string(#now)] + data to: filenames[filename] type: "csv" rewrite: false;
		}
		if level <= printLevel {
			write [cycle, string(#now)] + data;
		}
	}
}



species Logger {
	
	action logPredicate virtual: true type: bool;
	string filename;
	
	agent loggingAgent;
	
	action log(int level, list data) {
		if logPredicate() {
			ask host {
				do log(myself.filename, level, [string(myself.loggingAgent)] + data);
			}
		}
	}
	
}


species bikeLogger_roadsTraveled parent: Logger mirrors: bike {
	//`target` is the bike we mirror
	string filename <- 'bike_roadstraveled';
	bool logPredicate { return bikeLogs; }
	bike biketarget;
	float totalDistance <- 0.0;
	int totalIntersections <- 0;
	
	
	init {
		write "im a travel logger, tied to " + string(target);
		biketarget <- bike(target);
		biketarget.travelLogger <- self;
		loggingAgent <- biketarget;
	}
	
	
	action logRoads(float distanceTraveled, int numIntersections) {
		totalDistance <- totalDistance + distanceTraveled;
		totalIntersections <- totalIntersections + numIntersections;
		
		do log(2, ["Distance Traveled:", distanceTraveled, "Num Intersections", numIntersections]);
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
	float batteryStartActivity;
	string currentState;
	
	action logActivity(bike main, string activity, string otherInvolved){
		if bikeLogs {
			if biketarget.state = "wandering" {
				save [string(main), activity, otherInvolved, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, (cycle-cycleStartActivity)*biketarget.distancePerCycle, batteryStartActivity, main.batteryLife/maxBatteryLife * 100] to: "BikeTrips.csv" type: "csv" rewrite: false;			
			} else {
				save [string(main), activity, otherInvolved, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, locationStartActivity distance_to main.location, batteryStartActivity, main.batteryLife/maxBatteryLife * 100] to: "BikeTrips.csv" type: "csv" rewrite: false;		
			}
		}
	}
	
	action logEnterState { do logEnterState(nil); }
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		batteryStartActivity <- biketarget.batteryLife/maxBatteryLife * 100;
		locationStartActivity <- biketarget.location;
		currentState <- biketarget.state;
		do log(1, ['Entered State: ' + biketarget.state] + (logmessage != nil ? ['Message: ' + logmessage] : []));
	}
	action logExitState {
		do logExitState("");
	}
	action logExitState(string logmessage) {
		do log(1, ['Exiting State: ' + currentState, 'Message: ' + logmessage, cycleStartActivity*step, cycle*step, cycle*step - cycleStartActivity*step, locationStartActivity distance_to biketarget.location, batteryStartActivity, biketarget.batteryLife/maxBatteryLife * 100]);
	}
	
	
}