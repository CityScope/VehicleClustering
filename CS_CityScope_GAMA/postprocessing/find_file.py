import numpy as np
import pandas as pd
import os
import glob
from itertools import islice


#CHANGE folder  
os.chdir("../../../../results/CORRECT_VERSIONS/FINAL_FINAL")

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
    

#Read values and filter dataframe
n_bikes=900
wander_speed=5
evaporation=0.25
exploitation=0.75
temp=df.loc[(df[0]==n_bikes)&(df[1]==wander_speed)&(df[2]==evaporation)&(df[3]==exploitation)]
#print(temp.shape[0])
print(temp)