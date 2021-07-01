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
	float step <- 10 #mn;
	
	//----------------------Bike Parameters------------------------
	//Number of Bikes to generate. Juan: Change this so nb is generated according to real GIS Data.
	int numBikes <- 5 				min: 1 max: 1000 parameter: "Num Bikes:" category: "Initial";
	//Max battery life of bikes - Maximum number of meters with the battery
	int maxBatteryLife <- 25000 	min: 10000 max: 1000000 parameter: "Battery Capacity (m)" category: "Bike";
	//speed of bikes - about 5.5  m/s for PEV (it can be changed accordingly to different robot specification)
	float BikeSpeed <- 2.5 #m/#s min: 1 #m/#s max: 15#m/#s parameter: "Bike Top Speed:" category:  "Bike";
	
	//----------------------Docking Parameters------------------------
	//Number of docking stations
	int numDockingStations <- 2 	min: 1 max: 1000 parameter: "Num Bikes:" category: "Initial";
	
	//----------------------People Parameters------------------------
	int numPeople <- 5 				min: 1 max: 1000 parameter: "Num People:" category: "Initial";
    int workStartMin <- 6			min: 4 max: 12 parameter: "Min Work Start Time:" category: "People";
    int workStartMax <- 8			min: 4 max: 12 parameter: "Max Work Start Time:" category: "People";
    int workEndMin <- 16			min: 14 max: 24 parameter: "Min Work End Time:" category: "People";
    int workEndMax <- 20			min: 14 max: 24 parameter: "Max Work End Time:" category: "People";
    float minSpeedPeople <- 1.0 #km/#h	min: 0.5#km/#h max: 10#km/#h parameter: "People Min Speed:" category: "People";
    float maxSpeedPeople <- 5.0 #km/#h	min: 0.5#km/#h max: 10#km/#h parameter: "People Max Speed:" category: "People";
    
    //----------------------Pheremone Parameters------------------------
    float singlePheromoneMark <- 0.5;
	float evaporation <- 0.5;
	float exploratoryRate <- 0.8;
	float diffusion <- (1-exploratoryRate) * 0.5; 
	
	
	//GIS FILES To Upload
	//Case 1 - Urban Swarms Map
 	string cityScopeCity<-"UrbanSwarm";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp")			parameter: "Road Shapefile:" category: "GIS";
	map<string, rgb> color_map <- ["R"::#white, "O"::#gray, "Other"::#black];	
	//Case 2 - Cambridge Map
	/*
	string cityScopeCity<-"clustering";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/BOUNDARY_CityBoundary.shp");
	file buildings_shapefile <- file(cityGISFolder + "/CDD_LandUse.shp");
	file roads_shapefile <- file(cityGISFolder + "/TRANS_CenterLines.shp");
	file dockingStations <- file(cityGISFolder + "/dockingStations.shp");
	file dockingStations <- file("./../../includes/City/clustering" + "/dockingStations.shp");
	map<string, rgb> color_map <- ["Residential"::#white, "Office"::#gray, "Other"::#black];
	 */
	//Image File
	file imageRaster <- file('./../../images/gama_black.png');
			
}	