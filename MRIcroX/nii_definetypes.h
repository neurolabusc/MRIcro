//
//  nii_definetypes.h
//  MRIpro
//
//  Created by Chris Rorden on 8/17/12.
//  Copyright (c) 2012 U South Carolina. All rights reserved.
//

#ifndef MRIpro_nii_definetypes_h
#define MRIpro_nii_definetypes_h
#include "nii_io.h"  // defines struct nifti_1_header
#import "nifti1_io_core.h"

#define NII_IMG_RENDER //determines whether 3D rendering code is compiled

#ifdef  __cplusplus
extern "C" {
#endif
    
    #define GL_2D_ONLY 0 //displayModeGL - only show 2D sections
    #define GL_3D_ONLY 1 //displayModeGL - only show 3D rendering
    #define GL_2D_AND_3D 2  //displayModeGL - show both 2D sections and 3D renderings
    #define GL_2D_AXIAL 3 //displayModeGL - only show 2D sections
    #define GL_2D_CORONAL 4 //displayModeGL - only show 2D sections
    #define GL_2D_SAGITTAL 5 //displayModeGL - only show 2D sections
    
    
    #define MAX_OVERLAY 3 //maximum number of overlays allowed
    #define MAX_CLIPDEPTH 1000 //clip depth 0...1000 - e.g. 300 means 30% clip
#define MAX_DTIvectors 64
#define MAX_HISTO_BINS 512
    //typedef uint32_t tRGBAlut[256];
    
    typedef struct   {
        //overlay rescaled to have same dimensions as background image, so only few details required 
        float scl_inter, scl_slope, lut_bias;
        double fullMin, fullMax, nearMin, nearMax, viewMin, viewMax; //ranges for image scaling
        tRGBAlut lut; //lookup table stores current color scheme
        int datatype, colorScheme;
        void *data ;                  /*!< pointer to data: nbyper*nvox bytes     */
    } NII_OVERLAY;
    //typedef  SCALED_IMGDATA_TYPE = NIFTI_TYPE_FLOAT32;
    #define SCALED_IMGDATA_TYPE        NIFTI_TYPE_FLOAT32
    typedef float SCALED_IMGDATA; //this should either be float (32-bit) or double (64-bit)
    //typedef unsigned int tRGBAlut[256]; //color lookup table is array 0..255 storing RGBA values

    typedef struct   {
        CGFloat backColor[4], xBarColor[4], colorBarBorderColor[4], colorBarTextColor[4]; //colors of background and crosshairs
        CGFloat colorBarPos[4]; //Left/Top/Right/Bottom of colorbar 0..1 (fraction of screen size)
        double fullMin, fullMax, nearMin, nearMax, viewMin, viewMax; //ranges for image scaling
          //fullMin..fullMax are extreme values in image, nearMin...nearMax is range excluding outliers
          // viewMin..viewMax is the range selected by user for current display
        int voxelDim[4]; //size in voxels for X (1), Y (2) and Z (3) dimensions - Dim[0] unused
        double fieldOfViewMM[4]; //Field of View in mm for X(1), Y(2) and Z (3) dimensions - FOV[0] unused
        double sliceFrac[4];//crosshair location as a fraction of volume size
        int tempSliceVox[4];//current slice - used for mouse drags
        double mm[4]; //crosshair location in MNI space
        int scrnDim[4];//size of X,Y,Z in pixels
        int colorScheme; //index of current colorscheme 0=black&white, 2=hot... etc
        int xBarGap; //size of gap at center of cross-hairs (in pixels)
        int scrnHt, scrnWid, scrnOffsetX, scrnOffsetY; //dimensions of OpenGL window in pixels
        bool scrnWideLayout;
        int currentVolume, numVolumes, numOverlay; //for 3D images both =1, for 4D volumes currentVolume can be set 1..numVolumes
        int mouseX, mouseY; //location of last mouse action....(down or drag)
        int mouseDownX, mouseDownY; //location of last mouse down....
        double mouseIntensity; //brightness under mouse
        size_t numVox3D ; //voxels in spatial dimensions nX*nY*nZ, so fslio->nvox = prefs->numVox3D*prefs->numVolumes
        mat44 sto_ijk, sto_xyz; //matrices to convert between voxel space and mm space
        tRGBAlut lut; //lookup table stores current color scheme
        //GLuint intensityTexture3D; //handle to current OpenGL texture
        //this class keeps track of when OpenGL screen changes are needed
        // force_refreshGL : rapid redraw of screen at next "doRedraw" timer - e.g. new origin selected
        // force_recalcGL : a slow recalculation is required at next "doRedraw" timer - e.g. rescale colors
        // busyGL : OpenGL is currently busy on an update, new "doRedraw" calls deferred until task is completed
        bool retinaResolution, dicomWarn, force_refreshGL, force_recalcGL, busyGL, updatedTimeline, showInfo, showOrient, orthoOrient,loadFewVolumes,  advancedRender, viewRadiological;
        float overlayFrac; //, colorBarBorder;
        int colorBarBorderPx;
        NII_OVERLAY overlays[MAX_OVERLAY];
        GLuint intensityOverlay3D, intensityTexture3D;
        #ifdef NII_IMG_RENDER //from nii_definetypes.h
        GLuint backFaceBuffer; //backFace only used in 2Pass
        GLuint glslprogramInt, renderBuffer, frameBuffer, finalImage, gradientOverlay3D, gradientTexture3D;
        float TexScale[4];
        GLuint glslprogramIntBlur;
        GLuint glslprogramIntSobel;
        bool glslUpdateGradientsBG, glslUpdateGradientsOverlay;
        int renderAzimuth, renderElevation, renderSlices, renderWid, renderHt, renderLeft, renderBottom;
        #endif
        float renderDistance;
        int rayCastQuality1to10,  clipDepth, clipAzimuth, clipElevation, displayModeGL;
        float lut_bias;
        bool showCube;
        int numDtiV;
        float dtiV[MAX_DTIvectors][3];
        float histo[MAX_HISTO_BINS];
        char nii_prefs_fname[256];
    } NII_PREFS;
    
#ifdef  __cplusplus
}
#endif

#endif
