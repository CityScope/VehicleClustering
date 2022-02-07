import numpy as np
import pandas as pd
import os
import glob
import matplotlib
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1 import AxesGrid



#CHANGE folder  
os.chdir("../data")
extension = 'csv'

date='2021-01-31 12.00.00'
date2='2021-02-03 12.00.00'

if False: #Load all csv files in directory and concat just once 
    #Charging
    charge_filenames = [i for i in glob.glob('./'+date+'/bike_station_charge*.{}'.format(extension))]
    charge_df_temp= pd.concat([pd.read_csv(f) for f in charge_filenames ])
    print(charge_df_temp.head())
    charge_df_temp.to_csv('./'+date+'/charge_concat.csv',index=False)

    #Bike trips
    bike_filenames =[i for i in glob.glob('./'+date+'/bike_trip_event*.{}'.format(extension))]
    bike_df_temp= pd.concat([pd.read_csv(f) for f in bike_filenames ])
    print(bike_df_temp.head())
    bike_df_temp.to_csv('./'+date+'/bike_concat.csv',index=False)

    #User trips
    user_filenames =[i for i in glob.glob('./'+date+'/people_trips_*.{}'.format(extension))]
    user_df_temp= pd.concat([pd.read_csv(f) for f in user_filenames ])
    print(user_df_temp.head())
    user_df_temp.to_csv('./'+date+'/user_concat.csv',index=False)

if False:
    #Charging
    charge_filenames2 = [i for i in glob.glob('./'+date2+'/bike_station_charge*.{}'.format(extension))]
    charge_df_temp2= pd.concat([pd.read_csv(f) for f in charge_filenames2 ])
    print(charge_df_temp2.head())
    charge_df_temp2.to_csv('./'+date2+'/charge_concat.csv',index=False)

    #Bike trips
    bike_filenames2 =[i for i in glob.glob('./'+date2+'/bike_trip_event*.{}'.format(extension))]
    bike_df_temp2= pd.concat([pd.read_csv(f) for f in bike_filenames2 ])
    print(bike_df_temp2.head())
    bike_df_temp2.to_csv('./'+date2+'/bike_concat.csv')

    #User trips
    user_filenames2 =[i for i in glob.glob('./'+date2+'/people_trips_*.{}'.format(extension))]
    user_df_temp2= pd.concat([pd.read_csv(f) for f in user_filenames2 ])
    print(user_df_temp2.head())
    user_df_temp2.to_csv('./'+date2+'/user_concat.csv')


#Results with perhomones
charge_df=pd.read_csv('./'+date+'/charge_concat.csv')
bike_df=pd.read_csv('./'+date+'/bike_concat.csv')
user_df=pd.read_csv('./'+date+'/user_concat.csv')
#user_df=pd.read_csv('./'+date+'/user_concat.csv',dtype={"Num Bikes": int, "Wandering Speed": float, "Evaporation":float, "Exploitation":float})

#Just trying to patch some error...
charge_df.drop(charge_df.loc[charge_df['Num Bikes']=='Num Bikes'].index, inplace=True)
bike_df.drop(bike_df.loc[bike_df['Num Bikes']=='Num Bikes'].index, inplace=True)
user_df.drop(user_df.loc[user_df['Num Bikes']=='Num Bikes'].index, inplace=True)
error_charge=[0,2,3,4,5,6,7,8,9,14,15,16,17]
error_bike=[0,2,3,4,5,6,7,8,9,15,16,17,18,19]
error_user=[0,2,3,4,5,6,7,8,9,12,15,16,17,18,19]
for i in error_charge:
    print(i)
    charge_df.iloc[:,i]=pd.to_numeric(charge_df.iloc[:,i])
for i in error_bike:
    print(i)
    bike_df.iloc[:,i]=pd.to_numeric(bike_df.iloc[:,i])
for i in error_user:
    print(i)
    user_df.iloc[:,i]=pd.to_numeric(user_df.iloc[:,i])

#Results without perhomones
charge_df_n=pd.read_csv('./'+date2+'/charge_concat.csv')
bike_df_n=pd.read_csv('./'+date2+'/bike_concat.csv')
user_df_n=pd.read_csv('./'+date2+'/user_concat.csv')

#Get the parameter ranges
user_df['Num Bikes'] = pd.to_numeric(user_df['Num Bikes'])
n_bikes_possible=user_df['Num Bikes'].unique()
n_bikes_possible.sort()
print('Num Bikes: ',n_bikes_possible)

user_df['Wandering Speed'] = pd.to_numeric(user_df['Wandering Speed'])
wander_speed_possible=user_df['Wandering Speed'].unique()
wander_speed_possible.sort()
print('Wandering Speed: ',wander_speed_possible)

user_df['Evaporation'] = pd.to_numeric(user_df['Evaporation'])
evaporation_possible=user_df['Evaporation'].unique()
evaporation_possible.sort()
print('Evaporation: ',evaporation_possible)

user_df['Exploitation'] = pd.to_numeric(user_df['Exploitation'])
exploitation_possible=user_df['Exploitation'].unique()
exploitation_possible.sort()
print('Exploitation: ',exploitation_possible)


user_df['Trip Served'] = user_df['Trip Served'].astype('bool')
#Set matrix sizes
i_size=n_bikes_possible.size
j_size=wander_speed_possible.size
k_size=evaporation_possible.size
l_size=exploitation_possible.size

#We have four variables in two axes i+j combined / k+l combined
x_size= i_size*j_size
y_size=k_size*l_size

#Initialize matrices
wait_matrix=np.zeros((x_size,y_size))
served_matrix=np.zeros((x_size,y_size))

u=-1

for i in range(i_size):

    for j in range(j_size):
        v=0
        u+=1
        for k in range(k_size):
            
            for l in range(l_size):

                #Read values and filter dataframe
                n_bikes=n_bikes_possible[i]
                wander_speed=wander_speed_possible[j]
                evaporation=evaporation_possible[k]
                exploitation=exploitation_possible[l]

                #PHEROMONES#
                temp=user_df.loc[(user_df['Num Bikes']==n_bikes)&(user_df['Wandering Speed']==wander_speed)&(user_df['Evaporation']==evaporation)&(user_df['Exploitation']==exploitation)]

                #Compute aveage wait 
                sum=temp['Wait Time (min)'].sum()
                len=temp['Wait Time (min)'].size
                average_wait=sum/len

                #Compute average percentage of served trips
                count_served=temp.loc[temp['Trip Served']==True].shape[0]
                count_unserved=temp.loc[temp['Trip Served']==False].shape[0]
                average_served=(count_served)/(count_served+count_unserved)*100

                #NO PHEROMONES
                temp_n=user_df_n.loc[(user_df_n['Num Bikes']==n_bikes)]
                #Compute aveage wait 
                sum_n=temp_n['Wait Time (min)'].sum()
                len_n=temp_n['Wait Time (min)'].size
                average_wait_n=sum_n/len_n

                #Compute average percentage of served trips
                count_served_n=temp_n.loc[temp_n['Trip Served']==True].shape[0]
                count_unserved_n=temp_n.loc[temp_n['Trip Served']==False].shape[0]
                average_served_n=(count_served_n)/(count_served_n+count_unserved_n)*100

                #SAVE DATA
                wait_matrix[u,v]=average_wait - average_wait_n #
                served_matrix[u,v]=average_served - average_served_n #

                v+=1


#Process the labels for the combined axis
labels_1= []
for i in range(i_size):
    for j in range(j_size):
        labels_1.append([n_bikes_possible[i],wander_speed_possible[j]])

labels_2 =[]

for k in range(k_size):
    for l in range(l_size):
        labels_2.append([evaporation_possible[k],exploitation_possible[l]])




#Create grid
yi = np.arange(0, x_size+1) #shift x and y
xi = np.arange(0, y_size+1)
X, Y = np.meshgrid(xi, yi)

def shiftedColorMap(cmap, start=0, midpoint=0.5, stop=1.0, name='shiftedcmap'):
    '''
    Function to offset the "center" of a colormap. Useful for
    data with a negative min and positive max and you want the
    middle of the colormap's dynamic range to be at zero.

    Input
    -----
      cmap : The matplotlib colormap to be altered
      start : Offset from lowest point in the colormap's range.
          Defaults to 0.0 (no lower offset). Should be between
          0.0 and `midpoint`.
      midpoint : The new center of the colormap. Defaults to 
          0.5 (no shift). Should be between 0.0 and 1.0. In
          general, this should be  1 - vmax / (vmax + abs(vmin))
          For example if your data range from -15.0 to +5.0 and
          you want the center of the colormap at 0.0, `midpoint`
          should be set to  1 - 5/(5 + 15)) or 0.75
      stop : Offset from highest point in the colormap's range.
          Defaults to 1.0 (no upper offset). Should be between
          `midpoint` and 1.0.
    '''
    cdict = {
        'red': [],
        'green': [],
        'blue': [],
        'alpha': []
    }

    # regular index to compute the colors
    reg_index = np.linspace(start, stop, 257)

    # shifted index to match the data
    shift_index = np.hstack([
        np.linspace(0.0, midpoint, 128, endpoint=False), 
        np.linspace(midpoint, 1.0, 129, endpoint=True)
    ])

    for ri, si in zip(reg_index, shift_index):
        r, g, b, a = cmap(ri)

        cdict['red'].append((si, r, r))
        cdict['green'].append((si, g, g))
        cdict['blue'].append((si, b, b))
        cdict['alpha'].append((si, a, a))

    newcmap = matplotlib.colors.LinearSegmentedColormap(name, cdict)
    plt.register_cmap(cmap=newcmap)

    return newcmap

max_wait=wait_matrix.max()
min_wait=wait_matrix.min()

served_max=served_matrix.max()
served_min=served_matrix.min()

m= 1-((served_max)/(served_max-served_min))
orig_cmap = matplotlib.cm.coolwarm
shifted_cmap = shiftedColorMap(orig_cmap, midpoint=m, name='shifted')


#### FIGURE 1: WAIT TIMES

plt.pcolormesh(X, Y, wait_matrix,cmap='coolwarm')
for i in range(x_size):
    for j in range(y_size):
        plt.text(j,i, round(wait_matrix[i,j],2), color="w")
plt.colorbar()
plt.xticks(xi[:-1]+0.5, labels_2, rotation=90)
plt.xlabel("[Evaporation, Exploitation]")
plt.yticks(yi[:-1]+0.5, labels_1)
plt.ylabel("[Num bikes, Wander Speed]")
plt.title('Wait times difference [min]: pheromones - nominal')

plt.show()

#### FIGURE 2: PERCENTAGE SERVED TRIPS

plt.pcolormesh(X, Y, served_matrix,cmap=shifted_cmap)
for i in range(x_size-1):
    for j in range(y_size-1):
        plt.text(j,i, round(served_matrix[i,j],2), color="w")
plt.colorbar()
plt.xticks(xi[:-1]+0.5, labels_2, rotation=90)
plt.xlabel("[Evaporation, Exploitation]")
plt.yticks(yi[:-1]+0.5, labels_1)
plt.ylabel("[Num bikes, Wander Speed]")
plt.title('Served trips [%]: pheromones - nominal')

plt.show()


#Combined matrix
comb_matrix=np.zeros((x_size,y_size))

for i in range(x_size):
    for j in range(y_size):
        comb_matrix[i,j]=((served_matrix[i,j]-served_min)/(served_max-served_min))-((wait_matrix[i,j]-min_wait)/(max_wait-min_wait))

plt.pcolormesh(X, Y, comb_matrix,cmap='coolwarm_r')
    #for i in range(x_size-1):
        #for j in range(y_size-1):
            #plt.text(j,i, wait_matrix[i,j], color="w")
plt.colorbar()
plt.xticks(xi[:-1]+0.5, labels_2, rotation=90)
plt.xlabel("[Evaporation, Exploitation]")
plt.yticks(yi[:-1]+0.5, labels_1)
plt.ylabel("[Num bikes, Wander Speed]")
plt.title('Combined')

plt.show()