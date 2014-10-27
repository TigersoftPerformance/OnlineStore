BEGIN		{
		linesPerFile = 2000;

		outfilePrefix = "AllSE";
		outfileSuffix = ".csv";
		outfileCount = 0;
		}

NR == 1		{
		headerrow = $0;
		outfileCount = outfileCount + 1;
		outfileName = sprintf ("%s%02d%s", outfilePrefix, outfileCount, outfileSuffix);
		print headerrow > outfileName;
		next;
		}

		{
		print >> outfileName;
		}

(NR % linesPerFile) == 0 {
		close (outfileName);
		outfileCount = outfileCount + 1;
		outfileName = sprintf ("%s%02d%s", outfilePrefix, outfileCount, outfileSuffix);
		print headerrow > outfileName;
		next;
		}

		

