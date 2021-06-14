/**
* Name: Vehicles
* Based on the internal empty template. 
* Author: Juan
* Tags: 
*/


model Agents

import "./clustering.gaml"
/* Insert your model definition here */

species pheromoneRoad {
	float pheromone;
	int lastUpdate;
	aspect base {
		draw shape color: rgb(125, 125, 125);
	}
}

species docking{
	aspect base {
			draw circle(10) color:#blue;		
	}
}

species building {
    string type; 
    aspect type{
		draw shape color: color_map[type];
	}
}

species chargingStation{
	int bikes;
	aspect base {
			draw circle(10) color:#blue;		
	}
}

species intersection{
	aspect base {
			draw circle(10) color:#green;		
	}
}

species tagRFID {
	int id;
	//bool checked;
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
	int currentBattery;
	float speedDist; 
	
	int lastDistanceToChargingStation;
	
	bool lowBattery;	
	bool picking <- false ;
	
	people rider <- nil ;	

    aspect realistic {
		draw triangle(15)  color: rgb(25*1.1,25*1.6,200) rotate: heading + 90;
		if lowBattery{
			draw triangle(15) color: #darkred rotate: heading + 90;
		}
		if (picking){
			draw triangle(15) color: rgb(175*1.1,175*1.6,200) rotate: heading + 90;
		}
	}


	action updatePheromones{
		list<tagRFID>closeTag <- tagRFID at_distance 1000;
		ask closeTag closest_to(self){
			loop j from:0 to: (length(self.pheromonesToward)-1) {					
							
							self.pheromones[j] <- self.pheromones[j] + myself.pheromoneToDiffuse - (singlePheromoneMark * evaporation * (cycle - self.lastUpdate));					
							
							if (self.pheromones[j]<0.001){
								self.pheromones[j] <- 0;
							}	
							
							if(myself.picking){								
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
								
				if(myself.picking){
						self.pheromone <- self.pheromone + myself.pheromoneMark ;
				}	
				self.lastUpdate <- cycle;				
			}							
		}
	}
	
	reflex searching when: (!picking and !lowBattery){		
		my_path <- self.goto(on:roadNetwork, target:target, speed:speedDist, return_path: true);				
		if (target != location) { 
			do updatePheromones;
		}
		else {				
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
							if(myself.picking){
								//self.trash <- self.trash + carriableTrashAmount;
								myself.picking <- false;
								myself.pheromoneMark <- 0.0;
							}					
							if(myself.lowBattery){
								self.bikes <- self.bikes + 1;
								myself.lowBattery <- false;
								myself.batteryLife <- maxBatteryLife;
							}							
						}
					}
			}
		}
	}
	reflex pickUp when: picking{
		do goto target: target on: roadNetwork ; 
	    if target = location {
	        target <- nil ;
	        create ride {
	        	self.riderTarget <- myself.rider.the_target ;
	        	//Save rider characteristics
	        	self.r_objective <- myself.rider.objective ;
	        	self.r_living_place <- myself.rider.living_place ;
	        	self.r_working_place <- myself.rider.working_place ;
	        	self.r_start_work <- myself.rider.start_work ;
	        	self.r_end_work <- myself.rider.end_work ;
	        	//Save bike characteristics
				self.r_pheromoneToDiffuse <- myself.pheromoneToDiffuse ;
				self.r_pheromoneMark <- myself.pheromoneMark ; 
				self.r_batteryLife <- myself.batteryLife;
				self.r_speedDist <- myself.speedDist;
				//Save Path nodes
				self.intTarget <- (intersection closest_to(self.riderTarget)).location ;
				self.total_path <- path_between(roadNetwork, myself.location, self.intTarget) ;
				//self.total_path <- path_between(roadNetwork, myself.location, myself.rider.the_target) ;
				self.target <- total_path.vertices[0] ;
	        }
        	ask self.rider {
				do die ;
			}
			do die ;
    	}
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
    point closest_int <- nil;
    bool call_bike <- false;

    
    reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
	    objective <- "working" ;
	    the_target <- any_location_in (working_place);
	    call_bike <- true ;
	    }
    
    reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
	    objective <- "resting" ;
	    the_target <- any_location_in (living_place);
	    call_bike <- true ;
	    }
    
    reflex to_intersection when: call_bike = true {
    	call_bike <- false ;
	    closest_int <- (intersection closest_to(self)).location ;
	    do callBike;
    }
    
    
    aspect base {
    draw circle(10) color: color border: #black;
    }
    
    action callBike {
    	list<bike>avaliableBikes <- bike where (each.picking = false and each.lowBattery = false) ;
    	//If no avaliable bikes, automatic transport to destiny
    	if(!empty(avaliableBikes)){
	    	ask avaliableBikes closest_to(self){
	    		self.target <- myself.closest_int;
	    		self.rider <- myself ;
	    		self.picking <- true ;
	    	}
	    	do goto target: closest_int on: roadNetwork ; 		    	
    	}
    	else{
    		location <- the_target ;
    	}   	
    }
}

species ride skills:[moving]{
	bike rided <- nil;
	people rider <- nil;
	point riderTarget <- nil;
	point intTarget <- nil ;
	
	//Rider characteristics
    building r_living_place <- nil ;
    building r_working_place <- nil ;
    int r_start_work ;
    int r_end_work  ;
    string r_objective ;
    
    //Rided characteristics
	float r_pheromoneToDiffuse;
	float r_pheromoneMark; 
	int r_batteryLife;
	float r_speedDist;
	
	
	point target;
	path my_path;
	path total_path;
	int pathIndex <- 0; 
	point source;
	
	float pheromoneToDiffuse;
	float pheromoneMark; 
	
	int batteryLife; 
	
	int lastDistanceToChargingStation;
	
	//Juan: look how to eliminate this parameter. Separate bike from ride behavior
	bool carrying <- true;
	 
    aspect realistic {
		draw triangle(15)  color: #gamagreen rotate: heading + 90;
	}	
	action updatePheromones{
		list<tagRFID>closeTag <- tagRFID at_distance 1000;
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
	reflex carrying {		
		my_path <- self.goto(on:roadNetwork, target:target, speed:r_speedDist, return_path: true);
						
		if (target != location) {
			do updatePheromones;
		}		
		else{				
			pathIndex <- pathIndex +1 ;			
			do updatePheromones;
			source <- location;
			if(location=intTarget){
				create people {
					living_place <- myself.r_living_place ;
					working_place <- myself.r_working_place ;
					start_work <- myself.r_start_work;
			        end_work <- myself.r_end_work;
			        objective <- myself.r_objective;
			        location <- myself.location;
			        do goto target: myself.riderTarget on: roadNetwork ;
				}
				create bike {
					location <- (intersection closest_to myself).location ;
					target <- location ; 
					source <- location ;
					picking <- false;
					lowBattery <- false;
					speedDist <- myself.r_speedDist ;
					//Values to change
					pheromoneToDiffuse <- myself.r_pheromoneToDiffuse ;
					pheromoneMark <- myself.r_pheromoneMark ;
					batteryLife <- myself.r_batteryLife ;
				}
				do die;
			}
			target <- point(total_path.vertices[pathIndex]);
		}
		}
			

}



