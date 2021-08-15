/**
* Name: Loggers
* Based on the internal empty template. 
* Author: qbowe
* Tags: 
*/


model Loggers
import "./Agents.gaml"

/* Insert your model definition here */
species Logger {
	
	action logPredicate virtual: true type: bool;
	
	
	action log(string filename, int level, list data) {
		if logPredicate() {
			ask host {
				do log(filename, level, data);
			}
		}
	}
}
species bikeLogger_roadsTraveled mirrors: bike parent: Logger {
	//`target` is the bike we mirror
	float totalDistance <- 0.0;
	int totalIntersections <- 0;
	
	
	init {
		bike(target).travelLogger <- self;
	}
	bool logPredicate { return bikeLogs; }
	
	action logRoads(float distanceTraveled, int numIntersections) {
		totalDistance <- totalDistance + distanceTraveled;
		totalIntersections <- totalIntersections + numIntersections;
		
		do log(bikeFile, 1, [string(target), "Distance Travelled:", distanceTraveled, "Num Intersections", numIntersections]);
	}
	
	float avgRoadLength {
		float overallD <- bikeLogger_roadsTraveled sum_of (each.totalDistance);
		int overallI <- bikeLogger_roadsTraveled sum_of (each.totalIntersections);
		
		return overallD / overallI;
	}	
}