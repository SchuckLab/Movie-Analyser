import ij.plugin.filter.PlugInFilter;
import java.awt.Color;
import java.util.*;
import java.io.*;
import java.lang.Float;
import ij.*;
import ij.gui.*;
import ij.gui.WaitForUserDialog;
import ij.io.*;
import ij.process.*;
import ij.plugin.SubHyperstackMaker;
import ij.plugin.HyperStackConverter;
import ij.plugin.SubstackMaker;
import ij.plugin.Concatenator;
import ij.plugin.filter.ParticleAnalyzer;
import ij.plugin.filter.Analyzer;
import ij.measure.*;
 

/**
	Uses ImageJ's particle analyzer to track the movement of
	multiple objects through a stack. 
	Based on the Object Tracker plugin filter by Wayne Rasband

	Based on Multitracker, but should be quite a bit more intelligent
	Nico Stuurman, Vale Lab, UCSF/HHMI, May,June 2003
*/
public class MTrack2_mod implements PlugInFilter, Measurements  {

	ImagePlus	imp;
	int		nParticles;
	float[][]	ssx;
	float[][]	ssy;
	String directory,filename,sdirectory;

	static int	minSize = 1;
	static int	maxSize = 999999;
	static int 	minTrackLength = 2;
	static boolean 	bSaveResultsFile = false;
	static boolean 	bShowLabels = false;
	static boolean 	bShowPositions = false;
	static boolean 	bShowPaths = false;
	static boolean 	bShowPathLengths = false;
	static boolean  bSliceParticles = false;
	static int  radius = 50;
   static float   	maxVelocity = 10;
	static int 	maxColumns=75;
   static boolean skipDialogue = false;

	public class particle {
		float	x;
		float	y;
		int	z;
		int	trackNr;
		boolean inTrack=false;
		boolean flag=false;

		public void copy(particle source) {
			this.x=source.x;
			this.y=source.y;
			this.z=source.z;
			this.inTrack=source.inTrack;
			this.flag=source.flag;
		}

		public float distance (particle p) {
			return (float) Math.sqrt(sqr(this.x-p.x) + sqr(this.y-p.y));
		}
	}

	public int setup(String arg, ImagePlus imp) {
		this.imp = imp;
		if (IJ.versionLessThan("1.17y"))
			return DONE;
		else
			return DOES_8G+NO_CHANGES;
	}

   public static void setProperty (String arg1, String arg2) {
      if (arg1.equals("minSize"))
         minSize = Integer.parseInt(arg2);
      else if (arg1.equals("maxSize"))
         maxSize = Integer.parseInt(arg2);
      else if (arg1.equals("minTrackLength"))
         minTrackLength = Integer.parseInt(arg2);
      else if (arg1.equals("maxVelocity"))
         maxVelocity = Float.valueOf(arg2).floatValue();
      else if (arg1.equals("saveResultsFile"))
         bSaveResultsFile = Boolean.valueOf(arg2);
      else if (arg1.equals("showPathLengths"))
         bShowPathLengths = Boolean.valueOf(arg2);
      else if (arg1.equals("showLabels"))
         bShowLabels = Boolean.valueOf(arg2);
      else if (arg1.equals("showPositions"))
         bShowPositions = Boolean.valueOf(arg2);
      else if (arg1.equals("showPaths"))
         bShowPaths = Boolean.valueOf(arg2);
      else if (arg1.equals("sliceParticles"))
         bSliceParticles = Boolean.valueOf(arg2);
      else if (arg1.equals("radius"))
         radius = Integer.valueOf(arg2);
      else if (arg1.equals("skipDialogue"))
         skipDialogue = Boolean.valueOf(arg2);
   }

	public void run(ImageProcessor ip) {
      if (!skipDialogue) {
         GenericDialog gd = new GenericDialog("Object Tracker");
         gd.addNumericField("Minimum Object Size (pixels): ", minSize, 0);
         gd.addNumericField("Maximum Object Size (pixels): ", maxSize, 0);
         gd.addNumericField("Maximum_ Velocity:", maxVelocity, 0);
         gd.addNumericField("Minimum_ track length (frames)", minTrackLength, 0);
         gd.addCheckbox("Save Results File", bSaveResultsFile);
         gd.addCheckbox("Display Path Lengths", bShowPathLengths);
         gd.addCheckbox("Show Labels", bShowLabels);
         gd.addCheckbox("Show Positions", bShowPositions);
         gd.addCheckbox("Show Paths", bShowPaths);
         gd.addCheckbox("Slice Particles", bSliceParticles);
         gd.addNumericField("Radius:", radius, 0);
         gd.showDialog();
         if (gd.wasCanceled())
            return;
         minSize = (int)gd.getNextNumber();
         maxSize = (int)gd.getNextNumber();
         maxVelocity = (float)gd.getNextNumber();
         minTrackLength = (int)gd.getNextNumber();
         bSaveResultsFile = gd.getNextBoolean();
         bShowPathLengths = gd.getNextBoolean();
         bShowLabels = gd.getNextBoolean();
         bShowPositions = gd.getNextBoolean();
         bShowPaths = gd.getNextBoolean();
         bSliceParticles = gd.getNextBoolean();
         radius = (int)gd.getNextNumber();
         if (bShowPositions)
            bShowLabels =true;
      }
      if (bSaveResultsFile) {
         SaveDialog sd=new  SaveDialog("Save Track Results","trackresults",".txt");
         directory=sd.getDirectory();
         filename=sd.getFileName();
      }
      if (bSliceParticles) {
         DirectoryChooser dc=new  DirectoryChooser("Directory for cropped particle stacks");
         sdirectory=dc.getDirectory();
      }
		track(imp, minSize, maxSize, maxVelocity, directory, filename, radius, sdirectory);
	}
	

	public void track(ImagePlus imp, int minSize, int maxSize, float maxVelocity, String directory, String filename, int radius, String sdirectory) {
		int nFrames = imp.getStackSize();
		if (nFrames<2) {
			IJ.showMessage("Tracker", "Stack required");
			return;
		}
		
		ImageStack stack = imp.getStack();
		int options = 0; // set all PA options false
		int measurements = CENTROID;

		// Initialize results table
		ResultsTable rt = new ResultsTable();
		rt.reset();

		// create storage for particle positions
		List[] theParticles = new ArrayList[nFrames];
		int trackCount=0;

		// record particle positions for each frame in an ArrayList
		for (int iFrame=1; iFrame<=nFrames; iFrame++) {
			theParticles[iFrame-1]=new ArrayList();
			rt.reset();
			ParticleAnalyzer pa = new ParticleAnalyzer(options, measurements, rt, minSize, maxSize);
			pa.analyze(imp, stack.getProcessor(iFrame));
			float[] sxRes = rt.getColumn(ResultsTable.X_CENTROID);				
			float[] syRes = rt.getColumn(ResultsTable.Y_CENTROID);
			if (sxRes==null)
				continue;

			for (int iPart=0; iPart<sxRes.length; iPart++) {
				particle aParticle = new particle();
				aParticle.x=sxRes[iPart];
				aParticle.y=syRes[iPart];
				aParticle.z=iFrame-1;
				theParticles[iFrame-1].add(aParticle);
			}
			IJ.showProgress((double)iFrame/nFrames);
		}

		// now assemble tracks out of the particle lists
		// Also record to which track a particle belongs in ArrayLists
		List theTracks = new ArrayList();
		for (int i=0; i<=(nFrames-1); i++) {
			IJ.showProgress((double)i/nFrames);
			for (ListIterator j=theParticles[i].listIterator();j.hasNext();) {
				particle aParticle=(particle) j.next();
				if (!aParticle.inTrack) {
					// This must be the beginning of a new track
					List aTrack = new ArrayList();
					trackCount++;
					aParticle.inTrack=true;
					aParticle.trackNr=trackCount;
					aTrack.add(aParticle);
					// search in next frames for more particles to be added to track
					boolean searchOn=true;
					particle oldParticle=new particle();
					particle tmpParticle=new particle();
					oldParticle.copy(aParticle);
					for (int iF=i+1; iF<=(nFrames-1);iF++) {
						boolean foundOne=false;
						particle newParticle=new particle();
						for (ListIterator jF=theParticles[iF].listIterator();jF.hasNext() && searchOn;) { 
							particle testParticle =(particle) jF.next();
							float distance = testParticle.distance(oldParticle);
							// record a particle when it is within the search radius, and when it had not yet been claimed by another track
							if ( (distance < maxVelocity) && !testParticle.inTrack) {
								// if we had not found a particle before, it is easy
								if (!foundOne) {
									tmpParticle=testParticle;
									testParticle.inTrack=true;
									testParticle.trackNr=trackCount;
									newParticle.copy(testParticle);
									foundOne=true;
								}
								else {
									// if we had one before, we'll take this one if it is closer.  In any case, flag these particles
									testParticle.flag=true;
									if (distance < newParticle.distance(oldParticle)) {
										testParticle.inTrack=true;
										testParticle.trackNr=trackCount;
										newParticle.copy(testParticle);
										tmpParticle.inTrack=false;
										tmpParticle.trackNr=0;
										tmpParticle=testParticle;
									}
									else {
										newParticle.flag=true;
									}	
								}
							}
							else if (distance < maxVelocity) {
							// this particle is already in another track but could have been part of this one
							// We have a number of choices here:
							// 1. Sort out to which track this particle really belongs (but how?)
							// 2. Stop this track
							// 3. Stop this track, and also delete the remainder of the other one
							// 4. Stop this track and flag this particle:
								testParticle.flag=true;
							}
						}
						if (foundOne)
							aTrack.add(newParticle);
						else
							searchOn=false;
						oldParticle.copy(newParticle);
					}
					theTracks.add(aTrack);
				}
			}
		}

		// Create the column headings based on the number of tracks
		// with length greater than minTrackLength
		// since the number of tracks can be larger than can be accomodated by Excell, we deliver the tracks in chunks of maxColumns
		// As a side-effect, this makes the code quite complicated
		String strHeadings = "Frame";
		int frameCount=1;
		for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
			List bTrack=(ArrayList) iT.next();
			if (bTrack.size() >= minTrackLength) {
				if (frameCount <= maxColumns)
					strHeadings += "\tX" + frameCount + "\tY" + frameCount +"\tFlag" + frameCount;
				frameCount++;
			}
		}

		String contents="";
		boolean writefile=false;
		if (filename != null) {
			File outputfile=new File (directory,filename);
			if (!outputfile.canWrite()) {
				try {
					outputfile.createNewFile();
				}
				catch (IOException e) {
					IJ.showMessage ("Error", "Could not create "+directory+filename);
				}
			}
			if (outputfile.canWrite())
				writefile=true;
			else
				IJ.showMessage ("Error", "Could not write to " + directory + filename);
		}

		String flag;
		int repeat=(int) ( (frameCount/maxColumns) );
		float reTest = (float) frameCount/ (float) maxColumns;
		if (reTest > repeat)
			repeat++;
		// display the table with particle positions
		// first when we only write to the screen
		if (!writefile) {
			IJ.setColumnHeadings(strHeadings);

			for (int j=1; j<=repeat;j++) {
				int to=j*maxColumns;
				if (to > frameCount-1)
					to=frameCount-1;
				String stLine="Tracks " + ((j-1)*maxColumns+1) +" to " +to;
				IJ.write(stLine);
				for(int i=0; i<=(nFrames-1); i++) {
					String strLine = "" + (i+1);
					int trackNr=0;
					int listTrackNr=0;
					for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
						trackNr++;
						List bTrack=(ArrayList) iT.next();
						boolean particleFound=false;
						if (bTrack.size() >= minTrackLength) {
							listTrackNr++;
							if ( (listTrackNr>((j-1)*maxColumns)) && (listTrackNr<=(j*maxColumns))) {
								for (ListIterator k=theParticles[i].listIterator();k.hasNext() && !particleFound;) {
									particle aParticle=(particle) k.next();
									if (aParticle.trackNr==trackNr) {
										particleFound=true;
										if (aParticle.flag) 
											flag="*";
										else
											flag=" ";
										strLine+="\t" + aParticle.x + "\t" + aParticle.y + "\t" + flag;
									}
								}
								if (!particleFound)
									strLine+="\t \t \t ";
							}
						}
					}
					IJ.write(strLine);
				}
			}
		}
		// and now when we write to file
		if (writefile) {
			try {
				File outputfile=new File (directory,filename);
				BufferedWriter dos= new BufferedWriter (new FileWriter (outputfile));
				dos.write(strHeadings+"\n",0,strHeadings.length()+1);
				for (int j=1; j<=repeat;j++) {
					int to=j*maxColumns;
					if (to > frameCount-1)
						to=frameCount-1;
					String stLine="Tracks " + ((j-1)*maxColumns+1) +" to " +to;
					dos.write(stLine + "\n",0,stLine.length()+1);
					for (int i=0; i<=(nFrames-1); i++) {
						String strLine = "" + (i+1);
						int trackNr=0;
						int listTrackNr=0;
						for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
							trackNr++;
							List bTrack=(ArrayList) iT.next();
							boolean particleFound=false;
							if (bTrack.size() >= minTrackLength) {
								listTrackNr++;
								if ( (listTrackNr>((j-1)*maxColumns)) && (listTrackNr<=(j*maxColumns))) {
									for (ListIterator k=theParticles[i].listIterator();k.hasNext() && !particleFound;) {
										particle aParticle=(particle) k.next();
										if (aParticle.trackNr==trackNr) {
											particleFound=true;
											if (aParticle.flag) 
												flag="*";
											else
												flag=" ";
											strLine+="\t" + aParticle.x + "\t" + aParticle.y + "\t" + flag;
										}
									}
									if (!particleFound)
										strLine+="\t \t \t ";
								}
							}
						}
						dos.write(strLine + "\n",0,strLine.length()+1);
					}
				}
				if (bShowPathLengths) {
					double[] lengths = new double[trackCount];
					double[] distances = new double[trackCount];
					int[] frames = new int[trackCount];
					double x1, y1, x2, y2;
					int trackNr=0;
					int displayTrackNr=0;
					for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
						trackNr++;
						List bTrack=(ArrayList) iT.next();
						if (bTrack.size() >= minTrackLength) {
							displayTrackNr++;
							ListIterator jT=bTrack.listIterator();
							particle oldParticle=(particle) jT.next();
							particle firstParticle=new particle();
							firstParticle.copy(oldParticle);
							frames[displayTrackNr-1]=bTrack.size();
							for (;jT.hasNext();) {
								particle newParticle=(particle) jT.next();
								lengths[displayTrackNr-1]+=Math.sqrt(sqr(oldParticle.x-newParticle.x)+sqr(oldParticle.y-newParticle.y));
								oldParticle=newParticle;
							}
							distances[displayTrackNr-1]=Math.sqrt(sqr(oldParticle.x-firstParticle.x)+sqr(oldParticle.y-firstParticle.y));
						}
					}
					dos.write("\n");
					dos.write("Track \tLength\tDistance traveled\tNr of Frames\n",0,45);
					for (int i=0; i<displayTrackNr; i++) {
						String str = "" + (i+1) + "\t" + (float)lengths[i] + "\t" + (float)distances[i] + "\t" + (int)frames[i];
						dos.write(str+"\n",0,str.length()+1);
					}
				}
				dos.close();
			}
			catch (IOException e) {
				if (filename != null)
					IJ.error ("An error occurred writing the file. \n \n " + e);
			}
		}

		// Now do the fancy stuff when requested:

		// makes a new stack with objects labeled with track nr
		// optionally also displays centroid position
		if (bShowLabels) {
			String strPart;
			ImageStack newstack = imp.createEmptyStack();
			int xHeight=newstack.getHeight();
			int yWidth=newstack.getWidth();
			for (int i=0; i<=(nFrames-1); i++) {
				int iFrame=i+1;
				String strLine = "" + i;
				ImageProcessor ip = stack.getProcessor(iFrame);
				newstack.addSlice(stack.getSliceLabel(iFrame),ip.crop());
				ImageProcessor nip = newstack.getProcessor(iFrame);
				nip.setColor(Color.black);
				// hack to only show tracks longerthan minTrackLength
				int trackNr=0;
				int displayTrackNr=0;
				for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
					trackNr++;
					List bTrack=(ArrayList) iT.next();
					if (bTrack.size() >= minTrackLength) {
						displayTrackNr++;
						for (ListIterator k=theParticles[i].listIterator();k.hasNext();) {
							particle aParticle=(particle) k.next();
							if (aParticle.trackNr==trackNr) {
								strPart=""+displayTrackNr;
								if (bShowPositions) {
									strPart+="="+(int)aParticle.x+","+(int)aParticle.y;
								}
								// we could do someboundary testing here to place the labels better when we are close to the edge
								nip.moveTo((int)aParticle.x+5,doOffset((int)aParticle.y,yWidth,5) );
								//nip.moveTo(doOffset((int)aParticle.x,xHeight,5),doOffset((int)aParticle.y,yWidth,5) );
								nip.drawString(strPart);
							}
						}
					}
				}
				IJ.showProgress((double)iFrame/nFrames);
			}
			ImagePlus nimp = new ImagePlus(imp.getTitle() + " labels",newstack);
			nimp.show();
			imp.show();
			nimp.updateAndDraw();
		}


		// total length traversed
		if (bShowPathLengths && !writefile) {
			double[] lengths = new double[trackCount];
			double[] distances = new double[trackCount];
			int[] frames = new int[trackCount];
			double x1, y1, x2, y2;
			int trackNr=0;
			int displayTrackNr=0;
			for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
				trackNr++;
				List bTrack=(ArrayList) iT.next();
				if (bTrack.size() >= minTrackLength) {
					displayTrackNr++;
					ListIterator jT=bTrack.listIterator();
					particle oldParticle=(particle) jT.next();
					particle firstParticle=new particle();
					firstParticle.copy(oldParticle);
					frames[displayTrackNr-1]=bTrack.size();
					for (;jT.hasNext();) {
						particle newParticle=(particle) jT.next();
						lengths[displayTrackNr-1]+=Math.sqrt(sqr(oldParticle.x-newParticle.x)+sqr(oldParticle.y-newParticle.y));
						oldParticle=newParticle;
					}
					distances[displayTrackNr-1]=Math.sqrt(sqr(oldParticle.x-firstParticle.x)+sqr(oldParticle.y-firstParticle.y));
				}
			}
			IJ.write("");
			IJ.write("Track \tLength\tDistance traveled\tNr of Frames");
			for (int i=0; i<displayTrackNr; i++) {
				String str = "" + (i+1) + ":\t" + (float)lengths[i] + "\t" + (float)distances[i] + "\t" + (int)frames[i];
				IJ.write(str);
			}
		}


		// 'map' of tracks
		if (bShowPaths) {
			if (imp.getCalibration().scaled()) {
				IJ.showMessage("MultiTracker", "Cannot display paths if image is spatially calibrated");
				return;
			}
			ImageProcessor ip = new ByteProcessor(imp.getWidth(), imp.getHeight());
			ip.setColor(Color.white);
			ip.fill();
			trackCount=0;
			int color;
			for (ListIterator iT=theTracks.listIterator();iT.hasNext();) {
				trackCount++;
				List bTrack=(ArrayList) iT.next();
				if (bTrack.size() >= minTrackLength) {
					ListIterator jT=bTrack.listIterator();
					particle oldParticle=(particle) jT.next();
					for (;jT.hasNext();) {
						particle newParticle=(particle) jT.next();
						color =Math.min(trackCount+1,254);
						ip.setValue(color);
						ip.moveTo((int)oldParticle.x, (int)oldParticle.y);
						ip.lineTo((int)newParticle.x, (int)newParticle.y);
						oldParticle=newParticle;
					}
				}
			}
			new ImagePlus("Paths", ip).show();
		}
		
		// Modification for single particle movie slicing by Julia Schessner
		if (bSliceParticles) {
			// pause here to have the user open the image stack and give an output folder
			WaitForUserDialog wfs = new WaitForUserDialog("Please open the original data stack from which you want to have the particles cropped.\nThen push OK.", "Wait for Stack");
			wfs.show();
			if (wfs.escPressed())
				return;
			ImagePlus oimp = IJ.getImage();
			int sFrames = oimp.getStackSize();
			if (sFrames<2) {
				IJ.showMessage("Slicer", "Stack required");
				return;
			}
			if (imp.getWidth() != oimp.getWidth() || imp.getHeight() != oimp.getHeight()) {
				IJ.showMessage("Slicer", "Stack of same width and height required.");
				return;
			}
			// put padding around hyperstack
			
			ImageStack ostack = oimp.getStack();
			int[] dims = oimp.getDimensions(); //Returns the dimensions of this image (width, height, nChannels, nSlices, nFrames) as a 5 element int array.
			HyperStackConverter hc = new HyperStackConverter();
			ImageStack exp = ImageStack.create(dims[0]+radius+radius, dims[1]+radius+radius, dims[2]*dims[3]*dims[4], 16);
			ImageProcessor tip = exp.getProcessor(1);
			tip.setColor(Color.black);
			tip.fill();
			StackProcessor expp = new StackProcessor(exp);
			expp.copyBits(tip, 1,1,0);
			expp.copyBits(ostack, radius+1,radius+1,0);
			ostack = null;
			oimp = null;
			System.gc();
			oimp = new ImagePlus("padded", exp);
			oimp = hc.toHyperStack(oimp, dims[2], dims[3], dims[4]);
			
			// initialize variables
			int trackNr=0;
			int x1, x2, y1, y2;
			int xc = 0;
			int yc = 0;
			int trackoutNr=0;
			// iterate Tracks
			for (ListIterator iT=theTracks.listIterator(); iT.hasNext();) {
				trackNr++;
				List bTrack=(ArrayList) iT.next();
				if (bTrack.size() >= minTrackLength) {
					trackoutNr++;
					// inititalize Array
					int[][] crops=new int[bTrack.size()+2][2];
					int firstframe=-1;
					// iterate Frames
					for (int i=0; i<=(nFrames-1); i++) {
						boolean particleFound=false;
						// iterate Particles
						for (ListIterator k=theParticles[i].listIterator();k.hasNext() && !particleFound;) {
							particle aParticle=(particle) k.next();
							if (aParticle.trackNr==trackNr) {
								particleFound=true;
								if (firstframe==-1)
									firstframe=i;
								xc = (int) Math.round(aParticle.x);
								yc = (int) Math.round(aParticle.y);
								crops[i+1-firstframe][0] = x1 = xc-radius;
								crops[i+1-firstframe][1] = y1 = yc-radius;
								
							}
						}
						// if (!particleFound) next
					}
					// duplicate last and first frame
					int lastframe = firstframe+bTrack.size();
					if (lastframe == nFrames) {
						crops = Arrays.copyOfRange(crops, 0, bTrack.size()+1);
					}
					else {
						crops[bTrack.size()+1] = crops[bTrack.size()];
						lastframe++;
					}
					if (firstframe == 0) {
						crops = Arrays.copyOfRange(crops, 1, crops.length);
					}
					else {
						crops[0] = crops[1];
						firstframe--;
					}
					firstframe++;
					// call slice function and save file
					oimp.show();
					String stackname = ""+trackoutNr+"_"+firstframe+"-"+lastframe+"_"+xc+"-"+yc+".tif";
					//ImagePlus timp = NewImage.createImage(stackname, 20, 20, lastframe-firstframe+1, 8, 1);
					ImagePlus timp = trackslice(oimp, firstframe, crops, radius*2+1, radius*2+1);
					FileSaver fs = new FileSaver(timp);
					fs.saveAsTiff(sdirectory+stackname);
					if (trackoutNr%10 == 0) IJ.log(stackname);
				}
			}
		}
	}

	// Utility functions
	double sqr(double n) {return n*n;}
	
	int doOffset (int center, int maxSize, int displacement) {
		if ((center - displacement) < 2*displacement) {
			return (center + 4*displacement);
		}
		else {
			return (center - displacement);
		}
	}

 	double s2d(String s) {
		Double d;
		try {d = new Double(s);}
		catch (NumberFormatException e) {d = null;}
		if (d!=null)
			return(d.doubleValue());
		else
			return(0.0);
	}
	
	ImagePlus trackslice(ImagePlus stack, int first, int[][] coords, int wid, int hei) {
		ImagePlus timp = new ImagePlus();
		ImagePlus ostack = new ImagePlus();
		Concatenator con = new Concatenator();
		int hwid = (wid-1)/2;
		int hhei = (hei-1)/2;
		if(stack.isHyperStack() == true) {
			int[] dims = stack.getDimensions(); //Returns the dimensions of this image (width, height, nChannels, nSlices, nFrames) as a 5 element int array.
			SubHyperstackMaker shm = new SubHyperstackMaker();
			HyperStackConverter hc = new HyperStackConverter();
			for(int i=first; i<first+coords.length; i++) {
				// calculate which slices in the original stack are needed (c*s slices per frame)
				int slice1 = ((i-1)*dims[2]*dims[3])+1;
				int sliceN = i*dims[2]*dims[3];
				// run for loop over the slices and crop out roi for all of them instead of using the stack processor
				ImageStack oframe = new ImageStack(wid, hei);
				ImageStack tstack = stack.getStack();
				ImageProcessor ip2;
				for(int s=slice1; s <= sliceN; s++) {
					ImageProcessor ip1 = tstack.getProcessor(s);
					String label = tstack.getSliceLabel(s);
					ip1.setRoi(coords[i-first][0]+hwid, coords[i-first][1]+hhei, wid, hei);
					ip2 = ip1.crop();
					oframe.addSlice(label, ip2);
				}
				timp = new ImagePlus("single frame", oframe);
				if (i == first) {
					ostack = timp;
				}
				else {
					ImagePlus[] imps = new ImagePlus[]{ostack, timp};
					ostack = con.concatenateHyperstacks(imps, "", false);
				}
			}
			ostack = hc.toHyperStack(ostack, dims[2], dims[3], coords.length);
		}
		else {
			int[] dims = stack.getDimensions(); //Returns the dimensions of this image (width, height, nChannels, nSlices, nFrames) as a 5 element int array.
			ImageStack tstack = stack.getStack();
			for(int i=first; i<first+coords.length; i++) {
				ImageProcessor tip = tstack.getProcessor(i);
				ImageProcessor exp = tip.duplicate();
				exp = exp.resize(dims[0]+wid-1, dims[1]+hei-1);
				exp.setColor(Color.black);
				exp.fill();
				exp.insert(tip, hwid+1, hhei+1);
				tip = exp;
				int x1 = coords[i-first][0]+hwid;
				int y1 = coords[i-first][1]+hhei;
				tip.setRoi(x1, y1, wid, hei);
				tip = tip.crop();
				timp = new ImagePlus("single frame", tip);
				if (i == first) {
					ostack = timp;
				}
				else {
					ImagePlus[] imps = new ImagePlus[]{ostack, timp};
					ostack = con.concatenate(imps, false);
				}
			}
		}
		return(ostack);
	}

}
