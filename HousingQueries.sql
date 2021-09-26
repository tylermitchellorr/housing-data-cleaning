--A cleaning of Nashville housing data

--A small disclaimer - In this cleaning, I removed columns that I had deemed superfluous. I would *never* do this in
--a professional setting without a direct order in-writing from a superior. 

--Quick check to see if our data was correctly imported. We are set!

SELECT * 
FROM dbo.Houses

--We have some strange half-null rows in the data. Rather than just getting rid of all nulls,
--let's see if we can salvage as much data as possible.

SELECT *
FROM dbo.Houses
WHERE PropertyAddress IS NULL

--Notice that ParcelID often has multiple entries for the same property - this is because a property is listed in multiple
--instances over time. In some cases, it appears sale information is missing, meaning that we have null rows grouped with 
--filled rows with the same ParcelID. Let's get rid of the null rows.
--We will need to use a self-join for this, since we're comparing rows to rows. 

SELECT * 
FROM dbo.Houses
ORDER BY ParcelID

SELECT p.ParcelID, q.ParcelID, p.PropertyAddress, q.PropertyAddress
FROM dbo.Houses p
JOIN dbo.Houses q
	ON p.ParcelID = q.ParcelID
	AND p.[UniqueID ] <> q.[UniqueID ] 
WHERE p.PropertyAddress IS NULL

--Excellent! We've identified distinct properties that have NULL addresses in some rows. Let's use IS NULL to populate these rows.

SELECT p.ParcelID, q.ParcelID, p.PropertyAddress, q.PropertyAddress, ISNULL(p.PropertyAddress, q.PropertyAddress)
FROM dbo.Houses p
JOIN dbo.Houses q
	ON p.ParcelID = q.ParcelID
	AND p.[UniqueID ] <> q.[UniqueID ] 
WHERE p.PropertyAddress IS NULL

-- THE ISNULL statement is what we want to UPDATE to.

UPDATE p
SET PropertyAddress = ISNULL(p.PropertyAddress, q.PropertyAddress)
FROM dbo.Houses p
JOIN dbo.Houses q
	ON p.ParcelID = q.ParcelID
	AND p.[UniqueID ] <> q.[UniqueID ] 
WHERE p.PropertyAddress IS NULL

--Double checking our work with the same query...

SELECT p.ParcelID, q.ParcelID, p.PropertyAddress, q.PropertyAddress, ISNULL(p.PropertyAddress, q.PropertyAddress)
FROM dbo.Houses p
JOIN dbo.Houses q
	ON p.ParcelID = q.ParcelID
	AND p.[UniqueID ] <> q.[UniqueID ] 
WHERE p.PropertyAddress IS NULL

--Perfect! We have filled in all of the null rows with information found from other related rows. Let us move on.

SELECT SaleDate 
FROM dbo.Houses

--The SaleDate column has time included, which is irrelevant. Let's trim it.

SELECT SaleDate, CONVERT(DATE, SaleDate) as SaleDateDesired
FROM dbo.Houses

--This is what we want, let's update!

ALTER TABLE Houses
ADD SaleDateFixed DATE;

UPDATE Houses
SET SaleDateFixed = CONVERT(DATE, SaleDate)

SELECT SaleDate, SaleDateFixed
FROM dbo.Houses

--We can see that we've added a new column called SaleDateFixed that has our desired formatting. Let's DROP the old column.

ALTER TABLE Houses
DROP COLUMN SaleDate

--Next, let's take a look at the PropertyAddress column.

SELECT PropertyAddress
FROM dbo.Houses

--Currently, the PropertyAddress column contains street address and city data. Let's split these into two columns.

SELECT
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) as Address,
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) as Address
FROM Houses

ALTER TABLE Houses
ADD StreetAddress nvarchar(255);

UPDATE Houses
SET StreetAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1)

ALTER TABLE Houses
ADD City nvarchar(255);

UPDATE Houses
SET City = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress))


--Quick check to see that our columns were added correctly:

SELECT * FROM Houses

--Perfect! Let's nix the old PropertyAddress column.

ALTER TABLE Houses
DROP COLUMN PropertyAddress

--Now, let's look at why we have NULLS in the OwnerAddress column. 

SELECT OwnerAddress
FROM Houses

SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1),
		PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2),
		PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3)
FROM Houses

--Whoops, let's reorder these so our columns aren't in State City Address order
--Note that SQL doesn't care about the order of the columns, but reordering this will make the data easier for us to use.

SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3),
		PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2),
		PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1)
FROM Houses

--Let's add these new columns to our table, and drop the old columns.

ALTER TABLE Houses
ADD OwnerStreet nvarchar(255);

ALTER TABLE Houses
ADD OwnerCity nvarchar(255);

ALTER TABLE Houses
ADD OwnerState nvarchar(255);

UPDATE Houses
SET OwnerStreet = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3)

UPDATE Houses
SET OwnerCity = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2)

UPDATE Houses
SET OwnerState = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1)

--Perfect! Time to drop the old column.

ALTER TABLE Houses
DROP COLUMN OwnerAddress


--Next, we can see that in the SoldAsVacant column, we have multiple distinct responses (Yes, Y, No, N). Let's standardize these.

SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'Y' THEN 'YES'
	 WHEN SoldAsVacant = 'N' THEN 'NO'
	 ELSE SoldAsVacant
	 END
FROM Houses

--Perfect. Let us update the table to add this new column.

UPDATE Houses
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'YES'
						WHEN SoldAsVacant = 'N' THEN 'NO'
						ELSE SoldAsVacant
						END
FROM Houses

--Next, let's see if we have any duplicate rows to clean up. We will be partitioning on rows that should be unique to individual rows. 


WITH rnCTE AS (

SELECT *, ROW_NUMBER() OVER (
		  PARTITION BY ParcelID, 
					   StreetAddress,
					   SalePrice,
					   SaleDateFixed,
					   LegalReference
					   ORDER BY UniqueID
					   ) row_num
					   
FROM Houses
)

SELECT * 
FROM rnCTE
WHERE row_num > 1
ORDER BY StreetAddress

--this CTE query tells us that we have 104 duplicates. So, let's repeat this query except DELETE rather than SELECT.

WITH rnCTE AS (

SELECT *, ROW_NUMBER() OVER (
		  PARTITION BY ParcelID, 
					   StreetAddress,
					   SalePrice,
					   SaleDateFixed,
					   LegalReference
					   ORDER BY UniqueID
					   ) row_num
					   
FROM Houses
)

DELETE
FROM rnCTE
WHERE row_num > 1
ORDER BY StreetAddress

--At this point, I would consider the data minimally cleaned for use. Thanks for sticking around if you're reading this!