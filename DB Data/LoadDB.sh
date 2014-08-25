#!/bin/sh

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP Cars.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP ModelCodes.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP SuperchipsWebsite.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP SuperchipsMakes.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP Categories.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCAirFilters.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCAirProducts.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCCars.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCmods.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP CarFilters.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP FIWebsite.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP FIProducts.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP FIStoreLayout.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCRacingCoilovers.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP QuantumCars.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP ZenCartStoreEntries.csv

