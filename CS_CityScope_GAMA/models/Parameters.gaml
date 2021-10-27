/**
* Name: Parameters
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Parameters

import "./clustering.gaml"
/* Insert your model definition here */
global {
	//----------------------Simulation Parameters------------------------
	//Simulation time step
	float step <- 35.0 #sec;
	//Simulation starting date
	//date starting_date <- #now;
	date starting_date <- date("2021-10-12 06:00:00");
	date logDate <- #now;
	//How many days we simulate
	int numberOfDays <- 1;
	int numberOfHours <- 14; //If one day, we can also specify the number of hours, otherwise set 24h


	
	//----------------------Logging Parameters------------------------
	int loggingLevel <- 10		min: 0 max: 10 parameter: "Logging Level" category: "Logs";
	int printLevel <- 0		min: 0 max: 10 parameter: "Printing Level" category: "Logs";
	bool bikeLogs <- true		parameter: "Bike Logs" category: "Logs";
	string bikeFile <- "bikes"	parameter: "Bike Logfile" category: "Logs";
	bool peopleLogs <- true		parameter: "People Logs" category: "Logs";
	string peopleFile <- "people"	parameter: "Person Logfile" category: "Logs";
	bool stationLogs <- true		parameter: "Charging Station Logs" category: "Logs";
	string stationFile <- "stations"	parameter: "Charging Station Logfile" category: "Logs";
	bool pheromoneLogs <- true;
	
	//----------------------Pheromone Parameters------------------------
    float singlePheromoneMark <- 1.0;
	float evaporation <- 1.0; //unsure of this value - changed evaporation to be proportional to time instead of cycles
	float exploratoryRate <- 0.8;
	float diffusion <- (1-exploratoryRate) * 0.5; 
	float maxPheromoneLevel <- 50*singlePheromoneMark;
	float minPheromoneLevel <- 0.0;
	
	//----------------------Bike Parameters------------------------
	//Number of Bikes to generate. Juan: Change this so nb is generated according to real GIS Data.
	int numBikes <- 50 				min: 0 max: 500 parameter: "Num Bikes:" category: "Initial";
	//Max battery life of bikes - Maximum number of meters with the battery
	float maxBatteryLife <- 50000.0 #m	min: 10000#m max: 300000#m parameter: "Battery Capacity (m):" category: "Bike";
	//speed of bikes - about 5.5  m/s for PEV (it can be changed accordingly to different robot specification)
	float WanderingSpeed <- 3/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Bike Wandering  Speed (m/s):" category:  "Bike";
	float PickUpSpeed <-  8/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Bike Pick-up Speed (m/s):" category:  "Bike";
	float RidingSpeed <-  10.2/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Riding Speed (m/s):" category:  "Bike";
	
	float clusterDistance <- 300#m; //Radius in which we look for bikes to cluster with
	float clusterThreshold <- 0.05*maxBatteryLife; //(see bike.clusterCost) the charge a follower must be able to give the leader in order to cluster
	
	float followDistance <- 5#m;
	float V2VChargingRate <- maxBatteryLife/(1*60*60) #m/#s; //assuming 1h fast charge
	
	float chargingPheromoneThreshold <- 0*singlePheromoneMark; //Disables charge-seeking when low pheromone
	
	
	float minSafeBattery <- 0.25*maxBatteryLife #m; //Amount of battery always reserved when charging another bike, also at which we seek battery
	//int numberOfStepsReserved <- 3; //number of simulation steps worth of movement to reserve before seeking charge
	//int distanceSafetyFactor <- 10; //factor of distancetochargingstaiton at which we seek charge
	float tripSafetyFactor <- 1.15;
	
	
	
	
	//----------------------numChargingStationsion Parameters------------------------
	//Number of charging stations
	int numChargingStations <- 2 	min: 1 max: 10 parameter: "Num Charging Stations:" category: "Initial";
	float V2IChargingRate <- maxBatteryLife/(4.5*60*60) #m/#s; // min: 1.4 #m/#s max: 20 #m/#s parameter: "V2I Charging Rate (m/s):" category: "Charging";
	int chargingStationCapacity <- 25; //TODO: review, this limit is not working
	
	//----------------------People Parameters------------------------
	int numPeople <- 250 				min: 0 max: 1000 parameter: "Num People:" category: "Initial";
	float maxWaitTime <- 20#mn		min: 3#mn max: 60#mn parameter: "Max Wait Time:" category: "People";
	float rideDistance <- maxWaitTime*60*PickUpSpeed #m;
    int workStartMin <- 6			min: 4 max: 12 parameter: "Min Work Start Time:" category: "People";
    int workStartMax <- 10			min: 4 max: 12 parameter: "Max Work Start Time:" category: "People";
    int workEndMin <- 16			min: 14 max: 24 parameter: "Min Work End Time:" category: "People";
    int workEndMax <- 20			min: 14 max: 24 parameter: "Max Work End Time:" category: "People";
    float peopleSpeed <- 5/3.6 #m/#s	min: 1/3.6 #m/#s max: 10/3.6 #m/#s parameter: "People Speed (m/s):" category: "People";
//    float maxSpeedPeople <- 5.0 #km/#h	min: 0.5#km/#h max: 10#km/#h parameter: "People Max Speed (m/s):" category: "People";
    
    float bikeCostBatteryCoef <- 200.0; //(see global.bikeCost)relative importance of batterylife when selecting bikes to ride
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