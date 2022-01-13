/**
* Name: Parameters
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Parameters

import "./clustering.gaml"

global {
	//----------------------Simulation Parameters------------------------
	
	//Simulation time step
	float step <- 35 #sec; //For tangible we need about 0.1s
	
	//Simulation starting date
	date starting_date <- date("2021-10-12 06:00:00"); // <- #now; TODO: Change to now 
	
	//Date for log files
	date logDate <- #now;
	
	//Duration of the simulation
	int numberOfDays <- 1; //WARNING: If >1 set numberOfHours to 24h
	int numberOfHours <- 14; //WARNING: If one day, we can also specify the number of hours, otherwise set 24h
	
	//----------------------Logging Parameters------------------------
	int loggingLevel <- 10		min: 0 max: 10 parameter: "Logging Level" category: "Logs"; // Question posted as issue on GitHUb
	int printLevel <- 0		min: 0 max: 10 parameter: "Printing Level" category: "Logs";
	bool bikeLogs <- true		parameter: "Bike Logs" category: "Logs";
	string bikeFile <- "bikes"	parameter: "Bike Logfile" category: "Logs";
	bool peopleLogs <- true		parameter: "People Logs" category: "Logs";
	string peopleFile <- "people"	parameter: "Person Logfile" category: "Logs";
	bool stationLogs <- true		parameter: "Charging Station Logs" category: "Logs";
	string stationFile <- "stations"	parameter: "Charging Station Logfile" category: "Logs";
	bool pheromoneLogs <- true;
	bool tangibleLogs <- false; //Output for tangible swarm-bots
	
	//----------------------Pheromone Parameters------------------------
    float singlePheromoneMark <- 1.0;
	float evaporation <- 0.15; //0.05%, *0.15%,* and 0.3% in the paper but we changed evaporation to be proportional to time instead of just cycles
	float exploitationRate <- 0.6; // Paper values: *0.6*, 0.75, and 0.9. Note: 0.8 means 0.2 of randomness 
	float diffusion <- (1-exploitationRate) * 0.5;  // the more they explore randomly, they are less 'trustable' so they have to diffuse less for system convergence
	float maxPheromoneLevel <- 50*singlePheromoneMark; //satutration
	float minPheromoneLevel <- 0.0;
	
	//----------------------Bike Parameters------------------------
	int numBikes <- 50 				min: 0 max: 500 parameter: "Num Bikes:" category: "Initial";
	float maxBatteryLife <- 30000.0 #m	min: 10000#m max: 300000#m parameter: "Battery Capacity (m):" category: "Bike"; //battery capacity in m
	float WanderingSpeed <- 3/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Bike Wandering  Speed (m/s):" category:  "Bike";
	float PickUpSpeed <-  8/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Bike Pick-up Speed (m/s):" category:  "Bike";
	float RidingSpeed <-  10.2/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Riding Speed (m/s):" category:  "Bike";
	
	float clusterDistance <- 300#m; //Radius in which we look for bikes to cluster with
	float clusterThreshold <- 0.05*maxBatteryLife; //(see bike.clusterCost) the charge a follower must be able to give the leader in order to cluster
	
	float followDistance <- 0.1#m; //distance at which we consider bikes to be clustered and able to share battery
	float V2VChargingRate <- maxBatteryLife/(1*60*60) #m/#s; //assuming 1h fast charge
	
	float chargingPheromoneThreshold <- 0.02*singlePheromoneMark; //Disables charge-seeking when low pheromone
	float pLowPheromoneCharge <- 0.01; // probability of going for a charge when reading low pheromone levels
	
	float minSafeBattery <- 0.25*maxBatteryLife #m; //Amount of battery at which we seek battery and that is always reserved when charging another bike
	
	//Old - other parameters to decide if a bike should go for a charge 
	//int numberOfStepsReserved <- 3; //number of simulation steps worth of movement to reserve before seeking charge
	//int distanceSafetyFactor <- 10; //factor of distancetochargingstaiton at which we seek charge
	
	//Inactive- If bikes are going to consume battery when the user is riding and we assume users provide their desired destination in advances we could implement this again
	//float tripSafetyFactor <- 1.15;
	//TODO: make users consume battery while riding 
	
	//----------------------numChargingStationsion Parameters------------------------
	int numChargingStations <- 2 	min: 1 max: 10 parameter: "Num Charging Stations:" category: "Initial";
	float V2IChargingRate <- maxBatteryLife/(4.5*60*60) #m/#s; //4.5 h of charge
	int chargingStationCapacity <- 15; //TODO: review, is this working? What is the status of the bikes while waiting?
	
	//----------------------People Parameters------------------------
	//int numPeople <- 250 				min: 0 max: 1000 parameter: "Num People:" category: "Initial";
	float maxWaitTime <- 20#mn		min: 3#mn max: 60#mn parameter: "Max Wait Time:" category: "People";
	float maxDistance <- maxWaitTime*60*PickUpSpeed #m; //The maxWaitTime is translated into a max radius taking into account the speed of the bikes
    /* OLD 
    int workStartMin <- 6			min: 4 max: 12 parameter: "Min Work Start Time:" category: "People";
    int workStartMax <- 10			min: 4 max: 12 parameter: "Max Work Start Time:" category: "People";
    int workEndMin <- 16			min: 14 max: 24 parameter: "Min Work End Time:" category: "People";
    int workEndMax <- 20			min: 14 max: 24 parameter: "Max Work End Time:" category: "People";*/
    float peopleSpeed <- 5/3.6 #m/#s	min: 1/3.6 #m/#s max: 10/3.6 #m/#s parameter: "People Speed (m/s):" category: "People";
    
    float bikeCostBatteryCoef <- 200.0; //(see global.bikeCost)relative importance of batterylife when selecting bikes to ride
    
    //NEW demand 
    
    string cityDemandFolder <- "./../includes/Demand";
    csv_file demand_csv <- csv_file (cityDemandFolder+ "/user_trips_new.csv",true);
     
    //csv_file demand_csv <- csv_file (cityDemandFolder+ "/user_trips_"+ demand_i +".csv",true);
    //int demand_i <- 0 min: 0 max: 5 parameter: "Demand File:" category "Pepole";
     //csv_file f <- csv_file("file.csv", ";",int,true, {5, 100});//TODO: review -2474 1 day
     
     
    //----------------------Map Parameters------------------------
	
	//Case 1 - Urban Swarms Map
	string cityScopeCity <- "UrbanSwarm";
	string residence <- "R";
	string office <- "O";
	string usage <- "Usage";
	//Case 2 - Cambridge Map
	/*string cityScopeCity <- "Cambridge";
	string residence <- "Residential";
	string office <- "Office";
	string usage <- "Category";*/

    map<string, rgb> color_map <- [residence::#white, office::#gray, "Other"::#black];
    
	//GIS FILES To Upload
	string cityGISFolder <- "./../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp")			parameter: "Road Shapefile:" category: "GIS";
	
	//Case Cambridge Map
	//file chargingStations <- file(cityGISFolder + "/chargingStations.shp");
	//file chargingStations <- file("./../includes/City/clustering" + "/chargingStations.shp");
	 
	//Image File
	file imageRaster <- file('./../images/gama_black.png');
			
}	