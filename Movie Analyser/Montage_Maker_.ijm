// Get input arguments
// $1	spooling folder
// $2	points
// $3	coverage
// $4	sorting
// $5   filter
sortingOptions = newArray("frames", "max_channel_1", "stringent_max_channel_2", "max_channel_2", "stringent_max_channel_3", "max_channel_3", "max_channel_4", "onset");
// $6	basis
// $7	flags
// $8	!flags
// $9	rows
// $10	columns
// $11	cellnumber
args = getArgument();
dialog = true;
cmd = false;
if (lengthOf(args) != 0) { // arguments included in call
	cmd = true;
	
	// Split arguments at blanks and merge what's in []
	args = split(args, " ");
	i=0;
	while (i<args.length) { // deal with blanks inside arguments
		if (startsWith(args[i], "[")) {
			x = substring(args[i], 1, lengthOf(args[i]));
			while (!endsWith(x, "]")) {
				x = x+" "+args[i+1];
				args = arrayRemoveItem(args, i+1);
			}
			x = substring(x, 0, lengthOf(x)-1);
			args[i] = ""+x+"";
		}
		i++;
	}
	
	// Open with specified default dialog settings (run from toolbar button)
	if (args.length == 1) {
		dirspool   = call("ij.Prefs.get", "MovieAnalyser.Experiment", "home/");
		sets       = readSettings(dirspool+args[0]);
		coverage   = getSetting(sets, "MM.coverage");
		coverage   = split(coverage, "+-");
		cframe     = parseInt(coverage[0]);
		pframes    = parseInt(coverage[1]);
		fframes    = parseInt(coverage[2]);
		sorting    = getSetting(sets, "MM.sorting");
		filter     = getSetting(sets, "MM.filter");
		basis      = getSetting(sets, "MM.basis");
		posflags   = getSetting(sets, "MM.posflags");
		negflags   = getSetting(sets, "MM.negflags");
		rows       = getSetting(sets, "MM.rows");
		columns    = getSetting(sets, "MM.columns");
		cellnumber = getSetting(sets, "MM.cellnumber");
		cellnumber = split(cellnumber, "-");
		cell       = cellnumber[0];
		if (cell == "all") number = 50;
		else number = parseInt(cellnumber[1]);
	}
	
	// Otherwise an exact number of arguments has to be passed on by the command line call (e.g. from main pipeline)
	else if (args.length != 11) exit("Please provide exactly the seven arguments to the montage maker:\n1: spooling folder, 2: points, 3: sorting, 4: flags, 5: !flags, 6: rows, 7: columns");
	else {
		// in this case no dialog has to be shown
		dialog = false;
		// parse arguments
		// $1	spooling folder
		dirspool = toString(args[0]);
		if (!endsWith(dirspool, File.separator)) dirspool = dirspool+File.separator;
		if (File.isDirectory(dirspool)) {
			cropdir = dirspool+"crops";
			if (!File.exists(cropdir)) exit("Please generate cropped cell movies first");
		}
		else {
			Array.print(args);
			exit("Spooling directory not found.");
		}
		// $2	points
		pointdirs = getFileList(cropdir); // possible folders
		i=0;
		while (i<pointdirs.length) { // remove files
			if (!File.isDirectory(cropdir+File.separator+pointdirs[i])) {pointdirs = arrayRemoveItem(pointdirs, i); i--;}
			i++;
		}
		if (args[1] == "all") { // process all points
			points = Array.getSequence(pointdirs.length);
		}
		else { // process specific points
			points = split(args[1],",,");
			if (points.length > pointdirs.length) exit("More points selected, than crops are present.");
			// error handling for numbers, that are too big
		}
		// $3	coverage
		coverage   = args[2];
		coverage   = split(coverage, "+-");
		cframe     = parseInt(coverage[0]);
		pframes    = parseInt(coverage[1]);
		fframes    = parseInt(coverage[2]);
		minstart   = cframe-pframes;
		minend     = cframe+fframes;
		coverage = ""+cframe+"+"+pframes+"-"+fframes;
		// $4	sorting
		sorting = args[3];
		if (arrayIndexOf(sortingOptions, sorting) == -1) exit("Please select one of the valid sorting options.");
		// $5	filter
		filter = args[4];
		filter = split(filter, "-");
		// $6	basis of classifications
		basis = args[5];
		if (File.exists(dirspool+"classification.csv")) {
			classification = File.openAsString(dirspool+"classification.csv");
			classification = split(classification, "\n");
			title = split(classification[0], "\t");
			basiscol = arrayIndexOf(title, basis);
			if (basiscol == -1) exit("Given classification set was not found.");
		}
		// $7 and $8	flags
		posflags = args[6];
		if (posflags == "none") posflags = "";
		negflags = args[7];
		if (negflags == "none") negflags = "";
		allflags = posflags+negflags;
		if (lengthOf(allflags) > 1) {
			uniqueflags = removeDuplicateCharacters(allflags);
			if (lengthOf(allflags) != lengthOf(uniqueflags)) exit("You can't select for and against a flag at once");
		}
		// $9 and $10
		rows    = parseInt(args[8]);
		columns = parseInt(args[9]);
		nperas  = rows*columns;
		// $11
		cellnumber =args[10];
	}
}
// define defaults for dialog
else {
	coverage   = "50+5-10";
	coverage   = split(coverage, "+-");
	cframe     = parseInt(coverage[0]);
	pframes    = parseInt(coverage[1]);
	fframes    = parseInt(coverage[2]);
	coverage = ""+cframe+"+"+pframes+"-"+fframes;
	sorting    = "frames";
	filter     = "min-max";
	posflags   = "c";
	negflags   = "d";
	rows       = 3;
	columns    = 5;
	cellnumber = "all";
	cell       = "all";
	number     = 50;
}
// Display user dialog
if (dialog) {
	if (!cmd) dirspool = getDirectory("Select spooling of the experiment ...");
	cropdir = dirspool+"crops";
	if (!File.exists(cropdir)) exit("Please generate cropped cell movies first");
	pointdirs = getFileList(cropdir);
	// remove files from list
	i=0;
	while (i<pointdirs.length) {
		if (!File.isDirectory(cropdir+File.separator+pointdirs[i])) {
			pointdirs = arrayRemoveItem(pointdirs, i);
		}
		else i++;
	}
	// Get Sample matching if present
	if (File.exists(dirspool+"experimentParameters.cfg")) {
		expe = readSettings(dirspool+"experimentParameters.cfg");
		ptmatching = newArray();
		i = 0;
		found = arrayIndexOf(expe, "pt_"+i);
		while (found != -1) {
			x = getSetting(expe, "pt_"+i);
			ptmatching = Array.concat(ptmatching, x);
			i++;
			found = arrayIndexOf(expe, "pt_"+i);
		}
	}
	else ptmatching = newArray();
	// append sample matching if length matches
	if (ptmatching.length == pointdirs.length) {
		for (i=0;i<pointdirs.length;i++) {
			pointdirs[i] = pointdirs[i]+" (sample "+ptmatching[i]+")";
		}
	}
	
	// Generat Dialog to get Settings form the user
	Dialog.create("Select which cells to assemble and how.");
	Dialog.addMessage("Point selection:");
	for (i=0;i<pointdirs.length;i++) {
		Dialog.addCheckbox(pointdirs[i], true);
	}
	Dialog.addNumber("Class-defining frame in full length movie:", cframe, 0, 2, "");
	Dialog.addNumber("Mininum number of preceding frames:", pframes, 0, 2, "");
	Dialog.addNumber("Mininum number of following frames:", fframes, 0, 2, "");
	bclassification = File.exists(dirspool+"classification.csv");
	if (bclassification) {
		classification = File.openAsString(dirspool+"classification.csv");
		classification = split(classification, "\n");
		title = split(classification[0], "\t");
		classchoice = Array.slice(title, 2, title.length);
		if (!cmd) basis = classchoice[0];
		Dialog.addChoice("Select based on classification set", classchoice, basis);
		Dialog.addString("Only show cells classified as:", posflags);
		Dialog.addString("Do not include cells classified as:", negflags);
	}
	Dialog.addChoice("Sorting criterium", sortingOptions, sorting);
	Dialog.addString("Filter by sorting criterium (##/min-##/max)", filter);
	cellnumberChoices = newArray("all", "top", "bottom", "random");
	Dialog.addChoice("Which cells whould be considered?", cellnumberChoices, cell);
	Dialog.addString("If not all, then how many cells per point? (## or ##%)", number);
	Dialog.addMessage("Montage dimensions:");
	Dialog.addNumber("rows:", rows, 0, 2, "");
	Dialog.addNumber("columns:", columns, 0, 2, "");
	Dialog.show();
	
	// Read out user input
	points   = newArray();
	for (i=0;i<pointdirs.length;i++) {
		p    = Dialog.getCheckbox();
		if (p) points = Array.concat(points, i);
	}
	// remove sample matching again
	if (ptmatching.length == pointdirs.length) {
		for (i=0;i<pointdirs.length;i++) {
			x = split(pointdirs[i], " ");
			pointdirs[i] = x[0];
		}
	}
	if (lengthOf(points) < 1) exit("Please select at least one point.");
	cframe   = Dialog.getNumber();
	pframes  = Dialog.getNumber();
	fframes  = Dialog.getNumber();
	minstart = cframe-pframes;
	minend   = cframe+fframes;
	if (minstart <= 0) exit("Classification frame must be > minimum preceding frames");
	coverage = ""+cframe+"+"+pframes+"-"+fframes;
	if (bclassification) {
		basis    = Dialog.getChoice();
		basiscol = arrayIndexOf(title, basis);
		posflags = Dialog.getString();
		negflags = Dialog.getString();
	}
	else {
		posflags = "";
		negflags = "";
	}
	sorting  = Dialog.getChoice();
	filter   = Dialog.getString();
	filter   = split(filter, "-");
	if (filter.length != 2) exit("Invalid filter entered. If you don't want to filter enter 'min-max'.");
	cell     = Dialog.getChoice();
	number   = Dialog.getString();
	if (cell != "all") cellnumber = cell+"-"+number;
	else cellnumber = cell;
	rows     = Dialog.getNumber();
	columns  = Dialog.getNumber();
	nperas   = rows*columns;
}

setBatchMode(true);
setBatchMode("show");

// Generate file list for each point and apply sorting and filters
// This will generate several matched arrays for each point: pfiles, pflags, psort
// All the points will be concatenated into matched arrays: files, sort
files = newArray();
dirfiles = newArray();
cframes = newArray();
sort = newArray();
for (p=0;p<points.length;p++) {
	
	// Read filenames
	pid = points[p];
	pdir = cropdir+File.separator+pointdirs[pid];
	pfiles = getFileList(pdir); // array containing file names
	f=0;
	while (f<pfiles.length) {
		if (!endsWith(pfiles[f], ".tif")) pfiles = arrayRemoveItem(pfiles, f);
		else f++;
	}
	
	// Filter for cells with valid coverage
	f=0;
	n=pfiles.length;
	pcframe = newArray(n); // array containing classification frame indices
	if (coverage != "1+0-0") {
		while (f<pfiles.length) {
			filename = pfiles[f];
			info = split(filename, "-_");
			start = parseInt(info[1]);
			stop = parseInt(info[2]);
			if (start > minstart || stop < minend) {
				pfiles = arrayRemoveItem(pfiles, f);
				pcframe = arrayRemoveItem(pcframe, f);
			}
			else {
				pcframe[f] = cframe-start+1;
				f++;
			}
		}
	}
	if (pfiles.length == 0) print("For point "+p+" no cells had the required coverage.");
	
	// Prepend point directory
	n = pfiles.length;
	pdirfiles = newArray(n); // array containing file folder and name as unique identifier
	for (f=0;f<pfiles.length;f++) {
		pdirfiles[f] = File.getName(pdir)+"\t"+pfiles[f];
	}
	
	// filter for flags
	if (lengthOf(posflags) != 0 || lengthOf(negflags) != 0) {
		// Read in classifications
		n=pfiles.length;
		pflags = newArray(n); // array containing flags of all cells
		for (f=0;f<pfiles.length;f++) {
			id = arrayIndexOf(classification, pdirfiles[f]);
			if (id != -1) {
				idsplit = split(classification[id], "\t");
				pflags[f] = idsplit[basiscol];
			}
		}
		// Filter flags
		if (lengthOf(posflags) != 0) { // flags to keep
			for (i=0;i<lengthOf(posflags);i++) {
				flag = substring(posflags, i, i+1);
				f=0;
				while(f<pflags.length) {
					if (indexOf(pflags[f], flag) == -1) { // flag is not present -> delete
						pfiles = arrayRemoveItem(pfiles, f);
						pcframe = arrayRemoveItem(pcframe, f);
						pdirfiles = arrayRemoveItem(pdirfiles, f);
						pflags = arrayRemoveItem(pflags, f);
						f--;
					}
					f++;
				}
			}
		}
		if (lengthOf(negflags) != 0) { // flags to ignore
			for (i=0;i<lengthOf(negflags);i++) {
				flag = substring(negflags, i, i+1);
				f=0;
				while(f<pflags.length) {
					if (indexOf(pflags[f], flag) != -1) { // flag is present -> delete
						pfiles = arrayRemoveItem(pfiles, f);
						pcframe = arrayRemoveItem(pcframe, f);
						pdirfiles = arrayRemoveItem(pdirfiles, f);
						pflags = arrayRemoveItem(pflags, f);
						f--;
					}
					f++;
				}
			}
		}
	}
	
	// generate sorting array
	n=pfiles.length;
	psort = newArray(n); // array containing sorting / filtering value
	mdir = getDirectory("plugins");
	mdir = mdir+"Movie Analyser"+File.separator;
	if (sorting == "frames") { // sort by movie length
		for (f=0;f<pfiles.length;f++) {
			filename = pfiles[f];
			info = split(filename, "-_");
			start = parseInt(info[1]);
			stop = parseInt(info[2]);
			length = stop-start;
			psort[f] = length;
		}
	}
	else if (sorting == "max_channel_1" || sorting == "stringent_max_channel_2" || sorting == "max_channel_2" || sorting == "stringent_max_channel_3" ||sorting == "max_channel_3" || sorting == "max_channel_4") {
		if (!File.exists(pdir+File.separator+sorting+".csv")) {
			print("Calculating sorting criterium for point "+File.getName(pdir)+".");
			runMacro(mdir+"Feature_Quantifier_.ijm", pdir+"\t"+sorting);
		}
		sortingvals = File.openAsString(pdir+File.separator+sorting+".csv");
		sortingvals = split(sortingvals, "\n");
		for (f=0;f<pfiles.length;f++) {
			ID = arrayIndexOf(sortingvals, pdirfiles[f]);
			if (ID == -1) print(pfiles[f]+" error in reading sorting.");
			else {
				val = sortingvals[ID];
				val = split(val, "\t");
				psort[f] = parseInt(val[2]);
			}
		}
	}
	else if (sorting == "onset") { // sort by onset of the movie
		for (f=0;f<pfiles.length;f++) {
			filename = pfiles[f];
			info = split(filename, "-_");
			start = parseInt(info[1]);
			psort[f] = start;
		}
	}
	
	// apply that sorting
	pfiles = sortByArray(pfiles, psort);
	pcframe = sortByArray(pcframe, psort);
	pdirfiles = sortByArray(pdirfiles, psort);
	psort = Array.sort(psort);
	
	
	// apply filtering
	if (filter[0] != "min") {
		fmin = parseInt(filter[0]);
		x = Array.concat(psort, fmin);
		x = Array.sort(x);
		fmin = arrayIndexOf(x, fmin);
	}
	else fmin = 0;
	if (filter[1] != "max") {
		fmax = parseInt(filter[1]);
		x = Array.concat(psort, fmax);
		x = Array.sort(x);
		fmax = arrayIndexOf(x, fmax);
	}
	else fmax = psort.length;
	if (fmin != 0 || fmax != 0) {	
		pfiles = Array.slice(pfiles, fmin, fmax);
		pcframe = Array.slice(pcframe, fmin, fmax);
		pdirfiles = Array.slice(pdirfiles, fmin, fmax);
		psort = Array.slice(psort, fmin, fmax);
	}
	
	// Reduce number of cells
	if (startsWith(cellnumber, "bottom")) {
		number = split(cellnumber, "-");
		if (endsWith(number[1], "%")) {
			number = split(number[1], "%");
			number = parseInt(number[0]);
			total = pfiles.length;
			number = floor(total/100*number);
		}
		else number = parseInt(number[1]);
		if (number < pfiles.length) {
			pfiles = Array.trim(pfiles, number);
			pcframe = Array.trim(pcframe, number);
			pdirfiles = Array.trim(pdirfiles, number);
			psort = Array.trim(psort, number);
		}
		else print("Point "+p+" contains <"+number+" elements. All elements will be used.");
	}
	else if (startsWith(cellnumber, "top")) {
		number = split(cellnumber, "-");
		if (endsWith(number[1], "%")) {
			number = split(number[1], "%");
			number = parseInt(number[0]);
			total = pfiles.length;
			number = floor(total/100*number);
		}
		else number = parseInt(number[1]);
		if (number < pfiles.length) {
			pfiles = Array.reverse(pfiles);
			pdirfiles = Array.reverse(pdirfiles);
			pcframe = Array.reverse(pcframe);
			psort = Array.reverse(psort);
			pfiles = Array.trim(pfiles, number);
			pcframe = Array.trim(pcframe, number);
			pdirfiles = Array.trim(pdirfiles, number);
			psort = Array.trim(psort, number);
		}
		else print("Point "+p+" contains <"+number+" elements. Alle elements will be used.");
	}
	else if (startsWith(cellnumber, "random")) {
		number = split(cellnumber, "-");
		if (endsWith(number[1], "%")) {
			number = split(number[1], "%");
			number = parseInt(number[0]);
			total = pfiles.length;
			number = floor(total/100*number);
		}
		else number = parseInt(number[1]);
		if (number < pfiles.length) {
			strippedPfiles = newArray(number);
			strippedPcframe = newArray(number);
			strippedPdirfiles = newArray(number);
			strippedPsort = newArray(number);
			// Generate sequence of indices, pick random sample and strip pfiles and psort
			indices = Array.getSequence(pfiles.length);
			indices = arrayRandomN(indices, number);
			for (i=0;i<indices.length;i++) {
				id = indices[i];
				strippedPfiles[i] = pfiles[id];
				strippedPcframe[i] = pcframe[id];
				strippedPdirfiles[i] = pdirfiles[id];
				strippedPsort[i] = psort[id];
			}
			pfiles = strippedPfiles;
			pcframe = strippedPcframe;
			pdirfiles = strippedPdirfiles;
			psort = strippedPsort;
		}
		else print("Point "+p+" contains <"+number+" elements. Alle elements will be used.");
	}
	
	// Prepend point directory for opening
	for (f=0;f<pfiles.length;f++) {
		pfiles[f] = File.getName(pdir)+File.separator+pfiles[f];
	}
	
	// Concatenate to previous points
	files = Array.concat(files, pfiles);
	cframes = Array.concat(cframes, pcframe);
	dirfiles = Array.concat(dirfiles, pdirfiles);
	sort = Array.concat(sort, psort);
}

// Suffle files
number = files.length;
strippedfiles = newArray(number);
strippedcframes = newArray(number);
strippeddirfiles = newArray(number);
strippedsort = newArray(number);
// Generate sequence of indices, pick random sample and strip pfiles and psort
indices = Array.getSequence(files.length);
indices = arrayRandomN(indices, number);
for (i=0;i<indices.length;i++) {
	id = indices[i];
	strippedfiles[i] = files[id];
	strippedcframes[i] = cframes[id];
	strippeddirfiles[i] = dirfiles[id];
	strippedsort[i] = sort[id];
}
files = strippedfiles;
cframes = strippedcframes;
dirfiles = strippeddirfiles;
sort = strippedsort;

// Sort files again across all points
// first by sorting criterium
files = sortByArray(files, sort);
cframes = sortByArray(cframes, sort);
dirfiles = sortByArray(dirfiles, sort);
sort = Array.sort(sort);
// second by classification frame
if (coverage != "1+0-0") {
	files = sortByArray(files, cframes);
	dirfiles = sortByArray(dirfiles, cframes);
	cframes = Array.sort(cframes);
}
	
// Calculate how many assemblies there are and sort within them by frame number
nout = files.length/nperas;
nout = floor(nout);
if (files.length%nperas != 0) nout++;
print(nout+" assemblies will be generated.");
// Removed with addition of coverage requirement
//newfiles = newArray();
//for (a=1;a<=nout;a++) {
//	first = (a-1)*nperas;
//	last = (a*nperas)-1;
//	if (last >= files.length) last = files.length-1;
//	subfiles = Array.slice(files, first, last+1);
//	n=subfiles.length;
//	subsort = newArray(n);
//	for (f=0;f<subfiles.length;f++) {
//		filename = File.getName(cropdir+File.separator+subfiles[f]);
//		info = split(filename, "-_");
//		start = parseInt(info[1]);
//		stop = parseInt(info[2]);
//		length = stop-start;
//		subsort[f] = length;
//	}
//	subfiles = sortByArray(subfiles, subsort);
//	subfiles = Array.reverse(subfiles);
//	newfiles = Array.concat(newfiles, subfiles);
//}
//files = newfiles;

// Generate assembly directory and write the settingsfile and sorting
dateStamp = getDateYMD();
if (lengthOf(posflags) == 0) posflags = "-";
if (lengthOf(negflags) == 0) negflags = "-";
pointStamp = "Points";
for (p=0;p<points.length;p++) pointStamp = pointStamp+" "+points[p];
filter = ""+filter[0]+"-"+filter[1];
coverage = ""+cframe+"+"+pframes+"-"+fframes;
assemblydir = dateStamp+"_"+pointStamp+"_"+coverage+"_"+sorting;
if (filter != "min-max") assemblydir = assemblydir+"_"+filter; // filtering
if (posflags != "-" || negflags != "-") assemblydir = assemblydir+"_"+basis+"-"+posflags+"_"+negflags; // flagfiltering
assemblydir = assemblydir+"_"+rows+"by"+columns+"_"+cellnumber;
if (!File.exists(dirspool+"assemblies")) File.makeDirectory(dirspool+"assemblies");
File.makeDirectory(dirspool+"assemblies"+File.separator+assemblydir);
assemblydir = dirspool+"assemblies"+File.separator+assemblydir+File.separator;
// settings
pointSetting = "";
for (p=0;p<points.length;p++) pointSetting = pointSetting+","+points[p];
pointSetting = substring(pointSetting, 1, lengthOf(pointSetting));
settings = newArray("points", pointSetting, "coverage", coverage,  "sorting", sorting, "filter", filter);
settings = Array.concat(settings, newArray("basis", basis, "posflags", posflags, "negflags", negflags, "rows", rows, "columns", columns, "cellnumber", cellnumber));
x = writeSettings(assemblydir+"assemblySettings.cfg", settings);
// sorting
f=File.open(assemblydir+"sorting.txt");
for(i=0;i<files.length;i++) print(f, dirfiles[i]);
f=File.close(f);

// Write to log if it exists
if (File.exists(dirspool+"log.txt")) {
	entry = getDateYMD();
	folder = File.getName(assemblydir);
	name = call("ij.Prefs.get", "MovieAnalyser.Name", "user");
	entry = entry+"\t"+name+"\tgenerated assemblies\t'"+folder+"'";
	File.append(entry, dirspool+"log.txt");
}
print("Settings written.");

// Initialize variables for assemblygeneration
hs = 0;
cropdir = cropdir+File.separator;
run("Colors...", "foreground=white background=black");
for (o=1;o<=nout;o++) {
	first = (o-1)*nperas;
	last = (o*nperas)-1;
	if (last >= files.length) last = files.length-1;
	open(cropdir+files[first]);
	print(files[first]);
	if (coverage != "1+0-0") {
		maxcframe = cframes[last];
		cfr = cframes[first];
		drawBoundingBox(cfr);
		if (maxcframe > cfr) prependFrames(maxcframe-cfr);
	}
	if (Stack.isHyperstack==1) hs=1;
	rename("Combined Stacks");
	for (i=1;i<columns;i++) {
		if (first+i <= last) {
			open(cropdir+files[first+i]);
			print(files[first+i]);
			if (coverage != "1+0-0") {
				cfr = cframes[first+i];
				drawBoundingBox(cfr);
				if (maxcframe > cfr) prependFrames(maxcframe-cfr);
			}
			wintitle = File.getName(cropdir+files[first+i]);
			if (hs == 1) adjustFrames("Combined Stacks", ""+wintitle+"");
			print('combine in row');
			run("Combine...", "stack1=[Combined Stacks] stack2="+wintitle+"");
		}
	}
	rename("C1");
	for (r=1;r<rows;r++) {
		offset =r*columns;
		if(first+offset <= last) {
			open(cropdir+files[first+offset]);
			print(files[first+offset]);
			if (coverage != "1+0-0") {
				cfr = cframes[first+offset];
				drawBoundingBox(cfr);
				if (maxcframe > cfr) prependFrames(maxcframe-cfr);
			}
			rename("Combined Stacks");
			for (i=offset+1;i<offset+columns;i++) {
				if (first+i <= last) {
					open(cropdir+files[first+i]);
					print(files[first+offset+1]);
					if (coverage != "1+0-0") {
						cfr = cframes[first+i];
						drawBoundingBox(cfr);
						if (maxcframe > cfr) prependFrames(maxcframe-cfr);
					}
					wintitle = File.getName(cropdir+files[first+i]);
					if (hs == 1) adjustFrames("Combined Stacks", ""+wintitle+"");
					print('combine in further row');
					run("Combine...", "stack1=[Combined Stacks] stack2="+wintitle+"");
				}
			}
			rename("C2");
			if (hs == 1) adjustFrames("C1", "C2");
			print('Combine in column.');
			run("Combine...", "stack1=C1 stack2=C2 combine");
			rename("C1");
		} else {
			if (isOpen("C1") == true) {
				if (files.length != nout) save(assemblydir+"assembly"+pad(o)+"_"+first+"-"+last+".tif");
				else save(assemblydir+"cell"+pad(o)+".tif");
				close();
			}
		}
	}
	if (isOpen("C1") == true) {
		if (files.length != nout) save(assemblydir+"assembly"+pad(o)+"_"+first+"-"+last+".tif");
		else save(assemblydir+"cell"+pad(o)+".tif");
		close();
	}
	print("\\Update:Assembly "+o+" written.");
}
print("Assembly generation done.");

// ----- Utility functions ----------
// ----------------------------------
function adjustFrames(name1, name2) {
	selectWindow(name1);
	getDimensions(w,h,c,s,nF1);
	selectWindow(name2);
	getDimensions(w,h,c,s,nF2);
	while (nF1 > nF2) {
		Stack.setFrame(nF2);
		run("Add Slice", "add=frame");
		getDimensions(w,h,c,s,nF2);
	}
	selectWindow(name1);
	while (nF2 > nF1) {
		Stack.setFrame(nF1);
		run("Add Slice", "add=frame");
		getDimensions(w,h,c,s,nF1);
	}
}
function prependFrames(n) {
	i=1;
	while (i<=n) {
		run("Add Slice", "add=frame prepend");
		i++;
	}
}
function pad(n) {
	str = toString(n);
	while (lengthOf(str)<4)
	    str = "0" + str;
	return str;
}
function arrayRemoveItem(array, index) {
	if (index >= array.length || index < 0) exit("Index "+index+" out of bounds."); // out of bounds
	else if (index == 0) out = Array.slice(array, 1, array.length); // first element
	else if (index == array.length-1) out = Array.slice(array, 0, array.length-1); // last element
	else {
		start = Array.trim(array, index);
		end = Array.slice(array, index+1, array.length);
		out = Array.concat(start, end);
	}
	return out;
}
function arrayIndexOf(array, string) {
	index = -1;
	i = 0;
	while (i<array.length) {
		if (startsWith(array[i], string)) {
			index = i;
			i = array.length-1;
		}
		i++;
	}
	return index;
}
function removeDuplicateCharacters(s) {
	y = newArray();
	for (i=0;i<lengthOf(s);i++) {
		q = substring(s, i, i+1);
		if (arrayIndexOf(y,q) == -1) y = Array.concat(y, q);
	}
	y = Array.sort(y);
	o = y[0];
	if (y.length>1) {
		for (i=1;i<y.length;i++) {
			o = o+y[i];
		}
	}
	return o;
}
function sortByArray(x, y) {
	sortedx = Array.copy(x);
	ranking = Array.rankPositions(y);
	for (i=0; i<x.length; i++) {
		pos = ranking[i];
		sortedx[i] = x[pos];
	}
	return sortedx;
}
function readSettings(filename) {
	print(filename);
	content = File.openAsString(filename);
	lines=split(content,"\n");
	if (lengthOf(lines) <=1) exit("Empty file.");
	separators = newArray("\t", ",,", ";;"); // Add more separators here if you are desperate.
	separator = 0;
	for (s=0;s<separators.length;s++) {
		l=0;
		separatorValid = 1;
		while (separatorValid == 1 && l<lines.length) {
			args = split(lines[l],separators[s]);
			if (args.length != 2) separatorValid = 0;
			l++;
		}
		if (separatorValid == 1) separator = separators[s];
	}
	if (separator == 0) exit("Settings couldn't be read with either tab, comma or semicolon as field separator.");
	settings = split(lines[0], separator);
	i=1;
	while (i < lines.length) {
		args = split(lines[i], separator);
		settings = Array.concat(settings, args);
		i++;
	}
	return settings;
}
function writeSettings(filename, settings) {
	if (settings.length%2 != 0) exit("Each setting must have exactly one name and value.");
	if (File.exists(filename)) {
		or = getBoolean("The file "+filename+" already exists. Do you want to overwrite it?", "Yes", "No");
		if (!or) return 0;
		else f = File.delete(filename);
	}
	file = File.open(filename);
	lines = settings.length/2;
	for (l=1;l<=lines;l++) {
		line = settings[(l-1)*2]+"\t"+settings[1+(l-1)*2];
		// print(line);
		print(file, line);
	}
	File.close(file);
	return 1;
}
function getSetting(settings, field) {
	id = arrayIndexOf(settings, field);
	if (id == -1) return "error";
	id = id+1;
	if (id >= settings.length) return "error";
	val = settings[id];
	return val;
}
function setSetting(settings, field, value) {
	id = arrayIndexOf(settings, field);
	if (id == -1) return settings;
	id = id+1;
	if (id >= settings.length) return settings;
	settings[id] = value;
	return settings;
}
function arrayRandomN(array, N) {
	if (array.length < N) exit("You can not select more unique random elements than there are array elements.");
	else if (array.length == N) return array;
	else {
		n=array.length;
		randomKeys = newArray(n);
		for (i=0; i<randomKeys.length; i++) randomKeys[i] = random;
		sortedArray = sortByArray(array, randomKeys);
		out = Array.trim(sortedArray, N);
		return out;
	}
}
function drawBoundingBox(frame) {
	run("Colors...", "foreground=white");
	Stack.getDimensions(width, height, channels, slices, frames);
	Stack.setFrame(frame);
	for (c=1;c<=channels;c++) {
		Stack.setChannel(c);
		for (s=1;s<=slices;s++) {
			Stack.setSlice(s);
			makeLine(0,0,0,height-1,width-1,height-1,width-1,0,0,0);
			run("Draw", "slice");
		}
	}
}
function getDateYMD() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	date = ""+year+"";
	month = month+1;
	if (month<10) date = date+"0";
	date = date+month;
	if (dayOfMonth<10) date = date+"0";
	date = date+dayOfMonth;
	return date;
}