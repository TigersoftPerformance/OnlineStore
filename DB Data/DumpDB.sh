sudo rm -f /tmp/Alias[MF]* /tmp/BCForged* /tmp/BCRacing* /tmp/BMC* /tmp/Cars* /tmp/Categories* /tmp/ModelCodes* /tmp/QuantumCars.* /tmp/Superchips* /tmp/FIWebsite.* /tmp/FIProducts.* /tmp/FIStoreLayout.* /tmp/ZenCartStoreEntries.*

sudo -u john mysqldump --tab="/tmp" --fields-enclosed-by='"' --fields-terminated-by="," --lines-terminated-by="\n" --no-create-info TP;

cp /tmp/AliasMake.txt ./AliasMake.csv
cp /tmp/AliasModel.txt ./AliasModel.csv
cp /tmp/AliasModelCode.txt ./AliasModelCode.csv
cp /tmp/AliasFuelType.txt ./AliasFuelType.csv

cp /tmp/BCForgedWheelsImages.txt ./BCForgedWheelsImages.csv
cp /tmp/BCForgedWheelsPCD.txt ./BCForgedWheelsPCD.csv
cp /tmp/BCForgedWheelsPrices.txt ./BCForgedWheelsPrices.csv
cp /tmp/BCForgedWheelsRemarks.txt ./BCForgedWheelsRemarks.csv
cp /tmp/BCForgedWheelsSizes.txt ./BCForgedWheelsSizes.csv
cp /tmp/BCForgedWheelsWebsite.txt ./BCForgedWheelsWebsite.csv

cp /tmp/BCRacingCoilovers.txt ./BCRacingCoilovers.csv

cp /tmp/BMCCars.txt ./BMCCars.csv
cp /tmp/BMCFitment.txt ./BMCFitment.csv
cp /tmp/BMCProducts.txt ./BMCProducts.csv
cp /tmp/BMCStockedProducts.txt ./BMCStockedProducts.csv

cp /tmp/Cars.txt ./Cars.csv
cp /tmp/Categories.txt ./Categories.csv
cp /tmp/ModelCodes.txt ./ModelCodes.csv

cp /tmp/QuantumCars.txt ./QuantumCars.csv

cp /tmp/FIWebsite.txt ./FIWebsite.csv
cp /tmp/FIProducts.txt ./FIProducts.csv
cp /tmp/FIStoreLayout.txt ./FIStoreLayout.csv

cp /tmp/SuperchipsWebsite.txt ./SuperchipsWebsite.csv
cp /tmp/SuperchipsMakes.txt ./SuperchipsMakes.csv

cp /tmp/ZenCartStoreEntries.txt ./ZenCartStoreEntries.csv
