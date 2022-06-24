CREATE DATABASE EData;
USE EData;

/*Analyze the data by finding the answers to the questions below:*/

/*1. Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, 
“prod_dimen”, “shipping_dimen”, Create a new table, named as
“combined_table”. */
CREATE VIEW combined_table
AS
SELECT	
		C.First_name,
		C.Last_name,
		C.Region,
		C.Customer_Segment,
		
		P.Prod_Main_id,
		P.Product_Sub_Category,
				
		O.Order_Date,
		O.Order_Priority,
				
		S.Order_ID,
		S.Ship_Mode,
		S.Ship_Date,
		
		M.Ship_id,
		M.Ord_id,
		M.Prod_id,
		M.Cust_id,
		M.Sales,
		M.Discount,
		M.Order_Quantity,
		M.Product_Base_Margin
FROM dbo.market_fact M
LEFT JOIN dbo.prod_dimen P ON M.Prod_id = P.Prod_id
LEFT JOIN dbo.orders_dimen O ON M.Ord_id = O.Ord_id
LEFT JOIN dbo.shipping_dimen S ON M.Ship_id = S.Ship_id
LEFT JOIN dbo.cust_dimen C ON M.Cust_id = C.Cust_id

SELECT *
FROM combined_table;

----------------------------------------------------------------------
/*2. Find the top 3 customers who have the maximum count of orders.*/
select TOP 3 Cust_id,First_name,Last_name, count (Ord_id) as cnt_ord
from combined_table
group by Cust_id, First_name,Last_name
ORDER BY cnt_ord DESC;

------------------------------------------------------------------------
/*3. Create a new column at combined_table as DaysTakenForDelivery that 
contains the date difference of Order_Date and Ship_Date.*/
SELECT		*, DATEDIFF(DAY, Order_Date, Ship_Date) DaysTakenForDelivery
FROM		combined_table;

-----------------------------------------------------------------------
/*4. Find the customer whose order took the maximum time to get delivered.*/
SELECT TOP 1 First_name, Last_Name,  DATEDIFF(DAY, Order_Date, Ship_Date) AS MaxTime
FROM combined_table
ORDER BY MaxTime DESC;

----------------------------------------------------------------------
/*5. Count the total number of unique customers in January and how many of them 
came back every month over the entire year in 2011.*/
SELECT MONTH(Order_Date) Month_in_2011,COUNT(DISTINCT Cust_id) CustCameBack
FROM combined_table
WHERE Cust_id in
    (
    SELECT DISTINCT Cust_id
    FROM combined_table
    WHERE MONTH(Order_Date) = 1 AND YEAR(Order_Date) = 2011
    ) 
AND YEAR(Order_Date) =2011
GROUP BY MONTH(Order_Date);

----------------------------------------------------------------------
/*6. Write a query to return for each user the time elapsed(tamamlanan) between the first 
purchasing and the third purchasing, in ascending order by Customer ID.*/


SELECT  Cust_id,
		DATEDIFF(DAY,FirstOrderDate, ThirdOrderDate) date_dif
FROM(SELECT Cust_id, Ord_id,
		MIN(Order_Date) OVER (PARTITION BY Cust_id, Ord_id ORDER BY Cust_id) FirstOrderDate,
		LEAD(Order_Date,2) OVER (PARTITION BY Cust_id ORDER BY Order_date) ThirdOrderDate,
		ROW_NUMBER() OVER (PARTITION BY Cust_id ORDER BY Order_Date) row_num
FROM combined_table) D
WHERE DATEDIFF(DAY,FirstOrderDate, ThirdOrderDate) IS NOT NULL 
AND row_num = 1
;

-----------------------------------------------------------
/*7. Write a query that returns customers who purchased both product 11 and 
product 14, as well as the ratio of these products to the total number of 
products purchased by the customer.*/

WITH tab1 as (
Select Cust_id ,
		SUM(CASE WHEN Prod_id = 11 THEN order_quantity else 0 end) sum_prod11,
		SUM(CASE WHEN Prod_id = 14 THEN order_quantity else 0 end) sum_prod14,
		SUM (Order_Quantity) sum_prod
FROM combined_table
group by Cust_id
having SUM(CASE WHEN Prod_id = 11 THEN order_quantity else 0 end) >=1
		and SUM(CASE WHEN Prod_id = 14 THEN order_quantity else 0 end) >=1
		)
SELECT Cust_id,sum_prod11,sum_prod14,	
		CAST (1.0*sum_prod11/ sum_prod AS NUMERIC (3,2)) AS ratıo_p11,
		CAST (1.0*sum_prod14/ sum_prod AS NUMERIC (3,2)) AS ratıo_p14
FROM tab1;






----------------Customer Segmentation--------------------
/*Categorize customers based on their frequency of visits. The following steps 
will guide you. If you want, you can track your own way.*/
/*1. Create a “view” that keeps visit logs of customers on a monthly basis. (For 
each log, three field is kept: Cust_id, Year, Month)*/
CREATE VIEW customer_log as 
SELECT Cust_id as cust_id, Order_Date,YEAR(Order_Date)as order_date_year, MONTH(order_date) as order_date_month
FROM combined_table;

SELECT * FROM customer_log;

----------------------------------------------------------
/*2. Create a “view” that keeps the number of monthly visits by users. (Show 
separately all months from the beginning business)*/

CREATE VIEW num_visit as  

SELECT	Cust_id,Order_Date,order_date_year ,order_date_month ,
		COUNT(*) count_visit
FROM	customer_log
GROUP BY Cust_id,Order_Date ,order_date_year ,order_date_month ;

SELECT * FROM num_visit ;


-----------------------------------------------------------
/*3. For each visit of customers, create the next month of the visit as a separate 
column.*/
CREATE VIEW next_month_visit as 
 SELECT  Cust_id,First_name, Last_name, YEAR(Order_Date) as Order_year, Month(Order_Date) as Order_month,
		LEAD(Month(Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Order_Date) next_visit
FROM	combined_table
Group by Cust_id, First_name, Last_name, Order_Date;
  SELECT * FROM next_month_visit
;

-----------------------------------------------------------
/*4. Calculate the monthly time gap between two consecutive visits by each 
customer.*/
CREATE VIEW time_gaps AS
SELECT	*,
		DATEDIFF(MONTH, Order_Date, next_visit) time_gap
FROM
		(
		SELECT		M.Cust_id, O.Order_Date, 
					LEAD((Order_Date)) OVER(PARTITION BY Cust_id ORDER BY Order_Date) next_visit
		FROM		market_fact M, orders_dimen O
		WHERE		M.Ord_id = O.Ord_id
		) A
SELECT * FROM time_gaps;
--drop view if exists time_gaps
-----------------------------------------------------------
/*5. Categorise customers using average time gaps. Choose the most fitted
labeling model for you.
For example: 
o Labeled as churn if the customer hasn't made another purchase in the 
months since they made their first purchase.
o Labeled as regular if the customer has made a purchase every month.
Etc.*/
--first step--
CREATE  VIEW total_avg_gap AS
SELECT AVG(avg_time_gap*1.0) avg_gap
FROM(
SELECT Cust_id, AVG( time_gap ) avg_time_gap
	 FROM  time_gaps
	 GROUP BY Cust_id) A;

----last step---
 SELECT cust_id, avg_time_gap,
	CASE 
		WHEN avg_time_gap <= (SELECT * FROM total_avg_gap)	  THEN 'Regular'
		WHEN (avg_time_gap > (SELECT * FROM total_avg_gap)	 OR avg_time_gap  IS NULL) THEN 'Churn'
	END cust_avg_time_gaps
FROM(SELECT Cust_id, AVG( time_gap ) avg_time_gap
	 FROM  time_gaps
	 GROUP BY Cust_id) A;

----------------Month-Wise Retention Rate------------------------
/*Find month-by-month customer retention ratei since the start of the business.
There are many different variations in the calculation of Retention Rate. But we will 
try to calculate the month-wise retention rate in this project.
So, we will be interested in how many of the customers in the previous month could 
be retained in the next month.
Proceed step by step by creating “views”. You can use the view you got at the end of 
the Customer Segmentation section as a source.*/

/*1. Find the number of customers retained month-wise. (You can use time gaps)*/
CREATE VIEW RetentionMonthWise AS
SELECT	DISTINCT *,
		COUNT (Cust_id)	OVER (PARTITION BY next_visit ORDER BY Cust_id, next_visit) retention_month_wise
FROM	time_gaps
where	time_gap =1
 ;
 --DROP VIEW IF EXISTS retention_month_vise
 SELECT * FROM RetentionMonthWise;
/*2. Calculate the month-wise retention rate.
Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total 
Number of Customers in the Current Month
If you want, you can track your own way.*/ 
CREATE VIEW time_gap_4
AS
SELECT Cust_id, Month(Order_Date) as Month_of_order, YEAR(Order_Date) as Year_of_Order, time_gap,
		CASE
			WHEN time_gap = 1 THEN 'retained'
		
		END AS Ret_num
from  time_gaps;


SELECT * FROM time_gap_4;


CREATE VIEW Toplamretinsayisi3
AS
SELECT Year_of_Order,Month_of_order, COUNT(Cust_id) as toplamret
FROM time_gap_4
WHERE Ret_num='retained'
GROUP BY  Year_of_Order, Month_of_order
-- ORDER BY 1,2


SELECT  *
FROM    Toplamretinsayisi3


CREATE VIEW Year_Month_Cust
AS
SELECT DISTINCT YEAR(Order_date) AS Yearly, MONTH(Order_Date) as Monthly, 
       count(cust_id) OVER (PARTITION BY YEAR(Order_date), MONTH(Order_Date)) as MonthlyCustomer
FROM combined_table
GROUP BY YEAR(Order_date), MONTH(Order_Date), Cust_id


SELECT *
FROM Year_Month_Cust


WITH ret_table AS 
(
SELECT  A.*, B.toplamret, 
        MIN(1.0*B.toplamret/A.MonthlyCustomer) OVER (PARTITION BY Yearly, Monthly) AS retention
FROM    Year_Month_Cust A, Toplamretinsayisi3 B
WHERE   A.Yearly = B.Year_of_Order AND A.Monthly = B.Month_of_Order
)
SELECT Yearly, Monthly, CAST(retention AS NUMERIC (3,2)) as Retention_Rate
FROM ret_table
-------END-------------------------------------