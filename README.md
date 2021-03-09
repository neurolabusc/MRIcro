## About

MRIcro is a 3D viewer and volume renderer for medical images. It is designed for NIfTI format images (popular with neuroimaging scientists) but can typically view images in many popular 3D raster formats including BioRad PIC, DICOM, NRRD, MGZ/MGH, AFNI BRIK, ITK MHA format images.

![alt tag](visibleHuman.png)

#### Versions

 - 1.8.2 (build 182, 6-April-2016) Initial GitHub release
 - 1.8.6 (build 186, 6-June-2016) Updated to XCode 7.3, updated dcm2niix
 - 1.8.7 (build 187, 21-September-2016) Updated dcm2niix
 - 1.9.0 (build 190, 29-January-2021) Apple Silicon support
 - 1.9.1 (build 191, 9-March-2021) XCode 12.4

#### Requirements, Downloading and Installation

This software is a universal binary that runs natively on both Intel (x86-64) and Apple Silicon (arm64) CPUs. Users of other operating systems should consider the more powerful [MRIcroGL](https://www.nitrc.org/plugins/mwiki/index.php/mricrogl:MainPage). Users with older versions of macOS should consider [MRIcron](https://www.nitrc.org/plugins/mwiki/index.php/mricron:MainPage). The software uses the computers graphics card, so computers with better cards and drivers will be able to view higher resolution images as described in the troubleshooting section.

 - [Click here to get a compiled copy](/releases/latest). 
 - [Click here for NITRC page](https://www.nitrc.org/projects/mricro)
 - [Also available in the AppStore](https://apps.apple.com/app/id1557491371).

#### Supported Formats

This software can display the following formats: [NIfTI](https://nifti.nimh.nih.gov/) (.nii, .nii.gz, .hdr/.img), Bio-Rad Pic (.pic), [NRRD](http://teem.sourceforge.net/nrrd/format.html) (.nhdr, .nrrd), Philips (.par/.rec), [ITK MetaImage](https://itk.org/Wiki/ITK/File_Formats) (.mhd, .mha), ECAT (.v), DeltaVision (.dv), [AFNI](https://afni.nimh.nih.gov/pub/dist/doc/program_help/README.attributes.html) (.head/.brik), [Freesurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/MghFormat) (.mgh, .mgz), and DICOM (extensions vary).

#### Getting Started

To load an image, you can drag the image to the application icon, drag the image to an open window, or use the File/Open command. The software also provides a File/OpenRecent menu item for reloading images. You can view multiple images simultaneously. Here are some simple commands for adjusting the view:

 - Toolbar adjustments (you can hide or show the toolbar with the View menu)
 - The “Color Scheme” pulldown menu allows you to adjust the colors used to display image intensity. Initially, this is set to black-white, but you have many options such as blue-green.
 - The “Darkest” and “Brightest” number values allow you to display the range for image intensity. For example, in Figure 2 the color range for the blue-green overlay is from 2 to 5.
 - The “I”nformation button displays basic information about your image (e.g. image resolution).
 - The “View” pull down menu allows you to set whether you want to see only 2D slices, only 3D renderings or both (the default).
 - Mouse/Touchpad adjustments
 - Click on any location on a 2D slice to jump to that location.
 - Drag the 3D rendering to rotate the object.
 - Roll the scroll wheel up and down (or pull two fingers up and down on a touch pad) to adjust the clipping depth of the 3D rendering (for example, in Figure 2 we have clipped the top of the brain from the rendering).
 - Right-click and drag over the 3D rendering to adjust the position of the clipping plane (for example, in Figure 2 we have set the clip plane to remove the top of the head).
 - If you have an overlay loaded (described below), right-click and drag over the 2D slices to adjust the transparency of the overlay.
 - If you have a 4D dataset loaded (described below), roll the scroll wheel left and right (or swipe left and right with two fingers) to adjust which volume is displayed.
 - Menu adjustments
 - The View/RemoveHaze command removes ‘dust’ from the air around an object (described below).
 - The View/ChangeBackground switches the background between black and white.
 - The Window/YokeWindows option allows you to link different images so they display the same location.

#### Tutorial 1: Viewing a MRI scan

MRIcro can view images in many medical imaging formats. You can display an image by dragging-and-dropping the file or using the File/Open menu item. The File/OpenStandard and File/OpenAtlas menus open images included with the software, which is ideal for a simple tutorial.

 - Choose File/OpenStandard/Chris_T1.nii.gz this should display and image of the brain.
 - Note that if you click on the image at different locations, you will change the position of the slices and crosshairs. 
 - The following controls are on the toolbar. If you do not see the toolbar, choose the View/ShowToolbar menu item. You can choose View/CustomizeToolbar to change the items on the toolbar. Below we consider the default items, as listed from left to right.
 - The "View" pull down menu lets you select between different 3D and 2D displays. For example if you choose "Axial" you will see a [https://en.wikipedia.org/wiki/Anatomical_plane horizontal] slice through the image.
 - The "i" button displays information about the image, including its dimensions and spatial resolution.
 - The layer menu only lists one layer (the T1 scan we loaded as the background). The function of this widget is described in the overlay demo.
 - The color scheme menu allows you to set a color mapping for the image. By default, this is a grayscale "Black-white". For this T1 scan, air and water (CSF) is dark, while fat is bright, with gray matter and muscle falling between these two extremes. If you select the "Winter" color scheme you will see that the colors go from blue to green instead of black to white.
 - The darkest and brightest values allow us to set the range for our color scheme. By default, the T1 scan loaded with a range of 0 and 140. Thus, any voxel darker than zero will be transparent, while a value of zero will appear as the darkest color of our color scheme, while values brighter than 140 will appear in the darkest color of our color scheme.
 
 ![alt tag](main.png)

#### Tutorial 2: Viewing a CT scan

Computerized Axial Tomography (CT or CAT) uses XRays to acquire images. Since bones attenuate XRays, this is an excellent modality for visualizing bones (whereas bone has little hydrogen, so it is harder to observer with MRI scans). Another nice feature of CT scans is that the intensity of the voxels is calibrated: air will always have a value of around -1000, water will be around 0 and bone near +1000. MRIcro leverages this fact with special color schemes with names that begin with "CT". These color schemes set both the color and the intensity range (the darkest and brightest values) to help display tissues.

 - Choose File/OpenStandard and select the image "CT_abdomen.nii.gz". Note the brightest and darkest values are set to the range -1024..+750, providing a contrast and brightness that covers the full dynamic range of the image.
 - Select the Color Scheme pulldown menu in the toolbar and choose "CT kidneys". Note that the brightest and darkest range is now from +114 to +302. Most of the soft tissue is now invisible, revealing the kidneys (in red) and the bones (in white). This CT scan used a gadolinium contrast agent, which is absorbed by the kidneys.
 - Choose the "CT airways" color scheme. Now the image contrast is set from -643 to -235. This color scheme highlights the boundary between air and soft tissue, revealing the lungs.

![alt tag](kidneys.jpg)

#### Tutorial 3: Loading a DICOM series

Most medical images are initially stored in the industry standard DICOM format (though scientists like to save them to simpler formats like NIfTI). One issue is that 3D images are typically stored as hundreds of separate 2D slices, just like a 3D loaf of bread is composed of many 2D slices. This poses a challenge for users of macOS, where the operating system only allows an application to open files that the user has explicitly selected. Consider a DICOM image with 2 slices: "a.dcm" and "b.dcm". If a user drags the file "a.dcm" to a viewer, the viewer does not have permission to open the associated file "b.dcm". This is further complicated by the fact that DICOM filenames do not end with a simple extension like ".dcm", but have unique but complicated numeric names. Therefore, to view DICOMs you need to select all the files.

 - To complete this tutorial, you will need some DICOM files. You can download [this UIH dataset](https://github.com/neurolabusc/dcm_qa_uih) by pressing the `Code` button and choosing to download the zip file. You will want to extract the zip file.
 - Go to a folder with many DICOM files. For this example, select the 192 files in the [t1_gre_fsp_3d_sag__132750](https://github.com/neurolabusc/dcm_qa_uih/tree/master/In/DTI_132225/t1_gre_fsp_3d_sag__132750) folder. Drag all the DICOM images and drop their icons onto MRIcro (either an open window or its icon in the dock).
 - Note that the images load. If you are displaying a 3D view, you might notice that the surface appears a bit hazy. This is easiest to see if you are viewing images with a white background (the Preferences window allows you to select a white or black background color).
 - You can choose the View/RemoveHaze menu item to remove noisy dark voxels. This can make it easier to observe the surface of an object, as shown in the images below.
 
![alt tag](nohaze.png)
 
#### Tutorial 4: Loading overlays
 
 We often want to compare the alignment of two scans, or to view one scan (like a statistical map) on top of another image (for example, a high resolution anatomical scan). One option is to open two windows of MRIcro, and open a separate image in each. If you have "Yoke windows" selected in the "Window" menu, clicking on the 2D image of one window will show you the corresponding locations of both images (the crosshairs will show the same location). You can also open one image on top of the other:

  - Choose File/OpenStandard and select the spm152.nii.gz image.
  - Choose File/OpenStandard and select the spmMotor.nii.gz image '''while holding down the control key'''. This will load the low resolution statistical ap as an overlay. You can also use the File/AddOverlay menu item to select an image to overlay.
  - The "Layer" toolbar dropdown menu now lists two items: the "Background" image is our structural scan "spm152", where "Layer 1" refers to the statistical map for hand movements. Select "Overlay 1" and note that it uses the warm color with values from +2.9 to +2.9. Set the color scheme to "Winter" and set the darkest and brightest values to -3 and -4. Since the statistical map shows brain areas that are more active for left hand movement versus right hand movement, the negative contrast will reveal brain regions that respond preferentially to right hand movements (the left primary motor cortex and right cerebellum).

![alt tag](overlay.png)

#### Loading Overlays

MRIcro viewer can load additional images on top of your initial (background) image. This is useful for interpreting the anatomical coordinates of statistical maps. For example, Figure 2 shows a scalp-stripped high resolution MRI scan in grayscale with a statistical map on top. To achieve this, first open your background image, then choose File/Add to select your overlay maps. Note that overlay maps must be aligned (in register with) your background image – however they do not have to have the same dimensions (the overlay images will be automatically resliced to the resolution of the background image). You can independently adjust the color scheme and contrast of the background and overlays by selecting the layer from the rightmost drop down menu (e.g. in Figure 2, “Overlay 1” is selected) and then setting the color scheme (e.g. blue-green) and color range (in this case 2..5). For statistical maps, these numbers typically refer to Z-scores or T-scores, and your analysis software should suggest good thresholds. You can also adjust the transparency of your overlay on the background image by right-dragging your mouse up and down over one of the 2D slices (though be careful – the same gesture over the 3D rendering adjusts the clip angle of the rendering).

#### Removing Haze

Most raw medical images exhibit a little bit of noise. This can make renderings appear dusty or hazy. The View/RemoveHaze command attempts to eliminate this noise. This is illustrated in Figure 3. You can also use other tools that will attempt to extract the brain from the surrounding scalps – popular alternatives include [AFNI 3dSkullStrip](https://afni.nimh.nih.gov/pub/dist/doc/program_help/3dSkullStrip.html), [FSL Brain Extraction Tool (BET)](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET), [MNI Brain Extraction based on nonlocal Segmentation Technique (BEaST)](https://www.bic.mni.mcgill.ca/ServicesSoftwareAdvancedImageProcessingTools/BEaST), and [SPM using the Clinical Toolbox](https://www.nitrc.org/plugins/mwiki/index.php/clinicaltbx:MainPage). 

#### Working with multiple images: Yoking Images

MRIcro viewer can display multiple images simultaneously. Sometimes we want to see if different images are aligned to each other (“in register”). For example, is an individual’s T1 scan aligned to their fMRI data, or have two individuals’ T1 scans been accurately normalized to have the same shape? If you select Window/YokeWindows clicking on one slice on any image will cause all the other images to jump to the same location. For example, in Figure 4 we have shown coordinate -44x-36x50mm on the high resolution T1 and the lower resolution T2* (functional MRI, fMRI) images.

#### Working with 4D datasets: Timelines and swiping

Many datasets are four dimensional: for example with functional MRI we often collect hundreds of images, one every second or so. Likewise, with diffusion images we often collect dozens of different gradient directions. MRIcro viewer allows you to quickly load and inspect the 4D datasets. To select a different timepoint, roll the mouse scroll wheel left or right (or swipe the touchpad left or right with two fingers). Figure 4 also shows a timeline – you can change the size of the timeline by pulling the horizontal scroll bar up and down. The timeline shows the image intensity at the selected location for all 232 volumes. Often we want to see if there are any huge outliers in the volume and then swipe to the unusual volumes to determine if they are due to reconstruction errors, poor shim or dramatic head movements. The file menu allows you to save timelines in PDF format, or to export them as text (so you can import them into your favorite spreadsheet).

#### Displaying Diffusion Tensor Imaging (DTI) data

Diffusion Tensor Imaging acquires images that are sensitive to the spontaneous, random motion of water in our tissues. Water diffuses faster in large compartments (like the ventricles of our brains) than small compartments (e.g. inside the cells of our brain). Further, diffusion can have a preferred direction (it can be “anisotropic”) – for example in the fiber tracts of our brain water diffuses faster along the axis of the axons. These properties allow us to measure the integrity of white matter in the brain and to detect acute injury (as diffusion changes rapidly). You can view any NIfTI format DTI image just like an image from any other modality – just drag and drop it. However, MRIcro viewer has a handy tool for combining fractional anisotropy maps (FA: which shows whether regions have a preferred direction) and principle vector maps (V1: which shows the preferred direction). Select the File/OpenDTI option and select either a V1 or FA image- the software will load both and display an image where the colors reveal the preferred direction and the brightness displays the magnitude of this preference. The Figure illustrates this view: red fibers are oriented left-right, green are anterior-posterior and blue are superior-inferior.

#### Troubleshooting

MRIcro should just work. However, in order to generate fluid graphics it relies on hardware accelerated graphics. If you attempt to load images that are beyond the capability of your graphics card and graphics driver, the images may look scrambled. For example, Figure 6 illustrates that a high-resolution image appears scrambled on my MacBook (using a Sandy Bridge processor with integrated GPU). There are four solutions to this problem. First, you can ensure that your graphics driver is up-to-date: Intel integrated graphics were crippled in versions of macOS between 10.6.6 and 10.8. However, with macOS 10.8 or later (or 10.6.6 and earlier) the Intel Sandy Bridge and Ivy Bridge MacBooks and MacBook Airs should be able to render images up to 256x256x256 voxels (press the round ‘header information’ button in MRIcro’s toolbar to see the resolution of an image). Second, you could use a different computer – computers with a modern dedicated graphics cards should be able to display high resolution scans flawlessly. Third, you could use `MRIcron <https://www.nitrc.org/plugins/mwiki/index.php/mricron:MainPage>`_ instead – MRIcron does not use the graphics card so it runs on any computer (though it is slower and therefore the interface is not as fluid). Finally, you can reslice your data to a lower resolution (for example using one of my :ref:`“reslice” scripts <my_spm_scripts>`. for SPM and Matlab).

#### Alternatives

MRIcro only runs on Macintosh macOS. It was designed to be a simple, intuitive tool for displaying medical images. However, just like there are different types of car to suit different drivers, there are different programs that are suited for different applications. Here are some of my favorites.

 - [FSLeyes](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FSLeyes) runs on macOS and Linux (and Windows via WSL). It includes great features like a nice DTI fiber tracking view.
 - [itk-SNAP](http://www.itksnap.org/pmwiki/pmwiki.php) is a powerful tool for segmenting brain structures with useful visualization features.
 - [MRIcroGL](https://www.nitrc.org/plugins/mwiki/index.php/mricrogl:MainPage) for Windows, macOS and Linux. Scriptable, fast, and flexible. Visually very similar to MRIcro viewer, though less “Mac like” and the flexibility means it is more difficult to master. In our car analogy it is our BMW – lots of performance and features.
 - [MRIcron](https://www.nitrc.org/plugins/mwiki/index.php/mricron:MainPage) for Windows, macOS and Linux. It does not require a graphics card and so it can run anywhere. In our car analogy, this is like a pickup truck that has tremendous utility (drawing tools, peristimulus plots, etc).

