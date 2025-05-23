-- Check for duplicates
-- Some book seem to be listed twice, bu twith different produect deatils, including price

Select title, COUNT(title)
From PortfolioProject.dbo.KindleData
GROUP BY title
ORDER BY COUNT(title) desc;

WITH RowNumCTE AS(
Select *, 
	ROW_NUMBER() OVER (
	PARTITION BY Title,
				 Author,
				 publishedDate
				 ORDER BY asin
				 ) row_num
From PortfolioProject.dbo.KindleData;

SELECT *
From RowNumCTE
Where row_num > 1
Order by Title;

-- Change published date from date/time to date

ALTER TABLE PortfolioProject.dbo.KindleData
ALTER COLUMN publishedDate Date;

-- Checking categories for proper labeling

Select category_name, COUNT(category_name)
From PortfolioProject.dbo.KindleData
GROUP BY category_name
ORDER BY COUNT(category_name) desc;

-- Replacing "Literaturea & Fiction" with "Literature", and "nonfiction" with "Misc Nonfiction"

Select category_name,
CASE When category_name = 'Literature & Fiction' THEN 'Literature'
	   When category_name = 'Nonfiction' THEN 'Misc Nonfiction'
	   Else category_name
	   END
From PortfolioProject.dbo.KindleData;

Update PortfolioProject.dbo.KindleData
SET  category_name = CASE When category_name = 'Literature & Fiction' THEN 'Literature'
	   When category_name = 'Nonfiction' THEN 'Misc Nonfiction'
	   Else category_name
	   END;

-- Checking soldBy for proper labeling

Select soldBy, COUNT(soldBy)
From PortfolioProject.dbo.KindleData
GROUP BY soldBy
ORDER BY COUNT(soldBy) desc;

-- Checking odd Null value in SoldBY
-- It seems mostly childrens books and foreign language books have null soldbys

Select *
From PortfolioProject.dbo.KindleData
Where soldBy is null;

Select category_name, COUNT(category_name)
From PortfolioProject.dbo.KindleData
Where soldBy is null
GROUP BY category_name
ORDER BY COUNT(category_name) desc;

-- Check for outliers
-- author, it's just jame patterson lol

Select author, COUNT(author)
From PortfolioProject.dbo.KindleData
GROUP BY author
ORDER BY COUNT(author) desc;

-- Stars, it seems zero is used if there is no star rating. 
-- Minumum number of stars when there is at least one review is 1, which implies 1 is the lowest score users can give.

Select stars, COUNT(stars)
From PortfolioProject.dbo.KindleData
GROUP BY stars
Order by COUNT(stars) desc;

Select Title, stars
From PortfolioProject.dbo.KindleData
Where stars is null
Order by title desc;

Select Title, stars, reviews
From PortfolioProject.dbo.KindleData
Where stars < 2
	AND reviews > 0
Order by title desc;

-- set star rating to null when number of ratings is zero

Select stars
, CASE When stars = 0 THEN NULL
	   Else stars
	   END
From PortfolioProject.dbo.KindleData;

Update PortfolioProject.dbo.KindleData
SET  stars = CASE When stars = 0 THEN NULL
	   Else stars
	   END;

-- Reviews, nothing abnormal , where the crawdads sing is the most reviewed, didn't know it was that popular

Select reviews, COUNT(reviews)
From PortfolioProject.dbo.KindleData
GROUP BY reviews
Order by COUNT(reviews) desc;

Select title, reviews
From PortfolioProject.dbo.KindleData
Order by reviews asc;

--Price, there are a few very expensive books and many $0, if grouping by price may want to use seperate bings for free and $100+

Select title, price
From PortfolioProject.dbo.KindleData
Order by price desc;

Select price, COUNT(price)
From PortfolioProject.dbo.KindleData
GROUP BY price
Order by COUNT(price) asc;

--publishedDate, six books seemed to have been published after this dataset was published, two books have published date of 1900 mistankenly listed
-- large number have published date coinciding with the relese of the kindle international

Select title, publishedDate
From PortfolioProject.dbo.KindleData
Where publishedDate is not null
Order by publishedDate asc;

Select publishedDate, COUNT(publishedDate)
From PortfolioProject.dbo.KindleData
Where publishedDate < '2020-01-01'
GROUP BY publishedDate
Order by COUNT(publishedDate) desc;

-- Remove late published book from dataset and set date for 1900s books to null

DELETE FROM PortfolioProject.dbo.KindleData WHERE publishedDate > '2023-10-02';

Select publishedDate,
CASE When publishedDate = '1900-01-01' THEN NULL
	   Else publishedDate
	   END
From PortfolioProject.dbo.KindleData
Order by publishedDate asc;

Update PortfolioProject.dbo.KindleData
SET  publishedDate = CASE When publishedDate = '1900-01-01' THEN NULL
	   Else publishedDate
	   END;

--Investigate NULLS, 424 in author, 9299 in soldby, 49019 in publishedDate, (reminder 133096 total entries)
-- Seems more prevelant in foreign language for author, soldby and date nulls. More prevlant in children's ebooks for author and soldby nulls

Select *
From PortfolioProject.dbo.KindleData
Where publishedDate IS NULL;

Select category_name, COUNT(category_name)
From PortfolioProject.dbo.KindleData
Where publishedDate IS NULL
GROUP BY category_name
ORDER BY COUNT(category_name) desc;

-- Create published order by author for later views

ALTER TABLE PortfolioProject.dbo.KindleData
Add numberpublished int;

WITH RowNUMCTE AS(
Select asin,
	ROW_NUMBER() OVER (
		PARTITION BY Author
		ORDER BY publishedDate
	) as row_num
From PortfolioProject.dbo.KindleData);

Update a
SET a.numberpublished = b.row_num
From PortfolioProject.dbo.KindleData AS a
JOIN RowNUMCTE AS b
 on a.asin = b.asin;

Select author, numberpublished
From PortfolioProject.dbo.KindleData
Where author is not null
Order by numberpublished desc;

Update PortfolioProject.dbo.KindleData
SET  numberpublished = CASE When author IS NULL THEN NULL
	   Else numberpublished
	   END;


-- VIEWS

-- Odd of being special  over numberpublished
Create view awardodds AS
Select numberpublished, 
(SUM(CAST(isBestSeller AS float))/COUNT(numberpublished)) as BestSellerodds, (SUM(CAST(isEditorsPick AS float))/COUNT(numberpublished)) as editorsodds, (SUM(CAST(isGoodReadsChoice AS float))/COUNT(numberpublished)) as goodreadsodds
From PortfolioProject.dbo.KindleData
Where numberpublished is not null
Group by numberpublished;

--price changes over numberpublished

Create view avgprices AS
Select numberpublished, AVG(price) as avgprice
From PortfolioProject.dbo.KindleData
Where numberpublished is not null
Group by numberpublished;


-- category breakdown by authors who have published <10, 10-100, <100 books

WITH tenset AS(
	Select category_name, COUNT(category_name) AS subtencount
	From PortfolioProject.dbo.KindleData
	Where numberpublished is not null
		AND numberpublished < 10
	Group by category_name;
	),
	maxset AS(
		Select category_name, COUNT(category_name) as maxcount
		From PortfolioProject.dbo.KindleData
		Where numberpublished is not null
			AND numberpublished >= 100
		Group by category_name
	)

Create view catbreak AS
Select subten.category_name, COUNT(subten.category_name) as tentohundred, MAX(tenset.subtencount) as underten, MAX(maxset.maxcount) as overhundred
From PortfolioProject.dbo.KindleData AS subten
	JOIN tenset 
	ON subten.category_name = tenset.category_name
	JOIN maxset 
	ON subten.category_name = maxset.category_name
Where numberpublished is not null
	AND numberpublished >= 10
	AND numberpublished < 100
Group by subten.category_name;


-- odd of being special over time

Create view awardtime AS
Select publishedDate,
	(SUM(CAST(isBestSeller AS float))/COUNT(publishedDate)) as BestSellerodds, 
    (SUM(CAST(isEditorsPick AS float))/COUNT(publishedDate)) as editorsodds, 
	(SUM(CAST(isGoodReadsChoice AS float))/COUNT(publishedDate)) as goodreadsodds
FROM PortfolioProject.dbo.KindleData
Group by publishedDate
HAVING COUNT(publishedDate) <> 0
Order by publishedDate desc;

--avg star review of numberpublished

Create view starnum AS
Select numberpublished, AVG(stars) as avgrating, COUNT(reviews) as reviewcount
FROM PortfolioProject.dbo.KindleData
Group by numberpublished
Order by numberpublished desc;