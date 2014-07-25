sudo rm -f /tmp/Cars* /tmp/ModelCodes* /tmp/Superchips* /tmp/Categories* /tmp/BMC* /tmp/CarFilters* /tmp/BCRacing* /tmp/FIWebsite.* /tmp/FIProducts.* /tmp/QuantumCars.* /tmp/ZenCartStoreEntries.*

sudo -u john mysqldump --tab="/tmp" --fields-enclosed-by='"' --fields-terminated-by="," --lines-terminated-by="\n" --no-create-info TP;
cp /tmp/Cars.txt ./Cars.csv
cp /tmp/ModelCodes.txt ./ModelCodes.csv
cp /tmp/SuperchipsWebsite.txt ./SuperchipsWebsite.csv
cp /tmp/SuperchipsMakes.txt ./SuperchipsMakes.csv
cp /tmp/Categories.txt ./Categories.csv
cp /tmp/BMCAirFilters.txt ./BMCAirFilters.csv
cp /tmp/BMCCars.txt ./BMCCars.csv
cp /tmp/BMCmods.txt ./BMCmods.csv
cp /tmp/CarFilters.txt ./CarFilters.csv
cp /tmp/BCRacingCoilovers.txt ./BCRacingCoilovers.csv
cp /tmp/FIWebsite.txt ./FIWebsite.csv
cp /tmp/FIProducts.txt ./FIProducts.csv
cp /tmp/QuantumCars.txt ./QuantumCars.csv
cp /tmp/ZenCartStoreEntries.txt ./ZenCartStoreEntries.csv
