args = getArgument();
args = split(args, "\t");
if (args.length == 2) {
	dir = args[0];
	mode = args[1];
}
else {
	modes = newArray("max_channel_1", "max_channel_2", "max_channel_3", "max_channel_4", "stringent_max_channel_2", "stringent_max_channel_3");
	dir = getDirectory("Select point crop directory");
	Dialog.create("Select Mode");
	Dialog.addChoice("Mode", modes, modes[0]);
	Dialog.show();
	mode = Dialog.getChoice();
}
if (!File.isDirectory(dir)) exit("Please provide a folder of images to process.");
setBatchMode(true);
files = getFileList(dir);
f=0;
while(f<files.length) {
	if (!endsWith(files[f], ".tif")) files = arrayRemoveItem(files, f);
	else f++;
}
// Calculate values
n=files.length;
vals = newArray(n);
for (f=0;f<files.length;f++) {
	open(dir+files[f]);
	getDimensions(w,h,ch,sl,fr);
	if (mode == "max_channel_1") {
		run("Z Project...", "projection=[Max Intensity] all");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		run("Z Project...", "projection=[Max Intensity]");
		makeOval(0.1*w, 0.1*h, 0.8*w, 0.8*h);
		Stack.setChannel(1);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		vals[f] = max;
	}
	else if (mode == "max_channel_2") {
		run("Z Project...", "projection=[Max Intensity] all");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		run("Z Project...", "projection=[Max Intensity]");
		makeOval(0.1*w, 0.1*h, 0.8*w, 0.8*h);
		Stack.setChannel(2);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		vals[f] = max;
	}
	else if (mode == "max_channel_3") {
		run("Z Project...", "projection=[Max Intensity] all");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		run("Z Project...", "projection=[Max Intensity]");
		makeOval(0.1*w, 0.1*h, 0.8*w, 0.8*h);
		Stack.setChannel(3);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		vals[f] = max;
	}
	else if (mode == "max_channel_4") {
		run("Z Project...", "projection=[Max Intensity] all");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		run("Z Project...", "projection=[Max Intensity]");
		makeOval(0.1*w, 0.1*h, 0.8*w, 0.8*h);
		Stack.setChannel(4);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		vals[f] = max;
	}
	else if (mode == "stringent_max_channel_2") {
		run("Z Project...", "projection=[Max Intensity] all");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		run("Z Project...", "projection=[Max Intensity]");
		makeOval(0.25*w, 0.25*h, 0.5*w, 0.5*h);
		Stack.setChannel(2);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		vals[f] = max;
	}
	else if (mode == "stringent_max_channel_3") {
		run("Z Project...", "projection=[Max Intensity] all");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		run("Z Project...", "projection=[Max Intensity]");
		makeOval(0.25*w, 0.25*h, 0.5*w, 0.5*h);
		Stack.setChannel(3);
		getRawStatistics(nPixels, mean, min, max, std, histogram);
		vals[f] = max;
	}
	close("*");
	showProgress(-f/files.length);
}

// Write to file
out=File.open(dir+File.separator+mode+".csv");
for (f=0;f<files.length;f++) {
	file = File.getName(dir)+"\t"+files[f];
	print(out, file+"\t"+vals[f]);
}
out=File.close(out);

// Utility functions
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