model Parameters

import "./clustering.gaml"

global {
	//----------------------Simulation Parameters------------------------
	
	//Simulation time step
	float step <- 5 #sec; //For tangible we need about 0.1s
	
	//Simulation starting date
	date starting_date <- date("2021-10-12 00:00:00"); //TODO: Change to 00:00:00
	
	//Date for log files
	//date logDate <- #now;

	date logDate <- date("2022-06-29 03:00:00");
	
	date nowDate <- #now;
	//Duration of the simulation
	int numberOfDays <- 1; //WARNING: If >1 set numberOfHours to 24h
	int numberOfHours <- 24; //WARNING: If one day, we can also specify the number of hours, otherwise set 24h
	
	//----------------------Logging Parameters------------------------
	//int loggingLevel <- 10		min: 0 max: 10 parameter: "Logging Level" category: "Logs"; // Question posted as issue on GitHUb
	bool loggingEnabled <- true parameter: "Logging" category: "Logs";
	bool printsEnabled <- false parameter: "Printing" category: "Logs";
	
	bool bikeEventLog <-true parameter: "Bike Event/Trip Log" category: "Logs";
	bool bikeStateLog <-false parameter: "Bike Full State Log" category: "Logs";
	
	bool peopleTripLog <-true parameter: "People Trip Log" category: "Logs";
	bool peopleEventLog <-false parameter: "People Event Log" category: "Logs";
	
	bool stationChargeLogs <- true parameter: "Station Charge Log" category: "Logs";
	
	bool pheromoneLogs <- false  parameter: "Pheromone Log" category: "Logs";
	bool clusteringLogs <- true parameter: "Clustering Charge Log" category: "Logs";
	
	bool roadsTraveledLog <- false parameter: "Roads Traveled Log" category: "Logs";
	bool tangibleLogs <- false parameter: "Tangible Log" category: "Logs"; //Output for tangible swarm-bots


	
	//----------------------Pheromone Parameters------------------------
	bool pheromonesEnabled <- true ; // If false the PheromoneMark will always be zero and the bikes will just wander
	bool wanderingEnabled <- true; // Sets WanderingSpeed to zero
	
    float singlePheromoneMark <- 0.01; //0.5 in ours, 0.01 as a param in original code, set to 0.5 for SwarmBot
	float evaporation <- 0.15; //0.05%, *0.15%,* and 0.3% in the paper but we changed evaporation to be proportional to time instead of just cycles
	float exploitationRate <- 0.95; // Paper values: *0.6*, 0.75, and 0.9. Note: 0.8 means 0.2 of randomness  (exploration)	//*****
	//float diffusion <- (1-exploitationRate) * 0.5;  // the more they explore randomly, they are less 'trustable' so they have to diffuse less for system convergence
	float diffusion <- exploitationRate*0.5 ; // the more exploit vs expore the more trustable
	float maxPheromoneLevel <- 50*singlePheromoneMark; //satutration
	float minPheromoneLevel <- 0.0;
	
	//------------------- Task Switch Pheromone Levels----------------------
	bool taskSwitchEnabled <- false;
	float chargingPheromoneThreshold <- 0.00002*singlePheromoneMark; //Enables charge-seeking when low pheromone
	float pLowPheromoneCharge <- 0.02; // probability of going for a charge when reading low pheromone levels
	float readUpdateRate <- 0.5 ; //tune this so our average updates at desired speed
	
	//----------------------Bike Parameters------------------------
	int numBikes <- 300 				min: 0 max: 3000 parameter: "Num Bikes:" category: "Initial";
	float maxBatteryLife <- 30000.0 #m	min: 10000#m max: 300000#m parameter: "Battery Capacity (m):" category: "Bike"; //battery capacity in m
	float WanderingSpeed <- 3/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Bike Wandering  Speed (m/s):" category:  "Bike";
	float PickUpSpeed <-  8/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Bike Pick-up Speed (m/s):" category:  "Bike";
	float RidingSpeed <-  10.2/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Riding Speed (m/s):" category:  "Bike";
	float minSafeBattery <- 0.25*maxBatteryLife #m; //Amount of battery at which we seek battery and that is always reserved when charging another bike
	
	
	// -------------------- Clustering------------------------------
	bool clusteringEnabled <-false; // Toggle for enabling and disabling clustering
	
	float clusterDistance <- 300#m; //Radius in which we look for bikes to cluster with
	float clusterThreshold <- 0.05*maxBatteryLife; //(see bike.clusterCost) the charge a follower must be able to give the leader in order to cluster
	float followDistance <- 0.1#m; //distance at which we consider bikes to be clustered and able to share battery
	float V2VChargingRate <- maxBatteryLife/(1*60*60) #m/#s; //assuming 1h fast charge

	
	//----------------------numChargingStationsion Parameters------------------------
	int numChargingStations <- 21 	min: 1 max: 100 parameter: "Num Charging Stations:" category: "Initial";
	//float V2IChargingRate <- maxBatteryLife/(4.5*60*60) #m/#s; //4.5 h of charge
	float V2IChargingRate <- maxBatteryLife/(111) #m/#s;  // 111 s battery swapping -> average of the two reported by Fei-Hui Huang 2019 Understanding user acceptancd of battery swapping service of sustainable transport
	int chargingStationCapacity <- 16; //TODO: status of bikes waiting // average number of docks in bluebikes stations in April 2022
	
	//----------------------People Parameters------------------------
	//int numPeople <- 250 				min: 0 max: 1000 parameter: "Num People:" category: "Initial";
	float maxWaitTime <- 60 #mn		min: 3#mn max: 60#mn parameter: "Max Wait Time:" category: "People";
	float maxDistance <- maxWaitTime*PickUpSpeed #m; //The maxWaitTime is translated into a max radius taking into account the speed of the bikes
    float peopleSpeed <- 5/3.6 #m/#s	min: 1/3.6 #m/#s max: 10/3.6 #m/#s parameter: "People Speed (m/s):" category: "People";
    float bikeCostBatteryCoef <- 200.0; //(see global.bikeCost)relative importance of batterylife when selecting bikes to ride
   
    //Demand 
    string cityDemandFolder <- "./../includes/Demand";

    csv_file demand_csv <- csv_file (cityDemandFolder+ "/demand_halfcambridge.csv",true);
    //demand_halfcambridge.csv
    //bike.csv
    //user_trips_new.csv
    
    
    //csv_file f <- csv_file("file.csv", ";",int,true, {5, 100});//TODO: Set a limit equivalent to numPeople¿
    
    //For many demand files:
    
    //csv_file demand_csv <- csv_file (cityDemandFolder+ "/user_trips_"+ demand_i +".csv",true);
    //int demand_i <- 0 min: 0 max: 5 parameter: "Demand File:" category "Pepole";
    
     
     
    //----------------------Map Parameters------------------------
	
	//Case 1 - Urban Swarms Map
	/*string cityScopeCity <- "UrbanSwarm";
	string residence <- "R";
	string office <- "O";
	string usage <- "Usage";*/
	
	//Case 2 - Cambridge Map
	/*string cityScopeCity <- "Cambridge";
	string residence <- "Residential";
	string office <- "Office";
	string usage <- "Category";*/
	
	//Case 3 - Boston 
	string cityScopeCity <- "HalfCambridge";
	string residence <- "Residential";
	string office <- "Office";
	string usage <- "Category";

    map<string, rgb> color_map <- [residence::#white, office::#gray, "Other"::#black];
    
	//GIS FILES To Upload

	//string cityGISFolder <- "./../includes/City/"+cityScopeCity;
	//file bound_shapefile <- file(cityGISFolder + "/Bounds.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	//file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	//file roads_shapefile <- file(cityGISFolder + "/Roads.shp")			parameter: "Road Shapefile:" category: "GIS";
	

	// cityGISFolder <- "./../includes/City/"+cityScopeCity;
	//file bound_shapefile <- file(cityGISFolder + "../Cambridge/Bounds.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	//file buildings_shapefile <- file(cityGISFolder + "./Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	//file roads_shapefile <- file(cityGISFolder + "../HalfCambridge/halfcambridge_road.shp/edges.shp")			parameter: "Road Shapefile:" category: "GIS";
	
	
	file bound_shapefile <- file( "./../includes/City/HalfCambridge/halfcambridge-boundary/halfcambridge-boundary.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	file buildings_shapefile <- file( "./../includes/City/UrbanSwarm/Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	file roads_shapefile <- file( "./../includes/City/HalfCambridge/halfcambridge_road.shp/edges.shp")			parameter: "Road Shapefile:" category: "GIS";
	

	//Case Cambridge Map
	//file chargingStations <- file(cityGISFolder + "/chargingStations.shp");
	//file chargingStations <- file("./../includes/City/clustering" + "/chargingStations.shp");
	 
	//Image File
	file imageRaster <- file('./../images/gama_black.png');
			
}	