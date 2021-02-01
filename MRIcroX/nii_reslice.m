//
//  nii_reslice.m
//  MRIpro
//
//  Created by Chris Rorden on 9/2/12.
//  Copyright 2012 U South Carolina. All rights reserved.
//

#import "nii_reslice.h"
#import "nii_definetypes.h"
#include "nii_io.h"
#import "nifti1_io_core.h"
/*
float  deFuzz(float x)
{
    if (fabs(x) < 1.0E-6) return 0.0;
    return x;
}


mat44 transposeMat(mat44 lMat)
{
    mat44 lTemp;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            lTemp.m[j][i] = lMat.m[i][j];
        }
    }
    return lTemp;
}
*/
vec3 coord(vec3 lV, mat44 lMat)
//transform X Y Z by matrix
{
    float lXi = lV.v[0];
    float lYi = lV.v[1];
    float lZi = lV.v[2];
    vec3 ret;
    ret.v[0] = (lXi* lMat.m[0][0]+lYi*lMat.m[0][1]+lZi*lMat.m[0][2]+lMat.m[0][3]);
    ret.v[1] = (lXi* lMat.m[1][0]+lYi*lMat.m[1][1]+lZi*lMat.m[1][2]+lMat.m[1][3]);
    ret.v[2] = (lXi* lMat.m[2][0]+lYi*lMat.m[2][1]+lZi*lMat.m[2][2]+lMat.m[2][3]);
    return ret;
}

vec3 subVec (vec3 lVx, vec3 lV0)
{
    vec3 ret;
    ret.v[0] = lVx.v[0] - lV0.v[0];
    ret.v[1] = lVx.v[1] - lV0.v[1];
    ret.v[2] = lVx.v[2] - lV0.v[2];
    return ret;
}

mat44 voxel2Voxel (mat44 lDestMat, mat44 lSrcMat)
//return matrix to convert source to match target image
{
    //reportMatx(lDestMat); reportMatx(lSrcMat);
    vec3 lV0,lVx,lVy,lVz;
    mat44 lSrcMatInv;
    //Step 1 - compute source coordinates in mm for 4 voxels
    //the first vector is at 0,0,0, with the
    //subsequent voxels being left, up or anterior
    lV0 = setVec3  (0,0,0);
    lVx = setVec3  (1,0,0);
    lVy = setVec3  (0,1,0);
    lVz = setVec3  (0,0,1);
    lV0 = coord(lV0, lDestMat);
    lVx = coord(lVx, lDestMat);
    lVy = coord(lVy, lDestMat);
    lVz = coord(lVz, lDestMat);
    lSrcMatInv = nifti_mat44_inverse( lSrcMat) ;
    //the vectors should be rows not columns....
    //therefore we transpose the matrix
    //lSrcMatInv = Transposemat(lSrcMatInv); //now added into transform
    //the 'transform' multiplies the vector by the matrix
    //

    
    //lV0 = transform (lV0,lSrcMatInv);
    //lVx = transform (lVx,lSrcMatInv);
    //lVy = transform (lVy,lSrcMatInv);
    //lVz = transform (lVz,lSrcMatInv);
    
    lV0 = coord (lV0,lSrcMatInv);
    lVx = coord (lVx,lSrcMatInv);
    lVy = coord (lVy,lSrcMatInv);
    lVz = coord (lVz,lSrcMatInv);
    /*printVec3(lV0);
    printVec3(lVx);
    printVec3(lVy);
    printVec3(lVz);*/
    //subtract each vector from the origin
    // this reveals the voxel-space influence for each dimension
    lVx = subVec(lVx,lV0);
    lVy = subVec(lVy,lV0);
    lVz = subVec(lVz,lV0);
    mat44 ret;
    LOAD_MAT44(ret,lVx.v[0],lVy.v[0],lVz.v[0],lV0.v[0],
               lVx.v[1],lVy.v[1],lVz.v[1],lV0.v[1],
               lVx.v[2],lVy.v[2],lVz.v[2],lV0.v[2]);
    return ret;
/*    lSrcMatInv = setMat44(lVx.v[0],lVy.v[0],lVz.v[0],lV0.v[0],
                          lVx.v[1],lVy.v[1],lVz.v[1],lV0.v[1],
                          lVx.v[2],lVy.v[2],lVz.v[2],lV0.v[2]);
    printMat44(lSrcMatInv); */
}

int reslice2Targ8i (FSLIO* lDest, FSLIO* lSrc, bool lTrilinearInterpolation)
{
    int lXYs,lXs,lYs,lZs,lXi,lYi,lZi,lX,lY,lZ, lXo,lYo,lZo,lMinY,lMinZ,lMaxY,lMaxZ;
    float lXrM1,lYrM1,lZrM1,lXreal,lYreal,lZreal, lZx,lZy,lZz,lYx,lYy,lYz;
    mat44 lMat;
    if (lSrc->niftiptr->datatype != NIFTI_TYPE_UINT8 ) {
        printf("nii_reslice: unsupported format\n");
        return EXIT_FAILURE;
    }
    lMat = voxel2Voxel (lDest->niftiptr->sto_xyz,lSrc->niftiptr->sto_xyz);
    lXs = lSrc->niftiptr->dim[1];
    lYs = lSrc->niftiptr->dim[2];
    lZs = lSrc->niftiptr->dim[3];
    lXYs =lXs*lYs; //slice size
    lX = lDest->niftiptr->dim[1];
    lY = lDest->niftiptr->dim[2];
    lZ = lDest->niftiptr->dim[3];
    float* lXx = (float*) malloc(lX*sizeof(float));
    float* lXy = (float*) malloc(lX*sizeof(float));
    float* lXz = (float*) malloc(lX*sizeof(float));
    for (lXi = 0; lXi < lX; lXi++) {
        lXx[lXi] = lXi*lMat.m[0][0]+lMat.m[0][3];
        lXy[lXi] = lXi*lMat.m[1][0]+lMat.m[1][3];
        lXz[lXi] = lXi*lMat.m[2][0]+lMat.m[2][3];
    }
    bool lOverlap = false;
    int nvol = 1; //convert all non-spatial volumes from source to destination
    for (int vol = 4; vol < 8; vol++) {
        lDest->niftiptr->dim[vol] = lSrc->niftiptr->dim[vol];
        if (lSrc->niftiptr->dim[vol] > 1)
            nvol = nvol * lSrc->niftiptr->dim[vol];
    }
    lDest->niftiptr->nvox = lX*lY*lZ*nvol;
    #ifdef MY_DEBUG //from nii_io.h
    printf("Reslicing %d volumes\n", nvol);
    #endif
    THIS_UINT8 *outbuf = (THIS_UINT8 *) malloc(lDest->niftiptr->nvox*sizeof(THIS_UINT8));
    THIS_UINT8 *inbuf = (THIS_UINT8 *) lSrc->niftiptr->data;
    for (lZi = 0; lZi < lDest->niftiptr->nvox; lZi++)
        outbuf[lZi] = 0;
    int lPos = 0;
    for (int vol= 0; vol < nvol; vol++) {    
        if (lTrilinearInterpolation) {
            for (lZi = 0; lZi <lZ; lZi++) { //for each slice
                //these values are the same for all voxels in the slice
                lZx = lZi*lMat.m[0][2];
                lZy = lZi*lMat.m[1][2];
                lZz = lZi*lMat.m[2][2];
                for (lYi = 0; lYi < lY; lYi++) { //for each row
                    //these values are the same for all voxels in the row
                    lYx =  lYi*lMat.m[0][1];
                    lYy =  lYi*lMat.m[1][1];
                    lYz =  lYi*lMat.m[2][1];
                    for (lXi = 0; lXi < lX; lXi++) { //for each column
                        lXreal = (lXx[lXi]+lYx+lZx);
                        lYreal = (lXy[lXi]+lYy+lZy);
                        lZreal = (lXz[lXi]+lYz+lZz);
                        if ((lXreal >= 0) && (lYreal >= 0) && (lZreal >= 0) &&
                            (lXreal < (lXs -1)) && (lYreal < (lYs -1) ) && (lZreal < (lZs -1)) ) { //voxel in range
                            lOverlap = TRUE;
                            lXo = trunc(lXreal);
                            lYo = trunc(lYreal);
                            lZo = trunc(lZreal);
                            lXreal = lXreal-lXo;
                            lYreal = lYreal-lYo;
                            lZreal = lZreal-lZo;
                            lXrM1 = 1-lXreal;
                            lYrM1 = 1-lYreal;
                            lZrM1 = 1-lZreal;
                            lMinY = lYo*lXs;
                            lMinZ = lZo*lXYs;
                            lMaxY = lMinY+lXs;
                            lMaxZ = lMinZ+lXYs;
                            //change 12/2014 : round required, e.g. binary lesion map with slightly different alignment
                            outbuf[lPos] =
                            round(( (lXrM1*lYrM1*lZrM1)*inbuf[lXo+lMinY+lMinZ])
                             +((lXreal*lYrM1*lZrM1)*inbuf[lXo+1+lMinY+lMinZ]) //x+1
                             +((lXrM1*lYreal*lZrM1)*inbuf[lXo+lMaxY+lMinZ]) //y+1
                             +((lXrM1*lYrM1*lZreal)*inbuf[lXo+lMinY+lMaxZ]) //z+1
                             +((lXreal*lYreal*lZrM1)*inbuf[lXo+1+lMaxY+lMinZ]) //{x+1,y+1}
                             +((lXreal*lYrM1*lZreal)*inbuf[lXo+1+lMinY+lMaxZ]) //{x+1,z+1}
                             +((lXrM1*lYreal*lZreal)*inbuf[lXo+lMaxY+lMaxZ]) //{y+1,z+1}
                             +((lXreal*lYreal*lZreal)*inbuf[lXo+1+lMaxY+lMaxZ]) ); //{x+1,y+1,z+1}
                        } //if voxels in range
                        lPos++;
                    } //for lXi - each column
                } // for lYi - each row
            } //for lZi - each slice
        } else { //if trilinear else nearest neighbor
            for (lZi = 0; lZi <lZ; lZi++) { //for each slice
                //these values are the same for all voxels in the slice
                lZx = lZi*lMat.m[0][2];
                lZy = lZi*lMat.m[1][2];
                lZz = lZi*lMat.m[2][2];
                for (lYi = 0; lYi < lY; lYi++) { //for each row
                    //these values are the same for all voxels in the row
                    lYx =  lYi*lMat.m[0][1];
                    lYy =  lYi*lMat.m[1][1];
                    lYz =  lYi*lMat.m[2][1];
                    for (lXi = 0; lXi < lX; lXi++) { //for each column
                        lXo = round(lXx[lXi]+lYx+lZx);
                        lYo = round(lXy[lXi]+lYy+lZy);
                        lZo = round(lXz[lXi]+lYz+lZz);
                        if ((lXo >= 0) && (lYo >= 0) && (lZo >= 0) &&
                            (lXo < (lXs -1)) && (lYo < (lYs -1) ) && (lZo < lZs) ) {
                            lOverlap = true;
                            lYo = lYo*lXs;
                            lZo = lZo*lXYs;
                            outbuf[lPos] = inbuf[lXo+lYo+lZo];
                        }
                        lPos ++;
                    } //for lXi - each column
                } // for lYi - each row
            } //for lZi - each slice
        } //if trilinear else nearest neighbor
    }//for each volume
    free(lSrc->niftiptr->data);
    lSrc->niftiptr->data = outbuf;
    free(lXx);
    free(lXy);
    free(lXz);
    if (!lOverlap) printf("nii_reslice: warning overlay image does not overlap with background image.\n");   
    return EXIT_SUCCESS;
}

/*FUTURE - only interpolate slices that exist in both volumes
 vec3 vox2vox (int X, int Y, int Z, mat44 lMat) {
    vec3 ret;
    ret.v[0] = X*lMat.m[0][0]+Y*lMat.m[0][1]+Z*lMat.m[0][2]+lMat.m[0][3];
    ret.v[1] = X*lMat.m[1][0]+Y*lMat.m[1][1]+Z*lMat.m[1][2]+lMat.m[1][3];
    ret.v[2] = X*lMat.m[2][0]+Y*lMat.m[2][1]+Z*lMat.m[2][2]+lMat.m[2][3];
    return ret;
}

void voxbound (int X, int Y, int Z, mat44 lMat, vec3  *vlo, vec3 *vhi) {
    vec3 v = vox2vox(X,Y,Z,lMat);
    for (int i = 0; i < 3; i++) {
        if (v.v[i] < vlo->v[i])
            vlo->v[i] = v.v[i];
        if (v.v[i] > vhi->v[i])
            vhi->v[i] = v.v[i];
    }
    
    
}


void bound (FSLIO* lDest, FSLIO* lSrc) {
    mat44 lMat = voxel2Voxel (lSrc->niftiptr->sto_xyz, lDest->niftiptr->sto_xyz);
    //mat44 lMat = voxel2Voxel (lDest->niftiptr->sto_xyz,lSrc->niftiptr->sto_xyz);
    vec3 vlo, vhi;
    vlo = vox2vox(0,0,0,lMat);
    vhi = vlo;
    int x = lSrc->niftiptr->dim[1]-1;
    int y = lSrc->niftiptr->dim[2]-1;
    int z = lSrc->niftiptr->dim[3]-1;
    voxbound(0,   0,   z, lMat, &vlo, &vhi);
    voxbound(0,   y,   0, lMat, &vlo, &vhi);
    voxbound(0,   y,   z, lMat, &vlo, &vhi);
    voxbound(x,   0,   0, lMat, &vlo, &vhi);
    voxbound(x,   0,   z, lMat, &vlo, &vhi);
    voxbound(x,   y,   0, lMat, &vlo, &vhi);
    voxbound(x,   y,   z, lMat, &vlo, &vhi);
    for (int i = 0; i < 3; i++) {
        if (vlo.v[i] < 0)
            vlo.v[i] = 0;
        if (vhi.v[i] > (lDest->niftiptr->dim[i+1]-1))
            vhi.v[i] = (lDest->niftiptr->dim[i+1]-1);
    }
    NSLog(@"Lo %g %g %g", vlo.v[0], vlo.v[1], vlo.v[2]);
    NSLog(@"Hi %g %g %g", vhi.v[0], vhi.v[1], vhi.v[2]);
}
*/

//#define FAST_INTERP

//see renderNoThreads procedure findXBounds


int reslice2Targ16i (FSLIO* lDest, FSLIO* lSrc, bool lTrilinearInterpolation)
{
    int lXYs,lXs,lYs,lZs,lXi,lYi,lZi,lX,lY,lZ, lXo,lYo,lZo;
    float lXreal,lYreal,lZreal, lYx, lYy, lYz, lZx, lZy, lZz;
    mat44 lMat;
    if ( lSrc->niftiptr->datatype != NIFTI_TYPE_INT16 ) {
        printf("nii_reslice: unsupported format\n");
        return EXIT_FAILURE;
    }
    //bound (lDest,  lSrc);
    lMat = voxel2Voxel (lDest->niftiptr->sto_xyz,lSrc->niftiptr->sto_xyz);
    lXs = lSrc->niftiptr->dim[1];
    lYs = lSrc->niftiptr->dim[2];
    lZs = lSrc->niftiptr->dim[3];
    lXYs =lXs*lYs; //slice size
    lX = lDest->niftiptr->dim[1];
    lY = lDest->niftiptr->dim[2];
    lZ = lDest->niftiptr->dim[3];
    float* lXx = (float*) malloc(lX*sizeof(float));
    float* lXy = (float*) malloc(lX*sizeof(float));
    float* lXz = (float*) malloc(lX*sizeof(float));
    for (lXi = 0; lXi < lX; lXi++) {
        lXx[lXi] = lXi*lMat.m[0][0]+lMat.m[0][3];
        lXy[lXi] = lXi*lMat.m[1][0]+lMat.m[1][3];
        lXz[lXi] = lXi*lMat.m[2][0]+lMat.m[2][3];
    }
    bool lOverlap = false;
    int nvol = 1; //convert all non-spatial volumes from source to destination
    for (int vol = 4; vol < 8; vol++) {
        lDest->niftiptr->dim[vol] = lSrc->niftiptr->dim[vol];
        if (lSrc->niftiptr->dim[vol] > 1)
            nvol = nvol * lSrc->niftiptr->dim[vol];
    }
    lDest->niftiptr->nvox = lX*lY*lZ*nvol;
#ifdef MY_DEBUG //from nii_io.h
    printf("Reslicing %d volumes\n", nvol);
#endif
    //NSDate *startTime = [NSDate date]; //
    THIS_INT16 *outbuf = (THIS_INT16 *) malloc(lDest->niftiptr->nvox*sizeof(THIS_INT16));
    THIS_INT16 *inbuf = (THIS_INT16 *) lSrc->niftiptr->data;
    for (lZi = 0; lZi < lDest->niftiptr->nvox; lZi++)
        outbuf[lZi] = 0;
    int lPos = 0;
    for (int vol= 0; vol < nvol; vol++) {
        if (lTrilinearInterpolation) {
            lPos --;
            for (lZi = 0; lZi <lZ; lZi++) { //for each slice
                lZx = lZi*lMat.m[0][2];
                lZy = lZi*lMat.m[1][2];
                lZz = lZi*lMat.m[2][2];
                for (lYi = 0; lYi < lY; lYi++) { //for each row
                    lYx = lYi*lMat.m[0][1];
                    lYy = lYi*lMat.m[1][1];
                    lYz = lYi*lMat.m[2][1];
                    for (lXi = 0; lXi < lX; lXi++) { //for each column
                        lPos++;
                        lXreal = (lXx[lXi]+lYx+lZx);
                        //if ((lXreal < 0) || (lXreal >= (lXs -1))) continue;
                        lYreal = (lXy[lXi]+lYy+lZy);
                        //if ((lYreal < 0) || (lYreal >= (lYs -1))) continue;
                        lZreal = (lXz[lXi]+lYz+lZz);
                        //if ((lZreal < 0) || (lZreal >= (lZs -1))) continue;
                        //{
                        if ((lXreal >= 0) && (lYreal >= 0) && (lZreal >= 0) && (lXreal < (lXs -1)) && (lYreal < (lYs -1) ) && (lZreal < (lZs -1)) )
                        { //voxel in range
                            lOverlap = TRUE;
                            lXo = trunc(lXreal);
                            lYo = trunc(lYreal);
                            lZo = trunc(lZreal);
                            lXreal = lXreal-lXo;
                            lYreal = lYreal-lYo;
                            lZreal = lZreal-lZo;
#ifdef FAST_INTERP //see Steve Hill's "Tri-Linear Interpolation" in Graphic Gems IV - no influence on modern computers, might help float interp
                            int vx = lXo + (lYo*lXs) + (lZo*lXYs);
                            float x00 = inbuf[vx]     + (lXreal * (inbuf[vx+1]     - inbuf[vx]));
                            float x01 = inbuf[vx+lXs] + (lXreal * (inbuf[vx+1+lXs] - inbuf[vx+lXs]));
                            float x10 = inbuf[vx+lXYs] + (lXreal * (inbuf[vx+1+lXYs] - inbuf[vx+lXYs]));
                            float x11 = inbuf[vx+lXs+lXYs] + (lXreal * (inbuf[vx+1+lXs+lXYs] - inbuf[vx+lXs+lXYs]));
                            float xy0 = x00 + (lYreal * (x01 - x00));
                            float xy1 = x10 + (lYreal * (x11 - x10));
                            outbuf[lPos] = round ( xy0 + lZreal * (xy1 - xy0));
#else
                            float lXrM1 = 1-lXreal;
                            float lYrM1 = 1-lYreal;
                            float lZrM1 = 1-lZreal;
                            int lMinY = lYo*lXs;
                            int lMinZ = lZo*lXYs;
                            int lMaxY = lMinY+lXs;
                            int lMaxZ = lMinZ+lXYs;
                            // 12/2014 - round is better than default trunc
                            outbuf[lPos] =
                            round(( (lXrM1*lYrM1*lZrM1)*inbuf[lXo+lMinY+lMinZ])
                                  +((lXreal*lYrM1*lZrM1)*inbuf[lXo+1+lMinY+lMinZ]) //x+1
                                  +((lXrM1*lYreal*lZrM1)*inbuf[lXo+lMaxY+lMinZ]) //y+1
                                  +((lXrM1*lYrM1*lZreal)*inbuf[lXo+lMinY+lMaxZ]) //z+1
                                  +((lXreal*lYreal*lZrM1)*inbuf[lXo+1+lMaxY+lMinZ]) //{x+1,y+1}
                                  +((lXreal*lYrM1*lZreal)*inbuf[lXo+1+lMinY+lMaxZ]) //{x+1,z+1}
                                  +((lXrM1*lYreal*lZreal)*inbuf[lXo+lMaxY+lMaxZ]) //{y+1,z+1}
                                  +((lXreal*lYreal*lZreal)*inbuf[lXo+1+lMaxY+lMaxZ]) ); //{x+1,y+1,z+1}
#endif
                        } //if voxels in range
                        
                    } //for lXi - each column
                } // for lYi - each row
            } //for lZi - each slice
            
        } else { //if trilinear else nearest neighbor
            for (lZi = 0; lZi <lZ; lZi++) { //for each slice
                lZx = lZi*lMat.m[0][2];
                lZy = lZi*lMat.m[1][2];
                lZz = lZi*lMat.m[2][2];
                for (lYi = 0; lYi < lY; lYi++) { //for each row
                    lYx = lYi*lMat.m[0][1];
                    lYy = lYi*lMat.m[1][1];
                    lYz = lYi*lMat.m[2][1];
                    for (lXi = 0; lXi < lX; lXi++) { //for each column
                        lXo = round(lXx[lXi]+lYx+lZx);
                        lYo = round(lXy[lXi]+lYy+lZy);
                        lZo = round(lXz[lXi]+lYz+lZz);
                        if ((lXo >= 0) && (lYo >= 0) && (lZo >= 0) &&
                            (lXo < (lXs -1)) && (lYo < (lYs -1) ) && (lZo < lZs) ) {
                            lOverlap = true;
                            lYo = lYo*lXs;
                            lZo = lZo*lXYs;
                            outbuf[lPos] = inbuf[lXo+lYo+lZo];
                        }
                        lPos ++;
                    } //for lXi - each column
                } // for lYi - each row
            } //for lZi - each slice
        } //if trilinear else nearest neighbor
    } //for each volume
    //printf("min..max %d..%d of %lu %lu\n", mn, mx, lSrc->niftiptr->nvox, lDest->niftiptr->nvox);
    free(lSrc->niftiptr->data);
    lSrc->niftiptr->data = outbuf;
    free(lXx);
    free(lXy);
    free(lXz);
    //NSLog(@"Interpolation Time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
    if (!lOverlap) printf("nii_reslice: warning overlay image does not overlap with background image.\n");
    return EXIT_SUCCESS;
}

int reslice2Targ32f (FSLIO* lDest, FSLIO* lSrc, bool lTrilinearInterpolation)
{
    int lXYs,lXs,lYs,lZs,lXi,lYi,lZi,lX,lY,lZ, lXo,lYo,lZo,lMinY,lMinZ,lMaxY,lMaxZ;
    float lXrM1,lYrM1,lZrM1,lXreal,lYreal,lZreal, lZx,lZy,lZz,lYx,lYy,lYz;
    mat44 lMat;
    if (sizeof(SCALED_IMGDATA) != lSrc->niftiptr->nbyper ) {
        printf("nii_reslice: unsupported format\n");
        return EXIT_FAILURE;
    }
    lMat = voxel2Voxel (lDest->niftiptr->sto_xyz,lSrc->niftiptr->sto_xyz);
    lXs = lSrc->niftiptr->dim[1];
    lYs = lSrc->niftiptr->dim[2];
    lZs = lSrc->niftiptr->dim[3];
    lXYs =lXs*lYs; //slice size
    lX = lDest->niftiptr->dim[1];
    lY = lDest->niftiptr->dim[2];
    lZ = lDest->niftiptr->dim[3];
    float* lXx = (float*) malloc(lX*sizeof(float));
    float* lXy = (float*) malloc(lX*sizeof(float));
    float* lXz = (float*) malloc(lX*sizeof(float));
    for (lXi = 0; lXi < lX; lXi++) {
        lXx[lXi] = lXi*lMat.m[0][0]+lMat.m[0][3];
        lXy[lXi] = lXi*lMat.m[1][0]+lMat.m[1][3];
        lXz[lXi] = lXi*lMat.m[2][0]+lMat.m[2][3];
    }
    bool lOverlap = false;
    int nvol = 1; //convert all non-spatial volumes from source to destination
    for (int vol = 4; vol < 8; vol++) {
        lDest->niftiptr->dim[vol] = lSrc->niftiptr->dim[vol];
        if (lSrc->niftiptr->dim[vol] > 1)
            nvol = nvol * lSrc->niftiptr->dim[vol];
    }
    lDest->niftiptr->nvox = lX*lY*lZ*nvol;
    #ifdef MY_DEBUG //from nii_io.h
        printf("Reslicing %d volumes\n", nvol);
    #endif
    SCALED_IMGDATA *outbuf = (SCALED_IMGDATA *) malloc(lDest->niftiptr->nvox*sizeof(SCALED_IMGDATA));
    SCALED_IMGDATA *inbuf = (SCALED_IMGDATA *) lSrc->niftiptr->data;
    for (lZi = 0; lZi < lDest->niftiptr->nvox; lZi++)
        outbuf[lZi] = 0.0;
    int lPos = 0;
    for (int vol= 0; vol < nvol; vol++) {
        if (lTrilinearInterpolation) {
            //NSDate *startTime = [NSDate date]; //NSLog(@"Interpolation Time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
            for (lZi = 0; lZi <lZ; lZi++) { //for each slice
                //these values are the same for all voxels in the slice
                lZx = lZi*lMat.m[0][2];
                lZy = lZi*lMat.m[1][2];
                lZz = lZi*lMat.m[2][2];
                for (lYi = 0; lYi < lY; lYi++) { //for each row
                    //these values are the same for all voxels in the row
                    lYx =  lYi*lMat.m[0][1];
                    lYy =  lYi*lMat.m[1][1];
                    lYz =  lYi*lMat.m[2][1];
                    for (lXi = 0; lXi < lX; lXi++) { //for each column
                        lXreal = (lXx[lXi]+lYx+lZx);
                        lYreal = (lXy[lXi]+lYy+lZy);
                        lZreal = (lXz[lXi]+lYz+lZz);
                        if ((lXreal >= 0) && (lYreal >= 0) && (lZreal >= 0) &&
                            (lXreal < (lXs -1)) && (lYreal < (lYs -1) ) && (lZreal < (lZs -1)) ) { //voxel in range
                            lOverlap = TRUE;
                            lXo = trunc(lXreal);
                            lYo = trunc(lYreal);
                            lZo = trunc(lZreal);
                            lXreal = lXreal-lXo;
                            lYreal = lYreal-lYo;
                            lZreal = lZreal-lZo;
                            lXrM1 = 1-lXreal;
                            lYrM1 = 1-lYreal;
                            lZrM1 = 1-lZreal;
                            lMinY = lYo*lXs;
                            lMinZ = lZo*lXYs;
                            lMaxY = lMinY+lXs;
                            lMaxZ = lMinZ+lXYs;
                            outbuf[lPos] =
                            (( (lXrM1*lYrM1*lZrM1)*inbuf[lXo+lMinY+lMinZ])
                             +((lXreal*lYrM1*lZrM1)*inbuf[lXo+1+lMinY+lMinZ]) //x+1
                             +((lXrM1*lYreal*lZrM1)*inbuf[lXo+lMaxY+lMinZ]) //y+1
                             +((lXrM1*lYrM1*lZreal)*inbuf[lXo+lMinY+lMaxZ]) //z+1
                             +((lXreal*lYreal*lZrM1)*inbuf[lXo+1+lMaxY+lMinZ]) //{x+1,y+1}
                             +((lXreal*lYrM1*lZreal)*inbuf[lXo+1+lMinY+lMaxZ]) //{x+1,z+1}
                             +((lXrM1*lYreal*lZreal)*inbuf[lXo+lMaxY+lMaxZ]) //{y+1,z+1}
                             +((lXreal*lYreal*lZreal)*inbuf[lXo+1+lMaxY+lMaxZ]) ); //{x+1,y+1,z+1}
                        } //if voxels in range
                        lPos++;
                    } //for lXi - each column
                } // for lYi - each row
            } //for lZi - each slice
            //NSLog(@"Interpolation Time: %f", [[NSDate date] timeIntervalSinceDate:startTime]);
        } else { //if trilinear else nearest neighbor
            for (lZi = 0; lZi <lZ; lZi++) { //for each slice
                //these values are the same for all voxels in the slice
                lZx = lZi*lMat.m[0][2];
                lZy = lZi*lMat.m[1][2];
                lZz = lZi*lMat.m[2][2];
                for (lYi = 0; lYi < lY; lYi++) { //for each row
                    //these values are the same for all voxels in the row
                    lYx =  lYi*lMat.m[0][1];
                    lYy =  lYi*lMat.m[1][1];
                    lYz =  lYi*lMat.m[2][1];
                    for (lXi = 0; lXi < lX; lXi++) { //for each column
                        lXo = round(lXx[lXi]+lYx+lZx);
                        lYo = round(lXy[lXi]+lYy+lZy);
                        lZo = round(lXz[lXi]+lYz+lZz);
                        if ((lXo >= 0) && (lYo >= 0) && (lZo >= 0) &&
                            (lXo < (lXs -1)) && (lYo < (lYs -1) ) && (lZo < lZs) ) {
                            lOverlap = true;
                            lYo = lYo*lXs;
                            lZo = lZo*lXYs;
                            outbuf[lPos] = inbuf[lXo+lYo+lZo];
                        }
                        lPos ++;
                    } //for lXi - each column
                } // for lYi - each row
            } //for lZi - each slice
        } //if trilinear else nearest neighbor
} //for every 3D volume
    free(lSrc->niftiptr->data);
    lSrc->niftiptr->data = outbuf;
    free(lXx);
    free(lXy);
    free(lXz);
    if (!lOverlap) printf("nii_reslice: warning overlay image does not overlap with background image.\n");   
    return EXIT_SUCCESS;
}

int hdr2Targ (FSLIO* lDest, FSLIO* lSrc)
//make source header have same spatial information as destination
{
    for (int i = 1; i < 3; i++) {
        lSrc->niftiptr->dim[i] = lDest->niftiptr->dim[i];
        lSrc->niftiptr->pixdim[i] = lDest->niftiptr->pixdim[i];        
    }
    //There is a lot of redundant data in the FSLIO structure... so we need to fill all copies
    // nx,ny,nz are redundant with dim[1]..[3]; 
    // dx,dy,dz are redundant with pixdim[1]..[3]
    // quatern_b , quatern_c , quatern_d , qoffset_x , qoffset_y , qoffset_z , qfac are redundant with qto_xyz
    //The non-array structures are DEPRECATED - only kept only to maintain FSLIO compatibility
    lSrc->niftiptr->nx   = lSrc->niftiptr->dim[1];
    lSrc->niftiptr->ny   = lSrc->niftiptr->dim[2];
    lSrc->niftiptr->nz   = lSrc->niftiptr->dim[3];  
    lSrc->niftiptr->dx   = lSrc->niftiptr->pixdim[1];
    lSrc->niftiptr->dy   = lSrc->niftiptr->pixdim[2];
    lSrc->niftiptr->dz   = lSrc->niftiptr->pixdim[3];
    //adjust the quaternion (if set)
    lSrc->niftiptr->qform_code = lDest->niftiptr->qform_code;
    lSrc->niftiptr->qto_xyz = lDest->niftiptr->qto_xyz;
    lSrc->niftiptr->qto_ijk = lDest->niftiptr->qto_ijk;
    lSrc->niftiptr->sform_code = lDest->niftiptr->sform_code;
    lSrc->niftiptr->sto_xyz = lDest->niftiptr->sto_xyz;
    lSrc->niftiptr->sto_ijk = lDest->niftiptr->sto_ijk;
    return EXIT_SUCCESS;
}

bool isFloatDiffX (float a, float b) {
    return (fabs (a - b) > FLT_EPSILON);
} //isFloatDiff()

bool identicalAlignment  (FSLIO* lDest, FSLIO* lSrc)
{
    for (int i = 1; i < 3; i++) {
        //NSLog(@"%d %d %g %g",lSrc->niftiptr->dim[i] ,lDest->niftiptr->dim[i], lSrc->niftiptr->pixdim[i],lDest->niftiptr->pixdim[i]);
        if (lSrc->niftiptr->dim[i] != lDest->niftiptr->dim[i]) return FALSE;
        if (isFloatDiffX(lSrc->niftiptr->pixdim[i],lDest->niftiptr->pixdim[i])) return FALSE;
        //if (lSrc->niftiptr->pixdim[i] != lDest->niftiptr->pixdim[i]) return FALSE;
    }
    if ((lDest->niftiptr->sform_code == NIFTI_XFORM_UNKNOWN) || (lSrc->niftiptr->sform_code == NIFTI_XFORM_UNKNOWN)){
        printf("unknown or uncorrected spatial transforms: overlay loaded as saved to disk");
        return TRUE; //cross your fingers
    }
    for (int i = 1; i < 4; i++) {
        for (int j = 1; j < 4; j++) {
            //NSLog(@"%g %g",lSrc->niftiptr->sto_xyz.m[i][j], lDest->niftiptr->sto_xyz.m[i][j]);
            if (fabs (lSrc->niftiptr->sto_xyz.m[i][j] - lDest->niftiptr->sto_xyz.m[i][j]) > FLT_EPSILON) return FALSE;
            //if (lSrc->niftiptr->sto_xyz.m[i][j] != lDest->niftiptr->sto_xyz.m[i][j]) return FALSE;
        }
    }  
    return TRUE;
}

int reslice2Targ (FSLIO* lDest, FSLIO* lSrc, bool lTrilinearInterpolation)
{
    //bool lTrilinearInterpolation = true;
    if (identicalAlignment(lDest,lSrc)) {
        #ifdef MY_DEBUG //from nii_io.h
        printf("Identical alignment - no need to reslice\n");
        #endif
        return EXIT_SUCCESS;
    }
    
    int ret;
    if ( lSrc->niftiptr->datatype == NIFTI_TYPE_UINT8) { //THIS_UINT8
        ret = reslice2Targ8i (lDest, lSrc, lTrilinearInterpolation);
    } else if ( lSrc->niftiptr->datatype == NIFTI_TYPE_INT16) { //THIS_INT16
        ret = reslice2Targ16i (lDest, lSrc, lTrilinearInterpolation);
    } else if (sizeof(SCALED_IMGDATA) == lSrc->niftiptr->nbyper ) { //SCALED_IMGDATA
        ret = reslice2Targ32f (lDest, lSrc, lTrilinearInterpolation);
    } else {
        NSLog(@"nii_reslice: Unsupported data type!\n");
        return EXIT_FAILURE;
    }
    if (ret == EXIT_FAILURE) return ret;
    hdr2Targ(lDest,lSrc);
    return ret;
}
