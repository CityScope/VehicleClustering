/**
* Name: Parameters
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Parameters

import "./clustering.gaml"
/* Insert your model definition here */
global{
	//-------------------------------------------------------------My Parameters----------------------------------------------------------------------------------
	//Number of Bikes to generate. Juan: Change this so nb is generated according to real GIS Data.
	int bikeNum <- 5 min: 1 max: 1000 parameter: "Nb Vehicle:" category: "Initial";
	//Max battery life of bikes.
	int maxBatteryLife <- 200; // 2 h for PEV considering each cycle as 10 seconds in the real world
	//Max speed distance of Bikes
	float maxSpeedDist <- 2.5; // about 5.5  m/s for PEV (it can be changed accordingly to different robot specification)
	//Number of docking stations
	int dockingNum <- 2;
	//Number of charging stations
	int nb_chargingStation;
	//Number of people
	int nb_people <- 5;
	//Simulation time step
	float step <- 10 #mn;
	//Number of charging stations
	//PEOPLE'S Parameters
    int min_work_start <- 6;
    int max_work_start <- 8;
    int min_work_end <- 16; 
    int max_work_end <- 20; 
    float min_speed <- 1.0 #km / #h;
    float max_speed <- 5.0 #km / #h;
    //PHEROMONES Parameters
    float singlePheromoneMark <- 0.5;
	float evaporation <- 0.5;
	float exploratoryRate <- 0.8;
	float diffusion <- (1-exploratoryRate) * 0.5; 
	//GIS FILES To Upload
	//Case 1 - Urban Swarms Map
 	string cityScopeCity<-"UrbanSwarm";
	string cityGISFolder <- "./../../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp");
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp");
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp");
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