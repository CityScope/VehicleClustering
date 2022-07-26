import numpy as np
import pandas as pd
import os
import glob
from itertools import islice


#CHANGE folder  
os.chdir("../../../../results/CORRECT_VERSIONS/final-clean")


if True: #Load all csv files in directory and concat just once 
    extension = 'csv'

    #Bike trips
    bike_filenames =[i for i in glob.glob('bike_trip_event*.{}'.format(extension))]

df = pd.DataFrame([])

for file in bike_filenames: #Get first two rows of all the csv
    df_firstn = pd.read_csv(file, nrows=2)
    vals= pd.DataFrame([])
    vals[0]=df_firstn['Num Bikes']
    vals[1]=df_firstn['Wandering Speed']
    vals[2]=df_firstn['Evaporation']
    vals[3]=df_firstn['Exploitation']
    vals[4]=file
    df = df.append(vals)
    


#print(df)


#Get the parameter ranges
n_bikes_possible=df[0].unique()
n_bikes_possible.sort()
print('Num Bikes: ',n_bikes_possible)

wander_speed_possible=df[1].unique()
wander_speed_possible.sort()
print('Wandering Speed: ',wander_speed_possible)

evaporation_possible=df[2].unique()
evaporation_possible.sort()
print('Evaporation: ',evaporation_possible)

exploitation_possible=df[3].unique()
exploitation_possible.sort()
print('Exploitation: ',exploitation_possible)

with open("ListofWrongCSV_3.txt", "a") as f:
        
    for i in range(n_bikes_possible.size):

        for j in range(wander_speed_possible.size):

            for k in range(evaporation_possible.size):
                
                for l in range(exploitation_possible.size):

                    #Read values and filter dataframe
                    n_bikes=n_bikes_possible[i]
                    wander_speed=wander_speed_possible[j]
                    evaporation=evaporation_possible[k]
                    exploitation=exploitation_possible[l]
                    temp=df.loc[(df[0]==n_bikes)&(df[1]==wander_speed)&(df[2]==evaporation)&(df[3]==exploitation)]
                    #print(temp.shape[0])
                    if temp.shape[0]== 0:
                        print('Missing:',n_bikes,wander_speed,evaporation,exploitation, file=f)
                    if temp.shape[0]> 2:
                        print(temp, file=f)
