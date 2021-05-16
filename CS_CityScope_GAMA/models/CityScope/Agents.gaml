/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Agents

import "./clustering.gaml"
/* Insert your model definition here */

global{
	//-----------------------------------------------------Bike Parameters--------------------------------------------------
	//Juan: CHECK these parameters values
	float singlePheromoneMark <- 0.5;
	float evaporation <- 0.5;
	float exploratoryRate <- 0.8;
	float diffusion <- (1-exploratoryRate) * 0.5;
	graph roadNetwork;
	list<int> dockingLocation;
	list<int> chargingStationLocation;
}

species pheromoneRoad {
	float pheromone;
	int lastUpdate;
	aspect pheromoneLevel {
		draw shape  color: rgb(125,125,150);
	}
	aspect base {
		draw shape color: rgb(125, 125, 125);
	}
}

species docking{
	aspect base {
			draw circle(10) color:#blue;		
	}
}



species chargingStation{
	int bikes;
	aspect base {
			draw circle(10) color:#blue;		
	}
	aspect realistic{
		draw circle(10) color:rgb(107,171,158);
	}
}

species intersection{
	aspect base {
			draw circle(10) color:#green;		
	}
}

species tagRFID {
	int id;
	bool checked;
	string type;
	
	list<float> pheromones;
	list<geometry> pheromonesToward;
	int lastUpdate;
	
	geometry towardChargingStation;
	int distanceToChargingStation;

	aspect base{
		draw circle(10) color:#purple border: #black;
	}
	
	aspect realistic{
		draw circle(1+10*float(max(pheromones)/2)) color:rgb(107,171,158);
	}
}

species bike skills:[moving] {
	point target;
	path my_path; 
	point source;
	
	float pheromoneToDiffuse;
	float pheromoneMark; 
	
	int batteryLife;
	float speedDist; 
	
	int lastDistanceToChargingStation;
	
	bool lowBattery;	
	bool carrying;
	
	aspect base{
		draw circle(10) color:#brown border: #black;
	}
    //Juan: Aspect Realistic is not yet working
    aspect realistic {
		draw triangle(15)  color: rgb(25*1.1,25*1.6,200) rotate: heading + 90;
		if lowBattery{
			draw triangle(15) color: #darkred rotate: heading + 90;
		}
		if (carrying){
			draw triangle(15) color: rgb(175*1.1,175*1.6,200) rotate: heading + 90;
		}
	}


	action updatePheromones{
		list<tagRFID>closeTag <- tagRFID at_distance 10;
		ask closeTag closest_to(self){
			loop j from:0 to: (length(self.pheromonesToward)-1) {					
							
							self.pheromones[j] <- self.pheromones[j] + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
							
							if (self.pheromones[j]<0.001){
								self.pheromones[j] <- 0;
							}	
							
							if(myself.carrying){								
								if (self.pheromonesToward[j]=myself.source){
									self.pheromones[j] <- self.pheromones[j] + myself.pheromoneMark ;									
								}
																	
							}
							//Saturation
							if (self.pheromones[j]>50*singlePheromoneMark){
									self.pheromones[j] <- 50*singlePheromoneMark;
								}
				}
				// Update tagRFID and pheromoneToDiffuse
				self.lastUpdate <- cycle;				
				myself.pheromoneToDiffuse <- max(self.pheromones)*diffusion;
		}
		ask pheromoneRoad closest_to(self){	
			point p <- farthest_point_to (self , self.location);
			if (myself.location distance_to p < 1){			
				self.pheromone <- self.pheromone + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
								
				if (self.pheromone<0.01){
					self.pheromone <- 0.0;
				}	
								
				if(myself.carrying){
						self.pheromone <- self.pheromone + myself.pheromoneMark ;
				}	
				self.lastUpdate <- cycle;				
			}							
		}
	}
	
	reflex searching when: (!carrying and !lowBattery){		
		my_path <- self.goto(on:roadNetwork, target:target, speed:speedDist, return_path: true);				
		if (target != location) { 
			//collision avoidance time
				do updatePheromones;
			//Juan: INsert here carrying people behavior	
				
			//If there is enough battery and trash, carry it!
			/*list<trashBin> closeTrashBin <- trashBin at_distance 50;
			//ask closeTrashBin closest_to(self) {		
			ask closeTrashBin with_max_of(each.trash){		
				
				if (self.trash > carriableTrashAmount){
					if(myself.batteryLife > myself.lastDistanceToDeposit/myself.speedDist){
						self.trash <- self.trash - carriableTrashAmount;	
						self.decreaseTrashAmount<-true;
						myself.pheromoneMark <- (singlePheromoneMark * int(self.trash/carriableTrashAmount));		
						myself.carrying <- true;
					}
					else{
						myself.lowBattery <- true;
					}
				}	
			}*/
		}
		else{				
			ask tagRFID closest_to(self){
				myself.lastDistanceToChargingStation <- self.distanceToChargingStation;
				
				// If enough batteryLife follow the pheromone 
				if(myself.batteryLife < myself.lastDistanceToChargingStation/myself.speedDist){ 
					myself.lowBattery <- true;
				}
				else{
				
					list<float> edgesPheromones <-self.pheromones;
					
					if(mean(edgesPheromones)=0){ 
						// No pheromones,choose a random direction
						myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
					}
					else{  
						// Follow strongest pheromone trail (with exploratoryRate Probability if the last path has the strongest pheromone)					
						float maxPheromone <- max(edgesPheromones);	
						//*
						loop j from:0 to:(length(self.pheromonesToward)-1) {					
							if (maxPheromone = edgesPheromones[j]) and (myself.source = point(self.pheromonesToward[j])){
								edgesPheromones[j]<- flip(exploratoryRate)? edgesPheromones[j] : 0.0;					
							}											
						}
						maxPheromone <- max(edgesPheromones);	

								
						// Follow strongest pheromone trail (with exploratoryRate Probability in any case)			
						loop j from:0 to:(length(self.pheromonesToward)-1) {			
							if (maxPheromone = edgesPheromones[j]){
								if flip(exploratoryRate){	
									myself.target <- point(self.pheromonesToward[j]);
									break;	
									}	
									else {
										myself.target <- point(self.pheromonesToward[rnd(length(self.pheromonesToward)-1)]);
										break;
									}			
								}											
							}
						}				
					}
				}
				do updatePheromones;
				source <- location;
			}
	}
	//Implement logic for charging
	reflex toCharge when: lowBattery{
		my_path <- self.goto(on:roadNetwork, target:target, speed:speedDist, return_path: true);
		
		if (target != location) {
			//collision avoidance time
			do updatePheromones;
		}		
		else{				
			ask tagRFID closest_to(self) {
				// Update direction and distance from closest Docking station
				myself.target <- point(self.towardChargingStation);
				myself.lastDistanceToChargingStation <- self.distanceToChargingStation;
				
				
			}
			do updatePheromones;
			source <- location;
			// Recover wandering status, delete pheromones over Deposits
			loop i from: 0 to: length(chargingStationLocation) - 1 {
					if(location = point(roadNetwork.vertices[chargingStationLocation[i]])){
						ask tagRFID closest_to(self){
							self.pheromones <- [0.0,0.0,0.0,0.0,0.0];
						}
						
						ask chargingStation closest_to(self){
							if(myself.carrying){
								//self.trash <- self.trash + carriableTrashAmount;
								myself.carrying <- false;
								myself.pheromoneMark <- 0.0;
							}					
							if(myself.lowBattery){
								self.bikes <- self.bikes + 1;
								myself.lowBattery <- false;
								myself.batteryLife <- maxBatteryLife;
								// Add randomicity and diffusion when the battery is recharged. Juan: this last line ocasionated unexpected jumps
								//myself.target <- point(one_of(docking));
							}							
						}
					}
			}
		}
	}
	reflex carrying when: (!carrying and !lowBattery){
		my_path <- self.goto(on:roadNetwork, target:target, speed:speedDist, return_path: true);
	}
	
}

species people skills:[moving]{
    rgb color <- #yellow ;
    building living_place <- nil ;
    building working_place <- nil ;
    int start_work ;
    int end_work  ;
    string objective ;
    point the_target <- nil ;
    
    reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
    objective <- "working" ;
    the_target <- any_location_in (working_place);
    }
    
    reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
    objective <- "resting" ;
    the_target <- any_location_in (living_place); 
    }
    
    reflex move when: the_target != nil {
    /*do goto target: the_target on: the_graph ; 
    if the_target = location {
        the_target <- nil ;
    }*/
    do askBike;
    }
    
    aspect base {
    draw circle(10) color: color border: #black;
    }
    
    action askBike {
    	ask bike closest_to(self){
    		self.target <- myself.location;
    		self.carrying <- true;
    	}
    }
}



