args = getArgument();
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
Array.print(args);

if (lengthOf(args) == 2) { // arguments included in call
	
	// Open with specified default dialog settings (run from toolbar button)
	dirspool   = call("ij.Prefs.get", "MovieAnalyser.Experiment", "home/");
	sets       = readSettings(dirspool+args[0]);
	coverage   = getSetting(sets, "MM.coverage");
	coverage   = split(coverage, "+-");
	cframe     = parseInt(coverage[0]);
	pframes    = parseInt(coverage[1]);
	fframes    = parseInt(coverage[2]);
	minstart   = cframe-pframes;
	minend     = cframe+fframes;
	rows       = getSetting(sets, "MM.rows");
	columns    = getSetting(sets, "MM.columns");
	rows       = parseInt(rows);
	columns    = parseInt(columns);
	nperas     = rows*columns;
	
	assemblydir = dirspool+File.separator+"assemblies"+File.separator+args[1];
	if (!endsWith(assemblydir, File.separator)) assemblydir = assemblydir+File.separator;
	if (!File.isDirectory(assemblydir)) exit("Assembly directory not found.");
	
}
else exit("Two arguments needed: 1. default settings file, 2. target directory for assemblies.");

setBatchMode(true);
setBatchMode("show");

// Generate file list for each point and apply sorting and filters
// This will generate several matched arrays for each point: pfiles, pflags, psort
// All the points will be concatenated into matched arrays: files, sort
sorting = File.openAsString(assemblydir+"sorting.txt");
sorting = split(sorting, "\n");
number = sorting.length;
files = newArray(number);
dirfiles = newArray(number);
cframes = newArray(number);
sort = newArray(number);
for (f=0;f<sorting.length;f++) {
	
	line = split(sorting[f], "\t");
	p = line[0];
	filename = line[1];
	files[f] = p+File.separator+filename;
	dirfiles[f] = p+"\t"+filename;
	
	// get cframe and frames
	info = split(filename, "-_");
	start = parseInt(info[1]);
	stop = parseInt(info[2]);
	cframes[f] = cframe-start+1;
	length = stop-start;
	sort[f] = length;
}

// Suffle files
strippedfiles = newArray(number);
strippedcframes = newArray(number);
strippeddirfiles = newArray(number);
strippedsort = newArray(number);
// Generate sequence of indices, pick random sample and strip arrays
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
files = sortByArray(files, cframes);
dirfiles = sortByArray(dirfiles, cframes);
cframes = Array.sort(cframes);

// Calculate how many assemblies there are and sort within them by frame number
nout = files.length/nperas;
nout = floor(nout);
if (files.length%nperas != 0) nout++;
print(nout+" assemblies will be generated.");
coverage = ""+cframe+"+"+pframes+"-"+fframes;
settings = newArray("points", args[1], "coverage", coverage, "rows", rows, "columns", columns);
x = writeSettings(assemblydir+"assemblySettings.cfg", settings);

// Write to log if it exists
if (File.exists(dirspool+File.separator+"log.txt")) {
	entry = getDateYMD();
	folder = File.getName(assemblydir);
	name = call("ij.Prefs.get", "MovieAnalyser.Name", "user");
	entry = entry+"\t"+name+"\tgenerated assemblies\t'"+folder+"' highlighted frame: "+cframe;
	File.append(entry, dirspool+File.separator+"log.txt");
}

// Initialize variables for assemblygeneration
hs = 0;
cropdir = dirspool+File.separator+"crops"+File.separator;
run("Colors...", "foreground=white background=black");
for (o=1;o<=nout;o++) {
	first = (o-1)*nperas;
	last = (o*nperas)-1;
	if (last >= files.length) last = files.length-1;
	maxcframe = cframes[last];
	open(cropdir+files[first]);
	cfr = cframes[first];
	drawBoundingBox(cfr);
	if (maxcframe > cfr) prependFrames(maxcframe-cfr);
	if (Stack.isHyperstack==1) hs=1;
	rename("Combined Stacks");
	for (i=1;i<columns;i++) {
		if (first+i <= last) {
			open(cropdir+files[first+i]);
			cfr = cframes[first+i];
			drawBoundingBox(cfr);
			if (maxcframe > cfr) prependFrames(maxcframe-cfr);
			wintitle = File.getName(cropdir+files[first+i]);
			if (hs == 1) adjustFrames("Combined Stacks", ""+wintitle+"");
			run("Combine...", "stack1=[Combined Stacks] stack2="+wintitle+"");
		}
	}
	rename("C1");
	for (r=1;r<rows;r++) {
		offset =r*columns;
		if(first+offset <= last) {
			open(cropdir+files[first+offset]);
			cfr = cframes[first+offset];
			drawBoundingBox(cfr);
			if (maxcframe > cfr) prependFrames(maxcframe-cfr);
			rename("Combined Stacks");
			for (i=offset+1;i<offset+columns;i++) {
				if (first+i <= last) {
					open(cropdir+files[first+i]);
					cfr = cframes[first+i];
					drawBoundingBox(cfr);
					if (maxcframe > cfr) prependFrames(maxcframe-cfr);
					wintitle = File.getName(cropdir+files[first+i]);
					if (hs == 1) adjustFrames("Combined Stacks", ""+wintitle+"");
					run("Combine...", "stack1=[Combined Stacks] stack2="+wintitle+"");
				}
			}
			rename("C2");
			if (hs == 1) adjustFrames("C1", "C2");
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