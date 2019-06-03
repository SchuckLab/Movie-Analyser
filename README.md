# Movie-Analyser
A macro tool for ImageJ to analyse large scale movies on single cell level.
![](./img/interface_main.png "Main interface")


## Usage
This toolbox can be used to analyse movie of large cell populations semi-automatically.

The movie frames are aligned and separated into cingle cell movies, which can then be manually classified into categories.

## Installation
Download this repository and copy the two folders 'ActionBar' and 'Movie Analyser' to the plugin folder of your ImageJ installation.

Required plugins:
- Action Bar (https://figshare.com/articles/Custom_toolbars_and_mini_applications_with_Action_Bar/3397603/3)

A modified version of the Correct 3D Drift plugin is included in this repository, which was kindly adjusted to our needs by Christian Tischer, see https://github.com/fiji/Correct_3D_Drift/issues/3 for details.

A modified version of MTrack2 is also included in this repository - the argorithm remained unchanged, but cropped and aligned movies were added as output. The original can be found at https://imagej.net/MTrack2.

Optionally you can copy the Startup macros to the macro folder of your installation to add a button to your hotbar. Alternatively you can launch the toolbar by running the macro from the Action Bar folder.
