-- This is an SQL script to build an SQL Server database for the 
-- TRANDB.LG4 sample model.  You can run this script with the
-- SQL Server Query Analyzer:
--    Start|Programs|Microsoft SQL Server|Query Analyzer
-- You should then run the File|Open command to open this
-- script in the Analyzer.  Once opened, run the Query|Execute
-- command to run the scipt. Next, from the Windows Control 
-- Panel, you will need to run the ODBC Administrator to add
-- an SQL Server ODBC datasource that points to the new 
-- SQL database containing the tables you just created.  
-- You must title this datasource "transportation". You should 
-- then be able to run the TRANDB.LG4 model in LINGO, which 
-- reads data from and writes the solution to the tables 
-- created by this script.

BEGIN TRANSACTION

--DROP TABLE PLANTS, CUSTOMERS, ARCS;

CREATE TABLE PLANTS
(
 ID		CHAR(4)		PRIMARY KEY,
 PLANTS		CHAR(32)	NOT NULL,
 CAPACITY	FLOAT		NOT NULL
);

CREATE TABLE CUSTOMERS
(
 ID		CHAR(4)		PRIMARY KEY,
 CUSTOMERS	CHAR(32)	NOT NULL,
 DEMAND     	FLOAT		NOT NULL
);

CREATE TABLE ARCS
(
 ID	 	CHAR(4)		PRIMARY KEY,
 PLANTS		CHAR(32)	NOT NULL,
 CUSTOMERS	CHAR(32)	NOT NULL,
 COST   	FLOAT		NOT NULL,
 VOLUME   	FLOAT		NOT NULL
);

DELETE FROM PLANTS;
DELETE FROM CUSTOMERS;
DELETE FROM ARCS;

INSERT INTO PLANTS VALUES ('0001', 'Plant1', 30);
INSERT INTO PLANTS VALUES ('0002', 'Plant2', 25);
INSERT INTO PLANTS VALUES ('0003', 'Plant3', 21);

INSERT INTO CUSTOMERS VALUES ('0001', 'Cust1', 15);
INSERT INTO CUSTOMERS VALUES ('0002', 'Cust2', 17);
INSERT INTO CUSTOMERS VALUES ('0003', 'Cust3', 22);
INSERT INTO CUSTOMERS VALUES ('0004', 'Cust4', 12);

INSERT INTO ARCS VALUES ('0001', 'Plant1', 'Cust1', 6, 0);
INSERT INTO ARCS VALUES ('0002', 'Plant1', 'Cust2', 2, 0);
INSERT INTO ARCS VALUES ('0003', 'Plant1', 'Cust3', 6, 0);
INSERT INTO ARCS VALUES ('0004', 'Plant1', 'Cust4', 7, 0);

INSERT INTO ARCS VALUES ('0005', 'Plant2', 'Cust1', 4, 0);
INSERT INTO ARCS VALUES ('0006', 'Plant2', 'Cust2', 9, 0);
INSERT INTO ARCS VALUES ('0007', 'Plant2', 'Cust3', 5, 0);
INSERT INTO ARCS VALUES ('0008', 'Plant2', 'Cust4', 3, 0);

INSERT INTO ARCS VALUES ('0009', 'Plant3', 'Cust1', 8, 0);
INSERT INTO ARCS VALUES ('0010', 'Plant3', 'Cust2', 8, 0);
INSERT INTO ARCS VALUES ('0011', 'Plant3', 'Cust3', 1, 0);
INSERT INTO ARCS VALUES ('0012', 'Plant3', 'Cust4', 5, 0);

COMMIT;