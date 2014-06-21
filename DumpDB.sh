sudo rm -f /tmp/Cars* /tmp/ModelCodes* /tmp/Superchips* /tmp/Categories* /tmp/BMC* /tmp/CarFilters*

mysqldump --user=root --password=doover11 --tab='/tmp' --fields-enclosed-by='"' --fields-terminated-by="," --lines-terminated-by="\n" --no-create-info TP;
cp /tmp/Cars.txt ./Cars.csv
cp /tmp/ModelCodes.txt ./ModelCodes.csv
cp /tmp/SuperchipsWebsite.txt ./SuperchipsWebsite.csv
cp /tmp/SuperchipsMakes.txt ./SuperchipsMakes.csv
cp /tmp/Categories.txt ./Categories.csv
cp /tmp/BMCAirFilters.txt ./BMCAirFilters.csv
cp /tmp/BMCCars.txt ./BMCCars.csv
cp /tmp/BMCmods.txt ./BMCmods.csv
cp /tmp/CarFilters.txt ./CarFilters.csv

