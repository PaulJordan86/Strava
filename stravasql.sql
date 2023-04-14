CREATE DATABASE Strava;

USE Strava;

SELECT * FROM activities;

-- To start, this is messy raw data downloaded diectly from Strava.
-- Firstly to remove some Columns with very limited, zero or repeated data

ALTER TABLE activities
DROP COLUMN Distance2, Elapsed_Time2, Relative_Effort2,  Max_Watts, Max_Heart_Rate2, Calories, Max_Heart_rate,
Average_Positive_Grade, Average_Negative_Grade, Activity_Description, Commute, Activity_Private_Note,
Activity_gear, Filename, Bike_Weight, Max_temperature;

-- Now to change rides on Wattbike to virtual, as these are on a stationary bike, not on the road.

Update Activities
SET Activity_Type = 'Virtual Ride'
WHERE Activity_Name Like 'Wattbike%'

-- And my weight, is always within a 1kg range of 70, so we can fill in the gaps here without weighing myself each ride.

Update Activities
SET Athlete_Weight = 70
WHERE Athlete_Weight IS NULL

-- Remove decimal places from some numbers recorded as integers

ALTER TABLE Activities
ALTER COLUMN Relative_Effort int;

ALTER TABLE Activities
ALTER COLUMN Elevation_Loss int;

ALTER TABLE Activities
ALTER COLUMN Max_Cadence int;

ALTER TABLE Activities
ALTER COLUMN Average_Temperature int;

-- Round some columns which have needlessly long decimals

Alter Table Activities
Alter Column Distance Decimal (8,2);

Alter Table Activities
Alter Column Max_Speed Decimal (8,2);

Alter Table Activities
Alter Column Elevation_Low Decimal (8,2);

Alter Table Activities
Alter Column Elevation_High Decimal (8,2);

Alter Table Activities
Alter Column Average_Speed Decimal (8,2);

Alter Table Activities
Alter Column Max_Grade Decimal (8,2);

Alter Table Activities
Alter Column Average_Grade Decimal (8,2);

Alter Table Activities
Alter Column Average_Heart_Rate Int;

Alter Table Activities
Alter Column Elevation_Gain Decimal (8,2);

Alter Table Activities
Alter Column Average_Watts Decimal (8,2);

Alter Table Activities
Alter Column Average_Cadence Decimal (8,2);

/* We have 26 rows, where distance is 0. These are most likely where an activity has been recorded by accident, and are insignificant, so I
am happy to remove them. First use a SELECT query to ensure we have the right data, before substiting in a delete function */

Select * from Activities
WHERE Distance IS NULL OR Distance = 0 OR Moving_Time IS NULL OR Moving_Time = 0;

DELETE  from Activities
WHERE Distance IS NULL OR Distance = 0 OR Moving_Time IS NULL OR Moving_Time = 0;

/* Now Average_Speed in this table is not displaying in a commonly used format. As Time is displayed in seconds, I can use
 knowledge of the speeds involved to deduce that this value is being given in Metres per second. We would like this value, 
 and the Max_Speed value in Kilometres per hour, so we will need to mutiply this value by 3.6 */

 UPDATE Activities
 SET Average_Speed = Average_Speed * 3.6;

  UPDATE Activities
 SET Max_Speed = Max_Speed * 3.6;

 /* There are also NULL values in Average Speed, we can calculate an Average Speed simply by using the equation Speed = distance/time.
 Again, with time in seconds, we need to multiply by 3600 to get an hourly value. I will apply this calculation to all rows, in order to ensure we have the same 
 calculation used for all data, as there seemed to be an error in this column.*/

 UPDATE Activities
 SET Average_Speed = (Distance/Moving_Time)*3600;


/* Now that is all cleaned up, and easier to read and work with, we can look at an endless amount of metrics.
Firstly, how does the amount of climbing affect average speed? We may think it is lower, but then every climb is followed by a descent
Is there a trend here? */


SELECT Average_Speed, Elevation_Gain FROM ACTIVITIES;

-- We can sort this data into brackets in a CTE as there are too many individual results, then use a count of rides at each distance to produce a useful view

With bins as 
(
SELECT CASE 

	WHEN Average_Speed >= 0 AND Average_Speed < 20 THEN '0-20'
	WHEN Average_Speed >= 20 AND Average_Speed < 26 THEN '20-26'
	WHEN Average_Speed >= 26 AND Average_Speed< 31 THEN '26-31'
	WHEN Average_Speed >= 31 AND Average_Speed < 36 THEN '31-36'
	Else '36-40' END As Av_Sp_Bins,
CASE
	WHEN Elevation_Gain >= 0 AND Elevation_gain < 500 THEN '0-500'
	WHEN Elevation_Gain >= 500 AND Elevation_gain < 1000 THEN '500-1000'
	WHEN Elevation_Gain >= 1000 AND Elevation_gain < 1500 THEN  '1000-1500'
	WHEN Elevation_Gain >= 1500 AND Elevation_gain < 2000 THEN '1500-2000'
	WHEN Elevation_Gain >= 2000 AND Elevation_gain < 2500 THEN '2000-2500'
	Else '2500+' END As El_Gain_Bins
	
	from Activities

	
	)
	Select El_Gain_Bins, Av_Sp_Bins, COUNT(Av_Sp_Bins) AS Total from bins
	GROUP BY EL_Gain_Bins, Av_Sp_Bins
	ORDER BY El_Gain_Bins, Av_Sp_Bins;

/* We can also look at monthly distance, and if this affects average speed an all tiome metric not displayed by Strava, but interesting to a cyclist.
We can exclude 2023, as on a yearly basis, this will skew the table and we don't have a full dataset yet*/

SELECT  DATEPART(Year, Activity_Date) AS Year,DATEPART(Month, Activity_Date) AS Month, 
SUM(Distance) AS Distance, AVG(Average_Speed) as Av_Speed FROM Activities
WHERE DATEPART(Year, Activity_Date) != 2023
GROUP BY DATEPART(Month, Activity_Date), DATEPART(Year, Activity_Date)
ORDER BY Year, Month;

-- We can look at my 5 longest rides, both on a stationary bike (virtual ride) and outdoors (anything else)

With Ride as
(
SELECT CASE WHEN Activity_Type = 'Virtual Ride' THEN 'VIRTUAL'
ELSE 'OUTDOOR' END AS ride_Type, RANK () OVER (Partition by CASE WHEN Activity_Type = 'Virtual Ride' THEN 'VIRTUAL'
ELSE 'OUTDOOR' END ORDER BY Distance DESC) as Rank, average_watts,  distance, average_Speed, activity_date

FROM Activities)

SELECT 

rank, distance, average_speed, Activity_date, average_watts, ride_type from Ride
WHERE Rank <= 20

ORDER BY ride_type, RANK () OVER (Partition by Ride_Type ORDER BY Distance DESC)


/* Temperature is also  a factor, perhaps I am better suited to certain temperatures and can ride stronger and pedal faster. 
 We will look at watts, cadence and temperature next
 This produces 1718 rows, which will make for a messy chart, so best to sort this into bins, we will use power zones */
SELECT CASE 
	WHEN Average_Watts > 100 AND Average_Watts <= 150 THEN 'z1'
	 WHEN Average_Watts > 150 AND Average_Watts <= 190 THEN 'z2'
	  WHEN Average_Watts > 190 AND Average_Watts <= 230 THEN 'z3'
	   WHEN Average_Watts > 230 AND Average_Watts <= 260 THEN 'z4'
	    WHEN Average_Watts > 260  THEN 'z5'

		END AS Power_Zone ,
		
			AVG(average_temperature) as Av_Temp, CAST(ROUND(AVG(average_cadence),0) AS int)  AS Av_Cad
		from Activities
			   		
-- These metrics are not recorded with every ride, so we will include a where statement. also there are some exceptionally low average_watts numbers to exclude

WHERE Average_Watts IS NOT NULL AND Average_Temperature IS NOT NULL AND Average_Watts > 100
GROUP BY CASE 
	WHEN Average_Watts > 100 AND Average_Watts <= 150 THEN 'z1'
	 WHEN Average_Watts > 150 AND Average_Watts <= 190 THEN 'z2'
	  WHEN Average_Watts > 190 AND Average_Watts <= 230 THEN 'z3'
	   WHEN Average_Watts > 230 AND Average_Watts <= 260 THEN 'z4'
	    WHEN Average_Watts > 260  THEN 'z5'
		END

	ORDER BY Power_Zone;
