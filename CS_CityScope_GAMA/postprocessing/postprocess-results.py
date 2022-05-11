import numpy as np
import pandas as pd
import os
import glob

#CHANGE folder  
os.chdir("../../../../results/CORRECT_VERSIONS/latestresults_nominal")


if True: #Load all csv files in directory and concat just once 
    extension = 'csv'

    #Bike trips
    bike_filenames =[i for i in glob.glob('bike_trip_event*.{}'.format(extension))]

    bike_df_temp= pd.DataFrame()
    bike_df_temp= pd.concat([pd.read_csv(f) for f in bike_filenames], ignore_index=True)
    print(bike_df_temp.head())
    bike_df_temp.to_csv('bike_concat.csv')

    #To check bug
    # for f in bike_filenames:
    #     df_f=pd.read_csv(f)
    #     print(f)
    #     print(df_f.shape)
    #     bike_df_temp=pd.concat([bike_df_temp,df_f])
    #     print(bike_df_temp.shape)

    #User trips
    user_filenames =[i for i in glob.glob('people_trips_*.{}'.format(extension))]
    user_df_temp= pd.concat([pd.read_csv(f) for f in user_filenames ], ignore_index=True)
    print(user_df_temp.head())
    user_df_temp.to_csv('user_concat.csv')

#Read already concat .csv
bike_df=pd.read_csv('bike_concat.csv')
user_df=pd.read_csv('user_concat.csv')

if False:

    bike_df.drop(bike_df.loc[bike_df['Num Bikes']=='Num Bikes'].index, inplace=True)
    user_df.drop(user_df.loc[user_df['Num Bikes']=='Num Bikes'].index, inplace=True)
    error_bike=[1,3,4,5,6,7,8,9,10,16,18]
    error_user=[1,3,4,5,6,7,8,9,10,13,16,17,18,19,20,21]
    for i in error_bike:
        bike_df.iloc[:,i]=pd.to_numeric(bike_df.iloc[:,i])
    for i in error_user:
        user_df.iloc[:,i]=pd.to_numeric(user_df.iloc[:,i])
    user_df['Trip Served'] = user_df['Trip Served'].astype('bool')
    bike_df.to_csv('bike_concat.csv')
    user_df.to_csv('user_concat.csv')



#Get the parameter ranges

n_bikes_possible=user_df['Num Bikes'].unique()
n_bikes_possible.sort()
print('Num Bikes: ',n_bikes_possible)

wander_speed_possible=user_df['Wandering Speed'].unique()
wander_speed_possible.sort()
print('Wandering Speed: ',wander_speed_possible)

evaporation_possible=user_df['Evaporation'].unique()
evaporation_possible.sort()
print('Evaporation: ',evaporation_possible)

exploitation_possible=user_df['Exploitation'].unique()
exploitation_possible.sort()
print('Exploitation: ',exploitation_possible)

print('Num bikes count:', user_df['Num Bikes'].value_counts()/400)

print('Num Speed Values:', len(wander_speed_possible))
print('Num Evap Values:', len(evaporation_possible))
print('Num Exp Values:', len(exploitation_possible))
print('Num Rep: ', 5)
print('Total: ',5*(3*3*3 + 3*3))