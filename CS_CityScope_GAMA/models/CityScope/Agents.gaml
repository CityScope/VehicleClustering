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

}

species pheromoneRoad {
	float pheromone;
	int lastUpdate;
	aspect pheromoneLevel {
		draw shape  color: rgb(125,125,150);
	}
	aspect base {
		draw shape color: #black;
	}
}

species docking{
    int trash;
	int bikes;
	aspect base {
			draw circle(10) color:#blue;		
	}
	aspect realistic{
		draw circle(10) color:rgb(107,171,158);
	}
}

species tagRFID {
	int id;
	bool checked;
	string type;
	
	list<float> pheromones;
	list<geometry> pheromonesToward;
	int lastUpdate;
	
	geometry towardDocking;
	int distanceToDocking;
	
	aspect realistic{
		draw circle(1+10*float(max(pheromones)/2)) color:rgb(107,171,158);
		//draw imageRFID size:5#m;
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
	
	int lastDistanceToDocking;
	
	bool lowBattery;	
	bool carrying;
	

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
		list<tagRFID>closeTag <- tagRFID at_distance 1;
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
		//Juan: WHAT'S THIS?????? pheromoneRoad?
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
				myself.lastDistanceToDocking <- self.distanceToDocking;
				
				// If enough batteryLife follow the pheromone 
				if(myself.batteryLife < myself.lastDistanceToDocking/myself.speedDist){ 
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
	/*reflex toCharge when: lowBattery{
		my_path <- self.goto(on:roadNetwork, target:target, speed:speedDist, return_path: true);
		
		if (target != location) {
			//collision avoidance time
			do updatePheromones;
		}		
		else{				
			ask tagRFID closest_to(self) {
				// Update direction and distance from closest Deposit
				myself.target <- point(self.towardDeposit);
				myself.lastDistanceToDeposit <- self.distanceToDeposit;
				
				
			}
			do updatePheromones;
			source <- location;
			// Recover wandering status, delete pheromones over Deposits
			loop i from: 0 to: length(depositLocation) - 1 {
					if(location = point(roadNetwork.vertices[depositLocation[i]])){
						ask tagRFID closest_to(self){
							self.pheromones <- [0.0,0.0,0.0,0.0,0.0];
						}
						
						ask deposit closest_to(self){
							if(myself.carrying){
								self.trash <- self.trash + carriableTrashAmount;
								myself.carrying <- false;
								myself.pheromoneMark <- 0.0;
							}
							if(myself.lowBattery){
								self.robots <- self.robots + 1;
								myself.lowBattery <- false;
								myself.batteryLife <- maxBatteryLife;
								// Add randomicity and diffusion when the battery is recharged
								myself.target <- point(one_of(deposit));
							}							
						}
					}
			}
		}
	}*/
	
}


