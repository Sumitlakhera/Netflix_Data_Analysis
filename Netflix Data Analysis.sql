CREATE DATABASE netflix;

CREATE TABLE netflix_raw(
	show_id VARCHAR(10),
	type VARCHAR(7),
	title VARCHAR(200),
	director VARCHAR(250),
	casts VARCHAR(1000),
	country VARCHAR(150),
	date_added VARCHAR(20),
	release_year INT,
	rating VARCHAR(10),
	duration VARCHAR(10),
	listed_in VARCHAR(100),
	description VARCHAR(500)
	);
SELECT * FROM netflix_raw;

--DATA CLEANING AND PROCESSING
--1 REMOVING DUPLICATES:

SELECT show_id,count(*)
FROM netflix_raw
GROUP BY show_id
HAVING count(*)>1;

ALTER TABLE netflix_raw
ADD PRIMARY KEY(show_id);

SELECT * FROM netflix_raw
WHERE concat(title,type) in(
SELECT concat(title,type) 
FROM netflix_raw
GROUP BY title,type
HAVING count(*)>1
)
ORDER BY title;

DELETE FROM netflix_raw
WHERE show_id in ('s304','s160','s1271');

--2 NEW TABLES FOR listed_in, director, country, casts:

SELECT show_id, TRIM(unnest(string_to_array(director,','))) as directors
	into netflix_directors
FROM netflix_raw;
-------------------------------------------------------------------
SELECT show_id, TRIM(unnest(string_to_array(country,','))) as countries
	into netflix_countries
FROM netflix_raw;
--------------------------------------------------------------------
SELECT show_id, TRIM(CAST(unnest(string_to_array(listed_in,',')) AS VARCHAR(30))) as genres 
	into netflix_genres
FROM netflix_raw;
--------------------------------------------------------------------
SELECT show_id, TRIM(unnest(string_to_array(casts,','))) as casts
	into netflix_casts
FROM netflix_raw;
--------------------------------------------------------------------
--3 DATE TYPE CONVERSION FOR DATE_ADDED:
ALTER TABLE netflix_raw
ALTER date_added
TYPE date
USING date_added::date;

--4 POPULATING MISSING VALUES IN COUNTRY, DURATION:
	
SELECT directors,countries
FROM netflix_directors as nd
inner join netflix_countries as nc
ON nd.show_id=nc.show_id
GROUP BY directors,countries

insert into netflix_countries
SELECT show_id,mp.countries 
FROM netflix_raw as nr
	inner join(
	SELECT directors,countries
FROM netflix_directors as nd
inner join netflix_countries as nc
ON nd.show_id=nc.show_id
GROUP BY directors,countries
	) as mp
	ON nr.director=mp.directors
WHERE nr.country is null;
-----------------------------------------
--5 FINAL CLEAN TABLE:
with temp as(
SELECT *,
ROW_NUMBER() over(partition by title, type order by show_id) as rn
FROM netflix_raw
	)
SELECT show_id, type, title, date_added, release_year, rating,
case when duration is null then rating else duration end as duration, description
	INTO netflix
FROM temp;

--NETFLIX DATA ANALYSIS--
/* 1. For each director count the no of  movies and TV shows created by them in separate columns
 who have created tv shows and movies both*/

SELECT nd.directors,
	COUNT(distinct CASE WHEN n.type='Movie' then n.show_id end) as no_of_movies,
	COUNT(distinct CASE WHEN n.type='TV Show' then n.show_id end) as no_of_TVshows
	FROM netflix as n
INNER JOIN netflix_directors as nd
ON n.show_id=nd.show_id
GROUP BY nd.directors
	HAVING COUNT(distinct n.type)>1

--2) Which country has highest number of comedy movies:
with temp as(
SELECT ng.show_id,nc.countries
FROM netflix_genres as ng
	INNER JOIN netflix_countries as nc
	ON ng.show_id=nc.show_id
	INNER JOIN netflix as n
	ON ng.show_id=n.show_id
WHERE ng.genres='Comedies' AND n.type='Movie'
	)
SELECT countries,COUNT(show_id) as no_of_movies
	FROM temp
	GROUP BY countries
ORDER BY no_of_movies desc
LIMIT 1;

--3) For each year(as per date_added to netflix), which director has maximum number of movies released?
with temp as(
SELECT nd.directors,DATE_PART('YEAR',date_added) as date_year,COUNT(n.show_id) as no_of_movies
	FROM netflix as n
INNER JOIN netflix_directors as nd
ON n.show_id=nd.show_id
	WHERE n.type='Movie'
GROUP BY nd.directors, date_year
),
 temp2 as(
SELECT *,
	ROW_NUMBER() over(partition by date_year ORDER BY no_of_movies desc,directors) as rn
FROM temp
	)
SELECT date_year,directors,no_of_movies
FROM temp2
	WHERE rn=1
GROUP BY date_year,directors,no_of_movies
ORDER BY date_year desc;


--4)What is the average duration of movies in each genre?
SELECT ng.genres, avg(cast(replace(duration,' min','') as INT)) as avg_duration 
FROM netflix as n
INNER JOIN netflix_genres as ng
ON n.show_id=ng.show_id
WHERE type='Movie'
GROUP BY ng.genres

--5) Find the list of directors who have created horror and comedy movies both.
--Display director names along with number of comedy and horror movies directed by them

SELECT nd.directors,
COUNT(DISTINCT CASE WHEN ng.genres='Comedies' THEN ng.show_id END) as no_of_comedy_movies,
COUNT(DISTINCT CASE WHEN ng.genres='Horror Movies' THEN ng.show_id END) as no_of_horror_movies
FROM netflix as n
	INNER JOIN netflix_genres as ng
	ON n.show_id=ng.show_id
	INNER JOIN netflix_directors as nd
	ON n.show_id=nd.show_id
WHERE type='Movie' and ng.genres in('Comedies','Horror Movies')
GROUP BY nd.directors
HAVING COUNT(distinct ng.genres)=2









