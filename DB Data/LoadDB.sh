#!/bin/sh

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP AliasMake.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP AliasModel.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP AliasModelCode.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP AliasFuelType.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCForgedWheelsImages.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCForgedWheelsPCD.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCForgedWheelsPrices.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCForgedWheelsRemarks.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCForgedWheelsSizes.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCForgedWheelsWebsite.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BCRacingCoilovers.csv

mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCCars.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCProducts.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCFitment.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP BMCStockedProducts.csv


mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP Cars.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP Categories.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP ModelCodes.csv


mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP QuantumCars.csv


mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP FIWebsite.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP FIProducts.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP FIStoreLayout.csv


mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP SuperchipsWebsite.csv
mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP SuperchipsMakes.csv


mysqlimport --local --delete --fields-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by='\n' --verbose TP ZenCartStoreEntries.csv

