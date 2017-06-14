//  writtem by Chris Rorden on 8/14/12 - distributed under BSD license


#import <Foundation/Foundation.h>
#import "nii_img.h"
#import "nii_colorbar.h"
#include "nifti1.h"
#import "nii_io.h"
#import "nifti1_io_core.h"
#import "nii_ortho.h"
#import "nii_reslice.h"
#include "nii_definetypes.h"
#import  "nii_timelineView.h"
#include "nii_ostu_ml.h"
#import "nii_mosaic.h"
#import "nii_label.h"
#import <OpenGL/glu.h>
//#import "GLString.h"
#ifdef NII_IMG_RENDER //from nii_definetypes
    #import "nii_render.h"
#endif

@implementation nii_img

- (IBAction)closePopup
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
}

- (IBAction)notifyOpenFailed;
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Unable to read image";
    notification.informativeText = @"Unknown image format";
    notification.soundName = NULL;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    [NSTimer scheduledTimerWithTimeInterval: 4.0  target:self selector: @selector(closePopup) userInfo:self repeats:NO];
}

- (IBAction)notifyNotAllVolumesLoaded: (int) loadedVols RawVols: (int) rawVols;
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:@"Loaded %d of %d volumes", loadedVols, rawVols];
    notification.informativeText = @"Reason: The preference 'Only initial volumes' is selected";
    notification.soundName = NULL;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    [NSTimer scheduledTimerWithTimeInterval: 4.5  target:self selector: @selector(closePopup) userInfo:self repeats:NO];
}

- (IBAction)notifyDICOMwarning;
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"DICOM image";
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    BOOL inSandbox = (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
    if (inSandbox)
        notification.informativeText = @"For improved display convert DICOM images to NIfTI (solution: use the free dcm2nii tool)" ;
    else
        notification.informativeText = @"For improved display convert DICOM images to NIfTI (solution: use the 'Import' menu)";
#else
    notification.informativeText = @"For improved display convert DICOM images to NIfTI (solution: use the free dcm2nii tool)" ;
#endif
    notification.soundName = NULL;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    [NSTimer scheduledTimerWithTimeInterval: 4.0  target:self selector: @selector(closePopup) userInfo:self repeats:NO];
}

-(bool) is2D {
    if ((prefs->displayModeGL == GL_2D_ONLY) || (prefs->displayModeGL == GL_2D_AXIAL)
        || (prefs->displayModeGL == GL_2D_CORONAL) || (prefs->displayModeGL == GL_2D_SAGITTAL)
        )
        return TRUE;
    else
        return FALSE;
}


double getVoxelIntensity(long long vox, FSLIO* fslio) {
    if ((vox < 0) || (vox >= fslio->niftiptr->nvox)) return 0.0;
    if (fslio->niftiptr->datatype == NIFTI_TYPE_RGBA32) {
        // Y = 0.299R + 0.587G + 0.114B
        THIS_UINT8 *inbuf = (THIS_UINT8 *) fslio->niftiptr->data;
        vox = ((vox-1)*4); //saved as RGBA quads (RGBARGBA), indexed from 0
        if ((vox < 0) || (vox >= fslio->niftiptr->nvox)) return 0.0;
        return  roundf ((inbuf[vox]*0.299)+(inbuf[vox+1]*0.587)+(inbuf[vox+2]*0.114));
        //prefs->mouseIntensity = (inbuf[vox]*0.299)+(inbuf[vox+prefs->numVox3D]*0.587)+(inbuf[vox+2*prefs->numVox3D]*0.114);
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *inbuf = (THIS_UINT8 *) fslio->niftiptr->data;
        return (inbuf[vox]*fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *inbuf = (THIS_INT16 *) fslio->niftiptr->data;
        return (inbuf[vox]*fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    } else {
        SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) fslio->niftiptr->data;
        return(inbuf[vox]*fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    }
}

void getIntensity (NII_PREFS* prefs, FSLIO* fslio) {
    if (prefs->currentVolume > prefs->numVolumes) {
        prefs->mouseIntensity = 0;
        return;
    }
    int slice[3];
    //mm2slice (slice, prefs); //2014
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return;
    mat44 R = prefs->sto_ijk;
    for (int i = 0; i < 3; i++) {
        slice[i] = round( (R.m[i][0]*prefs->mm[1])+(R.m[i][1]*prefs->mm[2])+ (R.m[i][2]*prefs->mm[3])+R.m[i][3] );
        if (slice[i] < 0) slice[i] = 0;
        if (slice[i] >= prefs->voxelDim[i+1]) slice[i] = prefs->voxelDim[i+1]-1;
    }
    long long vox = slice[0] + (slice[1]*prefs->voxelDim[1])+(slice[2]*prefs->voxelDim[1]*prefs->voxelDim[2]);
    //long long nvox = prefs->numVox3D ;
    if (fslio->niftiptr->datatype != NIFTI_TYPE_RGBA32)
        vox = vox + ((prefs->currentVolume-1) * prefs->numVox3D);
    prefs->mouseIntensity = getVoxelIntensity(vox, fslio);
    #ifdef MY_DEBUG //from nii_io.h
    //NSLog(@"nii_img getIntensity for volume %d",prefs->currentVolume);
    #endif
}

void frac2slice (float frac[4], NII_PREFS* prefs) {
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return;
    for (int j = 1; j < 4; j++)
    {
        prefs->tempSliceVox[j] = frac[j]*prefs->voxelDim[j];//convert fraction to voxels
    }
}

void mm2frac (int Xmm, int Ymm, int Zmm, NII_PREFS* prefs)
{
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return;
    mat44 R = prefs->sto_ijk;
    for (int i = 0; i < 3; i++) {
        //-1 as zero based: frac=0.5
        prefs->sliceFrac[i+1] = ( (R.m[i][0]*Xmm)+(R.m[i][1]*Ymm)+ (R.m[i][2]*Zmm)+R.m[i][3] )/(prefs->voxelDim[i+1]-1);
        
        if ((prefs->sliceFrac[i+1] < 0) || (prefs->sliceFrac[i+1]> 1)) prefs->sliceFrac[i+1] = 0.5;
    }
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"mm2frac mm->frac %d %d %d -> %g %g %g mm",
          Xmm, Ymm, Zmm,
          prefs->sliceFrac[1], prefs->sliceFrac[2], prefs->sliceFrac[3]);
    #endif
    //next for 2D images, otherwise interpolation can make them appear washed out
    if (prefs->voxelDim[1] == 1) prefs->sliceFrac[1] = 0.5;
    if (prefs->voxelDim[2] == 1) prefs->sliceFrac[2] = 0.5;
    if (prefs->voxelDim[3] == 1) prefs->sliceFrac[3] = 0.5;
}

void frac2mm (float frac[4], NII_PREFS* prefs, bool sliceCenter)
{
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return;
    //if (prefs->viewRadiological) frac[1] = 1.0 - frac[1];
    if (sliceCenter) {
        for (int i = 1; i < 4; i++) {
            float hlf = 1.0/((double)prefs->voxelDim[i] * 2.0) ;
            if (frac[i] < hlf)
                frac[i] = hlf;
            else if (frac[i] > (1.0- hlf))
                frac[i] = 1.0 - hlf;
            else {
                float hlf2 = hlf * 2;
                frac[i] = (trunc(frac[i]/hlf2)* hlf2) + hlf;
            }
        }
    }
    float Vox[4];
    for (int j = 1; j < 4; j++) { //convert fraction to voxels
        //-1 as frac=0.5 voxelDim=9 is voxel 4 in zero-indexcoordinates
        Vox[j] = frac[j]*(prefs->voxelDim[j]-1.0);
        prefs->sliceFrac[j] = frac[j];
    }
    mat44 R = prefs->sto_xyz;
    for (int i = 0; i < 3; i++) {
        prefs->mm[i+1] = round( (R.m[i][0]*Vox[1])+(R.m[i][1]*Vox[2])+ (R.m[i][2]*Vox[3])+R.m[i][3] );
    }
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"frac2mm frac->vox->mm %g %g %g -> %g %g %g -> %g %g %g mm",
          prefs->sliceFrac[1], prefs->sliceFrac[2], prefs->sliceFrac[3],
          Vox[1], Vox[2], Vox[3],
          prefs->mm[1], prefs->mm[2], prefs->mm[3]);
    #endif
}

-(bool) changeXYZvoxel: (int) x Y: (int) y Z: (int) z {
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return FALSE;
    float frac[4];
    if (prefs->viewRadiological)
        frac[1] = ((prefs->sliceFrac[1]*(float)prefs->voxelDim[1])-x)/(float)prefs->voxelDim[1];
    else
        frac[1] = ((prefs->sliceFrac[1]*(float)prefs->voxelDim[1])+x)/(float)prefs->voxelDim[1];
    frac[2] = ((prefs->sliceFrac[2]*(float)prefs->voxelDim[2])+y)/(float)prefs->voxelDim[2];
    frac[3] = ((prefs->sliceFrac[3]*(float)prefs->voxelDim[3])+z)/(float)prefs->voxelDim[3];
    /*for (int i = 1; i < 4; i++) {
        float hlf = halfSlice(prefs->voxelDim[i]);
        if (frac[i] < hlf)
            frac[i] = hlf;
        else if (frac[i] > (1.0- hlf))
            frac[i] = 1.0 - hlf;
        else {
            float hlf2 = hlf * 2;
            frac[i] = (trunc(frac[i]/hlf2)* hlf2) + hlf;
        }
    }*/
    frac2mm (frac, prefs, true); //arrows
    prefs->force_refreshGL = TRUE;
    return TRUE;
}

-(bool) setXYZmm: (float) x Y: (float) y Z: (float) z {
    if ((prefs->mm[1] == x) && (prefs->mm[2] == y) && (prefs->mm[3] == z)) return FALSE;
    //NSLog(@" move from %fx%fx%f to %fx%fx%f", prefs->mm[1],prefs->mm[2],prefs->mm[3],x, y, z);
    mm2frac (x, y, z,  prefs);
    //it is possible that the desired mm were outside the range of our volume....
    float frac[4];
    frac[1] = prefs->sliceFrac[1];
    frac[2] = prefs->sliceFrac[2];
    frac[3] = prefs->sliceFrac[3];
    frac2mm (frac, prefs,true); //yoke
    prefs->force_refreshGL = TRUE;
    return TRUE;
}

-(bool) isTimelineUpdateNeeded {
    if (prefs->busyGL == TRUE) return FALSE;
    return prefs->updatedTimeline;
}

-(GraphStruct) getTimeline {
    GraphStruct graph;
    prefs->updatedTimeline = false;
    graph.timepoints = prefs->numVolumes;
    graph.selectedTimepoint = prefs->currentVolume;
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) graph.timepoints = 0;
    graph.lines = 1;
    graph.verticalScale =fslio->niftiptr->pixdim[4];
    int slice[3];
    //slice[0] = 0; slice[1] = 0; slice[2] = 0; //prevents compiler warning - adjusted in mm2slice
    //mm2slice (slice, prefs); //2014
    //if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return;
    mat44 R = prefs->sto_ijk;
    for (int i = 0; i < 3; i++) {
        slice[i] = round( (R.m[i][0]*prefs->mm[1])+(R.m[i][1]*prefs->mm[2])+ (R.m[i][2]*prefs->mm[3])+R.m[i][3] );
        if (slice[i] < 0) slice[i] = 0;
        if (slice[i] >= prefs->voxelDim[i+1]) slice[i] = prefs->voxelDim[i+1]-1;
    }
    long long vox = slice[0] + (slice[1]*prefs->voxelDim[1])+(slice[2]*prefs->voxelDim[1]*prefs->voxelDim[2]);
    long long nvox = prefs->numVox3D ; //prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3];
    if ((vox < 0) || (vox >= nvox) ) graph.timepoints = 0;
    if (graph.timepoints < 2) return graph; //no graph
    graph.data = (float *) malloc( prefs->numVolumes*sizeof(float));
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"nii_img 7 malloc size %ld", prefs->numVolumes*sizeof(float));
    #endif
    //load data
    //NSLog(@" %d %d %d  %d %d %d", prefs->voxelDim[1],prefs->voxelDim[2],prefs->voxelDim[3], fslio->niftiptr->dim[1],fslio->niftiptr->dim[2],fslio->niftiptr->dim[3]);
    if ((prefs->busyGL) || (fslio->niftiptr->dim[1] != prefs->voxelDim[1])  || (fslio->niftiptr->dim[2] != prefs->voxelDim[2]) || (fslio->niftiptr->dim[3] != prefs->voxelDim[3])){
        prefs->updatedTimeline = TRUE; //check back when the main process is not busy
        graph.timepoints = 1;
        return graph;
    }
    prefs->busyGL = TRUE;
    //slice[n] has i,j,k coordinate of voxel
    float scale =fslio->niftiptr->scl_slope;
    float inter =fslio->niftiptr->scl_inter;
    if (fslio->niftiptr->datatype == NIFTI_TYPE_RGBA32) {
        NSLog(@"Timelines not (yet) supported for RGBA data.");
        for (int i = 0; i < prefs->numVolumes; i++)
            graph.data[i] = i;
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *inbuf = (THIS_UINT8 *) fslio->niftiptr->data;
        for (int vol = 0; vol < prefs->numVolumes; vol++) {
            graph.data[vol] = (inbuf[vox]*scale)+inter;
            vox += nvox;
        }
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *inbuf = (THIS_INT16 *) fslio->niftiptr->data;
        for (int vol = 0; vol < prefs->numVolumes; vol++) {
            graph.data[vol] =  (inbuf[vox]*scale)+inter;
            vox = vox + nvox;
        }
    } else {
        SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) fslio->niftiptr->data;
        for (int vol = 0; vol < prefs->numVolumes; vol++) {
            graph.data[vol] = (inbuf[vox]*scale)+inter;
            vox += nvox;
        }
    }
    prefs->busyGL = FALSE;
    return graph;
}

//int ret = convertBufferToScaled(&outbuf[0], fslio->niftiptr->data, (long)(fslio->niftiptr->nvox), slope, inter, fslio->niftiptr->datatype);
//nii_unify_datatype
int xx(FSLIO* fslio) {
    

        if (fslio->niftiptr->scl_slope == 0) { //nonsense value - fix the header!
            fslio->niftiptr->scl_slope = 1.0;
            fslio->niftiptr->scl_inter = 0.0;
        }
    //fslio->niftiptr->
    size_t len = fslio->niftiptr->nvox;
    void *inbuf = fslio->niftiptr->data;

    int ret = 0;
    if (NIFTI_TYPE_UINT8)
        for (int i=0; i<len; i++)
            if (((THIS_UINT8 *)(inbuf)+i) != 0)
                ret += 1;
    
    return ret;
    
}
int  convertBufferToScaled(SCALED_IMGDATA *outbuf, void *inbuf, long len, float slope, float inter, int nifti_datatype ) {
//adapted from fslio.c "convertBufferToScaledDouble" library that was placed in the public domain
    long i;
    switch(nifti_datatype) {
        case NIFTI_TYPE_UINT8:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_UINT8 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_INT8:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_INT8 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_UINT16:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_UINT16 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_INT16:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_INT16 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_UINT64:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_UINT64 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_INT64:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_INT64 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_UINT32:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_UINT32 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_INT32:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_INT32 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_FLOAT32:
            for (i=0; i<len; i++)
                outbuf[i] = (SCALED_IMGDATA) ( *((THIS_FLOAT32 *)(inbuf)+i) * slope + inter);
            break;
        case NIFTI_TYPE_FLOAT64:
            if ((slope == 1.0f) && (inter == 0.0f)) { //NIFTI stores inter/slope as 32-bit floats, so not really appropriate for 64 bit
                for (i=0; i<len; i++)
                    outbuf[i] = (SCALED_IMGDATA) ( *((THIS_FLOAT64 *)(inbuf)+i) );
                
            } else {
                for (i=0; i<len; i++)
                    outbuf[i] = (SCALED_IMGDATA) ( *((THIS_FLOAT64 *)(inbuf)+i) * slope + inter);
            }
            break;
        case NIFTI_TYPE_FLOAT128:
        case NIFTI_TYPE_COMPLEX128:
        case NIFTI_TYPE_COMPLEX256:
        case NIFTI_TYPE_COMPLEX64:
        default:
            fprintf(stderr, "\nWarning, cannot support %d yet.\n",nifti_datatype);
            return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

/*double correlRGB(FSLIO* fslio, bool isAssumePlanar) {
//find correlation between red and green values on the middle slice of a RGB image
//returns Pearson's Correlation Coefficient https://people.richland.edu/james/lecture/m170/ch11-cor.html
    int voxSlice = fslio->niftiptr->dim[1] * fslio->niftiptr->dim[2];
    int incR = 3; //increment for successive red values if RGBRGBRGB
    int offG = 1; //offset for blue relative to red if RGBRGB
    if (isAssumePlanar) { //data stored RRRR...RGGGGG...GBBBB...B
        incR = 1; //increment for successive red values if RRR...
        offG = voxSlice; //offset for blue relative to red if RRRR...RGGGGG.
    }
    double sumR = 0.0; double sumRR = 0.0;
    double sumG = 0.0; double sumGG = 0.0;
    double sumRG = 0.0;
    int posR = (fslio->niftiptr->dim[3]/2) * voxSlice * 3; //offset to first red voxel: middle slice for 3D data
    THIS_UINT8 *rawRGB = (THIS_UINT8 *) fslio->niftiptr->data;
    for (int v = 0; v < voxSlice; v++) {
        sumR += rawRGB[posR];
        sumRR += rawRGB[posR]*rawRGB[posR];
        sumG += rawRGB[posR+offG];
        sumGG += rawRGB[posR+offG]*rawRGB[posR+offG];
        sumRG += rawRGB[posR]*rawRGB[posR+offG];
        posR += incR;
    }
    double ssR = sumRR - ( (sumR*sumR) / voxSlice);
    double ssG = sumGG - ( (sumG*sumG) / voxSlice);
    double ssRG = sumRG - ( (sumR*sumG) / voxSlice);
    double denom = sqrt(ssR * ssG);
    if (denom == 0) return 0.0;
    return ssRG/ denom;
}*/

bool isPlanarImg(FSLIO* fslio) {
//determine if RGB image is PACKED TRIPLETS (RGBRGBRGB...) or planar (RR..RGG..GBB..B)
//assumes strong correlation between voxel and neighbor on next line
    if (fslio->niftiptr->dim[2] < 2) return false; //requires at least 2 rows of data
    int incPlanar = fslio->niftiptr->dim[1]; //increment next row of PLANAR image
    int incPacked = fslio->niftiptr->dim[1] * 3; //increment next row of PACKED image
    int byteSlice = incPacked * fslio->niftiptr->dim[2]; //bytes per 3D slice of RGB data
    double dxPlanar = 0.0;//difference in PLANAR
    double dxPacked = 0.0;//difference in PACKED
    int pos = (fslio->niftiptr->dim[3]/2) * byteSlice; //offset to middle slice for 3D data
    THIS_UINT8 *rawRGB = (THIS_UINT8 *) fslio->niftiptr->data;
    int posEnd = pos + byteSlice - incPacked;
    while (pos < posEnd) {
        dxPlanar += abs(rawRGB[pos]-rawRGB[pos+incPlanar]);
        dxPacked += abs(rawRGB[pos]-rawRGB[pos+incPacked]);
        pos++;
    }
    return (dxPlanar < dxPacked);
} //isPlanarImg()

int convertRGB2RGBA(FSLIO* fslio)
//convert 24-bit red-green-blue to OpenGL-native red-green-blue-alpha components
//WARNING Analyze RGB format is planar RRRR...RGGGG....GBBBB...B we will convert to RGBARGBARGBARGBA....
{
    int nx = fslio->niftiptr->dim[1];
    int ny = fslio->niftiptr->dim[2];
    int nz = fslio->niftiptr->dim[3];
    //NSLog(@"%d\n", fslio->niftiptr->intent_code);
    int o = 0; //output
    size_t sizebytes = fslio->niftiptr->nvox*sizeof(uint32_t);
    THIS_UINT8 *outbuf = (THIS_UINT8 *) malloc(sizebytes);
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"nii_img 2 malloc size %ld", sizebytes);
    #endif
    THIS_UINT8 *rawRGB = (THIS_UINT8 *) fslio->niftiptr->data;
    int nvol = 1;
    for (int dim = 4; dim < 8; dim++)
        if (fslio->niftiptr->dim[dim] > 1)
            nvol = nvol * fslio->niftiptr->dim[dim];
    //NSLog(@"true %g", correlRGB(fslio, true));
    //NSLog(@"false %g", correlRGB(fslio, false));
    //NSLog(@"isPlanar %d", isPlanarImg(fslio));
    //bool isPlanar  = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask);
    bool isPlanar  = isPlanarImg(fslio);
    //isPlanar = false;
    if (!isPlanar) {//(fslio->niftiptr->intent_code != 0) {  //Assume triplets style RGBRGBRGB
        int i = 0; //output
        int nxyz = nx*ny*nz;
        for (int vol= 0; vol < nvol; vol++) {
            for (int vx= 0; vx < nxyz; vx++) {
                outbuf[o++] = rawRGB[i++]; //red
                outbuf[o++] = rawRGB[i++]; //gree
                outbuf[o++] = rawRGB[i++]; //blue
                outbuf[o++] = rawRGB[i-2] /2;//green best estimate for alpha
            }
        }
    } else { //Assume planar style RGBRGBRGB
        int nxy = nx*ny; //number of voxels in a plane
        int nxy3 = nxy*3; //size for group of RGB planes
        int sliceR =0;
        int sliceG =nxy;
        int sliceB = nxy+nxy;
        int row = 0;
        for (int vol= 0; vol < nvol; vol++) {
            for (int z = 0; z < nz; z++) { //for each slice
                row = 0; //start of row
                for (int y = 0; y < ny; y++) { //for each row
                    for (int x = 0; x < nx; x++) { //for each column
                        outbuf[o++] = rawRGB[sliceR+row+x];
                        outbuf[o++] = rawRGB[sliceG+row+x];
                        outbuf[o++] = rawRGB[sliceB+row+x];
                        outbuf[o++] = rawRGB[sliceG+row+x] /2; //green best estimate for alpha   666 2016
                    } //for each x
                    row = row + nx;
                } //for each y
                sliceR = sliceR + nxy3; //start of red plane
                sliceG = sliceG + nxy3; //start of green plane
                sliceB = sliceB + nxy3; //start of blue plane
            } //for each z
        }
    }
    //free(fslio->niftiptr->data);
    //fslio->niftiptr->data = outbuf;
    //int ret = convertBufferToScaled(&outbuf[0], fslio->niftiptr->data, (long)(fslio->niftiptr->nvox), slope, inter, fslio->niftiptr->datatype);
    fslio->niftiptr->datatype =DT_RGBA32;
    fslio->niftiptr->nbyper = 4;
    fslio->niftiptr->scl_slope = 1.0; //image data rescaled
    fslio->niftiptr->scl_inter = 0.0; //image data rescaled
    free(fslio->niftiptr->data);
    fslio->niftiptr->data = outbuf;
    //return EXIT_FAILURE;
    return EXIT_SUCCESS;
}

bool isNaN32( float value ) {
    return ((*(THIS_UINT32*)&value) & 0x7fffffff) > 0x7f800000;
}

//http://www.johndcook.com/IEEE_exceptions_in_cpp.html
void ZeroNaN32 (void *inbuf, size_t len) {
    THIS_FLOAT32  *buf = (THIS_FLOAT32 *) inbuf;
    for (size_t i=0; i<len; i++) {
        if ( isNaN32(buf[i]))
            buf[i] = 0.0;
    }
}

void clipInf32 (void *inbuf, size_t len) {
    THIS_FLOAT32  *buf = (THIS_FLOAT32 *) inbuf;
    bool hasInf = false;
    for (size_t i=0; i<len; i++) {
        if ((buf[i] == INFINITY) || (buf[i] == -INFINITY) ) {
            hasInf = true;
            break;
        }
    }//for each voxel
    if (!hasInf) return;
    //2nd pass - find largest and smallest values that are NOT infinity!
    THIS_FLOAT32 nmin = INFINITY;
    THIS_FLOAT32 nmax = -INFINITY;
    for (size_t i=0; i<len; i++) {
        if ((buf[i] > nmax) && (buf[i] < INFINITY)) nmax = buf[i];
        if ((buf[i] < nmin) && (buf[i] > -INFINITY)) nmin = buf[i];
    }//for each voxel
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"Removing inifinity values (finite data range %f..%f)",nmin,nmax);
    #endif
    if (nmax == nmin) { //all numerical values identical, e.g. region is 1 masked by NaNs
        THIS_FLOAT32 v = nmax;
        nmax = v - 1;
        nmin = v + 1;
    }
    if (nmin == INFINITY) nmin = 0; //ONLY occurs if all voxels are INFINITY
    if (nmax == -INFINITY) nmax = 0; //ONLY occurs if all voxels are -INFINITY
    
    for (size_t i=0; i<len; i++) {
        if (buf[i] == INFINITY) buf[i] = nmax;
        if (buf[i] == -INFINITY) buf[i] = nmin;
    }//for each voxel
}

#define I64(f) (*(long long int *)&f)
static bool isNaN64 (double value) {
    unsigned long long int jvalue = (I64(value) &
                                     ~0x8000000000000000uLL);
    return (jvalue > 0x7ff0000000000000uLL);
}

void ZeroNaN64 (void *inbuf, size_t len) {
    THIS_FLOAT64  *buf = (THIS_FLOAT64 *) inbuf;  
    for (size_t i=0; i<len; i++) {
        if ( isNaN64(buf[i]))
            buf[i] = 0.0;
    }
}

void clipInf64 (void *inbuf, size_t len) {
    THIS_FLOAT64  *buf = (THIS_FLOAT64 *) inbuf;
    bool hasInf = false;
    for (size_t i=0; i<len; i++) {
        if ((buf[i] == INFINITY) || (buf[i] == -INFINITY) ) {
            hasInf = true;
            break;
        }
    }//for each voxel
    if (!hasInf) return;
    //2nd pass - find largest and smallest values that are NOT infinity!
    THIS_FLOAT64 nmin = INFINITY;
    THIS_FLOAT64 nmax = -INFINITY;
    for (size_t i=0; i<len; i++) {
        if ((buf[i] > nmax) && (buf[i] < INFINITY)) nmax = buf[i];
        if ((buf[i] < nmin) && (buf[i] > -INFINITY)) nmin = buf[i];
    }//for each voxel
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"Removing inifinity values (finite data range %f..%f)",nmin,nmax);
    #endif
    if (nmax == nmin) { //all numerical values identical, e.g. region is 1 masked by NaNs
        THIS_FLOAT64 v = nmax;
        nmax = v - 1;
        nmin = v + 1;
    }
    if (nmin == INFINITY) nmin = 0; //ONLY occurs if all voxels are INFINITY
    if (nmax == -INFINITY) nmax = 0; //ONLY occurs if all voxels are -INFINITY
    for (size_t i=0; i<len; i++) {
        if (buf[i] == INFINITY) buf[i] = nmax;
        if (buf[i] == -INFINITY) buf[i] = nmin;
    }//for each voxel
}

int nii_unify_datatype(FSLIO* fslio)
//this converts all unusual datatypes to SCALED_IMGDATA type (nii_definetypes)
// common supported datatypes are not changed. 
{
    if (fslio->niftiptr->scl_slope == 0) { //nonsense value - fix the header!
        fslio->niftiptr->scl_slope = 1.0;
        fslio->niftiptr->scl_inter = 0.0;
    }


    if ( fslio->niftiptr->datatype == NIFTI_TYPE_FLOAT32) {
        ZeroNaN32(fslio->niftiptr->data, fslio->niftiptr->nvox);
        clipInf32(fslio->niftiptr->data, fslio->niftiptr->nvox);
    }
    if ( fslio->niftiptr->datatype == NIFTI_TYPE_FLOAT64) {
        
        ZeroNaN64(fslio->niftiptr->data, fslio->niftiptr->nvox);
        clipInf64(fslio->niftiptr->data, fslio->niftiptr->nvox);
    }
    if (fslio==NULL)  {
        printf("nii_unify: Null pointer passed for FSLIO");
        return EXIT_FAILURE;
    }
    /*if ((fslio->niftiptr->dim[0] <= 0) || (fslio->niftiptr->dim[0] > 4)) {
        printf("nii_unify: Incorrect dataset dimension, 1-4D needed, image reports %d\n", fslio->niftiptr->dim[0]);
        return EXIT_FAILURE;
    }*/
    if (fslio->niftiptr->nvox < 1) {
        printf("nii_unify: voxels not loaded!");
        return EXIT_FAILURE;
    }
    
//don't convert a format that is natively supported...
    if ( fslio->niftiptr->datatype == DT_RGB24) return convertRGB2RGBA(fslio); //24-bit RGBA must convert to 32-bit RGBA
    if ( fslio->niftiptr->datatype == DT_RGBA32) return EXIT_SUCCESS; //32-bit RGBA bit format is supported!
    if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) return EXIT_SUCCESS; //unsigned 8 bit format is supported!
    if ( fslio->niftiptr->datatype ==NIFTI_TYPE_INT16) return EXIT_SUCCESS;//signed 16 bit format is supported!
    //rescale image
    float slope = fslio->niftiptr->scl_slope;
    float inter = fslio->niftiptr->scl_inter;
    if ((fslio->niftiptr->datatype == SCALED_IMGDATA_TYPE) && (slope == 1.0f) && (inter == 0.0f)) return EXIT_SUCCESS;//float 32 bit format is supported!
    
    //if ((fslio->niftiptr->datatype == NIFTI_TYPE_FLOAT32) && (slope == 1.0f) && (inter == 0.0f)) return EXIT_SUCCESS;//float 32 bit format is supported!
    //convertBufferToScaled SCALED_IMGDATA_TYPE        NIFTI_TYPE_FLOAT32
    if (fslio->niftiptr->datatype == SCALED_IMGDATA_TYPE) {
        //special case: image format does not change, simply rescale data
        SCALED_IMGDATA *buf = (SCALED_IMGDATA *)fslio->niftiptr->data;
        for (int i=0; i<fslio->niftiptr->nvox; i++)
            buf[i] = buf[i] * slope + inter;
        fslio->niftiptr->scl_slope = 1.0; //image data rescaled
        fslio->niftiptr->scl_inter = 0.0; //image data rescaled
        return EXIT_SUCCESS;
    }
    size_t sizebytes = fslio->niftiptr->nvox*sizeof(SCALED_IMGDATA);
    SCALED_IMGDATA *outbuf = (SCALED_IMGDATA *) malloc(sizebytes);
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"nii_img 3 malloc size %ld",sizebytes);
    #endif
    int ret = convertBufferToScaled(&outbuf[0], fslio->niftiptr->data, (long)(fslio->niftiptr->nvox), slope, inter, fslio->niftiptr->datatype);
    if (ret != EXIT_SUCCESS) {
        free(fslio->niftiptr->data);
        fslio->niftiptr->data = outbuf;
        NSLog(@"convertBufferToScaled failed");
        return EXIT_FAILURE;
    }
    if (sizeof(SCALED_IMGDATA) == 4) {
        fslio->niftiptr->datatype =NIFTI_TYPE_FLOAT32;
        fslio->niftiptr->nbyper = 4;
    } else if (sizeof(SCALED_IMGDATA) == 8) {
        fslio->niftiptr->datatype =NIFTI_TYPE_FLOAT64;
        fslio->niftiptr->nbyper = 8;
    } else {
        printf("compiled with invalid SCALED_IMGDATA");
    }
    fslio->niftiptr->scl_slope = 1.0; //image data rescaled
    fslio->niftiptr->scl_inter = 0.0; //image data rescaled
    free(fslio->niftiptr->data);
    fslio->niftiptr->data = outbuf;
    return EXIT_SUCCESS;
}

const double kPercentile = 0.01; //proportion of voxels counted as outliers, e.g. if 0.05, then suggested contrast scales from darkest 5% to brightest 5%
//const long kBins = 1024; //we will sort the full image range into this many historgram bins...
const long kSampleRate = 7; //we do not have to test every voxel to detect typical intensity distribution - if 1 every voxel is tested, if 5 every 5th voxel is tested...

int nii_findrangefloat (FSLIO* fslio, NII_PREFS* prefs) {
    //find range for floating point data (default precision)
    //long len = fslio->niftiptr->nvox; //ALL VOLUMES
    long len = prefs->numVox3D; //ONLY FIRST VOLUME!
    SCALED_IMGDATA *num_list = (SCALED_IMGDATA *)fslio->niftiptr->data;
    if ( len < 1) return EXIT_FAILURE;
    SCALED_IMGDATA min = num_list[0];
    SCALED_IMGDATA max = min;
    for (long j = 0; j < len; j++) {
        if (num_list[j] < min) min = num_list[j];
        if (num_list[j] > max) max = num_list[j];
    }
    prefs->fullMin = (min* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    prefs->fullMax = (max* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    if (prefs->fullMin >= prefs->fullMax) { //no variability in data
        prefs->nearMin = prefs->fullMin;
        prefs->nearMax = prefs->fullMax;
        return EXIT_SUCCESS;
    }
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"nii_findrangefloat slope=%f intercept=%f range=%f..%f",fslio->niftiptr->scl_slope,fslio->niftiptr->scl_inter,prefs->fullMin, prefs->fullMax);
    #endif
    //long bins[kBins];
    for (long k = 0; k < MAX_HISTO_BINS; k++) prefs->histo[k] = 0; //XCode 4.0 Variable length arrays not initialized
    min = prefs->fullMin;
    //SCALED_IMGDATA slope = (kBins-1)/(prefs->fullMax - prefs->fullMin);
    double slope = (MAX_HISTO_BINS-1)/(prefs->fullMax - prefs->fullMin);
    int pos;
    for (long j = 0; j < len; j+=kSampleRate) {
        pos = round((num_list[j]-min)*slope);
        if ((pos >=0) && (pos < MAX_HISTO_BINS)) //only needed if extreme values, very little penalty
            prefs->histo[pos]++;
    }
    long percentile = round (((len+kSampleRate-1) / kSampleRate)  *kPercentile); //how many voxels eqaul desired %
    //next find darkest 5th percent
    long samples = 0;
    pos = 0;
    do {
        samples += prefs->histo[pos];
        pos++;
    } while (samples < percentile);
    prefs->nearMin = ((pos-1)/slope)+min;
    //find brightest 5th percent
    samples = 0;
    pos = MAX_HISTO_BINS-1;
    do {
        samples += prefs->histo[pos];
        pos--;
    } while (samples < percentile);
    prefs->nearMax = ((pos+1)/slope)+min;
    return EXIT_SUCCESS;
}

int nii_findrange8ui (FSLIO* fslio, NII_PREFS* prefs)
//find range for 8 bit unsigned integers
{
    //long len = fslio->niftiptr->nvox;//ALL VOLUMES
    long len = prefs->numVox3D; //ONLY FIRST VOLUME!
    if ( len < 1) return EXIT_FAILURE;
    THIS_UINT8 *num_list = (THIS_UINT8 *) fslio->niftiptr->data;
    THIS_UINT8 min = num_list[0];
    THIS_UINT8 max = min;
    for (long j = 0; j < len; j++) {
        if (num_list[j] < min) min = num_list[j];
        if (num_list[j] > max) max = num_list[j];
    }
    prefs->fullMin = (min* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    prefs->fullMax = (max* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    if (prefs->fullMin >= prefs->fullMax) { //no variability in data
        prefs->nearMin = prefs->fullMin;
        prefs->nearMax = prefs->fullMax;
        return EXIT_SUCCESS;
    }
    const long kBins8 = 256; //for 8 bit data, 256 bins provide complete coverage
    long bins[kBins8];
    for (long k = 0; k < kBins8; k++) bins[k] = 0; //XCode 4.0 variable length arrays not initialized
    int pos;
    for (long j = 0; j < len; j+=kSampleRate)
        bins[ num_list[j] ]++;
    long percentile = round (((len+kSampleRate-1) / kSampleRate)  *kPercentile); //how many voxels eqaul desired %
    //next find darkest 5th percent
    long samples = 0;
    pos = 0;
    do {
        samples += bins[pos];
        pos++;
    } while (samples < percentile);
    //prefs->nearMin = (pos-1);
    prefs->nearMin = ((pos-1)* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    //find brightest 5th percent
    samples = 0;
    pos = kBins8-1;
    do {
        samples += bins[pos];
        //printf("bin %d has %ld\n",pos,bins[pos]);
        pos--;
    } while (samples < percentile);
    prefs->nearMax = ((pos+1)* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;

    float histoScale = float(kBins8) / float(MAX_HISTO_BINS);
    for (long j = 0; j < MAX_HISTO_BINS; j++) {
        pos =  round( (float)j * histoScale);
        prefs->histo[j] = bins[pos];
    }
    
    return EXIT_SUCCESS;
}



int nii_findrange16i (FSLIO* fslio, NII_PREFS* prefs)
//find range for 16 bit signed integers
{
    //long len = fslio->niftiptr->nvox;//ALL VOLUMES
    long len = prefs->numVox3D; //ONLY FIRST VOLUME!
    if ( len < 1) return EXIT_FAILURE;
    THIS_INT16 *num_list = (THIS_INT16 *) fslio->niftiptr->data;
    long min = num_list[0];
    long max = min;
    for (long j = 0; j < len; j++) {
        if (num_list[j] < min) min = num_list[j];
        if (num_list[j] > max) max = num_list[j];
    }
    prefs->fullMin = (min* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    prefs->fullMax = (max* fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    if (min >= max) { //no variability in data
        prefs->nearMin = prefs->fullMin;
        prefs->nearMax = prefs->fullMax;
        return EXIT_SUCCESS;
    }
    for (long k = 0; k < MAX_HISTO_BINS; k++) prefs->histo[k] = 0; //XCode 4.0 variable length arrays not initialized
    float range = (max-min);
    float slope = (MAX_HISTO_BINS-1)/range;
    int pos;
    long long islope = 1 << 16;//source is 16 bit, we are using 64bit longs...
    islope = round(islope * slope);
    for (long j = 0; j < len; j+=kSampleRate) {
        //pos = round((num_list[j]-min)*slope); // <- OPTIMIZE this line is expensive - compute as integer or use look up table?
        pos = int( ((num_list[j]-min)*islope) >> 16); // <- integer multiplication dramatically faster on Intel i5 CPU (x3 for entire function)
        prefs->histo[ pos]++;
    }
    long percentile = round (((len+kSampleRate-1) / kSampleRate)  *kPercentile); //how many voxels eqaul desired %
    //next find darkest 5th percent
    long samples = 0;
    pos = 0;
    do {
        samples += prefs->histo[pos];
        pos++;
    } while (samples < percentile);
    prefs->nearMin = ((pos-1)/slope)+min;
    prefs->nearMin = (prefs->nearMin * fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    //find brightest 5th percent
    samples = 0;
    pos = MAX_HISTO_BINS-1;
    do {
        samples += prefs->histo[pos];
        pos--;
    } while (samples < percentile);
    prefs->nearMax = ((pos+1)/slope)+min;
    prefs->nearMax = (prefs->nearMax * fslio->niftiptr->scl_slope)+fslio->niftiptr->scl_inter;
    return EXIT_SUCCESS;
}

int nii_findrange (FSLIO* fslio, NII_PREFS* prefs) {
    //finds brightest and darkest voxels - both maximum extremes (fullMin/fullMax) and disregarding outliers (nearMin,nearMax)
    int ret = EXIT_FAILURE;
    if ((fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) && (( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) ||  ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16))  ){
        prefs->fullMin = 0;
        prefs->fullMax = 100;
        prefs->nearMin = prefs->fullMin;
        prefs->nearMax = prefs->fullMax;
        prefs->viewMin = prefs->fullMin;
        prefs->viewMax = prefs->fullMax;
        ret = EXIT_SUCCESS;
    } else if (fslio->niftiptr->datatype == NIFTI_TYPE_RGBA32) {
        prefs->fullMin = 0;
        prefs->fullMax = 255;
        prefs->nearMin = prefs->fullMin;
        prefs->nearMax = prefs->fullMax;
        if ((fslio->niftiptr->cal_min < fslio->niftiptr->cal_max) && ((fslio->niftiptr->cal_max - fslio->niftiptr->cal_min) > 2 )) {
            prefs->nearMin = fslio->niftiptr->cal_min;
            prefs->nearMax = fslio->niftiptr->cal_max;
        }
        prefs->viewMin = prefs->nearMin;
        prefs->viewMax = prefs->nearMax;
        ret = EXIT_SUCCESS;
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8)
        ret= nii_findrange8ui(fslio, prefs);
    else if ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16)
        ret= nii_findrange16i(fslio, prefs);
    else
        ret= nii_findrangefloat(fslio, prefs);
    if ((fslio->niftiptr->datatype != NIFTI_TYPE_RGBA32) && (fslio->niftiptr->intent_code != NIFTI_INTENT_LABEL) && (fslio->niftiptr->cal_min >= prefs->fullMin) && (fslio->niftiptr->cal_max <= prefs->fullMax)
        && (fslio->niftiptr->cal_min < fslio->niftiptr->cal_max)
        ) {
        #ifdef MY_DEBUG //from nii_io.h
        NSLog(@"Using header intensity calibration %g..%g",fslio->niftiptr->cal_min,fslio->niftiptr->cal_max);
        #endif
        prefs->nearMin = fslio->niftiptr->cal_min; //use values suggested in header
        prefs->nearMax = fslio->niftiptr->cal_max;
    }
    //initially provide the user with image contrast using the image intensity range that ignores outliers...
    if (prefs->nearMin != prefs->nearMax) { 
        prefs->viewMin = prefs->nearMin;
        prefs->viewMax = prefs->nearMax;
    } else {
        prefs->viewMin = prefs->fullMin;
        prefs->viewMax = prefs->fullMax;        
    }
    if ((prefs->viewMin >= -4096) && (prefs->viewMin <= -1000) && (prefs->viewMax >= 1000) && (prefs->viewMax <= 4096)) { //autoscale CT scans for brain
        prefs->viewMin = -10;
        prefs->viewMax = 100;
    }
    #ifdef MY_DEBUG //from nii_io.h
        printf("full intensity range %f..%f\n",prefs->fullMin ,prefs->fullMax);
        printf("range excluding outliers %f..%f\n",prefs->nearMin ,prefs->nearMax);
    #endif
    return ret;
}

uint32_t makeRGBA (THIS_UINT8 r, THIS_UINT8 g, THIS_UINT8 b, THIS_UINT8 a)
{
    return (r << 0)+ (g << 8) + (b << 16) + (a << 24);
}

uint32_t lerprgb (uint32_t lo, uint32_t hi, int loindex, int hiindex, int tarindex)
//linear interpolation for RGB color between lo and hi
{
    float frac = float(tarindex-loindex)/(hiindex-loindex);
    uint32_t ret;
    THIS_UINT8* plo = (THIS_UINT8*)&lo;
    THIS_UINT8* phi = (THIS_UINT8*)&hi;
    THIS_UINT8* pret = (THIS_UINT8*)&ret;
    for (int i = 0; i < 4; i++) 
        pret[i] = (plo[i]+ frac*(phi[i]- plo[i]) ); //linear interpolations
    return ret;
}



/*int filllut(uint32_t lo, uint32_t hi, int loIndex, int hiIndex, uint32_t* lut) {
    for (int i = loIndex; i < hiIndex; i++)
        lut[i] = lerprgb(lo, hi, loIndex, hiIndex,i);
    return hiIndex;
}*/

struct RGBAnode
{
    uint32_t rgba;
    int   intensity;
} ;

struct RGBAnode makeRGBAnode (THIS_UINT8 r, THIS_UINT8 g, THIS_UINT8 b, THIS_UINT8 a, int inten)
{
    struct RGBAnode ret;
    ret.rgba =  (r << 0)+ (g << 8) + (b << 16) + (a << 24);
    ret.intensity = inten;
    return ret;
}

void filllut(struct RGBAnode loNode, struct RGBAnode hiNode, uint32_t* lut) {
    int mn = (loNode.intensity >= 0) ? loNode.intensity : 0;
    int mx = (hiNode.intensity <= 256) ? hiNode.intensity : 256;
    for (int i = mn; i < mx; i++)
        lut[i] = lerprgb(loNode.rgba, hiNode.rgba, loNode.intensity, hiNode.intensity,i);
}

int createlutX(int colorscheme, uint32_t* lut) {
    if (colorscheme == 15) { //15=random
        createlutLabel(1, lut, 1.0);
        return EXIT_SUCCESS;
    }
    struct RGBAnode nodes[5];
    nodes[0] = makeRGBAnode(0,0,0,0,0); //assume minimum intensity is black
    nodes[1] = makeRGBAnode(255,255,255,128,256); //assume maximum intensity is white
    int numNodes = 2; //assume 2 nodes, e.g. [0]black [1]white
    switch (colorscheme) {
        case 1: //hot
            numNodes = 4;
            nodes[0] = makeRGBAnode(3,0,0,0,0);
            nodes[1] = makeRGBAnode(255,0,0,48,96);
            nodes[2] = makeRGBAnode(255,255,0,96,192);
            nodes[3] = makeRGBAnode(255,255,255,128,256);
            break;
        case 2: //2=winter
            numNodes = 3;
            nodes[0] = makeRGBAnode(0,0,255,0,0);
            nodes[1] = makeRGBAnode(0,128,96,64,128);
            nodes[2] = makeRGBAnode(0,255,128,128,256);
            break;
        case 3: //3=warm
            numNodes = 3;
            nodes[0] = makeRGBAnode(255,127,0,0,0);
            nodes[1] = makeRGBAnode(255,196,0,64,128);
            nodes[2] = makeRGBAnode(255,254,0,128,256);
            break;
        case 4: //4=cool
            numNodes = 3;
            nodes[0] = makeRGBAnode(0,127,255,0,0);
            nodes[1] = makeRGBAnode(0,196,255,64,128);
            nodes[2] = makeRGBAnode(0,254,255,128,256);
            break;
        case 5: //5=red/yell
            numNodes = 3;
            nodes[0] = makeRGBAnode(192,1,0,0,0);
            nodes[1] = makeRGBAnode(224,128,0,64,128);
            nodes[2] = makeRGBAnode(255,255,0,128,256);
            break;
        case 6: //6=blue/green
            numNodes = 3;
            nodes[0] = makeRGBAnode(0,1,222,0,0);
            nodes[1] = makeRGBAnode(0,128,127,64,128);
            nodes[2] = makeRGBAnode(0,255,32,128,256);
            break;
        case 7: //7=actc
            numNodes = 5;
            nodes[1] = makeRGBAnode(0,0,136,32,64);
            nodes[2] = makeRGBAnode(24,177,0,64,128);
            nodes[3] = makeRGBAnode(248,254,0,78,156);
            nodes[4] = makeRGBAnode(255,0,0,128,256);
            break;
        case 8: //8=bone
            numNodes = 3;
            nodes[1] = makeRGBAnode(103,126,165,76,153);
            nodes[2] = makeRGBAnode(255,255,255,128,256);
            break;
        case 9: //9=gold
            numNodes = 4;
            nodes[1] = makeRGBAnode(142,85,14,42,85);
            nodes[2] = makeRGBAnode(227,170,76,84,170);
            nodes[3] = makeRGBAnode(255,255,255,128,256);
            break;
        case 10: //10=hotiron
            numNodes = 4;
            nodes[1] = makeRGBAnode(255,0,0,64,128);
            nodes[2] = makeRGBAnode(255,126,0,96,191);
            nodes[3] = makeRGBAnode(255,255,255,128,256);
            break;
        case 11: //11=surface
            numNodes = 3;
            nodes[1] = makeRGBAnode(208,128,128,76,153);
            nodes[2] = makeRGBAnode(255,255,255,128,256);
            break;
        case 12: //12=red
            nodes[1] = makeRGBAnode(255,0,0,128,256);
            break;
        case 13: //13=green
            nodes[1] = makeRGBAnode(0,255,0,128,256);
            break;
        case 14: //14=blue
            nodes[1] = makeRGBAnode(0,0,255,128,256);
            break;
    }
    for (int i = 1; i < numNodes; i++)
        filllut(nodes[i-1], nodes[i], lut);
    lut[0] = 0;
    return EXIT_SUCCESS;
}

uint32_t copyAlpha (uint32_t rgb, uint32_t alpha)
//return RGBA with RGB for rgb and A from Alpha
{
    THIS_UINT8* a = (THIS_UINT8*)&alpha;
    uint32_t ret = rgb;
    THIS_UINT8* pret = (THIS_UINT8*)&ret;
    //pret[0] = a[0]; //linear interpolations
    pret[3] = a[3]; //linear interpolations
    
    return ret;
}

float getBias (float t, float bias) {
//http://blog.demofox.org/2012/09/24/bias-and-gain-are-your-friend/
    return (t / ((((1.0/bias) - 2.0)*(1.0 - t))+1.0));
}

float getGain (float t, float gain) {
    //http://blog.demofox.org/2012/09/24/bias-and-gain-are-your-friend/
    if(t < 0.5)
        return getBias(t * 2.0,gain)/2.0;
    else
        return getBias(t * 2.0 - 1.0,1.0 - gain)/2.0 + 0.5;
}


int createlut(int colorscheme, uint32_t* lut, float bias)
{
    //float bias = 0.3;
    if ((bias <= 0.0) || (bias >= 1.0) || ((bias > 0.499) && (bias < 0.501) ) )
        return createlutX(colorscheme, lut);
    tRGBAlut luto;
    createlutX(colorscheme, luto);
    for (int clr = 0; clr < 256; clr++) {
        //lut[clr] =  luto[clr];
        float t = (float)clr/255.0;
        float idx = 255.0 * getBias(t, bias);

        //float idx = 255.0 * getBias(t, bias);
        //float idx = 255.0 * (t / ((((1.0/bias) - 2.0)*(1.0 - t))+1.0));
        int i = trunc(idx);
        if (i > 254) i = 254;
        uint32_t lo = luto[i];
        uint32_t hi = luto[i+1];
        int frac = (idx-i) * 100;
        //uint32_t lerprgb (uint32_t lo, uint32_t hi, int loindex, int hiindex, int tarindex)
        lut[clr] = lerprgb(lo,hi, 0,100,frac);
        lut[clr] = copyAlpha(lut[clr], luto[clr]);
        //NSLog(@"%f %f", t, idx);
    }
    
    return EXIT_SUCCESS;
}

double nii_raw2cal(FSLIO* fslio, double raw)
{
    return (raw * fslio->niftiptr->scl_slope) + fslio->niftiptr->scl_inter;
}

double nii_cal2raw(float scl_inter, float scl_slope, double cal)
{
    return (cal - scl_inter) / scl_slope;
}

int sectionNumber(int x, int y, bool adjustView, NII_PREFS* prefs)
//0=rendering, 1=sagittal, 2= coronal, 3=axial
{
#ifdef NII_IMG_RENDER //defined in nii_definetypes.h
    if (prefs->displayModeGL == GL_3D_ONLY) return 0;
#endif
    float frac[4];
    frac[1] = prefs->sliceFrac[1]; //X-dimension
    frac[2] = prefs->sliceFrac[2]; //Y-dimension (Anterior-Posterio)
    frac[3] = prefs->sliceFrac[3];
    if (prefs->viewRadiological) frac[1] = 1.0 - frac[1]; //test
    int result = 0; //not in section
    if (prefs->displayModeGL == GL_2D_CORONAL) {
        frac[1] =  float(x)/prefs->scrnDim[1];
        frac[3] =  float(y)/prefs->scrnDim[3];
    } else if (prefs->displayModeGL == GL_2D_SAGITTAL) {
            frac[2] =  float(x)/prefs->scrnDim[2];
            frac[3] =  float(y)/prefs->scrnDim[3];
    } else if (prefs->scrnWideLayout) {
        if (x < prefs->scrnDim[1]) {
            frac[1] =  float(x)/prefs->scrnDim[1];
            frac[2] =  float(y)/prefs->scrnDim[2];
            result = 3; //axial slice (click somewhere in 3rd [head/foot] dimension)
        } else if ( x < (2* prefs->scrnDim[1])) {
            frac[1] =  float(x-prefs->scrnDim[1])/prefs->scrnDim[1];
            frac[3] =  float(y)/prefs->scrnDim[3];
            result = 2; //coronal slice
        } else if (x < ((2* prefs->scrnDim[1]) +(prefs->scrnDim[2])) ) {
            frac[2] =  float(x-prefs->scrnDim[1]-prefs->scrnDim[1])/prefs->scrnDim[2];
            frac[3] =  float(y)/prefs->scrnDim[3];
            result = 1; //Sagittal slice (click somewhere in 1st [left/right] dimension)
        } else if (( x < (prefs->renderLeft+prefs->renderWid)) && (y < prefs->renderHt)) {
            return 0; //in rendering
        } else
            return -1; //blank region
    } else {
        if (x < prefs->scrnDim[1]) {
            frac[1] =  float(x)/prefs->scrnDim[1];
            if (y < prefs->scrnDim[2]) {
                frac[2] =  float(y)/prefs->scrnDim[2];
                result = 2; //coronal slice (click somewhere in 2nd [anterior/posterior] dimension)
            } else if (y < (prefs->scrnDim[2]+prefs->scrnDim[3])) {
                frac[3] =  float(y-prefs->scrnDim[2])/prefs->scrnDim[3];
                result = 3; //axial slice (click somewhere in 3rd [head/foot] dimension)
            } else {
                return -1; //blank region
            }
        } else if ((x < (prefs->scrnDim[1]+prefs->scrnDim[2]) ) && ((y >= prefs->scrnDim[2]) && (y < (prefs->scrnDim[2]+prefs->scrnDim[3])) )) {
            //NSLog(@"Sagittal");
            frac[2] =  float(x-prefs->scrnDim[1])/prefs->scrnDim[2];
            frac[3] =  float(y-prefs->scrnDim[2])/prefs->scrnDim[3];
            result = 1; //Sagittal slice (click somewhere in 1st [left/right] dimension)
        } else if (( x < (prefs->renderLeft+prefs->renderWid)) && (y < prefs->renderHt)) {
            return 0; //on rendering
        } else
            return -1; //blank region
    }
    if ((frac[1] < 0.0) || (frac[1] > 1.0) || (frac[2] < 0.0) || (frac[2] > 1.0) || (frac[3] < 0.0) || (frac[3] > 1.0)) return -1;
    frac2slice (frac, prefs); //set tempSliceVox
    if (!adjustView) return result;
        if (prefs->viewRadiological) frac[1] = 1.0 - frac[1];//2015
    //frac2mm(frac, prefs, false);
    frac2mm(frac, prefs, true);
    NSDictionary *dict;
    dict = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:prefs->mm[1]], @"x",
            [NSNumber numberWithFloat:prefs->mm[2]], @"y",
            [NSNumber numberWithFloat:prefs->mm[3]], @"z",
            nil]; //precision of prefs->mm type, e.g. numberWithDouble
    [[NSNotificationCenter defaultCenter] postNotificationName:@"niiChanged" object:nil userInfo:dict];
    //NSValue *wrapper = [NSValue valueWithPoint: xy];
    //NSValue *wrapper = [NSValue valueWithPoint: xy];
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"NoteFromOne" object:wrapper];
    prefs->force_refreshGL = true;
    return result;
}

-(bool) setRightMouseUp: (int) x Y: (int) y;
{
    if ((prefs->mouseDownX) < 0) return FALSE;
    if (fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) return FALSE;
    prefs->mouseX = x;
    prefs->mouseY = y;
    if ((prefs->mouseDownX == prefs->mouseX) && (prefs->mouseDownY == prefs->mouseY)) return FALSE;
    int sectionDown = sectionNumber(prefs->mouseDownX, prefs->mouseDownY, false, prefs);
    int sliceVox[4];
    for (int j = 1; j < 4; j++)
        sliceVox[j] = prefs->tempSliceVox[j];
    int sectionUp = sectionNumber(prefs->mouseX, prefs->mouseY, false, prefs);
    if ((sectionDown == 0) ||(sectionDown != sectionUp) ) return FALSE; //exit if click on render or dragged across different views
    //NSLog(@"x %d..%d, y %d..%d",prefs->mouseDownX, prefs->mouseX, prefs->mouseDownY, prefs->mouseY);
    int sliceVoxHi[4];
    for (int j = 1; j < 4; j++) {
        sliceVoxHi[j] = prefs->tempSliceVox[j];
        if (sliceVoxHi[j] < sliceVox[j]) {
            int swap = sliceVoxHi[j];
            sliceVoxHi[j] = sliceVox[j];
            sliceVox[j] = swap;
        } //set order
    } //for each dimension
    //NSLog(@"x=%d..%d, y=%d..%d, z=%d..%d",sliceVox[1], sliceVoxHi[1], sliceVox[2], sliceVoxHi[2],sliceVox[3], sliceVoxHi[3]);
    double mn = INFINITY;
    double mx = -INFINITY;
    long long vol = prefs->numVox3D * (prefs->currentVolume-1);
    for (int z = sliceVox[3]; z <= sliceVoxHi[3]; z++) {
        long long slice = (z*prefs->voxelDim[1]*prefs->voxelDim[2])+ vol;
        for (int y = sliceVox[2]; y <= sliceVoxHi[2]; y++) {
            long long row = slice+(y*prefs->voxelDim[1]);
                for (int x = sliceVox[1]; x <= sliceVoxHi[1]; x++) {
                    double v = getVoxelIntensity(row+x, fslio);
                    if (v > mx) mx = v;
                    if (v < mn) mn = v;
                } //for z
        } //for y
    } //for z
    if ((mn == -INFINITY) || (mx == INFINITY) ) return FALSE;
    if (mn == mx ) return FALSE;
    //NSLog(@"x=%d..%d, y=%d..%d, z=%d..%d intensity %f..%f",sliceVox[1], sliceVoxHi[1], sliceVox[2], sliceVoxHi[2],sliceVox[3], sliceVoxHi[3], mn, mx);
    prefs->viewMin = mn;
    prefs->viewMax = mx;
    prefs->force_recalcGL = true;
    prefs->force_refreshGL = true;
    return TRUE;
   //[[NSNotificationCenter defaultCenter] postNotificationName:@"niiUpdate" object:self userInfo:nil];
}

int isInSection (int x, int y, bool adjustView, NII_PREFS* prefs, FSLIO* fslio)
{
#ifdef NII_IMG_RENDER //defined in nii_definetypes.h
    if (prefs->displayModeGL == GL_3D_ONLY) return 0;
#endif
    prefs->updatedTimeline = (prefs->numVolumes > 1); //for multivolume data, the user should refresh timeline at their convenience....
    int result = sectionNumber(x, y, adjustView, prefs);
    if (!result) return result;
    getIntensity(prefs, fslio);
    return result;
}

-(void) changeClipDepth: (float) x; {
    if (x == 0) return;
    [self setClip: prefs->clipAzimuth Elev: prefs->clipElevation Depth: prefs->clipDepth+x];
}

- (void) changeClipPlane: (int) x Y: (int) y;
{
    if (self.is2D) return;
    if (x < 0)
        prefs->clipAzimuth = prefs->clipAzimuth +5;
    if (x > 0)
        prefs->clipAzimuth = prefs->clipAzimuth - 5;
    if (y > 0)
        prefs->clipElevation = prefs->clipElevation+5;
    if (y < 0)
        prefs->clipElevation = prefs->clipElevation - 5;
    if (prefs->clipElevation < -360)
        prefs->clipElevation = prefs->clipElevation + 360;
    if (prefs->clipElevation > 360)
        prefs->clipElevation = prefs->clipElevation - 360;
/*    if (prefs->clipElevation < -90)
        prefs->clipElevation = -90;
    if (prefs->clipElevation > 90)
        prefs->clipElevation = 90;*/
    prefs->force_refreshGL = true;
    //NSLog(@"%d %d Change clip %d %d",x, y, prefs->clipAzimuth,  prefs->clipElevation);
    
}

-(bool) magnifyRender: (float) delta;
{
    //NSLog(@"swipe %g",delta);
    
    if ((delta == 0.0) || (isInSection(prefs->mouseX,prefs->mouseY, FALSE, prefs, fslio))) return false; //not for 2D slices, only rendering
    //NSLog(@"magnifyRender %g",delta);
    float dx = prefs->renderDistance;
    const float kMinRender = 0.5;
    const float kMaxRender = 5.0;
    const float kStepRender = 0.1;
    
    if (delta < 0)
        dx -= kStepRender;
    else
        dx += kStepRender;
    if (dx < kMinRender) dx = kMinRender;
    if (dx > kMaxRender) dx = kMaxRender;
    
    prefs->renderDistance = dx;
    //NSLog(@"magnifyRender %g",dx);
    prefs->force_refreshGL = true;
    return true;
}

/*-(bool) doSwipe: (float) x Y: (int) y; {
    if ((x == 0.0) && (x == 0.0)) return false;
    if  (isInSection(prefs->mouseX,prefs->mouseY, FALSE, prefs, fslio)) return false; //not for 2D slices, only rendering
    [self changeClipPlane: x Y: y];
    return true;

}*/

-(void) setRightMouseDragXY: (int) x Y: (int) y isMag: (bool) mag isSwipe: (bool) swipe;
//-(void) setRightMouseDragY: (int) y isMag: (bool) mag isSwipe: (bool) swipe;
{
    int dx = prefs->mouseX - x;
    int dy = prefs->mouseY - y;
    if ((dy == 0) && (dx == 0) ) return;
    if ((!self.is2D)  && (!isInSection(prefs->mouseX,y, FALSE, prefs, fslio))) {
        if ((mag) && (dy != 0))
                [self magnifyRender: dy];
        else if (swipe)
            //[self doSwipe: x Y: y];
            [self changeClipPlane: dx Y: -dy];
        else if  (dy != 0)
            [self changeClipDepth : dy*5];
    }
    prefs->mouseY = y;
    prefs->mouseX = x;
}


/*-(void) setRightMouseDragX: (int) x;
{
    int dxDown = abs(prefs->mouseDownX - x); //at least 3 voxels vertical to trigger effect
    int dx = x - prefs->mouseX; //we will use a 3 voxel tolerance before making a change
    if ((dxDown > 8) && (dx != 0) && (!self.is2D)  && (!isInSection(x,prefs->mouseY, FALSE, prefs, fslio)))
        [self magnifyRender: dx];
    prefs->mouseX = x;
}*/
/*-(void) setRightMouseDrag: (int) x Y: (int) y;
{
    if (isInSection(x,y, FALSE, prefs, fslio)) { //user clicked in 2D section
        prefs->mouseX = x;
        prefs->mouseY = y;
        return;
    }
#ifdef NII_IMG_RENDER //defined in nii_definetypes.h
    if (self.is2D) return;
    [self changeClipDepth : (x - prefs->mouseX)];
    [self magnifyRender: (y - prefs->mouseY)];
    prefs->mouseX = x;
    prefs->mouseY = y;
    
    //NSLog(@"nii_img right-drag %d %d", prefs->clipAzimuth, prefs->clipElevation);
#endif
}*/

-(void) setSwipe: (float) x Y: (float) y;
{
    //NSLog(@"swipe %g %g",x,y);
    if (!isInSection(prefs->mouseX,prefs->mouseY, FALSE, prefs, fslio)) {
        if (x > 0)
            [self changeClipDepth: -25]; // prefs->clipDepth = prefs->clipDepth - 25;
        else if (x < 0)
            [self changeClipDepth: +25]; //prefs->clipDepth = prefs->clipDepth + 25;
        
        //NSLog(@"new clip %d", prefs->clipDepth);
        [self setClip: prefs->clipAzimuth Elev: prefs->clipElevation Depth: prefs->clipDepth];
        //[self changeClipPlane: x Y:  y];
        
        return; //only for 2D slices, not rendering
        
    }if (prefs->numVolumes > 1) {
        //if (isInSection(prefs->mouseX,prefs->mouseY, FALSE, prefs, fslio)) {
            //NSLog(@"swipe %d %d",prefs->mouseX,prefs->mouseY);
            int v =prefs->currentVolume;
            if (x > 0)
                v ++;
            else
                v--;
            [self setVolume: v];
        //}
    }
}


-(void) setMagnify: (float) delta;
{
    [self magnifyRender : -delta];
}

-(bool) setScrollWheel:  (float) x Y: (float) delta;
{
    //NSLog(@" scroll %d",  delta);
    if ((x == 0) && (delta == 0)) return false; //nothing to do
    int deltaDx = 1;
    if (delta < 0) deltaDx = -1;
    switch (prefs->displayModeGL) {
        case   GL_2D_AXIAL:
            if (delta == 0) return false;
            [self  changeXYZvoxel:0 Y: 0 Z: deltaDx];
            return true;
        case  GL_2D_CORONAL:
            if (delta == 0) return false;
            [self  changeXYZvoxel:0 Y: deltaDx Z: 0];
            return true;
        case   GL_2D_SAGITTAL:
            if (delta == 0) return false;
            [self  changeXYZvoxel:deltaDx Y: 0 Z: 0];
            return true;
    }
    int numOverlay = 0;
    for (int i = 0; i < MAX_OVERLAY; i++)
        if (prefs->overlays[i].datatype != DT_NONE) numOverlay++; //filled slot
    int sect = sectionNumber(prefs->mouseX, prefs->mouseY, FALSE, prefs);
    if ((sect <1) || (sect >3) || ((prefs->numVolumes < 2) == (numOverlay == 0))) //not on one of the canonical slices - adjust rendering
    {
        [self changeClipPlane: x Y: delta];
        //prefs->clipDepth = prefs->clipDepth - (5* delta);
        //[self setClip: prefs->clipAzimuth Elev: prefs->clipElevation Depth: prefs->clipDepth];
        return true;
    }
    if (prefs->numVolumes > 1) {
        int v =prefs->currentVolume;
        if (delta > 0)
            v ++;
        else
            v--;
        [self setVolume: v];
        return true;
    }
    //scroll wheel over 2D slices with overlay - adjust opacity
    float startFrac = prefs->overlayFrac;
    if (delta > 0)
        prefs->overlayFrac = prefs->overlayFrac+0.1;
    else
        prefs->overlayFrac = prefs->overlayFrac-0.1;
    if (prefs->overlayFrac > 1.1)
        prefs->overlayFrac = 1.1; //1.1 mean additive
    if (prefs->overlayFrac < 0.1)
        prefs->overlayFrac = 0.1;
    if (startFrac == prefs->overlayFrac) return false;
    prefs->force_recalcGL = true;
    prefs->force_refreshGL = true;
    return true;
}


-(void) setMouseDrag: (int) x Y: (int) y;
{
    if (isInSection(x,y, TRUE, prefs, fslio)) return; //user clicked in 2D section
    #ifdef NII_IMG_RENDER //defined in nii_definetypes.h
    if (self.is2D) return;
    //if (prefs->displayModeGL == GL_2D_ONLY) return;
    [self setAzimElevInc: (x-prefs->mouseX) Elev: (prefs->mouseY-y)];
    prefs->mouseX = x;
    prefs->mouseY = y;
    prefs->force_refreshGL = true;
    #endif
}

-(void) setMouseDown: (int) x Y: (int) y;
{
    prefs->mouseDownX = x;
    prefs->mouseDownY = y;
    prefs->mouseX = x;
    prefs->mouseY = y;
    isInSection(x,y, TRUE, prefs, fslio);
}

void rescale16to8bit (void *data, size_t nvox, size_t voxOffset, int datatype, THIS_UINT8 *img8bit)
{
    if (datatype != NIFTI_TYPE_INT16) {
        NSLog(@"16-bit only!");
        return;
    }
    THIS_UINT8 *ptr = img8bit;
    size_t start = voxOffset;
    size_t end = voxOffset + nvox;
    THIS_INT16 *raw16 = (THIS_INT16 *) data;
    THIS_INT16 raw;
    for (size_t i = start; i < end; i++) {
        raw = raw16[i];
        if (raw == 0)
            *ptr++ = 0;
        else
            *ptr++ = ((raw-1) % 100)+1;
    } //for each voxel
}

void rescale8bit (void *data, size_t nvox, size_t voxOffset, int datatype, double minRaw, double maxRaw, THIS_UINT8 *img8bit)
//provided input volume data with numvoxels each of datatype, a scaled 8 bit image is generated
//WARNING: you must call subsequently call     free(img8bit);
{
    //img8bit = (THIS_UINT8 *) m alloc(nvox);
    size_t start = voxOffset;
    size_t end = voxOffset + nvox;
    THIS_UINT8 *ptr = img8bit;
    double slope = 255.0/(maxRaw-minRaw);
    if ( datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *raw8 = (THIS_UINT8 *) data;
        //create lookup table to convert raw 8 bit data to scaled 8 bit data
        const long kBins8 = 256; //for 8 bit data, 256 bins provide complete coverage
        THIS_UINT8 bins[kBins8];
        for (long k = 0; k < kBins8; k++) {
            if (k < minRaw)
                bins[k] = 0;
            else if (k > maxRaw)
                bins[k] =255;
            else
                bins[k] = (k-minRaw)*slope;
        } //for each bin
        // unfortunately XCode 5's clang does not support openMP... #pragma omp parallel for
        for (size_t i = start; i < end; i++)
            *ptr++ =  bins[raw8[i]];
    } else if (datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *raw16 = (THIS_INT16 *) data;
        THIS_INT16 raw;
        for (size_t i = start; i < end; i++) {
            raw = raw16[i];
            if (raw < minRaw)
                *ptr++ = 0;
            else if (raw > maxRaw)
                *ptr++ =255;
            else
                *ptr++ = (raw-minRaw)*slope;
        } //for each voxel
    } else if (datatype == NIFTI_TYPE_RGBA32) {
        //nothing to do
    } else if (datatype == NIFTI_TYPE_FLOAT32 ) { //666 TRUE
        SCALED_IMGDATA *rawf = (SCALED_IMGDATA *) data;
        SCALED_IMGDATA raw;
        for (size_t i = start; i < end; i++) {
            raw = rawf[i];
            if (raw < minRaw)
                *ptr++ = 0;
            else if (raw > maxRaw)
                *ptr++ =255;
            else
                *ptr++ = (raw-minRaw)*slope;
        }
    } else
        NSLog(@"makergb: Unsupported data type!");
}

void computeBlendAdditive (void* back, void* over, size_t nvox)
{
    THIS_UINT8 *backPtr = (THIS_UINT8 *) back;
    THIS_UINT8 *overPtr = (THIS_UINT8 *) over;
    for (size_t vx=0; vx<(nvox*4); vx++) {
        if (*overPtr > *backPtr) *backPtr = *overPtr;
        backPtr++; overPtr++;
    }
}

void computeBlend (void* back, void* over, size_t nvox, float overlayFraction)
{
    if ((overlayFraction < 0) || (overlayFraction > 1.0)  ) {
        computeBlendAdditive(back, over, nvox);
        return;
    }
    int overFrac = round(256*overlayFraction);
    int backFrac = (256-overFrac);
    THIS_UINT8 *backPtr = (THIS_UINT8 *) back;
    THIS_UINT8 *overPtr = (THIS_UINT8 *) over;
    uint32_t *over32Ptr = (uint32_t *) over;
    for (size_t vx=0; vx<(nvox); vx++) {
        if ( *over32Ptr++ > 0) {
            *backPtr = ((*overPtr * overFrac)+(*backPtr * backFrac) ) >>8 ;
            backPtr++; overPtr++;
            *backPtr = ((*overPtr * overFrac)+(*backPtr * backFrac) ) >>8;
            backPtr++; overPtr++;
            *backPtr = ((*overPtr * overFrac)+(*backPtr * backFrac) ) >> 8;
            backPtr++; overPtr++;
            //alpha channel based on background only...
            backPtr++; overPtr++;
        } else {
            backPtr+= 4;
            overPtr+= 4;
        }
    } //for each voxel
}

void computeBlendEither (void* back, void* over, size_t nvox, float overlayFraction)
{
    if ((overlayFraction < 0)  || (overlayFraction > 1.0)) {
        computeBlendAdditive(back, over, nvox);
        return;
    }
    int overFrac = round(256*overlayFraction);
    int backFrac = (256-overFrac);
    THIS_UINT8 *backPtr = (THIS_UINT8 *) back;
    THIS_UINT8 *overPtr = (THIS_UINT8 *) over;
    uint32_t *back32Ptr = (uint32_t *) back;
    uint32_t *over32Ptr = (uint32_t *) over;
    for (size_t vx=0; vx<(nvox); vx++) {
        if (( *over32Ptr > 0) && ( *back32Ptr > 0) ) {
            *backPtr = ((*overPtr * overFrac)+(*backPtr * backFrac) ) >>8 ;
            backPtr++; overPtr++;
            *backPtr = ((*overPtr * overFrac)+(*backPtr * backFrac) ) >>8;
            backPtr++; overPtr++;
            *backPtr = ((*overPtr * overFrac)+(*backPtr * backFrac) )>> 8;
            backPtr++; overPtr++;
            //alpha channel based on background only...
            backPtr++; overPtr++;
        } else if ( *over32Ptr > 0) {
            *backPtr = *overPtr;
            backPtr++; overPtr++;
            *backPtr = *overPtr;
            backPtr++; overPtr++;
            *backPtr = *overPtr ;
            backPtr++; overPtr++;
            *backPtr = *overPtr ;
            backPtr++; overPtr++;
        }else {
            backPtr+= 4;
            overPtr+= 4;
        }
        back32Ptr++; over32Ptr++;
    }
}

#ifndef MY_USE_GLSL_FOR_GRADIENTS //defined in nii_render.h

void smoothVol32(THIS_INT32 *img, int Xdim, int Ydim, int Zdim) {
    //roughly emulutes a tight Gaussian blur, wraps images L/R, A/P
    //image intensity increased 729 times (9*9*9), so 8-bit input returns as 32-bit, maximum value input = 255, output = 185895 so we use ~18 bits
    //http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    if ((Xdim < 5) || (Ydim < 5) || (Zdim < 5)) return;
    int nvox = Xdim * Ydim * Zdim;
    THIS_INT32 *sum = new THIS_INT32[nvox]();
    memcpy (sum, img, nvox*sizeof(THIS_INT32)); //memcpy(destination, source)
    //sum with left/right neighbors
    for (int i = 2; i < (nvox-2); i++)
        img[i] = sum[i-1]+ (sum[i] << 1)+ sum[i+1];// left+2*center+right
    //int Xdim2 = Xdim * 2;
    //sum result with anterior/posterior neighbors
    for (int i = Xdim; i < (nvox-Xdim-1); i++)
        sum[i] = img[i-Xdim] + (img[i] << 1) + img[i+Xdim];// anterior+2*center+posterior
    //sum with superior/inferior neighbors, generate output
    int sliceSz = Xdim*Ydim;
    //int sliceSz2 = sliceSz * 2;
    for (int i = sliceSz; i < (nvox-sliceSz-1); i++)
        img[i] = (sum[i-sliceSz] + (sum[i] << 1)+ sum[i+sliceSz]) >> 4 ; //shift right AT LEAST 3
    delete[] sum;
}

void computeGradientsCPU (NII_PREFS* prefs, uint32_t *img) {
    if ((prefs->voxelDim[1] < 5) || (prefs->voxelDim[2]<5) || (prefs->voxelDim[3] < 5)) return;
    int nvox = prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3];
    #ifdef MY_DEBUG //from nii_io.h
    NSDate *methodStart = [NSDate date];
    #endif
    THIS_INT32 *img32bit = (THIS_INT32 *) malloc(nvox*sizeof(THIS_INT32));
    for (int i = 0; i < nvox; i++) img32bit[i] = img[i] & 0xFF;
    smoothVol32(img32bit, prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3]);
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"smooth = %f", [[NSDate date] timeIntervalSinceDate:methodStart]);
    methodStart = [NSDate date];
    #endif
    THIS_INT32 *mag = new THIS_INT32[nvox](); //*4 as RGBA
    int I;
    THIS_INT32 Xm,Ym,Zm,aXm,aYm,aZm, mx;
    int colSz = prefs->voxelDim[1];
    int sliceSz = prefs->voxelDim[1]*prefs->voxelDim[2]; //each plane is X*Y voxels
    for (int Z = 1; Z < prefs->voxelDim[3] - 2; Z++) {   //for X,Y,Z dimensions indexed from zero, so := 1 gives 1 voxel border
        for (int Y = 1; Y < prefs->voxelDim[2] - 2; Y++) {   //for X,Y,Z dimensions indexed from zero, so := 1 gives 1 voxel border
            int Index = (Z * prefs->voxelDim[1]*prefs->voxelDim[2]) + (Y * prefs->voxelDim[1]);
            for (int X = 1; X < prefs->voxelDim[1] - 2; X++) {   //for X,Y,Z dimensions indexed from zero, so := 1 gives 1 voxel border
                I = Index+X;
                if (img32bit[I] > 0) { //intensity less than threshold: make invisible
                    Xm = img32bit[I-1]-img32bit[I+1];
                    Ym = img32bit[I-colSz]-img32bit[I+colSz];
                    Zm = img32bit[I-sliceSz]-img32bit[I+sliceSz];
                    aXm = abs(Xm);
                    aYm = abs(Ym);
                    aZm = abs(Zm);
                    mx = aXm;
                    if (aYm > mx) mx = aYm;
                    if (aZm > mx) mx = aZm;
                    if (mx > 0) {
                        mag[I] = aXm+aYm+aZm;//gradient magnitude = quick, precise would be sqrt(Xm^2+Ym^2+Zm^2)
                        Xm = ((255+((253*Xm)/mx))>>1);
                        Ym = ((255+((253*Ym)/mx))>>1);
                        Zm = ((255+((253*Zm)/mx))>>1);
                        img[I] = char(Xm) + (char(Ym) << 8) + (char(Zm) << 16);
                    }
                } //img32bit[I] > 0
                //data[I] = CentralDifference (img32bit, colSz, sliceSz, I, &mag[I]);
            }//X
        }//Y
    }//Z
    free(img32bit);
    //methodStart = [NSDate date];
    //normalize magnitude
    mx = mag[0];
    for (int i = 0; i < nvox; i++)
        if (mag[i] > mx) mx = mag[i];
    if (mx > 0 ) {
        float scale = 255.0f/mx; //we will save as a byte with range 0..255
        for (int i = 0; i < nvox; i++)
            img[i] = img[i] + ((char)((mag[i])*scale) << 24);
    }
    delete[] mag;
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"sobel = %f", [[NSDate date] timeIntervalSinceDate:methodStart]);
    #endif
}
#endif

void computeGradients (NII_PREFS* prefs, uint32_t *img, bool isOverlay) {
    if ((prefs->voxelDim[1] < 5) || (prefs->voxelDim[2]<5) || (prefs->voxelDim[3] < 5)) return;

    //if ((prefs->numOverlay > 0) && ~ isOverlay) return;
#ifdef MY_USE_GLSL_FOR_GRADIENTS //defined in nii_render.h
    //just copy raw texture, and process this
    if (isOverlay)
        prefs->glslUpdateGradientsOverlay = true;
    else
        prefs->glslUpdateGradientsBG = true;
#else
    computeGradientsCPU(prefs, img);
#endif
    if (isOverlay)
        prefs->gradientOverlay3D = bindSubGL(prefs, img, prefs->gradientOverlay3D);
    else
        prefs->gradientTexture3D = bindSubGL(prefs, img, prefs->gradientTexture3D);
}

void blendOverlays(NII_PREFS* prefs, uint32_t *data)
{
    prefs->numOverlay = 0;
    if (prefs->overlayFrac == 0) return; //overlays do not contribute to image
    //NSLog(@"test %d ", ((255*0) + (255*255)) >> 8);
    int numOverlay = 0;
    for (int i = 0; i < MAX_OVERLAY; i++)
        if (prefs->overlays[i].datatype != DT_NONE) numOverlay++; //filled slot
    if (numOverlay == 0) return; //no overlays
    prefs->numOverlay = numOverlay;
    size_t nvox = prefs->numVox3D; //voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3];
    //uint32_t clearclr = makeRGBA(prefs->BackColor[0]*255, prefs->BackColor[1]*255,prefs->BackColor[2]*255,0);
    uint32_t *overdata = new uint32_t[nvox]; // *4 as RGBA
    numOverlay = 0;
    for (int i = 0; i < MAX_OVERLAY; i++) {
        if (prefs->overlays[i].datatype != DT_NONE) {
            numOverlay++;
            tRGBAlut lut;
            createlut(prefs->overlays[i].colorScheme, lut, prefs->overlays[i].lut_bias);
            createlut(prefs->overlays[i].colorScheme, prefs->overlays[i].lut, prefs->overlays[i].lut_bias);
            double minRaw = nii_cal2raw(prefs->overlays[i].scl_inter, prefs->overlays[i].scl_slope, prefs->overlays[i].viewMin);
            double maxRaw = nii_cal2raw(prefs->overlays[i].scl_inter, prefs->overlays[i].scl_slope, prefs->overlays[i].viewMax);
            if ((minRaw <0.0) && (maxRaw < 0.0)) {
                //reverse polarity so more extreme values look brighter
                for (int c = 0; c < 256; c++)
                    lut[255-c] = prefs->overlays[i].lut[c];
                for (int c = 0; c < 256; c++)
                    prefs->overlays[i].lut[c] = lut[c];
            }
            THIS_UINT8 *img8bit = (THIS_UINT8 *) malloc(nvox);
            rescale8bit (prefs->overlays[i].data, nvox, 0, prefs->overlays[i].datatype, minRaw, maxRaw, img8bit);
            if (numOverlay == 1) { //first overlay defines colors...
                uint32_t *ptr = overdata;
                for (size_t v = 0; v < nvox; v++)
                    *ptr++ = lut[ img8bit[v]];
            } else { //additional overlay
                uint32_t *overdataAdd = new uint32_t[nvox]; // *4 as RGBA
                uint32_t *ptrAdd = overdataAdd;
                for (size_t v = 0; v < nvox; v++)
                    *ptrAdd++ = lut[img8bit[v]];
                //computeBlendEither(overdata, overdataAdd, nvox, prefs->overlayFrac);
                computeBlendEither(overdata, overdataAdd, nvox, 0.5);
                delete[] overdataAdd;//2014 free(overdataAdd);
            }
            free(img8bit);
        }
    }
    computeBlend(data, overdata, nvox, prefs->overlayFrac);
    if (prefs->advancedRender) {
        prefs->intensityOverlay3D = bindSubGL(prefs, overdata, prefs->intensityOverlay3D);
        //THIS_UINT8 *img8bit = (THIS_UINT8 *) malloc(nvox);
        //for (size_t v = 0; v < nvox; v++)
        //    img8bit[v] = overdata[v] & 0xFF; // (data[v] >> 24) & 0xFF
        //computeGradients ( prefs, img8bit, overdata, true);
        //free(img8bit);
        computeGradients ( prefs, overdata,  true);
    }
    delete[] overdata;//2014 free(overdata);
}


void recalcSubGL(NII_PREFS* prefs, THIS_UINT8 *img8bit, tRGBAlut lut)
//makes a volume with size Sz1*kSz2*kSz3 voxels
{
    //glDeleteTextures(1,&prefs->intensityTexture3D);
    uint32_t *data = new uint32_t[prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3]]; //*4 as RGBA
    uint32_t *ptr = data;
    for (size_t i = 0; i < (prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3]); i++) 
        *ptr++ = lut[img8bit[i]];
        //clock_t start = clock();
#ifdef MY_DEBUG //from nii_io.h
    NSDate *methodStart = [NSDate date];
#endif
    blendOverlays(prefs, data);
#ifdef MY_DEBUG //from nii_io.h
    NSLog(@"blendSec = %f", [[NSDate date] timeIntervalSinceDate:methodStart]);
#endif
    prefs->intensityTexture3D = bindSubGL(prefs, data, prefs->intensityTexture3D);

    //if (prefs->advancedRender) computeGradients ( prefs, img8bit, data,false);
    if (prefs->advancedRender)
            computeGradients ( prefs, data,false);
     else {
        if (prefs->gradientTexture3D != 0) glDeleteTextures(1,&prefs->gradientTexture3D);
        prefs->gradientTexture3D = 0;
        if (prefs->gradientOverlay3D != 0) glDeleteTextures(1,&prefs->gradientOverlay3D);
        prefs->gradientOverlay3D = 0;
        if (prefs->intensityOverlay3D != 0) glDeleteTextures(1,&prefs->intensityOverlay3D);
        prefs->intensityOverlay3D = 0;
    }
    delete[] data;
    //check this worked...
    //glGetTexLevelParameteriv(GL_PROXY_TEXTURE_3D, 0, GL_TEXTURE_WIDTH, &gli);
    //    if (gli < 1) {
    //        NSLog(@"Your video card is unable to load an image that is this large");
    //        return(EXIT_FAILURE);
    //    }
    //printf("handle %d\n",handle);
}

void rescaleRGBA(NII_PREFS* prefs, uint32_t *rawdata)
{
    //create look up table...
    long lut[256];
    int min = round(prefs->viewMin);
    int max = round(prefs->viewMax);
    if (min > max) {
        min = prefs->viewMax;
        max = prefs->viewMin;
    }
    #define MY_GAIN //#undef MY_GAIN //
    #ifdef MY_GAIN //Ken Perlin’s bias http://blog.demofox.org/2012/09/24/bias-and-gain-are-your-friend/
    float bias = 0.5;
    if ((prefs->fullMax > prefs->fullMin) && (max > min))
        bias = 0.5 * ((max-min)/ (prefs->fullMax - prefs->fullMin));
    bias = 1.0 - bias;
    if (bias <= 0.0) bias = 0.001;
    if (bias >= 1.0) bias = 0.999;
    for (int i = 0; i < 256; i++) {
        float v = (float)i/255.0;
        v = (v/ ((((1/bias) - 2)*(1 - v))+1));
        //if (i == 32) NSLog(@"-bias %g in %d out %g", bias, i, v);
        if (v > 1.0) v = 1.0;
        if (v < 0.0) v = 0.0;
        //if (i == 32) NSLog(@"bias %g in %d out %g", bias, i, round(v*255.0));
        lut[i] = round(255.0 * v);
    } //for all indices
    #else
    float slope = 255.0f/(max - min);
    for (int i = 0; i < 256; i++) {
        if (i <= min)
            lut[i] = 0;
        else if (i >= max)
            lut[i] = 255;
        else
            lut[i] = round((i-min)*slope);
    } //for all indices
    #endif
    //rescale volume with table...
    size_t nbytes = prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3]*4;//*4 as RGBA
    THIS_UINT8 *rawptr = (THIS_UINT8 *)rawdata;
    THIS_UINT8 *data = (THIS_UINT8 *) malloc(nbytes);
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"nii_img 4 malloc size %ld",nbytes);
    #endif
    THIS_UINT8 *ptr = data;
    //for (size_t i = 0; i < nbytes; i++)
    //    *ptr++ = lut[ *rawptr++];
    //for (size_t i = 0; i < nbytes; i++)
    //    *ptr++ = rand() % 256;
    nbytes = prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3];
    for (size_t i = 0; i < nbytes; i++) {
        *ptr++ = lut[ *rawptr++];//scale red
        *ptr++ = lut[ *rawptr++];//scale green
        *ptr++ = lut[ *rawptr++];//scale blue
        *ptr++ = *rawptr++; //leave alpha unchanged...
    }
  glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3], 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
  
delete[] data;
}

GLuint recalcSubRGBA(NII_PREFS* prefs, uint32_t *data, GLuint oldHandle)
{
    GLuint handle;
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (oldHandle != 0) glDeleteTextures(1,&oldHandle);
    glGenTextures(1, &handle);
    glBindTexture(GL_TEXTURE_3D, handle);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);//?
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);//?
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);//?
    
    if ((fabs(prefs->viewMin- 0.0) < 0.01) && (fabs(prefs->viewMax-255)<0.01 ) ) //no need to rescale image brightness/contrast
        glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3], 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    else
        rescaleRGBA(prefs, data);
    return handle;
}

int recalcGL(FSLIO* fslio, NII_PREFS* prefs)
{
//    if ((fslio->niftiptr->dim[0] < 3) || (fslio->niftiptr->dim[0] >4)) {
//        printf("nii_makergb: error only 3D and 4D data supported");
//        return EXIT_FAILURE;
//    }
    if (prefs->numVox3D < 1) {//(fslio->niftiptr->nvox < 1) {
        printf("nii_makergb: voxels not loaded!");
        return EXIT_FAILURE;
    }
     if ((fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) && (fslio->niftiptr->datatype == NIFTI_TYPE_UINT8)) {
        createlutLabel(prefs->colorScheme, prefs->lut,fabs(prefs->viewMax-prefs->viewMin)/100 );
        THIS_UINT8 *raw8 = (THIS_UINT8 *) fslio->niftiptr->data;
        prefs->lut[0] = makeRGBA(255*prefs->backColor[0],255* prefs->backColor[1],255*prefs->backColor[2],0);
         recalcSubGL(prefs,raw8, prefs->lut);
        return EXIT_SUCCESS;
    }
#ifdef MY_DEBUG
    NSDate *methodStart = [NSDate date];
#endif
    if ((fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) &&(fslio->niftiptr->datatype == NIFTI_TYPE_INT16)) {
        createlutLabel(prefs->colorScheme, prefs->lut, fabs(prefs->viewMax-prefs->viewMin)/100 );
        prefs->lut[0] = makeRGBA(255*prefs->backColor[0],255* prefs->backColor[1],255*prefs->backColor[2],0);
        THIS_UINT8 *img8bit = (THIS_UINT8 *) malloc(prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3]);
        size_t volOffset = prefs->currentVolume;
        if ((volOffset < 1) || (volOffset > prefs->numVolumes))
            volOffset = 1;
        volOffset = prefs->numVox3D* (volOffset-1);
        rescale16to8bit(fslio->niftiptr->data, prefs->numVox3D, volOffset, fslio->niftiptr->datatype, img8bit);
        recalcSubGL(prefs,img8bit, prefs->lut);
        free(img8bit);
        return EXIT_SUCCESS;
    }
    createlut(prefs->colorScheme, prefs->lut, prefs->lut_bias);
    prefs->lut[0] = makeRGBA(255*prefs->backColor[0],255* prefs->backColor[1],255*prefs->backColor[2],0);
    #ifdef MY_DEBUG //from nii_io.h
    printf("makergb: volume size %dx%dx%d\n",prefs->voxelDim[1],prefs->voxelDim[2],prefs->voxelDim[3]);
    #endif
    double minRaw = nii_cal2raw(fslio->niftiptr-> scl_inter, fslio->niftiptr-> scl_slope, prefs->viewMin);
    double maxRaw = nii_cal2raw(fslio->niftiptr-> scl_inter, fslio->niftiptr-> scl_slope, prefs->viewMax);
    if (fslio->niftiptr->datatype == DT_RGBA32) {
        uint32_t *data = (uint32_t *) fslio->niftiptr->data;
        prefs->intensityTexture3D = recalcSubRGBA(prefs, data, prefs->intensityTexture3D);
        if (prefs->advancedRender)
            computeGradients ( prefs, data,false);
    } else {
        THIS_UINT8 *img8bit = (THIS_UINT8 *) malloc(prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3]);
        size_t volOffset = prefs->currentVolume;
        if ((volOffset < 1) || (volOffset > prefs->numVolumes))
            volOffset = 1;
        volOffset = prefs->numVox3D* (volOffset-1);
        rescale8bit(fslio->niftiptr->data, prefs->numVox3D, volOffset, fslio->niftiptr->datatype, minRaw, maxRaw, img8bit);
        recalcSubGL(prefs,img8bit, prefs->lut);
        free(img8bit);
    }
#ifdef MY_DEBUG
    NSLog(@"recalcGL_Sec = %f", [[NSDate date] timeIntervalSinceDate:methodStart]);
#endif
    return EXIT_SUCCESS;
}

-(bool) isBackgroundRGB
{
    return (fslio->niftiptr->datatype == DT_RGBA32);
}

bool checkMat (mat44 mat)
//see if Matrix is plausible - each row must have at least one non-zero cell
{
    if ((mat.m[0][0] == 0) && (mat.m[0][1] == 0) && (mat.m[0][2] == 0)) return FALSE;
    if ((mat.m[1][0] == 0) && (mat.m[1][1] == 0) && (mat.m[1][2] == 0)) return FALSE;
    if ((mat.m[2][0] == 0) && (mat.m[2][1] == 0) && (mat.m[2][2] == 0)) return FALSE;
    return TRUE;
}

void fix_sform (FSLIO* fslio)
//ensure matrix in sform is plausible
{
    bool sformOK = checkMat(fslio->niftiptr->sto_xyz);
    if ((sformOK) && (fslio->niftiptr->sform_code != 0)) return; //use original sform....
    bool qformOK = checkMat(fslio->niftiptr->qto_xyz);
    if ((qformOK) && (fslio->niftiptr->qform_code != 0)) { //substitute qform
        fslio->niftiptr->sto_xyz = fslio->niftiptr->qto_xyz;
        fslio->niftiptr->sto_ijk = fslio->niftiptr->qto_ijk;
        return;
    }
    if (sformOK) return; //use sform even though sform_code ==0 !
    //NSLog( @" q-mat %@", matToTextX (fslio->niftiptr->qto_xyz));
    if (qformOK) { //substitute qform even though qform_code ==0 !
        fslio->niftiptr->sto_xyz = fslio->niftiptr->qto_xyz;
        fslio->niftiptr->sto_ijk = fslio->niftiptr->qto_ijk;
        return;
    }
    //now we are getting desperate - lets use 'the "old" way' from nifti1.h
    mat44 m_toxyz;
    LOAD_MAT44(m_toxyz,fslio->niftiptr->pixdim[1],0,0,0, 0, fslio->niftiptr->pixdim[2],0,0, 0,0,fslio->niftiptr->pixdim[3], 0);

    if ((fslio->niftiptr->pixdim[1] ==0) || (fslio->niftiptr->pixdim[2] ==0) || (fslio->niftiptr->pixdim[3] ==0))
        LOAD_MAT44(m_toxyz,1,0,0,0, 0,1,0,0, 0,0,1,0);
        //m_toxyz = setMat44(1,0,0,0, 0,1,0,0, 0,0,1,0);
    mat44 m_toijk = nifti_mat44_inverse( m_toxyz ) ;
    fslio->niftiptr->sto_xyz = m_toxyz;
    fslio->niftiptr->sto_ijk = m_toijk;
}

void nii_setOrthoFSL (FSLIO* f){
    
    if (f->niftiptr->sform_code == NIFTI_XFORM_UNKNOWN) {
        return;
    }
    if (isMat44Canonical( f->niftiptr->sto_xyz)) {
        //NSLog( @" already canonical");
        return;
    }
    //copy fsl header to nifti header
    struct nifti_1_header h;
    for (int i = 0; i < 8; i++) h.dim[i] = f->niftiptr->dim[i];
    for (int i = 0; i < 8; i++) h.pixdim[i] = f->niftiptr->pixdim[i];
    mat2sForm(&h,f->niftiptr->sto_xyz);
    h.datatype = f->niftiptr->datatype ;
    h.sform_code = f->niftiptr->sform_code;
    h.bitpix = f->niftiptr->nbyper * 8;
    unsigned char *imgM = (unsigned char *) f->niftiptr->data;
    nii_setOrtho(imgM,&h);
    //  NSLog(@"%g %g %g",h.srow_x[0],h.srow_x[1],h.srow_x[2]);
    //convert dimensions 1-3 from NIfTI back to FSLIO, also convert spatial transforms (qform & sform)
    f->niftiptr->nx   = f->niftiptr->dim[1] = h.dim[1];
    f->niftiptr->ny   = f->niftiptr->dim[2] = h.dim[2];
    f->niftiptr->nz   = f->niftiptr->dim[3] = h.dim[3];
    f->niftiptr->dx = f->niftiptr->pixdim[1] = h.pixdim[1] ;
    f->niftiptr->dy = f->niftiptr->pixdim[2] = h.pixdim[2] ;
    f->niftiptr->dz = f->niftiptr->pixdim[3] = h.pixdim[3] ;
    f->niftiptr->sto_xyz.m[0][0] = h.srow_x[0] ;
    f->niftiptr->sto_xyz.m[0][1] = h.srow_x[1] ;
    f->niftiptr->sto_xyz.m[0][2] = h.srow_x[2] ;
    f->niftiptr->sto_xyz.m[0][3] = h.srow_x[3] ;
    f->niftiptr->sto_xyz.m[1][0] = h.srow_y[0] ;
    f->niftiptr->sto_xyz.m[1][1] = h.srow_y[1] ;
    f->niftiptr->sto_xyz.m[1][2] = h.srow_y[2] ;
    f->niftiptr->sto_xyz.m[1][3] = h.srow_y[3] ;
    f->niftiptr->sto_xyz.m[2][0] = h.srow_z[0] ;
    f->niftiptr->sto_xyz.m[2][1] = h.srow_z[1] ;
    f->niftiptr->sto_xyz.m[2][2] = h.srow_z[2] ;
    f->niftiptr->sto_xyz.m[2][3] = h.srow_z[3] ;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            f->niftiptr->qto_xyz.m[i][j] = f->niftiptr->sto_xyz.m[i][j];
    f->niftiptr->sto_ijk = nifti_mat44_inverse( f->niftiptr->sto_xyz ) ;
    f->niftiptr->qto_ijk = nifti_mat44_inverse( f->niftiptr->qto_xyz ) ;
}

int nii_setup(FSLIO* fslio, NII_PREFS* prefs)
{
    //NSLog( @" q-mat %@", matToTextX (fslio->niftiptr->qto_xyz));
    fix_sform (fslio);
    prefs->numDtiV = 0;
    prefs->numVox3D = 1;
    for (int dim = 1; dim < 4; dim++)
        if (abs(fslio->niftiptr->dim[dim]) > 1)
            prefs->numVox3D = prefs->numVox3D * fslio->niftiptr->dim[dim];
    prefs->mouseIntensity = 0;
    prefs->mouseDownX = -1; //impossible!
    strcpy( prefs->nii_prefs_fname, "" );
    prefs->numVolumes = 1;
    prefs->currentVolume = 1;
    for (int dim = 4; dim < 8; dim++)
        if (fslio->niftiptr->dim[dim] > 1)
            prefs->numVolumes = prefs->numVolumes * fslio->niftiptr->dim[dim];
    int ret = nii_unify_datatype(fslio); //convert unusual formats to single precision datatype
    if (ret != EXIT_SUCCESS) {
        NSLog(@"nii_unify_datatype failed");
        setLoadDummy(fslio, prefs);
        return EXIT_FAILURE;
    }
    if (prefs->orthoOrient)
        nii_setOrthoFSL (fslio);
    else
        fslio->niftiptr->sform_code = NIFTI_XFORM_UNKNOWN; //unknown orientation, do not place L/R A/P S/I labels
    ret = nii_findrange(fslio, prefs);
    if (ret != EXIT_SUCCESS) return EXIT_FAILURE;
    for (long dim = 1; dim < 4; dim++) {
        prefs->voxelDim[dim] = fslio->niftiptr->dim[dim];
        prefs->fieldOfViewMM[dim] = fabs(fslio->niftiptr->dim[dim]*fslio->niftiptr->pixdim[dim]);
    }
    //NSLog(@"a %f -> %f",prefs->fullMin, prefs->fullMax);

    //NSLog(@"pxDim %g %g %g",fslio->niftiptr->pixdim[1], fslio->niftiptr->pixdim[2], fslio->niftiptr->pixdim[2]);
    //NSLog(@"voxDim %d %d %d",fslio->niftiptr->dim[1], fslio->niftiptr->dim[2], fslio->niftiptr->dim[2]);
    //NSLog(@"fovDim %g %g %g",prefs->fieldOfViewMM[1], prefs->fieldOfViewMM[2], prefs->fieldOfViewMM[3]);
    prefs->sto_ijk = fslio->niftiptr-> sto_ijk;
    prefs->sto_xyz = fslio->niftiptr-> sto_xyz;
    mm2frac (0,0,0, prefs);
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
    return ret;
}

void drawXBar (int lX, int lY, int lW,int lH, float lXFrac, float lYFrac, long Xgap, CGFloat XColor[4])
//draws crosshair that is horizontally at XFrac and Vertically at YFrac
//given box with corner at lX,lY, Width of lW and Height of lH
{
    if (Xgap < 0) return;
    glDisable (GL_TEXTURE_3D);
    glDisable (GL_BLEND);
    //float lYp = (lYFrac * lH);
    //float lXp = (lXFrac * lW);
    int lYp = round(lYFrac * lH);
    int lXp = round(lXFrac * lW);
    //printf("scale %f ht %d pix %f\n",lYFrac,lH, lYp);
    glLineWidth(2.0);
    glColor4f(XColor[0],XColor[1],XColor[2],1.0f);
    glBegin(GL_LINES); //draw crosshairs...
    //bottom vert
    glVertex3f(lX+lXp,  lY, 0.0);
    glVertex3f(lX+lXp, lY+lYp-Xgap, 0.0);
    //left horz
    glVertex3f(lX, lY+lYp, 0.0);
    glVertex3f(lX+lXp-Xgap, lY+lYp, 0.0);
    //top vert
    glVertex3f(lX+lXp,  lY+lYp+Xgap, 0.0);
    glVertex3f(lX+lXp, lY+lH, 0.0);
    //right horz
    glVertex3f(lX+lXp+Xgap, lY+lYp, 0.0);
    glVertex3f(lX+lW, lY+lYp, 0.0);
    glEnd();
}

void drawSagMirror (int lX, int lY, int lW, int lH, double lSlice[4], long Xgap, CGFloat XColor[4])
//Display a SAGITTAL slice at X pixels from left, Y pixels from bottom, W wide, H high, lSlice is 0..1 - fractional slice
// assumes texture bound to OpenGL: glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
{
    glEnable (GL_TEXTURE_3D);
    //glColor3f(1.0f, 1.0f, 1.0f);
    glBegin(GL_QUADS);
        glTexCoord3d (lSlice[1],0,1);
        glVertex2f(lX+lW,lY+lH);
        glTexCoord3d (lSlice[1],0, 0);
        glVertex2f(lX+lW,lY);
        glTexCoord3d (lSlice[1], 1, 0);
        glVertex2f(lX,lY);
        glTexCoord3d (lSlice[1],1, 1);
        glVertex2f(lX,lY+lH);
    glEnd();
    if (Xgap >= 0)
        drawXBar (lX, lY, lW, lH, 1-lSlice[2], lSlice[3], Xgap, XColor);
}

void drawSag (int lX, int lY, int lW, int lH, double lSlice[4], long Xgap, CGFloat XColor[4])
//Display a SAGITTAL slice at X pixels from left, Y pixels from bottom, W wide, H high, lSlice is 0..1 - fractional slice
//  assumes texture bound to OpenGL: glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
{
    glEnable (GL_TEXTURE_3D);
    //glColor3f(1.0f, 1.0f, 1.0f);
    glBegin(GL_QUADS);
        glTexCoord3d (lSlice[1],0,1);
        glVertex2f(lX,lY+lH);
        glTexCoord3d (lSlice[1],0, 0);
        glVertex2f(lX,lY);
        glTexCoord3d (lSlice[1], 1, 0);
        glVertex2f(lX+lW,lY);
        glTexCoord3d (lSlice[1],1, 1);
        glVertex2f(lX+lW,lY+lH);
    glEnd();
    if (Xgap > 0)
        drawXBar (lX, lY, lW, lH, lSlice[2], lSlice[3], Xgap, XColor);
}

void drawAx (int lX,int lY, int lW, int lH, double lSlice[4], long Xgap, CGFloat XColor[4], bool flipLR)
//Display an Axial slice at X pixels from left, Y pixels from bottom, W wide, H high, lSlice is 0..1 - fractional slice
//  assumes texture bound to OpenGL: glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
{
    glEnable (GL_TEXTURE_3D);
    float flip = 0;
    if (flipLR) flip = 1; //radiological
    glBegin(GL_QUADS);
        glTexCoord3d (flip, 1, lSlice[3]);
        glVertex2f(lX,lY+lH);
        glTexCoord3d (flip,0, lSlice[3]);
        glVertex2f(lX,lY);
        glTexCoord3d (1-flip,0,lSlice[3]);
        glVertex2f(lX+lW,lY);
        glTexCoord3d (1-flip,1, lSlice[3]);
        glVertex2f(lX+lW,lY+lH);
    glEnd();
    if ((Xgap > 0) && flipLR)
        drawXBar (lX, lY, lW, lH, 1.0 - lSlice[1], lSlice[2], Xgap, XColor);//Xgap
    else if (Xgap > 0)
        drawXBar (lX, lY, lW, lH, lSlice[1], lSlice[2], Xgap, XColor);//Xgap
}

void drawCoro (int lX, int lY, int lW,int lH, double lSlice[4], long Xgap, CGFloat XColor[4], bool flipLR)
//Display a CORONAL slice at X pixels from left, Y pixels from bottom, W wide, H high, lSlice is 0..1 - fractional slice
//  assumes texture bound to OpenGL: glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
{
    glEnable (GL_TEXTURE_3D);
    glColor3f(1.0f, 1.0f, 1.0f);
    float flip = 0;
    if (flipLR) flip = 1; //radiological
    glBegin(GL_QUADS);
        glTexCoord3d (flip, lSlice[2], 1);
        glVertex2f(lX,lY+lH);
        glTexCoord3d (flip,lSlice[2], 0);
        glVertex2f(lX,lY);
        glTexCoord3d (1-flip,lSlice[2],0);
        glVertex2f(lX+lW,lY);
        glTexCoord3d (1-flip,lSlice[2], 1);
        glVertex2f(lX+lW,lY+lH);
    glEnd();
    if ((Xgap > 0) && flipLR)
        drawXBar (lX, lY, lW, lH, 1.0-lSlice[1], lSlice[3], Xgap, XColor);
    else if (Xgap > 0)
        drawXBar (lX, lY, lW, lH, lSlice[1], lSlice[3], Xgap, XColor);
}

void setRGBColor (uint32_t clr)
{
    glColor4ub((clr) & 0xff, (clr >> 8) & 0xff, (clr >> 16) & 0xff, (clr >> 24) & 0xff);
    //glColor4ub((clr >> 24) & 0xff, (clr >> 16) & 0xff, (clr >> 8) & 0xff, 255);
}

float getMaxFloatXYZ(float v1, float v2, float v3)
{
    float ret;
    if ((v1 > v2) && (v1 > v3)) //v1 > v2, v1 > v3
        ret = v1;
    else if  (v2 > v3) //v2 > v3, v2 >= v1
        ret = v2;
    else //v3 >= v2, v3 >= v1
        ret = v3;
    return ret;
}

void scrnSizeX (NII_PREFS* prefs, CGPoint * imgSz)
{
    //NSLog(@"%g %g %g", prefs->fieldOfViewMM[1], prefs->fieldOfViewMM[2], prefs->fieldOfViewMM[3]);
    if ((prefs->scrnHt < 1) || (prefs->scrnWid < 1) || (prefs->fieldOfViewMM[1] <= 0.0) || (prefs->fieldOfViewMM[2] <= 0.0) || (prefs->fieldOfViewMM[3] <= 0.0) ) return;
    double mmPerPix = prefs->scrnWid/(prefs->fieldOfViewMM[1]+prefs->fieldOfViewMM[2]);
    double HmmPerPix = prefs->scrnHt/(prefs->fieldOfViewMM[2]+prefs->fieldOfViewMM[3]);
    prefs->scrnWideLayout = false;
    //NSLog(@"%gx%gx%g -", prefs->fieldOfViewMM[1], prefs->fieldOfViewMM[2], prefs->fieldOfViewMM[3]);
    switch (prefs->displayModeGL) {
        case   GL_2D_AXIAL:
            mmPerPix = prefs->scrnWid/prefs->fieldOfViewMM[1];
            HmmPerPix = prefs->scrnHt/prefs->fieldOfViewMM[2];
            if (mmPerPix > HmmPerPix) mmPerPix = HmmPerPix;
            prefs->scrnDim[1] = round(prefs->fieldOfViewMM[1]*mmPerPix);
            prefs->scrnDim[2] = round(prefs->fieldOfViewMM[2]*mmPerPix);
            imgSz->x = prefs->scrnDim[1]; //axial slice X is horizontal
            imgSz->y = prefs->scrnDim[2]; //axial slice Y is vertical
            return;
        case  GL_2D_CORONAL:
            mmPerPix = prefs->scrnWid/prefs->fieldOfViewMM[1];
            HmmPerPix = prefs->scrnHt/prefs->fieldOfViewMM[3];
            if (mmPerPix > HmmPerPix) mmPerPix = HmmPerPix;
            prefs->scrnDim[1] = round(prefs->fieldOfViewMM[1]*mmPerPix);
            prefs->scrnDim[3] = round(prefs->fieldOfViewMM[3]*mmPerPix);
            imgSz->x = prefs->scrnDim[1]; //coronal slice X is horizontal
            imgSz->y = prefs->scrnDim[3]; //coronal slice Z is vertical
            return;
        case   GL_2D_SAGITTAL:
            mmPerPix = prefs->scrnWid/prefs->fieldOfViewMM[2];
            HmmPerPix = prefs->scrnHt/prefs->fieldOfViewMM[3];
            if (mmPerPix > HmmPerPix) mmPerPix = HmmPerPix;
            prefs->scrnDim[2] = round(prefs->fieldOfViewMM[2]*mmPerPix);
            prefs->scrnDim[3] = round(prefs->fieldOfViewMM[3]*mmPerPix);
            imgSz->x = prefs->scrnDim[2]; //sagittal slice Y is horizontal
            imgSz->y = prefs->scrnDim[3]; //sagittal slice Z is vertical
            return;
            //break;
    }
    if (mmPerPix > HmmPerPix) mmPerPix = HmmPerPix;
    if ((prefs->displayModeGL == GL_2D_AND_3D) || (prefs->displayModeGL == GL_2D_ONLY))  { // GL_2D_AND_3D GL_2D_ONLY
        double mmMax = getMaxFloatXYZ(prefs->fieldOfViewMM[1], prefs->fieldOfViewMM[2], prefs->fieldOfViewMM[3]);
        double Hmm = prefs->fieldOfViewMM[1] + prefs->fieldOfViewMM[1] + prefs->fieldOfViewMM[2]; //Axial + Coronal + Sagittal
        if (prefs->displayModeGL == GL_2D_AND_3D) Hmm = Hmm + mmMax;
        Hmm = prefs->scrnWid/Hmm; //mmPerPix horizontal
        double Vmm = mmMax;
        
        Vmm = prefs->scrnHt/Vmm; //mmPerPix vertical
        if (Vmm > Hmm) Vmm = Hmm;
        //NSLog(@" %g %g", mmPerPix, Vmm );
        if (mmPerPix < Vmm) { //we can show larger images by having one row instead of two
            mmPerPix = Vmm;
            prefs->scrnWideLayout = true;
        }
    }
    prefs->scrnDim[1] = round(prefs->fieldOfViewMM[1]*mmPerPix);
    prefs->scrnDim[2] = round(prefs->fieldOfViewMM[2]*mmPerPix);
    prefs->scrnDim[3] = round(prefs->fieldOfViewMM[3]*mmPerPix);
    #ifdef NII_IMG_RENDER //defined in nii_definetypes.h
    prefs->renderBottom = 0;
    if (prefs->displayModeGL == GL_3D_ONLY) {
        prefs->renderLeft = 0;
        prefs->renderHt = prefs->scrnHt;//height;
        prefs->renderWid = prefs->scrnWid;//width;
        int renderPix = prefs->scrnHt;
        if (renderPix > prefs->scrnWid) renderPix = prefs->scrnWid;
        imgSz->x = renderPix;
        imgSz->y = renderPix;
    } else {
        if (prefs->scrnWideLayout) {
            prefs->renderLeft = prefs->scrnDim[1]+prefs->scrnDim[1]+prefs->scrnDim[2];
            //prefs->renderLeft = 0;//2*prefs->scrnDim[1];
            int renderPix = prefs->scrnWid - prefs->renderLeft;
            if (prefs->scrnHt < renderPix) renderPix = prefs->scrnHt;
            prefs->renderHt = renderPix;//height;
            prefs->renderWid = renderPix;//width;
            imgSz->x = prefs->scrnDim[1]+prefs->scrnDim[1]+prefs->scrnDim[2];
            imgSz->y = prefs->scrnDim[2]; //axial slice Y is vertical
            if (imgSz->y < prefs->scrnDim[3]) imgSz->y = prefs->scrnDim[3]; //coronal/sag slice Z is vertical
            if (prefs->displayModeGL == GL_2D_AND_3D) {
                imgSz->x = imgSz->x + renderPix;
                if (imgSz->y < renderPix) imgSz->y = renderPix; //rendering is largest image in vertical dimension
            }
        } else {
            prefs->renderLeft = prefs->scrnDim[1];
            prefs->renderHt = prefs->scrnDim[2];//height;
            prefs->renderWid = prefs->scrnDim[2];//width;
            imgSz->x = prefs->scrnDim[1]+prefs->scrnDim[2];
            imgSz->y = prefs->scrnDim[3]+prefs->scrnDim[2];
        }
    }
    #endif
    //NSLog(@"%gx%gx%g -> %dx%dx%d", prefs->fieldOfViewMM[1], prefs->fieldOfViewMM[2], prefs->fieldOfViewMM[3], prefs->scrnDim[1], prefs->scrnDim[2], prefs->scrnDim[3]);
    
}

void scrnSize (NII_PREFS* prefs) {
    CGPoint imgSz = {0.0f, 0.0f}; //initialize to avoid compiler warning - set in scrnSizeX
    scrnSizeX (prefs, &imgSz);
    if ((prefs->scrnWid- imgSz.x) < (prefs->scrnHt - imgSz.y)) {
        //NSLog(@"top %g %g",imgSz.x, imgSz.y);
        prefs->colorBarPos[0] = 0.05; //left
        prefs->colorBarPos[1] = 0.96;//bottom
        prefs->colorBarPos[2] = 0.95;  //right
        prefs->colorBarPos[3] = 0.99;  //top
    } else {
        //NSLog(@"right %g %g",imgSz.x, imgSz.y);
        prefs->colorBarPos[0] = 0.96; //left
        prefs->colorBarPos[1] = 0.125;//bottom
        prefs->colorBarPos[2] = 0.99;  //right
        prefs->colorBarPos[3] = 0.98;  //top
    }
}

void enter2D (int width, int height, int offsetX, int offsetY) //Enter2D = reshapeGL
{
    glDisable(GL_DEPTH_TEST);
    //    glViewport(0, 0, width, height);
    glViewport(offsetX, offsetY, width, height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, width, 0, height,-10, 10);//gluOrtho2D(0, width, 0, height);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glEnable (GL_BLEND); //blend transparency bar with background
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    //glDisable(GL_DEPTH_TEST);
}

float  defuzzz(float x)
{
    if (fabs(x) < 1.0E-6) return 0.0;
    return x;
}

double getOverlayVoxelIntensity(long long vox, int overlayIndex, NII_PREFS* prefs)
{
    if (prefs->overlays[overlayIndex].datatype == NIFTI_TYPE_RGBA32) {
        // Y = 0.299R + 0.587G + 0.114B
        THIS_UINT8 *inbuf = (THIS_UINT8 *) prefs->overlays[overlayIndex].data;
        vox = ((vox-1)*4); //saved as RGBA quads (RGBARGBA), indexed from 0
        return  roundf ((inbuf[vox]*0.299)+(inbuf[vox+1]*0.587)+(inbuf[vox+2]*0.114));
        //prefs->mouseIntensity = (inbuf[vox]*0.299)+(inbuf[vox+prefs->numVox3D]*0.587)+(inbuf[vox+2*prefs->numVox3D]*0.114);
    } else if ( prefs->overlays[overlayIndex].datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *inbuf = (THIS_UINT8 *) prefs->overlays[overlayIndex].data;
        return (inbuf[vox]*prefs->overlays[overlayIndex].scl_slope)+prefs->overlays[overlayIndex].scl_inter;
    } else if ( prefs->overlays[overlayIndex].datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *inbuf = (THIS_INT16 *) prefs->overlays[overlayIndex].data;
        return (inbuf[vox]*prefs->overlays[overlayIndex].scl_slope)+prefs->overlays[overlayIndex].scl_inter;
    } else {
        SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) prefs->overlays[overlayIndex].data;
        return(inbuf[vox]*prefs->overlays[overlayIndex].scl_slope)+prefs->overlays[overlayIndex].scl_inter;
    }
}

- (NSString *) getIntensityStr
{
    NSString *result = @"";
    if (prefs->currentVolume > prefs->numVolumes)
        return result;
    int slice[3];
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return result;
    mat44 R = prefs->sto_ijk;
    for (int i = 0; i < 3; i++) {
        slice[i] = round( (R.m[i][0]*prefs->mm[1])+(R.m[i][1]*prefs->mm[2])+ (R.m[i][2]*prefs->mm[3])+R.m[i][3] );
        if (slice[i] < 0) slice[i] = 0;
        if (slice[i] >= prefs->voxelDim[i+1]) slice[i] = prefs->voxelDim[i+1]-1;
    }
    long long vox = slice[0] + (slice[1]*prefs->voxelDim[1])+(slice[2]*prefs->voxelDim[1]*prefs->voxelDim[2]);
    if (fslio->niftiptr->datatype != NIFTI_TYPE_RGBA32)
        vox = vox + ((prefs->currentVolume-1) * prefs->numVox3D);
    float y = getVoxelIntensity(vox, fslio);
    if ( (fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) && (y <= [labelArray count]) && (y >= 1)  )
        result = [NSString stringWithFormat:@"%@", labelArray[(int)round(y)] ];
    else
        result = [NSString stringWithFormat:@"%g", defuzzz(y) ];
    //result = [result stringByAppendingString:[NSString stringWithFormat:@"%g", defuzzz(i) ]];
    for (int i = 0; i < MAX_OVERLAY; i++) {
        if (prefs->overlays[i].datatype != DT_NONE) {
            y = getOverlayVoxelIntensity(vox, i, prefs);
            result = [result stringByAppendingString:[NSString stringWithFormat:@",%g", defuzzz(y) ]];
        }
    }//for each overlay
    return result;
}

-(void) drawVolumeLabelTex {
    NSString * intensityStr = [self getIntensityStr];
    NSString * string;
    if (prefs->numVolumes < 2)
        string = [NSString stringWithFormat:@"%g\u00D7%g\u00D7%g=%@",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), intensityStr];
    else
        string = [NSString stringWithFormat:@"%g\u00D7%g\u00D7%g=%@ %d/%d",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), intensityStr,  prefs->currentVolume, prefs->numVolumes];
    //if (prefs->numVolumes < 2)
    //    string = [NSString stringWithFormat:@"%g x %g x %g = %@",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), intensityStr];
    //else
    //    string = [NSString stringWithFormat:@"%g x %g x %g = %@ %d/%d",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), intensityStr,  prefs->currentVolume, prefs->numVolumes];
    [glStringTex setString:string withAttributes:stanStringAttrib];
    //[glStringTex drawAtPoint:NSMakePoint (6, 24)];
    [glStringTex drawAboveLeftOfPoint:NSMakePoint (prefs->scrnWid-8, 4)];
}

void drawVector (int lX, int lY, int lXo, int lYo, CGFloat XColor[4]) {
    glColor4f(XColor[0],XColor[1],XColor[2],1.0f);
    glBegin(GL_LINES); //draw crosshairs...
    //top vert
    glVertex3f(lX+lXo,  lY+lYo, 0.0);
    glVertex3f(lX, lY, 0.0);
    glEnd();
} //drawVector()

void drawVectors (int dimX, int dimY, int dimZ, CGFloat Vec[3], CGFloat XColor[4]) {
    int min = dimX;
    if (dimY < min) min = dimY;
    if (dimZ < min) min = dimZ;
    min = min / 2;
    //adjust vector length
    Vec[0] = Vec[0]*min;
    Vec[1] = Vec[1]*min;
    Vec[2] = Vec[2]*min;
    //on coronal
    drawVector (dimX/2, dimY+(dimZ/2), Vec[0], Vec[2],XColor);
    //on axial
    drawVector (dimX/2, dimY/2, Vec[0], Vec[1],XColor);
    //on sagittal
    drawVector (dimX+ (dimY/2), dimY+(dimZ/2), Vec[1], Vec[2],XColor);
} //drawVectors

-(void) drawOrientLabelTex { //to do : radiological orientation!!!
    if (prefs->scrnDim[1] < 16) return;
    if ((fslio->niftiptr->dim[1] < 2) || (fslio->niftiptr->dim[2] < 2) || (fslio->niftiptr->dim[3] < 2)) return;
    if (fslio->niftiptr->sform_code == NIFTI_XFORM_UNKNOWN) return;
    glDisable (GL_TEXTURE_3D); //draw 2D text
    if (prefs->viewRadiological)
        [glStringTex setString:@"R" withAttributes:stanStringAttrib];
    else
        [glStringTex setString:@"L" withAttributes:stanStringAttrib];
    switch (prefs->displayModeGL) {
        case   GL_2D_AXIAL:
            [glStringTex drawRightOfPoint:NSMakePoint (8, prefs->scrnDim[2] /2)];
            return;
        case  GL_2D_CORONAL:
            //[glStringTex setString:@"L" withAttributes:stanStringAttrib];
            [glStringTex drawRightOfPoint:NSMakePoint (8, prefs->scrnDim[3] /2)];
            return;
        case   GL_2D_SAGITTAL:
            //2016
            return;
    }

    if  (prefs->scrnDim[2] > 16) //draw L/R on Axial
        [glStringTex drawRightOfPoint:NSMakePoint (8, prefs->scrnDim[2] /2)];
    if  (!(prefs->scrnWideLayout) && (prefs->scrnDim[3] > 16)) //draw L/R on Coronal
        [glStringTex drawRightOfPoint:NSMakePoint (8, prefs->scrnDim[2]+(prefs->scrnDim[3]/2) )];
    [glStringTex setString:@"A" withAttributes:stanStringAttrib];
    if (prefs->scrnDim[3] > 16) //draw A/P on Axial
        [glStringTex drawBelowPoint:NSMakePoint (prefs->scrnDim[1]/2, prefs->scrnDim[2] )];
    if (prefs->scrnWideLayout) {
        if (prefs->viewRadiological)
            [glStringTex setString:@"R" withAttributes:stanStringAttrib];
        else
            [glStringTex setString:@"L" withAttributes:stanStringAttrib];
        if  (prefs->scrnDim[3] > 16) //draw L/R on Coronal
            [glStringTex drawRightOfPoint:NSMakePoint (8+prefs->scrnDim[1], prefs->scrnDim[3]/2 )];
        [glStringTex setString:@"S" withAttributes:stanStringAttrib];
        if  (prefs->scrnDim[3] > 16) //draw S/I on Coronal
            [glStringTex drawBelowPoint:NSMakePoint (prefs->scrnDim[1]+prefs->scrnDim[1]/2, prefs->scrnDim[3] )];

        return;
    }
    [glStringTex setString:@"S" withAttributes:stanStringAttrib];
    if  (prefs->scrnDim[3] > 16) //draw S/I on Coronal
        [glStringTex drawBelowPoint:NSMakePoint (prefs->scrnDim[1]/2, prefs->scrnDim[2]+prefs->scrnDim[3] )];

}

-(void) redraw2D {//to do: radiological orientation
    enter2D(prefs->scrnWid,prefs->scrnHt, prefs->scrnOffsetX, prefs->scrnOffsetY);
    glDisable (GL_BLEND); //ignore Alpha for 2D slices...
    glEnable (GL_TEXTURE_3D);
    #ifdef MY_SHOW_GRADIENTS //defined in nii_render.h
    if (prefs->advancedRender)
        glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
    else
        glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    #else
    glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    #endif
    glColor3f(1.0f, 1.0f, 1.0f);
    switch (prefs->displayModeGL) {
        case   GL_2D_AXIAL:
            drawAx(0,0,prefs->scrnDim[1],prefs->scrnDim[2], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor, prefs->viewRadiological);
            break;
        case  GL_2D_CORONAL:
            drawCoro(0,0,prefs->scrnDim[1],prefs->scrnDim[3], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor, prefs->viewRadiological);
            break;
        case   GL_2D_SAGITTAL:
            drawSag(0,0,prefs->scrnDim[2],prefs->scrnDim[3], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor);
            break;
        default:
            if (prefs->scrnWideLayout) {
                drawAx(0,0,prefs->scrnDim[1],prefs->scrnDim[2], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor, prefs->viewRadiological);
                drawCoro(prefs->scrnDim[1],0,prefs->scrnDim[1],prefs->scrnDim[3], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor, prefs->viewRadiological);
                drawSag(2*prefs->scrnDim[1],0,prefs->scrnDim[2],prefs->scrnDim[3], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor);
                
            } else {
                drawAx(0,0,prefs->scrnDim[1],prefs->scrnDim[2], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor, prefs->viewRadiological);
                drawCoro(0,prefs->scrnDim[2],prefs->scrnDim[1],prefs->scrnDim[3], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor, prefs->viewRadiological);
                drawSag(prefs->scrnDim[1],prefs->scrnDim[2],prefs->scrnDim[2],prefs->scrnDim[3], prefs->sliceFrac, prefs->xBarGap, prefs->xBarColor);
                if (self.is2D)
                    drawHistogram(prefs, prefs->scrnDim[1], prefs->scrnDim[2], prefs->scrnDim[2]);
            }
            
    }

    if (prefs->numDtiV >= prefs->currentVolume) {
        CGFloat color[4] = {0.9, 0.9,0.1,0.9};
        CGFloat v[3] = {prefs->dtiV[prefs->currentVolume-1][0],prefs->dtiV[prefs->currentVolume-1][1],prefs->dtiV[prefs->currentVolume-1][2]};
        drawVectors(prefs->scrnDim[1],prefs->scrnDim[2],prefs->scrnDim[3],v, color);
    }
    //drawVector(33,33,44,44, prefs->xBarColor);
    //if ((prefs->showInfo) && (fslio->niftiptr->intent_code != NIFTI_INTENT_LABEL) )
    if (prefs->showInfo) {
        if (fslio->niftiptr->intent_code != NIFTI_INTENT_LABEL) drawColorBarTex(prefs, glStringTex, stanStringAttrib);
        [self drawVolumeLabelTex];
    }
    
    if (prefs->showOrient)
        [self drawOrientLabelTex];
    //glDisable (GL_TEXTURE_3D);
    //glColor4f(0.3f, 0.3f, 0.4f, 0.5f);
}

double Slicemm2frac (double mm, int orient, NII_PREFS* prefs) {
    if ((prefs->voxelDim[1] < 1) || (prefs->voxelDim[2] < 1) || (prefs->voxelDim[3] < 1) ) return 0.5;
    mat44 R = prefs->sto_ijk;
    double sliceFrac[4] = {0,0,0,0};
    double sliceMM[4] = {0,0,0,0};
    if (orient == 1) //axial
        sliceMM[3] = mm;
    else if (orient == 2) //coronal
        sliceMM[2] = mm;
    else //sagittal of sagittal mirror
        sliceMM[1] = mm;
    for (int i = 0; i < 3; i++) {
        sliceFrac[i+1] = round( (R.m[i][0]*sliceMM[1])+(R.m[i][1]*sliceMM[2])+ (R.m[i][2]*sliceMM[3])+R.m[i][3] )/prefs->voxelDim[i+1];
        if ((sliceFrac[i+1] < 0) || (sliceFrac[i+1]> 1)) sliceFrac[i+1] = 0.5;
    }
    if (prefs->viewRadiological) sliceFrac[1] = 1.0 - sliceFrac[1];  //test!!!
    if (orient == 1) //axial
        return sliceFrac[3];
    else if (orient == 2) //coronal
        return sliceFrac[2];
    else //sagittal or sagittal mirror
        return sliceFrac[1];
}

double  defuzzz(double x) {
    if (fabs(x) < 1.0E-6) return 0.0;
    return x;
}

-(void) mosaicPrepGL: (int) width Height:(int)height; {
    recalcGL(fslio, prefs);//2015 <- make sure we bind textures later
    //doShaderBlurSobel (prefs);
    prefs->glslUpdateGradientsBG = false;
    prefs->glslUpdateGradientsOverlay = false;
    glClearColor(prefs->backColor[0],prefs->backColor[1],prefs->backColor[2],0.5);
    glClear(GL_COLOR_BUFFER_BIT);
    //enter2D(width,height);
    enter2D(prefs->scrnWid,prefs->scrnHt, prefs->scrnOffsetX, prefs->scrnOffsetY);
    //glDisable (GL_BLEND); //ignore Alpha for 2D slices...
    //glPushAttrib (GL_ENABLE_BIT);
    glEnable (GL_TEXTURE_3D);
    glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    glDisable (GL_BLEND);
    glAlphaFunc(GL_GREATER,1/255);
    glEnable(GL_ALPHA_TEST);
}

-(void)redrawMosaic:(mosaicObj*) mos;
{
    //recalcGL(fslio, prefs); //<- done in mosaicPrepGL
    //rows ascending for positive overlap, descending for negative overlap
    //[self drawSag](floor(22),floor(22),prefs->scrnDim[2],prefs->scrnDim[3], 1, -1, prefs->xBarColor);
    int rInc = 1;
    int rStart = 1;
    int rEnd = kMaxMosaicDim;
    if (mos->VOverlap < 0) {
        rStart = kMaxMosaicDim-1;
        rEnd = 0;
        rInc = -1;
    }
    int cInc = 1;
    int cStart = 1;
    int cEnd = kMaxMosaicDim;
    if (mos->HOverlap < 0) {
        cStart = kMaxMosaicDim-1;
        cEnd = 0;
        cInc = -1;
    }
    for (int r = rStart; r != rEnd; r+=rInc) {
        for (int c = cStart; c != cEnd; c+=cInc) {
            double sliceFrac1 = mos->Slice[r][c];
            int orient = mos->Orient[r][c];
            if (mos->SliceIsMM)
                sliceFrac1 = Slicemm2frac (sliceFrac1, orient, prefs);
            double sliceFrac[4];
            if (orient == 1) //axial
                sliceFrac[3] = sliceFrac1;
            else if (orient == 2) //coronal
                sliceFrac[2] = sliceFrac1;
            else //sagittal of sagittal mirror
                sliceFrac[1] = sliceFrac1;
            if (mos->Orient[r][c] == 1)
                drawAx(round(mos->Pos[r][c].x),round(mos->Pos[r][c].y),prefs->voxelDim[1],prefs->voxelDim[2], sliceFrac, -1, prefs->xBarColor, prefs->viewRadiological);
            if (mos->Orient[r][c] == 2)
                drawCoro(round(mos->Pos[r][c].x),round(mos->Pos[r][c].y),prefs->voxelDim[1],prefs->voxelDim[3], sliceFrac, -1, prefs->xBarColor, prefs->viewRadiological);
            if (mos->Orient[r][c] == 3)
                drawSag(round(mos->Pos[r][c].x),round(mos->Pos[r][c].y),prefs->voxelDim[2],prefs->voxelDim[3], sliceFrac, -1, prefs->xBarColor);
            if (mos->Orient[r][c] == 4)
                drawSagMirror(round(mos->Pos[r][c].x),round(mos->Pos[r][c].y),prefs->voxelDim[2],prefs->voxelDim[3], sliceFrac, -1, prefs->xBarColor);
        }//for each colmn
    } //for each row
    //draw labels on second pass - so not hidden by overlay
    if (!mos->isLabel) return;
    //NSLog(@"labels");
    glDisable(GL_TEXTURE_3D);
    //drawVolumeLabel(prefs);
    //int textSize = prefs->voxelDim[1]; //find smallest dimension
    //if (textSize > prefs->voxelDim[2]) textSize = prefs->voxelDim[2];
    //if (textSize > prefs->voxelDim[3]) textSize = prefs->voxelDim[3];
    //textSize = (textSize / 256)+1;
    //glLoadIdentity();
    //glDisable(GL_ALPHA_TEST);
    for (int r = rStart; r != rEnd; r+=rInc) {
        for (int c = cStart; c != cEnd; c+=cInc) {
            if (mos->Orient[r][c] > 0) {
                double sliceFrac1 = mos->Slice[r][c];
                //if (mos->SliceIsMM)
                //    sliceFrac1 = Slicemm2frac (sliceFrac1, orient, prefs);
                float wid = prefs->voxelDim[1];
                float ht= prefs->voxelDim[3];
                if (mos->Orient[r][c] == 1)
                    ht = prefs->voxelDim[2];
                if (mos->Orient[r][c] > 2)
                    wid = prefs->voxelDim[3];
                /*char lS[255] = { '\0' };
                sprintf(lS, "%g",  sliceFrac1);
                textArrow (round(mos->Pos[r][c].x+ wid/2),round(mos->Pos[r][c].y+ht),textSize,lS,-2, prefs);
                 glLoadIdentity();
                 */
                NSString * string = [NSString stringWithFormat:@"%g", sliceFrac1];
                [glStringTex setString:string withAttributes:stanStringAttrib];
                [glStringTex drawBelowPoint:NSMakePoint (mos->Pos[r][c].x+ wid/2,mos->Pos[r][c].y+ht)];
            }
        }//for each colmn
    } //for each row
    //glFlush();     // Flush all OpenGL calls - we will have the NSOpenGLView do this
} //redrawMosaic

/*-(void) makeMosaic:(NSString *)mosStr
{
    //next two lines of code ensure text string is generated, only required if main image does not have labels
    [glStringTex setString:@"" withAttributes:stanStringAttrib];
    [glStringTex drawRightOfPoint:NSMakePoint (8, 8)];
    //NSString *str = @"V 0.5 H 0.5 0.5 S 0.3; C 0.1 0.7";
    mosaicObj *mos = [[mosaicObj alloc] init];
    [mos str2Mosaic:mosStr];
    [mos prepMosaic: prefs->voxelDim[1] Y: prefs->voxelDim[2] Z: prefs->voxelDim[3]];
    int width = mos->TotalSizeInPixels.x;
    int height = mos->TotalSizeInPixels.y;
    //NSLog(@"%d x %d", width, height);
    if((width <1) || (height <1)) return;
    //NSRect mosaicPixels = [self computeMosaic:str reDraw: false sliceFrac: true];
    NSRect mosaicRect = NSMakeRect(0,0,width,height);
    NSWindow *mosaicWindow = [[NSWindow alloc] initWithContentRect: mosaicRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
    //int width = mosaicPixels.size.width;
    //int height = mosaicPixels.size.height;
    //build OpenGL context
    //http://lists.apple.com/archives/mac-opengl/2010/Mar/msg00077.html
    //NSOpenGLPFARemotePixelBuffer, //<-deprecated
    NSLog(@"do work here");
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAColorSize, 24,
        (NSOpenGLPixelFormatAttribute) 0
    };
    // NSOpenGLPixelFormatAttribute
    //id pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    NSOpenGLPixelFormat* pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    NSRect viewRect = NSMakeRect(0.0, 0.0, mosaicRect.size.width, mosaicRect.size.height);
    NSOpenGLView *mosaicView = [[NSOpenGLView alloc] initWithFrame:viewRect pixelFormat: pf];
    
    [mosaicWindow setContentView: mosaicView];
    
    
    id ctx = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    [ctx setView: mosaicView];
    
    [ctx makeCurrentContext];
    glViewport(0,0,width,height);
    prefs->scrnWid = width;
    prefs->scrnHt = height;
    GLuint renderbuffer;
    glGenRenderbuffersEXT(1, &renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA8, width, height);
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    GLuint fbo_tex;
    glGenFramebuffersEXT(1, &fbo_tex);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo_tex);
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,
                              GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, tex, 0);
    if (glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) !=
        GL_FRAMEBUFFER_COMPLETE_EXT) {
        printf("glCheckFramebufferStatusEXT failed for tex\n");
        exit(1);
    }
    GLuint fb;
    glGenFramebuffersEXT(1, &fb);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fb);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT,
                                 GL_COLOR_ATTACHMENT0_EXT, GL_RENDERBUFFER_EXT, renderbuffer);
    if (glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) !=
        GL_FRAMEBUFFER_COMPLETE_EXT) {
        printf("glCheckFramebufferStatusEXT failed for renderbuffer\n");
        exit(1);
    }
    //we will create 3D volumes specific for this context...
    GLuint intensityOverlay3D = prefs->intensityOverlay3D;
    GLuint gradientOverlay3D = prefs->gradientOverlay3D;
    GLuint intensityTexture3D = prefs->intensityTexture3D;
    GLuint gradientTexture3D = prefs->gradientTexture3D;
    prefs->intensityOverlay3D = 0;
    prefs->gradientOverlay3D = 0;
    prefs->intensityTexture3D = 0;
    prefs->gradientTexture3D = 0;
    
    
    //create the mosaic
    [self mosaicPrepGL:  width Height:height];
    [self redrawMosaic: mos];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                                    pixelsWide: width pixelsHigh: height bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO
                                                                      isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 3*width bitsPerPixel: 0];
    // The following block does the actual reading of the image
    glPushAttrib(GL_PIXEL_MODE_BIT); // Save state about reading buffers
    glReadBuffer(GL_FRONT);
    glPixelStorei(GL_PACK_ALIGNMENT, 1); // Dense packing
    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, [rep bitmapData]);
    glPopAttrib();
    //next: use core image to flip the image so it is rightside up
    CIImage* ciimag = [[CIImage alloc] initWithBitmapImageRep: rep];
    CGAffineTransform trans = CGAffineTransformIdentity;
    trans = CGAffineTransformMakeTranslation(0.0f, height);
    trans = CGAffineTransformScale(trans, 1.0, -1.0);
    ciimag = [ciimag imageByApplyingTransform:trans];
    rep = [[NSBitmapImageRep alloc] initWithCIImage: ciimag];//get data back from core image
    //save to clipboard
    NSImage *imag = [[NSImage alloc] init] ;
    [imag addRepresentation:rep];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSArray *copiedObjects = [NSArray arrayWithObject:imag];
    [pasteboard writeObjects:copiedObjects];
    //release textures and frame buffer
    if (prefs->intensityOverlay3D != 0) glDeleteTextures(1,&prefs->intensityOverlay3D);
    if (prefs->gradientOverlay3D != 0) glDeleteTextures(1,&prefs->gradientOverlay3D);
    if (prefs->intensityTexture3D != 0) glDeleteTextures(1,&prefs->intensityTexture3D);
    if (prefs->gradientTexture3D != 0) glDeleteTextures(1,&prefs->gradientTexture3D);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0); //Bind 0, which means render to back buffer, as a result, fb is unbound
    glDeleteFramebuffersEXT(1, &fb); //cleanup https://www.opengl.org/wiki/Framebuffer_Object_Examples
    //return handles for screen textures
    prefs->intensityOverlay3D = intensityOverlay3D;
    prefs->gradientOverlay3D = gradientOverlay3D;
    prefs->intensityTexture3D = intensityTexture3D;
    prefs->gradientTexture3D = gradientTexture3D;
    //set openGL for correct canvas - not needed as we have set glslUpdateGradientsOverlay/glslUpdateGradientsBG to false
    //prefs->force_refreshGL = true;
    //prefs->force_recalcGL = true;
} //makeMosaic
*/

-(void) makeMosaic:(NSString *)mosStr
{
   //next two lines of code ensure text string is generated, only required if main image does not have labels
    [glStringTex setString:@"" withAttributes:stanStringAttrib];
    [glStringTex drawRightOfPoint:NSMakePoint (8, 8)];
    //NSString *str = @"V 0.5 H 0.5 0.5 S 0.3; C 0.1 0.7";
    mosaicObj *mos = [[mosaicObj alloc] init];
    [mos str2Mosaic:mosStr];
    [mos prepMosaic: prefs->voxelDim[1] Y: prefs->voxelDim[2] Z: prefs->voxelDim[3]];
    int width = mos->TotalSizeInPixels.x;
    int height = mos->TotalSizeInPixels.y;
    //NSLog(@"%d x %d", width, height);
    if((width <1) || (height <1)) return;
    prefs->scrnWid = width;
    prefs->scrnHt = height;
    //NSRect mosaicPixels = [self computeMosaic:str reDraw: false sliceFrac: true];
    //int width = mosaicPixels.size.width;
    //int height = mosaicPixels.size.height;
    //build OpenGL context
    //http://lists.apple.com/archives/mac-opengl/2010/Mar/msg00077.html
    //NSOpenGLPFARemotePixelBuffer, //<-deprecated
    //NSOpenGLPFAOpenGLProfile, (NSOpenGLPixelFormatAttribute)NSOpenGLProfileVersionLegacy,
    //NSOpenGLPFAOpenGLProfile, (NSOpenGLPixelFormatAttribute)NSOpenGLProfileVersion3_2Core,
    NSOpenGLPixelFormatAttribute attributes[] =
    {
        NSOpenGLPFAOpenGLProfile, (NSOpenGLPixelFormatAttribute)NSOpenGLProfileVersionLegacy,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAColorSize, 24,
        (NSOpenGLPixelFormatAttribute) 0
    };
    // NSOpenGLPixelFormatAttribute
    id pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    id ctx = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    [ctx makeCurrentContext];
    GLuint renderbuffer;
    glGenRenderbuffersEXT(1, &renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA8, width, height);
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, width, height,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    GLuint fbo_tex;
    glGenFramebuffersEXT(1, &fbo_tex);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo_tex);
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,
                              GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, tex, 0);
    if (glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) !=
        GL_FRAMEBUFFER_COMPLETE_EXT) {
        printf("glCheckFramebufferStatusEXT failed for tex\n");
        exit(1);
    }
    GLuint fb;
    glGenFramebuffersEXT(1, &fb);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fb);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT,
                                 GL_COLOR_ATTACHMENT0_EXT, GL_RENDERBUFFER_EXT, renderbuffer);
    if (glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) !=
        GL_FRAMEBUFFER_COMPLETE_EXT) {
        printf("glCheckFramebufferStatusEXT failed for renderbuffer\n");
        exit(1);
    }
    //we will create 3D volumes specific for this context...
    GLuint intensityOverlay3D = prefs->intensityOverlay3D;
    GLuint gradientOverlay3D = prefs->gradientOverlay3D;
    GLuint intensityTexture3D = prefs->intensityTexture3D;
    GLuint gradientTexture3D = prefs->gradientTexture3D;
    prefs->intensityOverlay3D = 0;
    prefs->gradientOverlay3D = 0;
    prefs->intensityTexture3D = 0;
    prefs->gradientTexture3D = 0;

    
    //create the mosaic
    [self mosaicPrepGL:  width Height:height];
    [self redrawMosaic: mos];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                                    pixelsWide: width pixelsHigh: height bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO
                                                                      isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 3*width bitsPerPixel: 0];
    // The following block does the actual reading of the image
    glPushAttrib(GL_PIXEL_MODE_BIT); // Save state about reading buffers
    glReadBuffer(GL_FRONT);
    glPixelStorei(GL_PACK_ALIGNMENT, 1); // Dense packing
    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, [rep bitmapData]);
    glPopAttrib();
    //next: use core image to flip the image so it is rightside up
    CIImage* ciimag = [[CIImage alloc] initWithBitmapImageRep: rep];
    CGAffineTransform trans = CGAffineTransformIdentity;
    trans = CGAffineTransformMakeTranslation(0.0f, height);
    trans = CGAffineTransformScale(trans, 1.0, -1.0);
    ciimag = [ciimag imageByApplyingTransform:trans];
    rep = [[NSBitmapImageRep alloc] initWithCIImage: ciimag];//get data back from core image
    //save to clipboard
    NSImage *imag = [[NSImage alloc] init] ;
    [imag addRepresentation:rep];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSArray *copiedObjects = [NSArray arrayWithObject:imag];
    [pasteboard writeObjects:copiedObjects];
    //release textures and frame buffer
    if (prefs->intensityOverlay3D != 0) glDeleteTextures(1,&prefs->intensityOverlay3D);
    if (prefs->gradientOverlay3D != 0) glDeleteTextures(1,&prefs->gradientOverlay3D);
    if (prefs->intensityTexture3D != 0) glDeleteTextures(1,&prefs->intensityTexture3D);
    if (prefs->gradientTexture3D != 0) glDeleteTextures(1,&prefs->gradientTexture3D);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0); //Bind 0, which means render to back buffer, as a result, fb is unbound
    glDeleteFramebuffersEXT(1, &fb); //cleanup https://www.opengl.org/wiki/Framebuffer_Object_Examples
    //return handles for screen textures
    prefs->intensityOverlay3D = intensityOverlay3D;
    prefs->gradientOverlay3D = gradientOverlay3D;
    prefs->intensityTexture3D = intensityTexture3D;
    prefs->gradientTexture3D = gradientTexture3D;
    //set openGL for correct canvas - not needed as we have set glslUpdateGradientsOverlay/glslUpdateGradientsBG to false
    //prefs->force_refreshGL = true;
    //prefs->force_recalcGL = true;
} //makeMosaic

- (bool) doRedraw {
    if (! prefs->force_refreshGL) return false;
    if (prefs->busyGL) return false;
    if ((prefs->scrnHt < 1) || (prefs->scrnWid < 1)) return false;
    prefs->busyGL = true;
    if (prefs->force_recalcGL) {
        //clock_t start = clock();
        prefs->force_recalcGL = false;
        #ifdef NII_IMG_RENDER
        createRender(prefs);
        #endif
        recalcGL(fslio, prefs);
        scrnSize(prefs); //666 <- redundant???
        #ifdef NII_IMG_RENDER
        recalcRender (prefs);
        #endif
        //printf("recalcGL required %fms\n", ((double)(clock()-start))/1000);
    }
    
    glClearColor(prefs->backColor[0],prefs->backColor[1],prefs->backColor[2],1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    #ifdef NII_IMG_RENDER
        //if ((prefs->displayModeGL == GL_2D_ONLY) || (prefs->displayModeGL == GL_2D_AXIAL)
        //    || (prefs->displayModeGL == GL_2D_CORONAL)  || (prefs->displayModeGL == GL_2D_SAGITTAL) )
        if (self.is2D)
            [self redraw2D]; //only draw 2D sections
        else {
            redrawRender(prefs); //draw 3D rendering
            if (prefs->displayModeGL == GL_2D_AND_3D) [self redraw2D]; //also draw 2D sections
        }
    #else
        [self redraw2D]; //if compiling without rendering: only draw 2D sections
    #endif
    GLenum err = glGetError();
    if (GL_NO_ERROR != err)   printf("glGetError = 0x%x\n", err);
    glFlush();     // Flush all OpenGL calls - we will have the NSOpenGLView do this
    prefs->force_refreshGL = false;
    prefs->busyGL = false;
    return true;
}



/*int setZeros(FSLIO* fslio, NII_PREFS* prefs) {
    if (fslio->niftiptr->datatype != SCALED_IMGDATA_TYPE) return EXIT_FAILURE;
    if (prefs->fullMin <= -1000) return EXIT_FAILURE; //not for Hounsfield units
    if ((prefs->fullMin >= 0) || (prefs->fullMax < 0)) return EXIT_FAILURE; //only for images with positive and negative values
    long len3d = (long)  prefs->numVox3D;
    if ( len3d < 1) return EXIT_FAILURE;
    size_t volOffset = prefs->currentVolume;
    if ((volOffset < 1) || (volOffset > prefs->numVolumes))
        volOffset = 1;
    volOffset = prefs->numVox3D * (volOffset-1);
    SCALED_IMGDATA *img = (SCALED_IMGDATA *)fslio->niftiptr->data;
    //make sure a reasonable proportion of data is zero
    long nZero = 0;
    for (long vx = 0; vx < len3d; vx++)
        if (img[volOffset+vx] == 0) nZero ++;
    if (nZero < (len3d >> 4)) return EXIT_FAILURE; //at least 6.25% of voxels must be zero 1/(2^4) = 1/16
    //allocate mask memory
    SCALED_IMGDATA mn = prefs->fullMin;
    SCALED_IMGDATA *mask = (SCALED_IMGDATA *) malloc((size_t) len3d * sizeof(SCALED_IMGDATA));
    SCALED_IMGDATA *mask2 = (SCALED_IMGDATA *) malloc((size_t) len3d * sizeof(SCALED_IMGDATA));
    //create mask
    for (long vx = 0; vx < len3d; vx++)
        mask[vx] = img[volOffset+vx];
    //dilate mask
    long dx = 1;
    for (long vx = 0; vx < dx; vx++)
        mask2[vx] = 0;
    for (long vx = dx; vx < len3d; vx++)
        mask2[vx] = mask[vx-dx]; //left
    for (long vx = 0; vx < (len3d-dx); vx++)
        mask2[vx] += mask[vx+dx]; //right
    dx = prefs->voxelDim[1];
    for (long vx = dx; vx < len3d; vx++)
        mask2[vx] += mask[vx-dx]; //anterior
    for (long vx = 0; vx < (len3d-dx); vx++)
        mask2[vx] += mask[vx+dx]; //posterior
    dx = prefs->voxelDim[1]*prefs->voxelDim[2];
    for (long vx = dx; vx < len3d; vx++)
        mask2[vx] += mask[vx-dx]; //below
    for (long vx = 0; vx < (len3d-dx); vx++)
        mask2[vx] += mask[vx+dx]; //above
    //apply mask
    for (long vx = 0; vx < len3d; vx++)
        if (mask2[vx] == 0.0)
            img[volOffset+vx] = mn;
    //release mask
    free(mask);
    free(mask2);
    return EXIT_SUCCESS;
} //setZeros */

-(bool) removeHaze{
    if (prefs->numVox3D < 2) return FALSE; //only for volumes
    //if (prefs->numVolumes > 1) return FALSE; //only for 3D data - not 4D
    if (fslio->niftiptr->datatype == DT_RGBA32) return FALSE; //not for RGB data
    if (prefs->numVox3D != (prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3])) NSLog(@"Haze: We have a problem");
    //setZeros(fslio, prefs); // <- this was only for float images
    THIS_UINT8 *mask8bit = (THIS_UINT8 *) malloc(prefs->numVox3D);
    size_t volOffset = prefs->currentVolume;
    if ((volOffset < 1) || (volOffset > prefs->numVolumes))
        volOffset = 1;
    volOffset = prefs->numVox3D* (volOffset-1);
    double minRaw = nii_cal2raw(fslio->niftiptr-> scl_inter, fslio->niftiptr-> scl_slope, prefs->viewMin);
    double maxRaw = nii_cal2raw(fslio->niftiptr-> scl_inter, fslio->niftiptr-> scl_slope, prefs->viewMax);
    rescale8bit(fslio->niftiptr->data, prefs->numVox3D, volOffset, fslio->niftiptr->datatype, minRaw, maxRaw, mask8bit);
    //applyOtsuBinary (img8bit,(int) prefs->numVox3D, 5);
    //NSLog(@" Voxels %d x %d x %d", prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3]);
    //NSDate *startTime = [NSDate date];
    maskBackground  (mask8bit, prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3], 5,2, TRUE);
    //NSLog(@"Execution Time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
    if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *inbuf = (THIS_UINT8 *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++)
            if (mask8bit[i] == 0)
                inbuf[i+volOffset] = 0;
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *inbuf = (THIS_INT16 *) fslio->niftiptr->data;
        THIS_INT16 min = round(nii_cal2raw(fslio->niftiptr-> scl_inter, fslio->niftiptr-> scl_slope, prefs->fullMin));
        for (int i = 0; i < prefs->numVox3D; i++)
            if (mask8bit[i] == 0)
                inbuf[i+volOffset] = min;
    } else {
        SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) fslio->niftiptr->data;
        SCALED_IMGDATA min = nii_cal2raw(fslio->niftiptr-> scl_inter, fslio->niftiptr-> scl_slope, prefs->fullMin);
        for (int i = 0; i < prefs->numVox3D; i++)
            if (mask8bit[i] == 0)
                inbuf[i+volOffset] = min;
    }
    free(mask8bit);
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
    return TRUE;
} //removeHaze()

-(bool) sharpen { //apply unsharp mask
    if (fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) return FALSE; //the border of Area 17 and 18 is NOT 16 or 19!!! 
    if (fslio->niftiptr->datatype == DT_RGBA32) return FALSE; //not for RGB data
    int Xdim = prefs->voxelDim[1];
    int Ydim = prefs->voxelDim[2];
    int Zdim = prefs->voxelDim[3];
    size_t volOffset = prefs->currentVolume;
    if ((volOffset < 1) || (volOffset > prefs->numVolumes))
        volOffset = 1;
    volOffset = prefs->numVox3D* (volOffset-1);
    if ((Xdim < 5) || (Ydim < 5) || (Zdim < 5)) return FALSE;
    if (prefs->numVox3D != (prefs->voxelDim[1]*prefs->voxelDim[2]*prefs->voxelDim[3])) return FALSE; //only 3D
    int nvox = Xdim * Ydim * Zdim;
    //generate two cloned volumes of image data: sum, img
    //  we will do our calculation in floating point, so we need to convert 8/16-bit integer values to floats.
    SCALED_IMGDATA *img = new SCALED_IMGDATA[nvox]();
    if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *inbuf = (THIS_UINT8 *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++)
                img[i] = inbuf[i+volOffset];
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *inbuf = (THIS_INT16 *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++)
            img[i] = inbuf[i+volOffset];
    } else {
        SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++)
            img[i] = inbuf[i+volOffset];
    }
    SCALED_IMGDATA mn = img[0];
    SCALED_IMGDATA mx = img[0];
    for (int i = 0; i < prefs->numVox3D; i++) { //find min/max for volume - clip to avoid ringing in air
        if (img[i] > mx) mx = img[i];
        if (img[i] < mn) mn = img[i];
    }
    SCALED_IMGDATA *sum = new SCALED_IMGDATA[nvox]();
    memcpy (sum, img, nvox*sizeof(THIS_INT32)); //memcpy(destination, source)
    //we will emulate a Gaussian blur be weighting the center twice as much as immediate neighbors
    //  we will do this in each dimension separately (since Gaussian kernel is separable)
    //sum with left/right neighbors
    for (int i = 2; i < (nvox-2); i++)
        img[i] = sum[i-1] + sum[i] + sum[i] + sum[i+1];// left+2*center+right
    //sum result with anterior/posterior neighbors
    for (int i = Xdim; i < (nvox-Xdim-1); i++)
        sum[i] = img[i-Xdim] + img[i] + img[i] + img[i+Xdim];// anterior+2*center+posterior
    //sum with superior/inferior neighbors, generate output
    int sliceSz = Xdim*Ydim;
    //int sliceSz2 = sliceSz * 2;
    for (int i = sliceSz; i < (nvox-sliceSz-1); i++)
        img[i] = (sum[i-sliceSz] + sum[i] + sum[i] + sum[i+sliceSz]) / 64.0f; //below+2*center+above
    delete[] sum;
    SCALED_IMGDATA v;
    //we add the difference between the original (high+low freq) and blurred image (low freq) to amplify high freq
    if ( fslio->niftiptr->datatype == NIFTI_TYPE_UINT8) {
        THIS_UINT8 *inbuf = (THIS_UINT8 *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++) {
            v = inbuf[i+volOffset] + inbuf[i+volOffset] - img[i];
            if (v < mn) v = mn;
            if (v > mx) v = mx;
            inbuf[i+volOffset] = v;
        }
    } else if ( fslio->niftiptr->datatype == NIFTI_TYPE_INT16) {
        THIS_INT16 *inbuf = (THIS_INT16 *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++) {
            v = inbuf[i+volOffset] + inbuf[i+volOffset] - img[i];
            if (v < mn) v = mn;
            if (v > mx) v = mx;
            inbuf[i+volOffset] = v;
         }
    } else {
        SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) fslio->niftiptr->data;
        for (int i = 0; i < prefs->numVox3D; i++) {
            v = inbuf[i+volOffset] + inbuf[i+volOffset] - img[i];
            if (v < mn) v = mn;
            if (v > mx) v = mx;
            inbuf[i+volOffset] = v;
        }
    }
    delete[] img;
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
    return TRUE;
}

-(void) setBackgroundColor: (double) red Green: (double) green Blue: (double) blue; {
    prefs->backColor[0] = red;
    prefs->backColor[1] = green;
    prefs->backColor[2] = blue;
    prefs->force_recalcGL = true;
    prefs->force_refreshGL = true;
}

-(void)getBackgroundColor:(double*)red Green:(double*)green Blue:(double*)blue;
//Returns red, green, blue of background. To call:
//  double rgb[3];
//  [basic_opengl_view->Gniiimg getBackgroundColor:&rgb[0] Green:&rgb[1] Blue:&rgb[2] ];
{
    *red = prefs->backColor[0];
    *green = prefs->backColor[1];
    *blue = prefs->backColor[2];
}

-(void) setColorScheme: (int) clrIndex; {
    prefs->colorScheme = clrIndex;
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
}

-(void) setColorSchemeForLayer: (int) index Layer: (int) layer; {
    if ((layer > MAX_OVERLAY) || (layer <= 0)) { //2014x >= MAX_OVERLAY
        //adjust background
        [self setColorScheme: index];
        return;
    }
    //-1 as background is layer 0, so background 0 is layer 1
    prefs->overlays[layer-1].colorScheme = index;
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
}

-(void) setDisplayModeX: (int) mode; {
    #ifdef NII_IMG_RENDER //from nii_definetypes.h
    if ((mode == GL_2D_AND_3D) || (mode == GL_2D_ONLY) || (mode == GL_3D_ONLY)
         || (mode == GL_2D_AXIAL)  || (mode == GL_2D_CORONAL)  || (mode == GL_2D_SAGITTAL))
        prefs->displayModeGL = mode;
    scrnSize(prefs); //dimensions change with mode...
    prefs->force_refreshGL = true;
    //NSLog(@"mode %d %d",prefs->displayModeGL,mode);//2016
    #endif
}

-(void) setAzimElev: (int) azim Elev: (int) elev; {
    #ifdef NII_IMG_RENDER //from nii_definetypes.h
    if ((prefs->renderElevation == elev) && (prefs->renderAzimuth == azim)) return;
    prefs->renderElevation = elev;
    prefs->renderAzimuth = azim;
    if (prefs->renderElevation > 360) prefs->renderElevation = prefs->renderElevation-360;
    if (prefs->renderElevation < -360) prefs->renderElevation = prefs->renderElevation+360;
    //if (prefs->renderElevation > 90) prefs->renderElevation = 90;
    //if (prefs->renderElevation < -90) prefs->renderElevation = -90;
    prefs->force_refreshGL = true;
    #endif
}

-(void) setAzimElevInc: (int) azim Elev: (int) elev; {
    #ifdef NII_IMG_RENDER //from nii_definetypes.h
    if ( (0 == elev) && (0 == azim)) return;
    prefs->renderElevation = prefs->renderElevation+elev;
    prefs->renderAzimuth = prefs->renderAzimuth+azim;
    //if (prefs->renderElevation > 90) prefs->renderElevation = 90;
    //if (prefs->renderElevation < -90) prefs->renderElevation = -90;
    if (prefs->renderElevation > 360) prefs->renderElevation = prefs->renderElevation-360;
    if (prefs->renderElevation < -360) prefs->renderElevation = prefs->renderElevation+360;
    prefs->force_refreshGL = true;
    #endif
}

-(int) getVolume {
    return prefs->currentVolume;
}

-(int) getNumberOfVolumes {
    return prefs->numVolumes;
}

-(void) setVolume: (int) volume {
    if (volume > prefs->numVolumes)
        volume = 1; //loop or limit with prefs->numVolumes;
    if (volume < 1)
        volume = prefs->numVolumes;//loop, or limit with 1;
    prefs->currentVolume = volume;
    isInSection(0,0, false, prefs, fslio); //refresh mouse voxel intensity
    prefs->updatedTimeline = (prefs->numVolumes > 1); //adjust currentTimepoint
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
}

-(void) getAzimElev: (int *) azim Elev: (int *) elev; {
    *azim = prefs->renderAzimuth;
    *elev = prefs->renderElevation;
}

-(void) getClip: (int *) azim Elev: (int *) elev Depth: (int *) depth {
    *azim = prefs->clipAzimuth;
    *elev = prefs->clipElevation;
    *depth = prefs->clipDepth;
}

-(void) setClip: (int) azim Elev: (int) elev Depth: (int) depth {
    if (depth > MAX_CLIPDEPTH) 
        depth = MAX_CLIPDEPTH;
    if (depth < 0) 
        depth = 0;
    /*if (elev < -90)
        elev = -90;
    if (elev > 90) 
        elev = 90;*/
    prefs->clipDepth = depth;  
    prefs->clipAzimuth = azim;
    prefs->clipElevation = elev;
    if (prefs->clipElevation < -360)
        prefs->clipElevation = prefs->clipElevation + 360;
    if (prefs->clipElevation > 360)
        prefs->clipElevation = prefs->clipElevation - 360;
    prefs->force_refreshGL = true;
}

-(void) setScreenWidHt: (double) width Height: (double) height; {
    prefs->scrnHt = height ;
    prefs->scrnWid = width;
    scrnSize(prefs);
    prefs->force_refreshGL = true;
}

-(void) setScreenWidHtOffset: (double) width Height: (double) height OffsetX: (double) offsetX OffsetY: (double) offsetY; {
    prefs->scrnHt = height;
    prefs->scrnWid = width;
    prefs->scrnOffsetX = offsetX;
    prefs->scrnOffsetY = offsetY;
    prefs->scrnWid = width;
    scrnSize(prefs);
    prefs->force_refreshGL = true;
}

-(void) setViewMinMax: (double) min Max: (double) max; {
    prefs->viewMin = min;
    prefs->viewMax = max;
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
}

-(void) setViewMinMaxForLayer: (double) min Max: (double) max Layer: (int) layer  {
    if ((layer > MAX_OVERLAY) || (layer <= 0)) { //2014x >= MAX_OVERLAY
        //adjust background
        [self setViewMinMax: min Max: max];
        return;
    }
    //-1 as background is layer 0, so background 0 is layer 1
    prefs->overlays[layer-1].viewMin = min;
    prefs->overlays[layer-1].viewMax = max;
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
}

-(void) getViewMinMax: (double*) min Max: (double*) max; {
    *min = prefs->viewMin;
    *max = prefs->viewMax;
}

-(void) getSuggestedViewMinMax: (double*) min Max: (double*) max; {
    *min = prefs->nearMin;
    *max = prefs->nearMax;
}

int setLoadDummy(FSLIO* fslio, NII_PREFS* prefs)
{
    if (fslio==NULL)  {
        printf("loaddummy: Null pointer passed for FSLIO\n");
        return EXIT_FAILURE;
    }
    prefs->busyGL = TRUE;
    const int kSz = 48;
    struct nifti_1_header  nhdr = {.extents = 0}; //2014 array initializer
    nhdr.dim[0] = 3;
    nhdr.dim[1] = kSz;
    nhdr.dim[2] = kSz;
    nhdr.dim[3] = kSz;
    nhdr.pixdim[1] = 1;
    nhdr.pixdim[2] = 1;
    nhdr.pixdim[3] = 1;
    nhdr.magic[0]='n';
    nhdr.magic[1]='+';
    nhdr.magic[2]='1';
    nhdr.magic[3]='\0';
    nhdr.srow_x[0]=1; nhdr.srow_x[1]=0; nhdr.srow_x[2]=0; nhdr.srow_x[3]=-kSz/2;
    nhdr.srow_y[0]=0; nhdr.srow_y[1]=1; nhdr.srow_y[2]=0; nhdr.srow_y[3]=-kSz/2;
    nhdr.srow_z[0]=0; nhdr.srow_z[1]=0; nhdr.srow_z[2]=1; nhdr.srow_z[3]=-kSz/2;
    nhdr.sform_code = 1;
    nhdr.datatype = DT_UNSIGNED_CHAR;
    nhdr.bitpix = 8;
    nhdr.sizeof_hdr = 348;
    nhdr.vox_offset = 352;
    nhdr.scl_inter = 0;
    nhdr.scl_slope = 1;
    nifti_image *nim ;
    nim = nifti_convert_nhdr2nim(nhdr,"dummy.nii");
    fslio->niftiptr = nim;
    //nifti_image_infodump(fslio->niftiptr);
    THIS_UINT8 *outbuf = (THIS_UINT8 *) malloc(kSz*kSz*kSz);
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"nii_img 4 malloc size %d",kSz*kSz*kSz);
    #endif
    //fill array with simple image
    long i =0;
    for (i = 0; i < (kSz*kSz*kSz); i++) outbuf[i] = 0;
    int lo = 2; //border
    int hi = kSz-lo;
    i = 0;
    for (long z = 0; z < kSz; z++) {
        for (long y = 0; y < kSz; y++) {
            for (long x = 0; x < kSz; x++) {
                if ((x < lo) || (x > hi) || (y < lo) || (y > hi) || (z < lo) || (z > hi) )
                    outbuf[i] = 0; //outside border
                else if ((x>6) && (x<12) && (y > 6) && (y < 42))
                    outbuf[i] = 0;  //vertical of L
                else if ((x > 11) && (x < 24) && (y>6) && (y<12))
                    outbuf[i] = 0; //horizontal of L
                else
                    outbuf[i] = x+y+z; //warning (kSz-1)*3 must be less than 255
                i++;
            }
        }
    }
    free(fslio->niftiptr->data);
    fslio->niftiptr->data = outbuf;
    nii_setup(fslio, prefs);
    prefs->busyGL = FALSE;
    return EXIT_SUCCESS;
}

void closeOverlays (NII_PREFS* prefs)
{
    for (int i = 0; i < MAX_OVERLAY; i++) {
        if (prefs->overlays[i].datatype != DT_NONE) free(prefs->overlays[i].data); //free memory
        prefs->overlays[i].datatype = DT_NONE; //mark slot as free
    }  
}

-(void) freePrefs 
{
    FslClose(fslio);
    closeOverlays(prefs);
    [labelArray removeAllObjects];
    prefs->currentVolume = 1;
    fslio = FslInit();
}

-(int)  setLoadDTI: (NSString *) faname V1name: (NSString *) v1name //dummy loaded if filename blank or non-existent
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:v1name]) return EXIT_FAILURE;
    if (![[NSFileManager defaultManager] fileExistsAtPath:faname]) return EXIT_FAILURE;
    if (![self checkSandAccess2: v1name]) return EXIT_FAILURE;
    if (![self checkSandAccess2: faname]) return EXIT_FAILURE;
    prefs->busyGL = TRUE;
    [self freePrefs];
    //load FA
    char fname[ [faname length]+1];    
    [faname getCString:fname maxLength:sizeof(fname)/sizeof(*fname) encoding:NSUTF8StringEncoding];
    int vol = FslReadVolumes(fslio,fname,0,1);
    if ((prefs->dicomWarn) && (fslio->niftiptr->isDICOM))
        [self notifyDICOMwarning];
    if (vol < 1) return setLoadDummy(fslio, prefs);
    //load 3 volumes vectors
    char vname[ [v1name length]+1]; 
    [v1name getCString:vname maxLength:sizeof(vname)/sizeof(*vname) encoding:NSUTF8StringEncoding];
    FSLIO* lfslio = FslInit();
    vol = FslReadVolumes(lfslio,vname,0,3);
    if ((prefs->dicomWarn) && (fslio->niftiptr->isDICOM))
        [self notifyDICOMwarning];
    if ((sizeof(SCALED_IMGDATA) == fslio->niftiptr->nbyper ) && (vol == 3) && (fslio->niftiptr->datatype == lfslio->niftiptr->datatype ) && (lfslio->niftiptr->dim[1] == fslio->niftiptr->dim[1]) && (lfslio->niftiptr->dim[2] == fslio->niftiptr->dim[2] ) && (lfslio->niftiptr->dim[3] == fslio->niftiptr->dim[3] ) ) {
        int nvox = fslio->niftiptr->dim[1]*fslio->niftiptr->dim[2]*fslio->niftiptr->dim[3];
        //THIS_UINT8 *rawRGB = (THIS_UINT8 *) fslio->niftiptr->data;
        THIS_UINT8 *outbuf = (THIS_UINT8 *) malloc(nvox * 4);
        SCALED_IMGDATA *faimg = (SCALED_IMGDATA *) fslio->niftiptr->data;
        SCALED_IMGDATA *v1img = (SCALED_IMGDATA *) lfslio->niftiptr->data;
        //inbuf[lXo+lYo+lZo];
        //int xyz = fslio->niftiptr->dim[1]*fslio->niftiptr->dim[2]*fslio->niftiptr->dim[3];
        int nvox2 = nvox * 2;
        int nvox3 = nvox * 3;
        for (int v = 0; v < (nvox3); v++)
            v1img[v] = fabs( v1img[v] );
        float mx = faimg[0];
        for (int v = 0; v < (nvox); v++)
            if (faimg[v]  > mx) mx = faimg[v];
//        if ((mx > 1.0) && (mx < 1.5)) {//FSL tends to have weird values >1 - clip to 1...
//            for (int v = 0; v < (nvox); v++)
//                if (faimg[v]  > 1.0) faimg[v] = 1.0;
//            mx = 1.0;
//        }
        int o = 0;
        
        float faval;
        for (int v = 0; v < nvox; v++) { //for each slice
            faval = faimg[v]/mx;
            if (faval < 0.0 ) faval = 0.0;
            faval = sqrt(faval) * 255.0;
            outbuf[o++] = round(v1img[v]*faval); //Red - 1st volume (Xdim=LR)
            outbuf[o++] =  round(v1img[v+nvox]*faval); //Green - 2nd volume (Ydim=PA)
            outbuf[o++] = round(v1img[v+nvox2]*faval); //Blue - 3rd volume (Zdim=IS)
            outbuf[o++] = round(faval); //green best estimate for alpha
        } //for each voxel
        free(fslio->niftiptr->data);
        fslio->niftiptr->data = outbuf;
        fslio->niftiptr->datatype =DT_RGBA32;
        fslio->niftiptr->nbyper = 4;
    }
    FslClose(lfslio);
    nii_setup(fslio, prefs);
    prefs->busyGL = FALSE;
    return EXIT_SUCCESS;
}

-(BOOL) checkSandAccess: (NSString *)file_name
{
    bool result = (!access([file_name UTF8String], R_OK) );
    if (result) return result; //already have access
    NSOpenPanel *openPanel  = [NSOpenPanel openPanel];
    [openPanel setDirectoryURL: [[NSURL alloc] initWithString:file_name]];
    //NSLog(@"selecting : %@",[FName lastPathComponent] ); // [FName lastPathComponent]
    openPanel.title = [@"Select file " stringByAppendingString:[file_name lastPathComponent]];
    NSString *Ext = [file_name pathExtension];
    NSArray *fileTypes = [NSArray arrayWithObjects: Ext, nil];
    [openPanel setAllowedFileTypes:fileTypes];
    [openPanel runModal];
    result = (!access([file_name UTF8String], R_OK) );
    if (result) return result; //already have access
    /*
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[@"You do not have access to the file " stringByAppendingString:[file_name lastPathComponent]] ];
    [alert runModal];*/
    NSBeginAlertSheet(@"Unable to open image", @"OK",NULL,NULL, [[NSApplication sharedApplication] keyWindow], self,
                      NULL, NULL, NULL,
                      @"%@"
                      , [@"You do not have access to the file " stringByAppendingString:[file_name lastPathComponent]]);
     return result; //no access*/
}

-(BOOL) checkSandAccess2: (NSString *)file_name
{
    if (file_name.length < 3) return true;
    bool result = [self checkSandAccess: file_name];
    //bool result = checkSandAccess(file_name);
    if (!result) return result; //no access to primary file
    NSString *Ext = [file_name pathExtension];
    if ([Ext caseInsensitiveCompare:@"HDR"]== NSOrderedSame ) {
        Ext = @"img"; //hdr file requires img
    }   else if([Ext caseInsensitiveCompare:@"IMG"]== NSOrderedSame ) {
        Ext = @"hdr"; //img file requires hdr
    }  else  return result; //no secondary file
    NSString *FName = [NSString stringWithFormat:@"%@.%@", [file_name stringByDeletingPathExtension], Ext];
    return [self checkSandAccess: FName];
}

-(void) setLoadBVec: (NSString *) file_name;
{
    if ((prefs->orthoOrient) || (prefs->numVolumes < 2)) return; //only if displaying 4D images in raw orientation
    NSString* theFileName = [file_name stringByDeletingPathExtension];
    if ([[theFileName pathExtension] rangeOfString:@"NII" options:NSCaseInsensitiveSearch].location != NSNotFound)
        theFileName = [theFileName stringByDeletingPathExtension]; //remove both .nii and .gz from img.nii.gz
    //NSLog(@"BVec! %@",theFileName);
    theFileName = [theFileName stringByAppendingString: @".bvec"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:theFileName]) return;
    if (![self checkSandAccess2: theFileName]) return;
    NSLog(@"BVec!! %@",theFileName);
    FILE *header_file;
    header_file = fopen([theFileName cStringUsingEncoding:1], "r");
    if (header_file == NULL) {
        NSLog(@"Error opening %@ ", theFileName);
        return;
    }
    float val;
    for (int v = 0; v < 3; v++) {
        for (int i = 0; i < prefs->numVolumes; i++) {
            int count = fscanf( header_file , "%f" , &val ) ;
            if ((count > 0) && (i < MAX_DTIvectors)) {
                //NSLog(@" %f<< %d",val, count);
                prefs->dtiV[i][v] = val;
                prefs->numDtiV = i+1;
            }
        } //for each i
    }//for v 0,1,2
    //NSLog(@" %gx%gx%g << %d",prefs->dtiV[1][0],prefs->dtiV[1][1],prefs->dtiV[1][2], prefs->dtiVnum);
    fclose( header_file ) ;
}

- (IBAction)notifyImageTooBig
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:@"Image too large for volume rendering"];
    notification.informativeText = @"Display may be impaired";
    notification.soundName = NULL;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    [NSTimer scheduledTimerWithTimeInterval: 4.5  target:self selector: @selector(closePopup) userInfo:self repeats:NO];
}

-(int)  setLoadImage2: (NSString *) file_name IsOverlay: (bool) isOverlay;
{
    if (![self checkSandAccess2: file_name]) return setLoadDummy(fslio, prefs);
    [self freePrefs];
    //fslio = FslInit();
    prefs->busyGL = TRUE;
    //strcpy( prefs->nii_prefs_fname, "" );//called in nii_setup
    //prefs->nii_prefs_fname ="";
    //if ([file_name isEqualToString:@""]) return setLoadDummy(fslio, prefs);
    if (([file_name length] < 1) || ([@"~" isEqualToString: file_name]) )
        return setLoadDummy(fslio, prefs);
    if (![[NSFileManager defaultManager] fileExistsAtPath:file_name]) {
        NSLog(@"Unable to find file : %@",file_name);
        return setLoadDummy(fslio, prefs);
    }
    char fname[ [file_name length]+1];
    [file_name getCString:fname maxLength:sizeof(fname)/sizeof(*fname) encoding:NSUTF8StringEncoding];
    int maxVols = INT_MAX;
    //if (prefs->loadFewVolumes) maxVols = 32;
    if (prefs->loadFewVolumes) maxVols = -1;
    
    if (isOverlay) maxVols = 1;
    void *buffer = FslReadAllVolumes(fslio,fname,maxVols);
    if (buffer == NULL) {
        fprintf(stderr, "Error opening and reading %s.\n",fname);
        [self notifyOpenFailed];
        return setLoadDummy(fslio, prefs);
    }
    #define kMaxDim 1536
    if ((fslio->niftiptr->dim[1]> kMaxDim) || (fslio->niftiptr->dim[2]> kMaxDim) || (fslio->niftiptr->dim[3]> kMaxDim))
        [self notifyImageTooBig];
    if ((prefs->dicomWarn) && (fslio->niftiptr->isDICOM))
        [self notifyDICOMwarning];
    //if (fslio->niftiptr->rawvols > maxVols)
    //    [self notifyNotAllVolumesLoaded: maxVols RawVols: fslio->niftiptr->rawvols];
    if ((maxVols < 1) && (fslio->niftiptr->rawvols > fslio->niftiptr->dim[4]))
        [self notifyNotAllVolumesLoaded: fslio->niftiptr->dim[4] RawVols: fslio->niftiptr->rawvols];
    nii_setup(fslio, prefs);
    NSString* theFileName = [[file_name lastPathComponent] stringByDeletingPathExtension];
    if ([[theFileName pathExtension] rangeOfString:@"NII" options:NSCaseInsensitiveSearch].location != NSNotFound)
        theFileName = [theFileName stringByDeletingPathExtension]; //remove both .nii and .gz from .nii.gz
    
    [self setLoadBVec: file_name];
    strcpy( prefs->nii_prefs_fname, [theFileName UTF8String] );
    if ( (fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) && (fslio->niftiptr->iname_offset >400)
        && ( (fslio->niftiptr->iname_offset % 16) == 0))
        readLabels (file_name, 352, round(fslio->niftiptr->iname_offset-352), labelArray);
    //prefs->nii_prefs_fname = theFileName;//[[file_name lastPathComponent] stringByDeletingPathExtension];//666 file_name;
    prefs->busyGL = FALSE;
    return EXIT_SUCCESS;
}

-(int)  setLoadImage: (NSString *) file_name;
{
    return [self setLoadImage2: file_name IsOverlay: false];
    
/*
    if (![self checkSandAccess2: file_name]) return EXIT_FAILURE;
    [self freePrefs];
     //fslio = FslInit();
    prefs->busyGL = TRUE;
    //strcpy( prefs->nii_prefs_fname, "" );//called in nii_setup
    //prefs->nii_prefs_fname ="";
    //if ([file_name isEqualToString:@""]) return setLoadDummy(fslio, prefs);
    if (([file_name length] < 1) || ([@"~" isEqualToString: file_name]) )
        return setLoadDummy(fslio, prefs);
    if (![[NSFileManager defaultManager] fileExistsAtPath:file_name]) {
        NSLog(@"Unable to find file : %@",file_name);
        return setLoadDummy(fslio, prefs);
    }
    char fname[ [file_name length]+1];
    [file_name getCString:fname maxLength:sizeof(fname)/sizeof(*fname) encoding:NSUTF8StringEncoding];
    int maxVols = INT_MAX;
    if (prefs->loadFewVolumes) maxVols = 32;
    if (prefs->loadOverlay) maxVols = 1;
    void *buffer = FslReadAllVolumes(fslio,fname,maxVols, prefs->dicomWarn);
    if (buffer == NULL) {
        fprintf(stderr, "Error opening and reading %s.\n",fname);
        return setLoadDummy(fslio, prefs);
    }
    nii_setup(fslio, prefs);
    NSString* theFileName = [[file_name lastPathComponent] stringByDeletingPathExtension];
    if ([[theFileName pathExtension] rangeOfString:@"NII" options:NSCaseInsensitiveSearch].location != NSNotFound)
        theFileName = [theFileName stringByDeletingPathExtension]; //remove both .nii and .gz from .nii.gz
    
    [self setLoadBVec: file_name];
    strcpy( prefs->nii_prefs_fname, [theFileName UTF8String] );
    if ( (fslio->niftiptr->intent_code == NIFTI_INTENT_LABEL) && (fslio->niftiptr->iname_offset >400)
        && ( (fslio->niftiptr->iname_offset % 16) == 0))
        readLabels (file_name, 352, round(fslio->niftiptr->iname_offset-352), labelArray);
    //prefs->nii_prefs_fname = theFileName;//[[file_name lastPathComponent] stringByDeletingPathExtension];//666 file_name;
    prefs->busyGL = FALSE;
    return EXIT_SUCCESS;*/
}

-(FSLIO *) getFSLIO;
{
    return fslio;
}

- (void) closeAllOverlays
{
    closeOverlays(prefs);
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
}

- (int) nextOverlaySlot
{
    if (fslio->niftiptr->datatype == DT_NONE) return -1; //no background
    if (fslio->niftiptr->datatype == DT_RGBA32) return -1; //can't load overlays on RGB backgrounds
    for (int i = 0; i < MAX_OVERLAY; i++)
        if (prefs->overlays[i].datatype == DT_NONE) return i; //empty slot
    return -1; //all slots full
}

-(void) setPrefsOrient: (bool) loadOrtho;
{
    prefs->orthoOrient = loadOrtho;
}

- (int) addOverlay: (NSString *) file_name
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:file_name]) return -1;
    int overlayNum = [self nextOverlaySlot];
    if (overlayNum < 0) return overlayNum;
    nii_img *lniiimg;
    lniiimg = [nii_img alloc];
    lniiimg = [lniiimg init];
    NSString *lname =  file_name;
    [lniiimg setPrefsOrient:prefs->orthoOrient];
    [lniiimg setLoadImage2:lname IsOverlay: true];
    FSLIO *over = [lniiimg getFSLIO];
    NII_PREFS *overp = [lniiimg getPREFS];
    //if (reslice2Targ (fslio, over, FALSE) == EXIT_FAILURE) {
    if (reslice2Targ (fslio, over, TRUE) == EXIT_FAILURE) {
    #if !__has_feature(objc_arc)
        [lniiimg release];
        #endif
        return -1;
    }
    //copy data to overlay
    prefs->overlays[overlayNum].lut_bias = 0.5;
    prefs->overlays[overlayNum].scl_inter = over->niftiptr->scl_inter;
    prefs->overlays[overlayNum].scl_slope = over->niftiptr->scl_slope;
    prefs->overlays[overlayNum].datatype = over->niftiptr->datatype;
    prefs->overlays[overlayNum].fullMin = overp->fullMin;
    prefs->overlays[overlayNum].fullMax = overp->fullMax;
    if ((overp->viewMin < 0) && (overp->viewMax > 0))
        overp->viewMin = overp->viewMax;
    prefs->overlays[overlayNum].viewMin = overp->viewMin;
    prefs->overlays[overlayNum].viewMax = overp->viewMax;
    prefs->overlays[overlayNum].nearMin = overp->nearMin;
    prefs->overlays[overlayNum].nearMax = overp->nearMax;
    prefs->overlays[overlayNum].colorScheme = overlayNum + 3;
    //printf(" OVERLAY %d %f %f\n", overlayNum, prefs->overlays[overlayNum].viewMin, prefs->overlays[overlayNum].viewMax );
    THIS_UINT8 *outbuf = (THIS_UINT8 *) malloc(prefs->numVox3D*over->niftiptr->nbyper);
    memcpy (outbuf, over->niftiptr->data, prefs->numVox3D*over->niftiptr->nbyper);
    prefs->overlays[overlayNum].data = outbuf;
     #if !__has_feature(objc_arc) 
    [lniiimg release];
    #endif
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"Loaded overlay %d", overlayNum);
    #endif
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
    return overlayNum; //all slots full
}

-(NII_PREFS *) getPREFS;
{
    return prefs;
}

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        fslio = FslInit();
        //fslio->niftiptr->datatype = DT_NONE;
        prefs = (NII_PREFS *) calloc(1,sizeof(NII_PREFS));
        prefs->currentVolume = 1;
        prefs->lut_bias = 0.5;
        prefs->numVolumes = 1;
        prefs->mouseX = -1; //no previous click...
        //prefs->xBarColor[0] = 1.0;
        prefs->backColor[0] = 0.0;
        prefs->backColor[1] = 0.0;
        prefs->backColor[2] = 0.0;
        prefs->xBarColor[0] = 0.3;
        prefs->xBarColor[1] = 0.3;
        prefs->xBarColor[2] = 1.0;
        prefs->colorBarBorderColor[0] = 0.25;
        prefs->colorBarBorderColor[1] = 0.25; 
        prefs->colorBarBorderColor[2] = 0.75;
        prefs->colorBarTextColor[0] = 0.5;
        prefs->colorBarTextColor[1] = 0.5;
        prefs->colorBarTextColor[2] = 0.5;
        prefs->colorBarPos[0] = 0.94; //left
        prefs->colorBarPos[1] = 0.125;//bottom
        prefs->colorBarPos[2] = 0.98;  //right
        prefs->colorBarPos[3] = 0.98;  //top
        prefs->xBarGap = 3;
        prefs->overlayFrac = 0.5;
        prefs->colorBarBorderPx = 2; // 1/2%
        
        //x prefs->colorBarBorder = 0.002; // 1/2%
        prefs->busyGL = FALSE; //prepared for drawing
        prefs->updatedTimeline = FALSE;
        prefs->intensityTexture3D = 0;
        prefs->gradientTexture3D = 0;
        prefs->intensityOverlay3D = 0;
        prefs->gradientOverlay3D = 0;
        prefs->numDtiV = 0;
        prefs->orthoOrient = true;
        prefs->advancedRender = false;
        prefs->loadFewVolumes = true;
        prefs->viewRadiological = false;
        
        for (int i = 0; i < MAX_OVERLAY; i++) prefs->overlays[i].datatype = DT_NONE; //all slots empty
        #ifdef NII_IMG_RENDER
        initTRayCast(prefs);
        #endif
        labelArray = [[NSMutableArray alloc]init];
        NSFont * font =[NSFont fontWithName:@"Helvetica" size:16.0];
        stanStringAttrib = [NSMutableDictionary dictionary];
        [stanStringAttrib setObject:font forKey:NSFontAttributeName];
        [stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
        NSString * string = [NSString stringWithFormat:@""];
        glStringTex = [[GLString alloc] initWithString:string withAttributes:stanStringAttrib withTextColor:[NSColor colorWithDeviceRed:0.7f green:0.7f blue:0.7f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:0.5f green:0.5f blue:0.5f alpha:0.5f] withBorderColor:[NSColor colorWithDeviceRed:0.5f green:0.7f blue:0.5f alpha:0.0f]];
    }
    return self;
}

- (void) updateFont: (NSColor *) aColor {
    //[glStringTex setScale: 1];
    [stanStringAttrib setObject:aColor forKey:NSForegroundColorAttributeName];
    //float y = 0.299 * aColor.redComponent + 0.587 * aColor.greenComponent + 0.114 * aColor.blueComponent;
    float y = (aColor.redComponent + aColor.greenComponent + aColor.blueComponent)*0.3333;
    if (y > 0.3)
        [glStringTex setBoxColor: [NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.9f]]; //use black background for dark text
    else
        [glStringTex setBoxColor: [NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.9f]]; //use white background for dark text
}

- (void) updateFontScale: (float) scale {
    [glStringTex setScale: scale];
}



- (void)dealloc
{
    [self closeAllOverlays];
    if (prefs->intensityTexture3D != 0) glDeleteTextures(1,&prefs->intensityTexture3D); //release texture memory
    if (prefs->gradientTexture3D != 0) glDeleteTextures(1,&prefs->gradientTexture3D); //release texture memory
    if (prefs->intensityOverlay3D != 0) glDeleteTextures(1,&prefs->intensityOverlay3D); //release texture memory
    if (prefs->gradientOverlay3D != 0) glDeleteTextures(1,&prefs->gradientOverlay3D); //release texture memory
    //if (prefs->glslprogram != NULL) glDeleteObjectARB(prefs->glslprogram); //release GLSL rendering program
    glDeleteProgram(prefs->glslprogramInt);
    glDeleteProgram(prefs->glslprogramIntSobel);
    glDeleteProgram(prefs->glslprogramIntBlur);
    //free(prefs);
    [self freePrefs];
    FslClose(fslio);
    #if !__has_feature(objc_arc) 
    [super dealloc];
    #endif
}

@end
