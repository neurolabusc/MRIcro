#include "nii_foreign.h"
#include "nii_io.h"
#include "nifti1.h"
#import "nifti1_io_core.h"
#include <stdio.h>
#import <Foundation/Foundation.h>
#import "nii_dicom.h" //rgb planar
#include <stdlib.h>  // for memory alloc/free


int THD_daxes_to_NIFTI(struct nifti_1_header *nhdr, vec3 xyzDelta, vec3 xyzOrigin, ivec3 orientSpecific )
//thd_niftiwrite
{
    static char ORIENT_xyz[]   = "xxyyzzg" ;  // DICOM directions are x = R->L , y = A->P , z = I->S
    static char ORIENT_sign[]  = "+--++-" ; //! Determines if orientation code (0..5) is DICOM positive or negative.
    int nif_x_axnum=0, nif_y_axnum=0, nif_z_axnum=0;
    int ii;
    char axcode[3], axsign[3] ;
    float axstep[3] , axstart[3] ;
    int   axnum[3] ;
    axnum[0] = nhdr->dim[1];
    axnum[1] = nhdr->dim[2];
    axnum[2] = nhdr->dim[3];
    axcode[0] = ORIENT_xyz[ orientSpecific.v[0] ] ;
    axcode[1] = ORIENT_xyz[ orientSpecific.v[1] ] ;
    axcode[2] = ORIENT_xyz[ orientSpecific.v[2] ] ;
    axsign[0] = ORIENT_sign[ orientSpecific.v[0] ] ;
    axsign[1] = ORIENT_sign[ orientSpecific.v[1] ] ;
    axsign[2] = ORIENT_sign[ orientSpecific.v[2] ] ;
    axstep[0] = xyzDelta.v[0] ;
    axstep[1] = xyzDelta.v[1]  ;
    axstep[2] = xyzDelta.v[2]  ;
    axstart[0] = xyzOrigin.v[0] ;
    axstart[1] = xyzOrigin.v[1] ;
    axstart[2] = xyzOrigin.v[2] ;
    for (ii = 0 ; ii < 3 ; ii++ ) {
        if (axcode[ii] == 'x') {
            nif_x_axnum = ii ;
        } else if (axcode[ii] == 'y') {
            nif_y_axnum = ii ;
        } else nif_z_axnum = ii ;
    }
    mat44 qto_xyz;
    qto_xyz.m[0][0] = qto_xyz.m[0][1] = qto_xyz.m[0][2] =
    qto_xyz.m[1][0] = qto_xyz.m[1][1] = qto_xyz.m[1][2] =
    qto_xyz.m[2][0] = qto_xyz.m[2][1] = qto_xyz.m[2][2] = 0.0 ;
    //-- set voxel and time deltas and units --
    nhdr->pixdim[1] = fabs ( axstep[0] ) ;
    nhdr->pixdim[2] = fabs ( axstep[1] ) ;
    nhdr->pixdim[3] = fabs ( axstep[2] ) ;
    qto_xyz.m[0][nif_x_axnum] = - axstep[nif_x_axnum];
    qto_xyz.m[1][nif_y_axnum] = - axstep[nif_y_axnum];
    qto_xyz.m[2][nif_z_axnum] =   axstep[nif_z_axnum];
    nhdr->qoffset_x =  -axstart[nif_x_axnum] ;
    nhdr->qoffset_y =  -axstart[nif_y_axnum];
    nhdr->qoffset_z =  axstart[nif_z_axnum];
    qto_xyz.m[0][3] = nhdr->qoffset_x ;
    qto_xyz.m[1][3] = nhdr->qoffset_y ;
    qto_xyz.m[2][3] = nhdr->qoffset_z ;
    float  dumdx, dumdy, dumdz; //dumqx, dumqy, dumqz,
    nifti_mat44_to_quatern( qto_xyz , &nhdr->quatern_b, &nhdr->quatern_c, &nhdr->quatern_d,&nhdr->qoffset_x, &nhdr->qoffset_y, &nhdr->qoffset_z, &dumdx, &dumdy, &dumdz,&nhdr->pixdim[0]) ;
    nhdr->qform_code = NIFTI_XFORM_SCANNER_ANAT;
    nhdr->srow_x[0]=qto_xyz.m[0][0]; nhdr->srow_x[1]=qto_xyz.m[0][1]; nhdr->srow_x[2]=qto_xyz.m[0][2]; nhdr->srow_x[3]=qto_xyz.m[0][3];
    nhdr->srow_y[0]=qto_xyz.m[1][0]; nhdr->srow_y[1]=qto_xyz.m[1][1]; nhdr->srow_y[2]=qto_xyz.m[1][2]; nhdr->srow_y[3]=qto_xyz.m[1][3];
    nhdr->srow_z[0]=qto_xyz.m[2][0]; nhdr->srow_z[1]=qto_xyz.m[2][1]; nhdr->srow_z[2]=qto_xyz.m[2][2]; nhdr->srow_z[3]=qto_xyz.m[2][3];
    nhdr->sform_code = NIFTI_XFORM_SCANNER_ANAT;
    return EXIT_SUCCESS;
}

void clearNifti(struct nifti_1_header  *nhdr) {
    for (int i=1; i<8; i++)
        nhdr->dim[i] = 1;
}

void convertForeignToNifti(struct nifti_1_header  *nhdr)
{
    nhdr->sizeof_hdr = 348; //used to signify header does not need to be byte-swapped
    nhdr->scl_inter = 0;
    nhdr->scl_slope = 1;
    nhdr->cal_max = -1;
    nhdr->cal_min = 0;
    nhdr->magic[0]='n';
    nhdr->magic[1]='+';
    nhdr->magic[2]='1';
    nhdr->magic[3]='\0';
    nhdr->sform_code = 1;
    for (int i = 3; i < 8; i++)
        if (nhdr->dim[i] < 1) nhdr->dim[i] = 1; //for 2D images the 3rd dim is not specified and set to zero, some tools want the number of volumes (dim[4]) >0
    int nonSpatialMult = 1;
    for (int i=4; i<8; i++)
        if (nhdr->dim[i] > 1) nonSpatialMult = nonSpatialMult * nhdr->dim[i];
    nhdr->dim[0] = 3; //for 2D images the 3rd dim is not specified and set to zero
    if (nonSpatialMult > 1) {
        nhdr->dim[0] = 4;
        nhdr->dim[4] = nonSpatialMult;
        for (int i=5; i<8; i++)
            nhdr->dim[i]= 0;
    }
    nhdr->bitpix = 8;
    if (nhdr->datatype == DT_RGB24) nhdr->bitpix = 24;
    if ((nhdr->datatype == 4) || (nhdr->datatype == 512)) nhdr->bitpix = 16;
    if ((nhdr->datatype == 8) || (nhdr->datatype == 16) || (nhdr->datatype == 768)) nhdr->bitpix = 32;
    if ((nhdr->datatype == 32) || (nhdr->datatype == 64) || (nhdr->datatype == 1024) || (nhdr->datatype == 1280)) nhdr->bitpix = 64;
    nhdr->sform_code = 1;
    for (int i = 0; i < 10; i++)
        nhdr->data_type[i] = 0;
    for (int i = 0; i < 18; i++)
        nhdr->db_name[i] = 0;
    for (int i = 0; i < 16; i++)
        nhdr->intent_name[i] = 0;
    for (int i = 0; i < 80; i++)
        nhdr->descrip[i] = 0;
    for (int i = 0; i < 24; i++)
        nhdr->aux_file[i] = 0;

}

NSString * NewFileExtX(NSString *oldname, NSString *newx)
{
    NSString* newname = [oldname stringByDeletingPathExtension];
    newname = [newname stringByAppendingString: newx];
    return newname;
}


int afni_readhead(NSString * fname, NSString ** imgname,  struct nifti_1_header *nhdr, long * gzBytes, bool * swapEndian)
//http://afni.nimh.nih.gov/afni/doc/faq/40
//portions of this function from http://afni.nimh.nih.gov/afni/doc/source/3ddata_8h.html
//see 3dAFNItoNIFTI.c
{
    *gzBytes = 0;
    *imgname = NewFileExtX(fname, @".BRIK");
    if (![[NSFileManager defaultManager] fileExistsAtPath:*imgname]) {
        *imgname = NewFileExtX(fname, @".BRIK.gz");
        *gzBytes = K_gzBytes_headeruncompressed;
    }
    *swapEndian = false;
    for(int ii=0 ; ii < 8 ; ii++)
        nhdr->dim[ii] = 0;
    const char * ATR_typestr[] = {"string-attribute" , "float-attribute" , "integer-attribute"};
#define THD_MAX_NAME   256
#define MAX_ATR 16384
#define FAIL 0
#define SUCCESS 1
#define ATR_STRING_TYPE   0
#define ATR_FLOAT_TYPE    1
#define ATR_INT_TYPE      2
#define FIRST_ATR_TYPE 0
#define LAST_ATR_TYPE  2
    FILE *header_file;
    header_file = fopen([fname cStringUsingEncoding:1], "r");
    if (header_file == NULL) {
        NSLog(@"Error opening %@ ", fname);
        return EXIT_FAILURE;
    }
    char aname[THD_MAX_NAME] , atypestr[THD_MAX_NAME] ;
    int  atype, acount, code , ii ;
    NSString *vString;
    float vFloat[MAX_ATR];
    int vInt[MAX_ATR];
    bool probMap = false; //MNIa_caez_gw_18+tlrc is BOTH an atlas and a continuous probability map: do not use indexed colors for these!
    //mat44  to_dicom_mat; //for tag IJK_TO_DICOM
    ivec3 orientSpecific;  //for tag ORIENT_SPECIFIC - slice direction LAS, RAI, etc...
    vec3 xyzOrigin; //for tag ORIGIN - volume translation
    vec3 xyzDelta = {1,1,1}; //for tag DELTA - distance between voxel centers
    //float floatFactor = 1;//for tag BRICK_FLOAT_FACS;
    int nVols = 1;
    do{
        atypestr[0] = aname[0] = '\0' ; acount = 0 ;
        code = fscanf( header_file ," type = %s name = %s count = %d" ,atypestr , aname , &acount ) ;
        if( code == 3 && acount == 0 ) continue ;  /* 24 Nov 2009 */
        code = (code != 3 || acount < 1) ? FAIL : SUCCESS ;
        if( code == FAIL ) break ;  /* bad read */
        //NSLog(@" %s %s %d", atypestr, aname, acount);
        for( atype=FIRST_ATR_TYPE ; atype <= LAST_ATR_TYPE ; atype++ )
            if( strcmp(atypestr,ATR_typestr[atype]) == 0 ) break ;
        if( atype > LAST_ATR_TYPE ){ // bad read
            //code = FAIL; //not required - we break from do{}
            break ;
        }
        code = 0 ;
        switch( atype ){
            case ATR_FLOAT_TYPE:{
                char bbb[256] ;
                int icount = (acount > MAX_ATR) ? MAX_ATR : acount ;
                for( ii=0 ; ii < icount ; ii++ ){
                    bbb[0] = '\0' ; fscanf( header_file , "%255s" , bbb ) ;
                    if( bbb[0] != '\0' ){
                        vFloat[ii] = strtod( bbb , NULL ) ;
                        code++;
                    }
                }
                code = (code != acount) ? FAIL : SUCCESS ;
            }
                break ;
            case ATR_INT_TYPE:{
                int icount = (acount > MAX_ATR) ? MAX_ATR : acount ;
                for( ii=0 ; ii < icount ; ii++ )
                    code += fscanf( header_file , "%d" , &vInt[ii] ) ;
                code = (code != acount) ? FAIL : SUCCESS ;
            }
                break ;
            case ATR_STRING_TYPE:{
                fscanf( header_file , " '" ) ;
                char cString[acount+1];
                cString[acount] = '\0'; //terminate string
                for( ii=0 ; ii < acount ; ii++ )
                    code += fscanf( header_file , "%c" , &cString[ii] ) ;
                code = (code != acount) ? FAIL : SUCCESS ;
                vString = [NSString stringWithCString:cString encoding:NSASCIIStringEncoding];
                vString = [vString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                //NSLog(@"%d:%s:",acount, cString);
            }
                break ;
        }  // end of switch
        if( code == FAIL ) break ;  // exit if an error!
        if (strcmp(aname,"BRICK_TYPES") == 0) {
            if (vInt[0] == 0) {
                nhdr->datatype = 2;
                //nhdr->bitpix = 8; //8 bit char
            } else if (vInt[0] == 1) {
                nhdr->datatype = 4;
                //nhdr->bitpix = 16; //16 bit signed int
            } else if (vInt[0] == 3) {
                nhdr->datatype = 16;
                //nhdr->bitpix = 32; //32-bit float
            } else {
                NSLog(@"Unsupported BRICK_TYPES %d", vInt[0]);
                return EXIT_FAILURE;
            }
            if (acount > 1) { //check that all volumes are of the same datatype
                nVols = acount;
                bool sameDatatype = true;
                for( ii=1 ; ii < acount ; ii++ )
                    if (vInt[0] != vInt[ii]) sameDatatype = false;
                if (!sameDatatype) {
                    NSLog(@"Unsupported BRICK_TYPES feature: datatype varies between sub-bricks");
                    return EXIT_FAILURE;
                }
            } //if acount > 0
            //NSLog(@"HEAD datatype %d bitpix %d",nhdr->datatype, nhdr->bitpix);
        } else if (strcmp(aname,"BRICK_FLOAT_FACS") == 0) {
            if (vFloat[0] > 0) nhdr->scl_slope = vFloat[0];
            if (acount > 1) { //check that all volumes are of the same datatype
                bool sameDatatype = true;
                for( ii=1 ; ii < acount ; ii++ )
                    if (vFloat[0] != vFloat[ii]) sameDatatype = false;
                if (!sameDatatype) {
                    NSLog(@"WARNING: Unsupported BRICK_FLOAT_FACS feature: scale factor varies between sub-bricks");
                }
            }//if acount > 0
        } else if (strcmp(aname,"DATASET_DIMENSIONS") == 0) {
            int icount = (acount > 7) ? 7 : acount;
            for( ii=0 ; ii < icount ; ii++ )
                nhdr->dim[ii+1] = vInt[ii];
            int nDim = 3;
            for(int ii=4; ii < 8 ; ii++ )
                if (nhdr->dim[ii] > 0) nDim++;
            nhdr->dim[0] = nDim; //Dim[0] stores the number of dimensions
            //if (nDim > 3) NSLog(@"Warning: This software does not yet read the TR (tag TAXIS_FLOATS) 666");
            //NSLog(@"HEAD dimensions %dx%dx%dx%d",nhdr->dim[1], nhdr->dim[2],nhdr->dim[3],nhdr->dim[4]);
        } else if (strcmp(aname,"BYTEORDER_STRING") == 0) {
            //LITTLE_ENDIAN=LSB_FIRST, BIG_ENDIAN=MSB_FIRST http://afni.nimh.nih.gov/pub/dist/doc/program_help/README.environment.html
#ifdef __BIG_ENDIAN__
            if ([vString rangeOfString:@"LSB_FIRST" options:NSCaseInsensitiveSearch].location != NSNotFound)
                *swapEndian = true;
#endif
#ifdef __LITTLE_ENDIAN__
            if ([vString rangeOfString:@"MSB_FIRST" options:NSCaseInsensitiveSearch].location != NSNotFound)
                *swapEndian = true;
#endif
            //NSLog(@"HEAD byte order %@",vString);// [vString substringToIndex:1]);
        } else if (strcmp(aname,"ORIENT_SPECIFIC") == 0) {
            int icount = (acount > 3) ? 3 : acount;
            for( ii=0 ; ii < icount ; ii++ )
                orientSpecific.v[ii] = vInt[ii];
            //NSLog(@"HEAD orient specific %d %d %d",orientSpecific.v[0],orientSpecific.v[1],orientSpecific.v[2]);
        } /*else if (strcmp(aname,"IJK_TO_DICOM") == 0) { //Disabled: 3dAFNItoNIFTI appears to ignore the affine transform?
           int icount = (acount > 12) ? 12 : acount;
           float mtx[12];
           for( ii=0 ; ii < icount ; ii++ )
           mtx[ii] = vFloat[ii];
           LOAD_MAT44( to_dicom_mat ,
           mtx[0],mtx[1],mtx[2],mtx[3],
           mtx[4],mtx[5],mtx[6],mtx[7],
           mtx[8],mtx[9],mtx[10],mtx[11]) ;
           //NSLog(@"HEAD IJKtoDICOM= [%f %f %f %f; %f %f %f %f; %f %f %f %f; 0 0 0 1]",mtx[0],mtx[1],mtx[2],mtx[3], mtx[4],mtx[5],mtx[6],mtx[7], mtx[8],mtx[9],mtx[10],mtx[11]);
           }*/  else if (strcmp(aname,"ORIGIN") == 0) {
               int icount = (acount > 3) ? 3 : acount;
               for( ii=0 ; ii < icount ; ii++ )
                   xyzOrigin.v[ii] = vFloat[ii];
               //NSLog(@"HEAD origin %g %g %g",xyzOrigin.v[0],xyzOrigin.v[1],xyzOrigin.v[2]);
           } else if (strcmp(aname,"ATLAS_PROB_MAP") == 0) {
               if (vInt[0]== 1) probMap = true;
           } else if (strcmp(aname,"ATLAS_LABEL_TABLE") == 0) {
               nhdr->intent_code = NIFTI_INTENT_LABEL;
           } else if (strcmp(aname,"DELTA") == 0) {
               int icount = (acount > 3) ? 3 : acount;
               for( ii=0 ; ii < icount ; ii++ )
                   xyzDelta.v[ii] = vFloat[ii];
               //NSLog(@"HEAD delta %g %g %g",xyzDelta.v[0],xyzDelta.v[1],xyzDelta.v[2]);
           } else if (strcmp(aname,"TAXIS_FLOATS") == 0) {
               if (acount > 1) nhdr->pixdim[4] = vFloat[1]; //vFloat[0]=timeOrigin, vFloat[1]=repeatTime
               //NSLog(@"HEAD taxis_floats %g", vFloat[1]);
           }
    } while(1) ; // end of for loop over all attributes
    fclose( header_file ) ;
    if ((probMap) && (nhdr->intent_code == NIFTI_INTENT_LABEL) ) nhdr->intent_code = NIFTI_INTENT_NONE;
    nhdr->dim[4] = nVols;
    //http://afni.nimh.nih.gov/pub/dist/src/thd_matdaxes.c
    THD_daxes_to_NIFTI(nhdr, xyzDelta, xyzOrigin, orientSpecific );
    nhdr->vox_offset = 0;
    convertForeignToNifti(nhdr);
    return EXIT_SUCCESS;
}

#define LOAD_MAT33(AA,a11,a12,a13,a21,a22,a23,a31,a32,a33)    \
( AA.m[0][0]=a11 , AA.m[0][1]=a12 , AA.m[0][2]=a13  ,   \
AA.m[1][0]=a21 , AA.m[1][1]=a22 , AA.m[1][2]=a23 ,   \
AA.m[2][0]=a31 , AA.m[2][1]=a32 , AA.m[2][2]=a33  )

int nii_readmha(NSString * fname, NSString ** imgname, struct nifti_1_header *nhdr, long * gzBytes, bool * swapEndian)
//Read VTK "MetaIO" format image
//http://www.itk.org/Wiki/ITK/MetaIO/Documentation#Reading_a_Brick-of-Bytes_.28an_N-Dimensional_volume_in_a_single_file.29
//https://www.assembla.com/spaces/plus/wiki/Sequence_metafile_format
//http://itk-insight-users.2283740.n2.nabble.com/MHA-MHD-File-Format-td7585031.html
{
    *gzBytes = 0;
    *swapEndian = false;
    FILE *fp;
    fp = fopen([fname cStringUsingEncoding:1], "r");
    if (fp == NULL) {
        NSLog(@"Error opening %@ ", fname);
        return EXIT_FAILURE;
    }
    const int kMaxStr = 1024;
    char str[kMaxStr];
    bool isLocal = true; //image and header embedded in same file, if false detached image
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    long dataType = 0;
    long nDims = 0;
    long compressedDataSize, headerSize = 0;
    mat33 mat,matOrient;
    long matElements = 0, matElementsOrient = 0, nPosition = 0, nOffset = 0;
    int dimSize[4] = {0,0,0,0};
    float elementSpacing[4] = {0,0,0,0};
    float position[3], offset[3], centerOfRotation[3], elementSize[4];
    //bool binaryData;
    bool compressedData = false, readelementdatafile = false; //imageAndHeaderInSingleFile=false;
    NSString *lnsStr;
    do {
        if( fgets (str, kMaxStr, fp)==NULL ) break;
        //NSLog(@"--> %s",str);
        lnsStr = [NSString stringWithUTF8String:str];
        lnsStr = [[lnsStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "]; //remove EOLN
        NSArray *array = [lnsStr componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        array = [array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
        long nItems = ([array count] -2); //first two items are tag name and equal sign "NDims = 3" has 3 ["NDims" "=" "3"]
        if (nItems < 1) break;
        if ([array[0] rangeOfString:@"ObjectType" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if ([array[2] rangeOfString:@"Image" options:NSCaseInsensitiveSearch].location == NSNotFound) {
                NSLog(@"Expecting file with tag 'ObjectType = Image' instead of 'ObjectType = %@'", array[2]);
            }
        } else if ([array[0] rangeOfString:@"NDims" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            nDims = [[f numberFromString: array[2]] intValue];
            if (nDims > 4) {
                NSLog(@"Warning: only reading first 4 dimensions");
                nDims = 4;
            }
        } else if ([array[0] rangeOfString:@"BinaryDataByteOrderMSB" options:NSCaseInsensitiveSearch].location != NSNotFound) {
#ifdef __BIG_ENDIAN__
            if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location == NSNotFound) *swapEndian = true;
#else
            if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location != NSNotFound) *swapEndian = true;
#endif
        } else if ([array[0] rangeOfString:@"BinaryData" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            //if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location != NSNotFound) binaryData = true;
        } else if ([array[0] rangeOfString:@"CompressedDataSize" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            //NSLog(@"nii_io myGZ %@", array[2]);
            compressedDataSize = [[f numberFromString: array[2]] intValue];
        } else if ([array[0] rangeOfString:@"CompressedData" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location != NSNotFound)
                compressedData = true;
        }  else if ([array[0] rangeOfString:@"TransformMatrix" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 12) nItems = 12;
            matElements = nItems;
            float transformMatrix[12];
            for (int i=0; i<nItems; i++)
                transformMatrix[i] = [[f numberFromString: array[2+i]] floatValue];
            if (matElements >= 12)
                LOAD_MAT33(mat, transformMatrix[0],transformMatrix[1],transformMatrix[2],
                           transformMatrix[4],transformMatrix[5],transformMatrix[6],
                           transformMatrix[8],transformMatrix[9],transformMatrix[10]);
            else if (matElements >= 9)
                LOAD_MAT33(mat, transformMatrix[0],transformMatrix[1],transformMatrix[2],
                           transformMatrix[3],transformMatrix[4],transformMatrix[5],
                           transformMatrix[6],transformMatrix[7],transformMatrix[8]);
            
        } else if ([array[0] rangeOfString:@"Offset" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 3) nItems = 3;
            nOffset = nItems;
            for (int i=0; i<nItems; i++)
                offset[i] = [[f numberFromString: array[2+i]] floatValue];
        } else if ([array[0] rangeOfString:@"Position" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 3) nItems = 3;
            nPosition = nItems;
            for (int i=0; i<nItems; i++)
                position[i] = [[f numberFromString: array[2+i]] floatValue];
        } else if ([array[0] rangeOfString:@"CenterOfRotation" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 3) nItems = 3;
            for (int i=0; i<nItems; i++)
                centerOfRotation[i] = [[f numberFromString: array[2+i]] floatValue];
        } else if ([array[0] rangeOfString:@"AnatomicalOrientation" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            //e.g. RAI
        } else if ([array[0] rangeOfString:@"Orientation" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            //n.b. do this AFTER AnatomicalOrientation, since both include "Orientation"
            if (nItems > 12) nItems = 12;
            matElementsOrient = nItems;
            float transformMatrix[12];
            for (int i=0; i<nItems; i++)
                transformMatrix[i] = [[f numberFromString: array[2+i]] floatValue];
            if (matElementsOrient >= 12)
                LOAD_MAT33(matOrient, transformMatrix[0],transformMatrix[1],transformMatrix[2],
                           transformMatrix[4],transformMatrix[5],transformMatrix[6],
                           transformMatrix[8],transformMatrix[9],transformMatrix[10]);
            else if (matElementsOrient >= 9)
                LOAD_MAT33(matOrient, transformMatrix[0],transformMatrix[1],transformMatrix[2],
                           transformMatrix[3],transformMatrix[4],transformMatrix[5],
                           transformMatrix[6],transformMatrix[7],transformMatrix[8]);
            
        } else if ([array[0] rangeOfString:@"ElementSpacing" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 4) nItems = 4;
            for (int i=0; i<nItems; i++)
                elementSpacing[i] = [[f numberFromString: array[2+i]] floatValue];
        } else if ([array[0] rangeOfString:@"DimSize" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 4) nItems = 4;
            for (int i=0; i<nItems; i++) {
                dimSize[i] = [[f numberFromString: array[2+i]] intValue];
                //NSLog(@"Dim %d %d",i, dimSize[i]);
            }
        } else if ([array[0] rangeOfString:@"HeaderSize" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            headerSize = [[f numberFromString: array[2]] intValue];
        } else if ([array[0] rangeOfString:@"ElementSize" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (nItems > 4) nItems = 4;
            for (int i=0; i<nItems; i++)
                elementSize[i] = [[f numberFromString: array[2+i]] floatValue];
        } else if ([array[0] rangeOfString:@"ElementNumberOfChannels" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            long channels = [[f numberFromString: array[2]] intValue];
            if (channels > 1) NSLog(@"Unable to read MHA/MHD files with multiple channels (%@ has %ld channels)",fname, channels);
        } else if ([array[0] rangeOfString:@"ElementByteOrderMSB" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            //if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location != NSNotFound) byteOrderMSB = true;
#ifdef __BIG_ENDIAN__
            if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location == NSNotFound) *swapEndian = true;
#else
            if ([array[2] rangeOfString:@"True" options:NSCaseInsensitiveSearch].location != NSNotFound) *swapEndian = true;
#endif
        } else if ([array[0] rangeOfString:@"ElementType" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            //convert metaImage format to NIfTI http://portal.nersc.gov/svn/visit/tags/2.2.1/vendor_branches/vtk/src/IO/vtkMetaImageWriter.cxx
            //set NIfTI datatype http://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h
            if ([array[2] rangeOfString:@"MET_UCHAR" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_UINT8; //
            else if ([array[2] rangeOfString:@"MET_CHAR" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_INT8; //
            else if ([array[2] rangeOfString:@"MET_SHORT" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_INT16; //
            else if ([array[2] rangeOfString:@"MET_USHORT" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_UINT16; //
            else if ([array[2] rangeOfString:@"MET_INT" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = 8; //DT_INT32
            else if ([array[2] rangeOfString:@"MET_UINT" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_UINT32; //DT_UINT32
            else if ([array[2] rangeOfString:@"MET_ULONG" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_UINT64; //DT_UINT64
            else if ([array[2] rangeOfString:@"MET_LONG" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_INT64; //DT_INT64
            else if ([array[2] rangeOfString:@"MET_FLOAT" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_FLOAT32; //DT_FLOAT32
            else if ([array[2] rangeOfString:@"MET_DOUBLE" options:NSCaseInsensitiveSearch].location != NSNotFound)
                dataType = DT_FLOAT64; //DT_FLOAT64
        } else if ([array[0] rangeOfString:@"ElementDataFile" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NSString *lowerStr =  [array[2] lowercaseString];
            if(![lowerStr isEqualToString:@"local"]) {
                *imgname = array[2];
                isLocal = false;
            }
            //readelementdatafile=true; //never used
            break;
        }
    } while (~readelementdatafile);  //while ~readelementdatafile
    if ((headerSize == 0) && (isLocal)) headerSize = ftell (fp);
    nhdr->vox_offset = headerSize;
    fclose(fp);
    //next: fill relevant parts of NIfTI array
    nhdr->datatype = dataType;
    nhdr->dim[0] = nDims;
    nhdr->dim[1] = dimSize[0];
    nhdr->dim[2] = dimSize[1];
    nhdr->dim[3] = dimSize[2];
    nhdr->dim[4] = dimSize[3];
    nhdr->pixdim[1] = elementSpacing[0];
    nhdr->pixdim[2] = elementSpacing[1];
    nhdr->pixdim[3] = elementSpacing[2];
    nhdr->pixdim[4] = elementSpacing[3];
    if (nDims == 2) {
        nhdr->dim[0] = 3;
        nhdr->dim[3] = 1;
        nhdr->pixdim[3] = (nhdr->pixdim[1]+nhdr->pixdim[2])/2; //for 2D images the 3rd dim is not specified and set to zero
        NSLog(@"This software is designed for 3D rather than 2D images like %@", fname);
    }
    ///convert transform
    if ((matElements >= 9) || (matElementsOrient >= 9)) {
        mat33 d, t;
        LOAD_MAT33(d, elementSpacing[0],0,0,
                   0,elementSpacing[1],0,
                   0,0,elementSpacing[2]);
        
        if (matElements >= 9)
            t = nifti_mat33_mul( d, mat);
        else
            t = nifti_mat33_mul( d, matOrient);
        if (nPosition > nOffset) {
            offset[0] = position[0];
            offset[1] = position[1];
            offset[2] = position[2];
        }
        nhdr->srow_x[0]=-t.m[0][0];
        nhdr->srow_x[1]=-t.m[1][0];
        nhdr->srow_x[2]=-t.m[2][0];
        nhdr->srow_x[3]=-offset[0];
        nhdr->srow_y[0]=-t.m[0][1];
        nhdr->srow_y[1]=-t.m[1][1];
        nhdr->srow_y[2]=-t.m[2][1];
        nhdr->srow_y[3]=-offset[1];
        nhdr->srow_z[0]=t.m[0][2];
        nhdr->srow_z[1]=t.m[1][2];
        nhdr->srow_z[2]=t.m[2][2];
        nhdr->srow_z[3]=offset[2];
        //NSLog(@"row_x = %g %g %g %g",nhdr->srow_x[0],nhdr->srow_x[1],nhdr->srow_x[2],nhdr->srow_x[3]);
        //NSLog(@"row_y = %g %g %g %g",nhdr->srow_y[0],nhdr->srow_y[1],nhdr->srow_y[2],nhdr->srow_y[3]);
        //NSLog(@"row_z = %g %g %g %g",nhdr->srow_z[0],nhdr->srow_z[1],nhdr->srow_z[2],nhdr->srow_z[3]);
    } else
        NSLog(@"Warning: unable to determine image orientation (no metaIO 'TransformMatrix' tag)");
    //end transform
    convertForeignToNifti(nhdr);
    //yflip_sform(nhdr);  2014 <- 66666
    if (compressedData) {
        //NSLog(@"ElementDataFile %@",*imgname);
        if (compressedDataSize < 1)
            *gzBytes = K_gzBytes_headeruncompressed;
        
        else
            *gzBytes = compressedDataSize;
    }
    /*    NSLog(@"MHA mat = [%g %g %g %g; %g %g %g %g; %g %g %g %g; 0 0 0 1]",
     nhdr->srow_x[0],nhdr->srow_x[1],nhdr->srow_x[2],nhdr->srow_x[3],
     nhdr->srow_y[0],nhdr->srow_y[1],nhdr->srow_y[2],nhdr->srow_y[3],
     nhdr->srow_z[0],nhdr->srow_z[1],nhdr->srow_z[2],nhdr->srow_x[3]);*/
    return EXIT_SUCCESS;
}

int nii_readnrrd(NSString * fname, NSString ** imgname, struct nifti_1_header *nhdr, long * gzBytes, bool * swapEndian)
//http://www.sci.utah.edu/~gk/DTI-data/
//http://teem.sourceforge.net/nrrd/format.html
{
    *gzBytes = 0;
    *swapEndian = false;
    FILE *fp;
    fp = fopen([fname cStringUsingEncoding:1], "r");
    if (fp == NULL) {
        NSLog(@"Error opening %@ ", fname);
        return EXIT_FAILURE;
    }
    const int kMaxStr = 1024;
    char str[kMaxStr];
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    long  nDims = 0;
    long headerSize = 0;
    bool detachedFile = false;
    mat33 mat;//float transformMatrix[9] = { 1,0,0, 0,1,0, 0,0,1  };
    long matElements = 0;
    int  nItems;
    float offset[3];
    NSString *lnsStr, *tagName;
    nhdr->pixdim[1] = 1.0f;
    nhdr->pixdim[2] = 1.0f;
    nhdr->pixdim[3] = 1.0f;
    nhdr->pixdim[4] = 1.0f;
    nhdr->vox_offset = 0;
    //check first line starts with NRRD
    if( fgets (str, kMaxStr, fp)==NULL ) return EXIT_FAILURE;
    lnsStr = [NSString stringWithUTF8String:str];
    if ([[lnsStr substringToIndex:4] rangeOfString:@"NRRD" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        NSLog(@"NRRD headers should start with the text 'NRRD'");
        return EXIT_FAILURE;
    }
    do {
        if( fgets (str, kMaxStr, fp)==NULL )
            break;
        //NSLog(@"--> %s",str);
        lnsStr = [NSString stringWithUTF8String:str];
        lnsStr = [[lnsStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "]; //remove EOLN
        if (lnsStr.length < 2) break;
        if ([[lnsStr substringToIndex:1] rangeOfString:@"#" options:NSCaseInsensitiveSearch].location == NSNotFound) {
            //NSLog(@"--> %@",lnsStr);
            NSArray *array = [lnsStr componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@":"]];
            array = [array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
            if (array.count < 2) break;
            tagName = array[0];
            array = [array[1] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,)("]];
            array = [array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
            nItems = (int)array.count;
            if (nItems < 1) break;
            if ([tagName rangeOfString:@"dimension" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                nDims = [[f numberFromString: array[0]] intValue];
                //NSLog(@"dim  %ld",nDims);
            } else if ([tagName rangeOfString:@"spacings" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if (nItems > 6) nItems = 6;
                for (int i=0; i<nItems; i++) {
                    nhdr->pixdim[i+1] = [[f numberFromString: array[i]] floatValue];
                    if isnan(nhdr->pixdim[i+1]) nhdr->pixdim[i+1] = 0;
                }
            } else if ([tagName rangeOfString:@"sizes" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if (nItems > 6) nItems = 6;
                for (int i=0; i<nItems; i++)
                    nhdr->dim[i+1] = [[f numberFromString: array[i]] intValue];
                //NSLog(@"dims  %d %d %d",nhdr->dim[1], nhdr->dim[2], nhdr->dim[3]);
            } else if ([tagName rangeOfString:@"space directions" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if (nItems > 12) nItems = 12;
                matElements = nItems;
                float transformMatrix[12];
                for (int i=0; i<nItems; i++)
                    transformMatrix[i] = [[f numberFromString: array[i]] floatValue];;
                if (matElements >= 12)
                    LOAD_MAT33(mat, transformMatrix[0],transformMatrix[1],transformMatrix[2],
                               transformMatrix[4],transformMatrix[5],transformMatrix[6],
                               transformMatrix[8],transformMatrix[9],transformMatrix[10]);
                else if (matElements >= 9)
                    LOAD_MAT33(mat, transformMatrix[0],transformMatrix[1],transformMatrix[2],
                               transformMatrix[3],transformMatrix[4],transformMatrix[5],
                               transformMatrix[6],transformMatrix[7],transformMatrix[8]);
                //NSLog(@"mtx");
            } else if ([tagName rangeOfString:@"type" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                //"uchar",  "uint8", "uint8_t", "unsigned char",
                if (([array[0] caseInsensitiveCompare:@"uchar"] == NSOrderedSame ) ||
                    ([array[0] caseInsensitiveCompare:@"uint8"] == NSOrderedSame) ||
                    ([array[0] caseInsensitiveCompare:@"uint8_t"] == NSOrderedSame) )
                    nhdr->datatype = DT_UINT8; //DT_UINT8 DT_UNSIGNED_CHAR
                //"short", "short int",  "int16", "int16_t" "signed short", "signed short int",
                else if (([array[0] caseInsensitiveCompare:@"short"] == NSOrderedSame) || //specific so
                         ([array[0] caseInsensitiveCompare:@"int16"] == NSOrderedSame) ||
                         ([array[0] caseInsensitiveCompare:@"int16_t"] == NSOrderedSame))
                    nhdr->datatype = DT_INT16; //DT_INT16
                else if ([array[0] rangeOfString:@"float" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    nhdr->datatype = DT_FLOAT32; //DT_FLOAT32
                else if (([array[0] caseInsensitiveCompare:@"unsigned"] == NSOrderedSame)
                         && (nItems > 1) && ([array[1] caseInsensitiveCompare:@"char"] == NSOrderedSame))
                    nhdr->datatype = DT_UINT8; //DT_UINT8
                else if (([array[0] caseInsensitiveCompare:@"unsigned"] == NSOrderedSame)
                         && (nItems > 1) && ([array[1] caseInsensitiveCompare:@"short"] == NSOrderedSame))
                    nhdr->datatype = DT_UINT16; //DT_UINT16
                
                else if (([array[0] caseInsensitiveCompare:@"unsigned"] == NSOrderedSame) &&
                         (nItems > 1) && ([array[1] caseInsensitiveCompare:@"int"] == NSOrderedSame))
                    nhdr->datatype = DT_INT32; //
                else if (([array[0] caseInsensitiveCompare:@"signed"] == NSOrderedSame) &&
                         (nItems > 1) && ([array[1] caseInsensitiveCompare:@"char"] == NSOrderedSame))
                    nhdr->datatype = DT_INT8; //do UNSIGNED first, as "isigned" includes string "unsigned"
                else if (([array[0] caseInsensitiveCompare:@"signed"] == NSOrderedSame) &&
                         (nItems > 1) && ([array[1] caseInsensitiveCompare:@"short"] == NSOrderedSame))
                    nhdr->datatype = DT_INT16; //do UNSIGNED first, as "isigned" includes string "unsigned"
                else if ([array[0] caseInsensitiveCompare:@"double"] == NSOrderedSame)
                    nhdr->datatype = DT_DOUBLE; //DT_DOUBLE
                else if ([array[0] rangeOfString:@"int" options:NSCaseInsensitiveSearch].location != NSNotFound) //do this last and "uint" includes "int"
                    nhdr->datatype = DT_UINT32;
                else {
                    NSLog(@"Unsupported NRRD datatype %@ %@",array[0],array[1]);
                    //if (nItems > 1) NSLog(@"... %@",array[1]);
                }
            } else if ([tagName rangeOfString:@"endian" options:NSCaseInsensitiveSearch].location != NSNotFound) {
#ifdef __BIG_ENDIAN__
                if ([array[0] rangeOfString:@"little" options:NSCaseInsensitiveSearch].location == NSNotFound) *swapEndian = true;
#else
                if ([array[0] rangeOfString:@"big" options:NSCaseInsensitiveSearch].location != NSNotFound) *swapEndian = true;
#endif
            } else if ([tagName rangeOfString:@"encoding" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if ([array[0] rangeOfString:@"raw" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    *gzBytes = 0;
                else if (([array[0] rangeOfString:@"gz" options:NSCaseInsensitiveSearch].location != NSNotFound) ||
                         ([array[0] rangeOfString:@"gzip" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
                    *gzBytes = K_gzBytes_headeruncompressed;
                    
                } else
                    NSLog(@"Unknown encoding format %@",array[0]);
            }  else if ([tagName rangeOfString:@"space origin" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                if (nItems > 3) nItems = 3;
                for (int i=0; i<nItems; i++)
                    offset[i] = [[f numberFromString: array[i]] floatValue];
                //NSLog(@"origin");
            }  else if ([tagName rangeOfString:@"line skip" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                NSLog(@"The NRRD tag 'line skip' is ignored, this will not appear correctly");
            }  else if ([tagName rangeOfString:@"byte skip" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                headerSize = [[f numberFromString: array[0]] intValue]; //dcm2niix
            } else if ([tagName rangeOfString:@"data file" options:NSCaseInsensitiveSearch].location != NSNotFound){
                *imgname = [array[0] lastPathComponent]  ;
                //NSLog(@"Filename is %@",*imgname);
                if (([[array[0] lastPathComponent] rangeOfString:@"%" options:NSCaseInsensitiveSearch].location != NSNotFound) && (nItems > 1) ) {
                    //"data file: ./r_sphere_%02d.raw.gz 1 4 1"
                    //NSLog(@"mango  moyamoya is %@",*imgname);
                    //NSString *string = [NSString i] ;
                    int firstVol = [[f numberFromString: array[1]] intValue];
                    //NSLog(@"Filename is %@",*imgname);
                    //NSLog(@"First Volume is %d",firstVol);
                    *imgname = [NSString stringWithFormat:*imgname, firstVol];
                    //NSLog(@"Filename is %@",*imgname);
                    
                }
                if(([array[0] lastPathComponent].length == 4 ) && ([[array[0] lastPathComponent] rangeOfString:@"LIST" options:NSCaseInsensitiveSearch].location != NSNotFound) )  {
                    // "data file: LIST \n ./r_sphere_01.raw.gz"
                    //NSLog(@"NRRD LIST");
                    if( fgets (str, kMaxStr, fp)==NULL )
                        break;
                    //NSLog(@"--> %s",str);
                    lnsStr = [NSString stringWithUTF8String:str];
                    lnsStr = [[lnsStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""]; //remove EOLN
                    *imgname = lnsStr;

                    
                }
                //NSLog(@"Filename is %lu",(unsigned long)array.count);
                
                detachedFile = true;
            } /*else if ([tagName caseInsensitiveCompare:@"space"] == NSOrderedSame) {
               NSLog(@"Space is %@", array[0]);
               }*/
        }
    } while (true);  //while ~readelementdatafile
    if ((headerSize == 0) && (!detachedFile)) headerSize = ftell (fp);
    //NSLog(@"header size %ld",headerSize);
    fclose(fp);
    //next: fill relevant parts of NIfTI array
    //nhdr->dim[0] = nDims;
    nhdr->vox_offset = headerSize;
    if (nhdr->dim[3] == 0) nhdr->dim[3] = 1; //for 2D images the 3rd dim is not specified and set to zero
    //NSLog(@" dims %d = %d x %d %d x %d", nhdr->dim[0],nhdr->dim[1],nhdr->dim[2],nhdr->dim[3],nhdr->dim[4]);
    if ((nDims == 2)  || (nhdr->dim[3] == 0)) {
        nhdr->dim[3] = 1;
        nhdr->pixdim[3] = (nhdr->pixdim[1]+nhdr->pixdim[2])/2; //for 2D images the 3rd dim is not specified and set to zero
        NSLog(@"This software is designed for 3D rather than 2D images like %@", fname);
    }
    if (matElements >= 9) {
        //report_mat33(mat);
        // *mat33 t = nifti_mat33_mul( d, mat);
        nhdr->srow_x[0]=-mat.m[0][0];
        nhdr->srow_x[1]=-mat.m[1][0];
        nhdr->srow_x[2]=-mat.m[2][0];
        nhdr->srow_x[3]=-offset[0];
        nhdr->srow_y[0]=-mat.m[0][1];
        nhdr->srow_y[1]=-mat.m[1][1];
        nhdr->srow_y[2]=-mat.m[2][1];
        nhdr->srow_y[3]=-offset[1];
        nhdr->srow_z[0]=mat.m[0][2];
        nhdr->srow_z[1]=mat.m[1][2];
        nhdr->srow_z[2]=mat.m[2][2];
        nhdr->srow_z[3]=offset[2];
        /*NSLog(@"row_x = %g %g %g %g",nhdr->srow_x[0],nhdr->srow_x[1],nhdr->srow_x[2],nhdr->srow_x[3]);
         NSLog(@"row_y = %g %g %g %g",nhdr->srow_y[0],nhdr->srow_y[1],nhdr->srow_y[2],nhdr->srow_y[3]);
         NSLog(@"row_z = %g %g %g %g",nhdr->srow_z[0],nhdr->srow_z[1],nhdr->srow_z[2],nhdr->srow_z[3]);*/
        //warning: ITK does not generate a "spacings" tag - lets get this from the matrix...
        for (int dim=0; dim < 3; dim++) {
            float vSqr = 0.0f;
            for (int i=0; i < 3; i++)
                vSqr += mat.m[dim][i]*mat.m[dim][i];
            nhdr->pixdim[dim+1] = sqrt(vSqr);
        } //for each dimension
    } else {
        NSLog(@"Warning: unable to determine image orientation (missing NRRD 'space directions' tag)");
        for (int i=0; i<=4; i++) {
            nhdr->srow_x[i] = 0.0f;
            nhdr->srow_y[i] = 0.0f;
            nhdr->srow_z[i] = 0.0f;
        }
        nhdr->srow_x[0] = 1.0;
        nhdr->srow_y[1] = -1.0f; //most image formats have data from top-to-bottom, Analyze/NIFTI is the reverse
        nhdr->srow_z[2] = 1.0f;
        nhdr->srow_x[3] = -nhdr->dim[1]/2;
        nhdr->srow_y[3] = -nhdr->dim[2]/2;
        nhdr->srow_z[3] = -nhdr->dim[3]/2;
    }
    convertForeignToNifti(nhdr);
    return EXIT_SUCCESS;
}

/*int nii_readDf3(NSString * fname, struct nifti_1_header *nhdr, long * gzBytes, bool * swapEndian)
 //BIG ENDIAN binary header http://www.povray.org/documentation/view/3.6.1/374/
 {
 typedef struct __attribute__((packed)) {
 int16_t xdim,ydim,zdim;
 } Tdf3;
 *gzBytes = 0;
 NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fname];
 size_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:fname error:NULL] fileSize]; // in bytes
 NSData *hdrdata = [fileHandle readDataOfLength:sizeof(Tdf3)];
 Tdf3 df3;
 [hdrdata getBytes:&df3 length:sizeof(df3)];
 if ((!hdrdata) || (hdrdata.length < sizeof(Tdf3))) return EXIT_FAILURE;
 #ifdef __LITTLE_ENDIAN__ //df3 data ALWAYS big endian!
 nifti_swap_2bytes(1, &df3.xdim);
 nifti_swap_2bytes(1, &df3.ydim);
 nifti_swap_2bytes(1, &df3.zdim);
 *swapEndian = true;
 #else
 *swapEndian = false;
 #endif
 size_t vox = df3.xdim*df3.ydim*df3.zdim;
 //NSLog(@"df3 format %d %d %d = %zu, %zu",df3.xdim,df3.ydim,df3.zdim, fileSize, vox+sizeof(df3));
 if ((vox + sizeof(df3)) == fileSize)
 nhdr->datatype = DT_UINT8;
 else if ( ((vox*2) + sizeof(df3)) == fileSize)
 nhdr->datatype = DT_INT16;
 else if ( ((vox*4) + sizeof(df3)) == fileSize)
 nhdr->datatype = DT_INT32;
 else
 return EXIT_FAILURE;
 nhdr->dim[1] = df3.xdim;
 nhdr->dim[2] = df3.ydim;
 nhdr->dim[3] = df3.zdim;
 nhdr->pixdim[1] = 1.0f;
 nhdr->pixdim[2] = 1.0f;
 nhdr->pixdim[3] = 1.0f;
 for (int i=0; i<=4; i++) {
 nhdr->srow_x[i] = 0.0f;
 nhdr->srow_y[i] = 0.0f;
 nhdr->srow_z[i] = 0.0f;
 }
 nhdr->srow_x[0] = 1.0;
 nhdr->srow_y[1] = 1.0f;
 nhdr->srow_z[2] = -1.0f;
 nhdr->srow_x[3] = -nhdr->dim[1]/2;
 nhdr->srow_y[3] = -nhdr->dim[2]/2;
 nhdr->srow_z[3] = -nhdr->dim[3]/2;
 nhdr->vox_offset = sizeof(df3);
 convertForeignToNifti(nhdr);
 return EXIT_SUCCESS;
 }*/

unsigned char * rgba2rgb(unsigned char* img, struct nifti_1_header *hdr) {
    //convert 32-bit red/green/blue/alpha to red/green/blue
    if (img == NULL) return NULL;
    if (hdr->datatype != DT_RGB24) return img;
    int vox = hdr->dim[1]*hdr->dim[2];
    for (int i = 3; i < 8; i++)
        if (hdr->dim[i] > 1) vox = vox * hdr->dim[i];
    int volBytes24 = vox * 3;
    int volBytes32 = vox * 4;
    NSLog(@" %dx%d %d", hdr->dim[1], hdr->dim[2], volBytes32);
    unsigned char  *img32 = (unsigned char  *) malloc(volBytes32);
    memcpy(&img32[0], &img[0], volBytes32);
    free(img);
    img = (unsigned char  *) malloc(volBytes24);
    int v24 = 0;
    int v32 = 0;
    for (int i = 0; i < vox; i++) {
        img[v24] = img32[v32];//red
        v24++; v32++;
        img[v24] = img32[v32];//green
        v24++; v32++;
        img[v24] = img32[v32];//blue
        v24++; v32++;
        v32++; //skip alpha
    }
    free(img32);
    return img;
} //rgba2rgb()


int nii_readpic(NSString * fname, struct nifti_1_header *nhdr) {
    //https://github.com/jefferis/pic2nifti/blob/master/libpic2nifti.c
#define BIORAD_HEADER_SIZE 76
#define BIORAD_NOTE_HEADER_SIZE 16
#define BIORAD_NOTE_SIZE 80
    typedef struct
    {
        unsigned short nx, ny;    //  0   2*2     image width and height in pixels
        short npic;               //  4   2       number of images in file
        short ramp1_min;          //  6   2*2     LUT1 ramp min. and max.
        short ramp1_max;
        int32_t notes;                // 10   4       no notes=0; has notes=non zero
        short byte_format;        // 14   2       bytes=TRUE(1); words=FALSE(0)
        unsigned short n;         // 16   2       image number within file
        char name[32];            // 18   32      file name
        short merged;             // 50   2       merged format
        unsigned short color1;    // 52   2       LUT1 color status
        unsigned short file_id;   // 54   2       valid .PIC file=12345
        short ramp2_min;          // 56   2*2     LUT2 ramp min. and max.
        short ramp2_max;
        unsigned short color2;    // 60   2       LUT2 color status
        short edited;             // 62   2       image has been edited=TRUE(1)
        short lens;               // 64   2       Integer part of lens magnification
        float mag_factor;         // 66   4       4 byte real mag. factor (old ver.)
        unsigned short dummy[3];  // 70   6       NOT USED (old ver.=real lens mag.)
    } biorad_header;
    typedef struct
    {
        short blank;		// 0	2
        int note_flag;		// 2	4
        int blank2;			// 6	4
        short note_type;	// 10	2
        int blank3;			// 12	4
    } biorad_note_header;
    size_t n;
    FILE *f;
    unsigned char buffer[BIORAD_HEADER_SIZE];
    f = fopen([fname fileSystemRepresentation], "rb");
    if (f)
        n = fread(&buffer, BIORAD_HEADER_SIZE, 1, f);
    if(!f || n!=1) {
        printf("Problem reading biorad file!\n");
        fclose(f);
        return EXIT_FAILURE;
    }
    biorad_header bhdr;
    memcpy( &bhdr.nx, buffer+0, sizeof( bhdr.nx ) );
    memcpy( &bhdr.ny, buffer+2, sizeof( bhdr.ny ) );
    memcpy( &bhdr.npic, buffer+4, sizeof( bhdr.npic ) );
    memcpy( &bhdr.byte_format, buffer+14, sizeof( bhdr.byte_format ) );
    memcpy( &bhdr.file_id, buffer+54, sizeof( bhdr.file_id ) );
    if (bhdr.file_id != 12345) {
        fclose(f);
        return EXIT_FAILURE;
    }
    nhdr->dim[0]=3;//3D
    nhdr->dim[1]=bhdr.nx;
    nhdr->dim[2]=bhdr.ny;
    nhdr->dim[3]=bhdr.npic;
    nhdr->dim[4]=1;
    nhdr->pixdim[1]=1.0;
    nhdr->pixdim[2]=1.0;
    nhdr->pixdim[3]=1.0;
    if (bhdr.byte_format == 1)
        nhdr->datatype = DT_UINT8; // 2
    else
        nhdr->datatype = DT_UINT16;
    nhdr->vox_offset = BIORAD_HEADER_SIZE;
    if(fseek(f, bhdr.nx*bhdr.ny*bhdr.npic*bhdr.byte_format, SEEK_CUR)==0) {
        biorad_note_header nh;
        char noteheaderbuf[BIORAD_NOTE_HEADER_SIZE];
        char note[BIORAD_NOTE_SIZE];
        while (!feof(f)) {
            fread(&noteheaderbuf, BIORAD_NOTE_HEADER_SIZE, 1, f);
            fread(&note, BIORAD_NOTE_SIZE, 1, f);
            memcpy(&nh.note_flag, noteheaderbuf+2, sizeof(nh.note_flag));
            memcpy(&nh.note_type, noteheaderbuf+10, sizeof(nh.note_type));
            //		printf("regular note line %s\n",note);
            //		printf("note flag = %d, note type = %d\n",nh.note_flag,nh.note_type);
            // These are not interesting notes
            if(nh.note_type==1) continue;
            
            // Look for calibration information
            double d1, d2, d3;
            if ( 3 == sscanf( note, "AXIS_2 %lf %lf %lf", &d1, &d2, &d3 ) )
                nhdr->pixdim[1] = d3;
            if ( 3 == sscanf( note, "AXIS_3 %lf %lf %lf", &d1, &d2, &d3 ) )
                nhdr->pixdim[2] = d3;
            if ( 3 == sscanf( note, "AXIS_4 %lf %lf %lf", &d1, &d2, &d3 ) )
                nhdr->pixdim[3] = d3;
            if(nh.note_flag==0) break;
        }
    }
    nhdr->sform_code = 1;
    nhdr->srow_x[0]=nhdr->pixdim[1];nhdr->srow_x[1]=0.0f;nhdr->srow_x[2]=0.0f;nhdr->srow_x[3]=0.0f;
    nhdr->srow_y[0]=0.0f;nhdr->srow_y[1]=nhdr->pixdim[2];nhdr->srow_y[2]=0.0f;nhdr->srow_y[3]=0.0f;
    nhdr->srow_z[0]=0.0f;nhdr->srow_z[1]=0.0f;nhdr->srow_z[2]=-nhdr->pixdim[3];nhdr->srow_z[3]=0.0f;
    fclose(f);
    convertForeignToNifti(nhdr);
    return EXIT_SUCCESS;
}

int nii_readmgh(NSString * fname, struct nifti_1_header *nhdr, long * gzBytes, bool * swapEndian)
//BIG ENDIAN binary header http://freesurfer.net/fswiki/FsTutorial/MghFormat
{
    typedef struct __attribute__((packed)) {
        int32_t version, width,height,depth,nframes,type,dof;
        int16_t goodRASFlag;
        float spacingX,spacingY,spacingZ,xr,xa,xs,yr,ya,ys,zr,za,zs,cr,ca,cs;
    } Tmgh;
    NSData *hdrdata;
    if ([[fname pathExtension] rangeOfString:@"MGZ" options:NSCaseInsensitiveSearch].location != NSNotFound)  {
        NSData *data = [NSData dataWithContentsOfFile:fname];
        if (!data) return EXIT_FAILURE;
        hdrdata = ungz(data, sizeof(Tmgh));
        *gzBytes = K_gzBytes_headercompressed;
    } else {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fname];
        hdrdata = [fileHandle readDataOfLength:sizeof(Tmgh)];
        if (!hdrdata) return EXIT_FAILURE;
        *gzBytes = 0;
    }
    if (hdrdata.length < sizeof(Tmgh)) return EXIT_FAILURE;
    Tmgh mgh;
    [hdrdata getBytes:&mgh length:sizeof(mgh)];
#ifdef __LITTLE_ENDIAN__ //mgh data ALWAYS big endian!
    nifti_swap_4bytes(1, &mgh.version);
    nifti_swap_4bytes(1, &mgh.width);
    nifti_swap_4bytes(1, &mgh.height);
    nifti_swap_4bytes(1, &mgh.depth);
    nifti_swap_4bytes(1, &mgh.nframes);
    nifti_swap_4bytes(1, &mgh.type);
    nifti_swap_4bytes(1, &mgh.dof);
    nifti_swap_2bytes(1, &mgh.goodRASFlag);
    nifti_swap_4bytes(1, &mgh.spacingX);
    nifti_swap_4bytes(1, &mgh.spacingY);
    nifti_swap_4bytes(1, &mgh.spacingZ);
    nifti_swap_4bytes(1, &mgh.xr);
    nifti_swap_4bytes(1, &mgh.xa);
    nifti_swap_4bytes(1, &mgh.xs);
    nifti_swap_4bytes(1, &mgh.yr);
    nifti_swap_4bytes(1, &mgh.ya);
    nifti_swap_4bytes(1, &mgh.ys);
    nifti_swap_4bytes(1, &mgh.zr);
    nifti_swap_4bytes(1, &mgh.za);
    nifti_swap_4bytes(1, &mgh.zs);
    nifti_swap_4bytes(1, &mgh.cr);
    nifti_swap_4bytes(1, &mgh.ca);
    nifti_swap_4bytes(1, &mgh.cs);
    *swapEndian = true;
#else
    *swapEndian = false;
#endif
    if ((mgh.version != 1) || (mgh.type < 0) || (mgh.type > 4)) {
        NSLog(@"Error: first value in a MGH header should be 1 and data type should be in the range 1..4.");
        return EXIT_FAILURE;
    }
    if (mgh.type == 0)
        nhdr->datatype = DT_UINT8; // 2
    else if (mgh.type == 4)
        nhdr->datatype = DT_INT16;// 4
    else if (mgh.type == 1)
        nhdr->datatype = DT_INT32; //8
    else if (mgh.type == 3)
        nhdr->datatype = DT_FLOAT32; //16
    nhdr->dim[1]=mgh.width;
    nhdr->dim[2]=mgh.height;
    nhdr->dim[3]=mgh.depth;
    nhdr->dim[4]=mgh.nframes;
    nhdr->pixdim[1]=mgh.spacingX;
    nhdr->pixdim[2]=mgh.spacingY;
    nhdr->pixdim[3]=mgh.spacingZ;
    nhdr->vox_offset = 284;
    nhdr->sform_code = 1;
    //convert MGH to NIfTI transform see Bruce Fischl mri.c MRIxfmCRS2XYZ https://github.com/neurodebian/freesurfer/blob/master/utils/mri.c
    mat44 m;
    LOAD_MAT44(m,mgh.xr*nhdr->pixdim[1],mgh.yr*nhdr->pixdim[2],mgh.zr*nhdr->pixdim[3],0,
               mgh.xa*nhdr->pixdim[1],mgh.ya*nhdr->pixdim[2],mgh.za*nhdr->pixdim[3],0,
               mgh.xs*nhdr->pixdim[1],mgh.ys*nhdr->pixdim[2],mgh.zs*nhdr->pixdim[3],0);
    vec4 Pcrs;
    //int base = 0.0; //0 or 1: are voxels indexed from 0 or 1?
    Pcrs.v[0] = (nhdr->dim[1]/2.0);//+base;
    Pcrs.v[1] = (nhdr->dim[2]/2.0);//+base;
    Pcrs.v[2] = (nhdr->dim[3]/2.0);//+base;
    Pcrs.v[3] = 1;
    vec4 PxyzOffset;
    for(int i=0; i<4; i++) { //multiply Pcrs * m
        PxyzOffset.v[i] = 0;
        for(int j=0; j<4; j++)
            PxyzOffset.v[i] += m.m[i][j]*Pcrs.v[j];
    }
    nhdr->srow_x[0]=m.m[0][0]; nhdr->srow_x[1]=m.m[0][1]; nhdr->srow_x[2]=m.m[0][2]; nhdr->srow_x[3]=mgh.cr - PxyzOffset.v[0];
    nhdr->srow_y[0]=m.m[1][0]; nhdr->srow_y[1]=m.m[1][1]; nhdr->srow_y[2]=m.m[1][2]; nhdr->srow_y[3]=mgh.ca - PxyzOffset.v[1];
    nhdr->srow_z[0]=m.m[2][0]; nhdr->srow_z[1]=m.m[2][1]; nhdr->srow_z[2]=m.m[2][2]; nhdr->srow_z[3]=mgh.cs - PxyzOffset.v[2];
    convertForeignToNifti(nhdr);
    return EXIT_SUCCESS;
} // nii_readmgh()

unsigned char * nii_readBitmap(NSString * fname, struct nifti_1_header *nhdr)
//To Do - Handle >3D images with multiple slices, channels and frames for example " tiffutil -info mitosis.tif" on ImageJ example dataset
{
    //NSArray * imageReps = [NSBitmapImageRep imageRepsWithContentsOfFile:@"/Users/rorden/desktop/t1-head.tif"];
    NSArray * imageReps = [NSBitmapImageRep imageRepsWithContentsOfFile:fname];
    if (imageReps.count < 1) {
        NSLog(@"Invalid image");
        return NULL;
    }
    //NSLog(@" image %@ " , imageReps);
    NSInteger maxwidth = 0;
    bool sameDims = true;
    NSBitmapImageRep *rep0 = [imageReps objectAtIndex: 0];
    int indx = 0;
    for (int i = 0; i < imageReps.count; i++) {
        NSBitmapImageRep *rep = [imageReps objectAtIndex: i];
        if ((rep.pixelsWide !=  rep0.pixelsWide) || (rep.pixelsHigh !=  rep0.pixelsHigh)
            || (rep.samplesPerPixel !=  rep0.samplesPerPixel) || (rep.bitsPerPixel !=  rep0.bitsPerPixel)) sameDims = false;
        if (rep.pixelsWide > maxwidth) {
            indx = i;
            maxwidth = rep.pixelsWide;
            //NSLog(@"Width from NSBitmapImageRep: %ld %ld %ld", rep.pixelsWide, rep.pixelsHigh, rep.bitsPerSample);
        }
    }
    NSBitmapImageRep *rep = [imageReps objectAtIndex: indx];
    //NSLog(@"Width from NSBitmapImageRep: %ld %ld %ld %ld %ld", rep.pixelsWide, rep.pixelsHigh, rep.samplesPerPixel, rep.bitsPerPixel, imageReps.count);
    if ( ((rep.bitsPerPixel == 24) && (rep.samplesPerPixel == 3))
        || ((rep.bitsPerPixel == 32) && (rep.samplesPerPixel == 4))
        || ((rep.bitsPerPixel == 32) && (rep.samplesPerPixel == 3)) ) //bizarre: OSX Yosemite reports JPEGs as 32 bits with 3 samples per pixel???
        nhdr->datatype = DT_RGB24 ;
    else if (rep.bitsPerPixel == 8)
        nhdr->datatype = DT_UINT8;
    else if (rep.bitsPerPixel == 16)
        nhdr->datatype = DT_UINT16;
    else {
        NSLog(@"Error loading OS imported image: H*W %ld*%ld, %ld bpp, %ld samples per pixel", (long)rep.pixelsWide, (long)rep.pixelsHigh, (long)rep.bitsPerPixel, (long)rep.samplesPerPixel);
        return NULL;
    }
    nhdr->dim[1] = rep.pixelsWide;
    nhdr->dim[2] = rep.pixelsHigh;
    if ((sameDims) && (imageReps.count > 1)) //e.g. TIF file with multiple reps
        nhdr->dim[3] = imageReps.count;
    else {
        int numFrame = [[rep0 valueForProperty:NSImageFrameCount] intValue];
        if (numFrame < 1) numFrame = 1;
        nhdr->dim[3] = numFrame;
    }
    nhdr->pixdim[1] = 1.0f;
    nhdr->pixdim[2] = 1.0f;
    nhdr->pixdim[3] = 1.0f;
    for (int i=0; i<=4; i++) {
        nhdr->srow_x[i] = 0.0f;
        nhdr->srow_y[i] = 0.0f;
        nhdr->srow_z[i] = 0.0f;
    }
    nhdr->srow_x[0] = 1.0;
    nhdr->srow_y[1] = -1.0f;
    nhdr->srow_z[2] = -1.0f;
    nhdr->srow_x[3] = -nhdr->dim[1]/2;
    nhdr->srow_y[3] = nhdr->dim[2]/2;
    nhdr->srow_z[3] = nhdr->dim[3]/2;
    nhdr->vox_offset = 0.0;
    convertForeignToNifti(nhdr);
    //read data
    //*gzBytes = K_gzBytes_skipRead;
    size_t sliceBytes = nhdr->dim[1] * nhdr->dim[2] * (rep.bitsPerPixel/8);
    
    if (sliceBytes <= 0) return NULL;
    size_t imgBytes = sliceBytes * nhdr->dim[3];
    unsigned char *img = (unsigned char *)malloc(imgBytes);
    if (nhdr->dim[3] == 1) { //2D : only one 2D image or images with different resolutions
        memcpy(&img[0], &rep.bitmapData[0], sliceBytes);
    } else { //3D : load all representations in volume
        if (imageReps.count > 1) { //slices saved as separate image reps
            for (int i = 0; i < imageReps.count; i++) {
                //NSBitmapImageRep *
                rep = [imageReps objectAtIndex: i];
                memcpy(&img[i * sliceBytes], &rep.bitmapData[0], sliceBytes);
            }
        } else { //slices saved as separate frames
            int numFrame = [[rep0 valueForProperty:NSImageFrameCount] intValue];
            for (int i = 0; i < numFrame; ++i) {
                // set the current frame
                [rep setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInt:i]];
                memcpy(&img[i * sliceBytes], &rep.bitmapData[0], sliceBytes);
            }
            
        }
    }
    //if ((rep.bitsPerPixel == 32) && (rep.samplesPerPixel == 4))
    if ((rep.bitsPerPixel == 32) )
        img = rgba2rgb(img, nhdr);
    if (nhdr->bitpix == 24)
        nhdr->intent_code = NIFTI_INTENT_ESTIMATE;
    //return nii_rgb2Planar(img, nhdr, 0);
    return img;
} // nii_readBitmap()

int numVox(struct nifti_1_header *nhdr ) {
    int vx = nhdr->dim[1]*nhdr->dim[2]*nhdr->dim[3];
    for (int i = 4; i < 8; i++)
        if (nhdr->dim[i] > 1) vx = vx * nhdr->dim[i];
    return vx;
}

unsigned char *  swapByteOrderX (unsigned char * img, struct nifti_1_header *nhdr) {
    if (nhdr->bitpix <= 8) return img; //byte order does not matter for one byte image
    if ((nhdr->datatype == DT_RGB24) || (nhdr->datatype == DT_RGBA32)) return img; //
    size_t nvox = numVox(nhdr );
    if (nhdr->bitpix == 16)
        nifti_swap_2bytes(nvox,(void *) img);
    else if (nhdr->bitpix == 32)
        nifti_swap_4bytes(nvox, (void *) img);
    else if (nhdr->bitpix == 64)
        nifti_swap_8bytes(nvox, (void *) img);
    else
        NSLog(@"swapByteOrder: Unsupported data type!");
    return img;
}

unsigned char * nii_readImg(NSString * imgname, struct nifti_1_header *nhdr, long gzBytes, bool swapEndian, int skipVol, int loadVol) {
    //load image data based on provided header
    FILE *pFile = fopen([imgname fileSystemRepresentation], "rb");
    if (pFile == NULL) {
        NSLog(@"Unable to find %@", imgname);
        return NULL;
    }
    fseek (pFile, 0, SEEK_END); //int FileSz=ftell (ptr_myfile);
    int nVol = 1;
    for (int i = 4; i < 8; i++)
        if (nhdr->dim[i] > 1) nVol = nVol * nhdr->dim[i];
    size_t vox3D =   nhdr->dim[1]*nhdr->dim[2]*nhdr->dim[3];
    size_t vox4D = vox3D * nVol;
    if (vox3D <= 0) return NULL;
    size_t imgBytes = vox4D * (nhdr->bitpix / 8);
    long long fsz = ftell (pFile);
    if (nhdr->vox_offset < 0.0) { //mha and mhd format use a -1 for HeaderSize to indicate that the image is the last bytes of the file
        nhdr->vox_offset = fsz - imgBytes;
        if (gzBytes > 0)  nhdr->vox_offset = fsz - gzBytes;
        if (nhdr->vox_offset < 0) {
            NSLog(@"File is smaller than required image data %@", imgname);
            return NULL;
        }
    }
    long long skipBytes = nhdr->vox_offset+(skipVol * vox3D * (nhdr->bitpix / 8));     //skip initial volumes
    if (loadVol < 1) { //adjust number of voxels loaded based on file size
        long long imgsz3D = nhdr->dim[1] * nhdr->dim[2] * nhdr->dim[3] * (nhdr->bitpix / 8);
        loadVol =  trunc(16777216.0 * 4) /imgsz3D ;
        if (loadVol > 32) loadVol = 32;
        if (loadVol < 1) loadVol = 1;
    }
    if  ((loadVol+skipVol) > nVol) //read remaining volumes
        loadVol = nVol - skipVol;
    if (loadVol < 1) return NULL;
    size_t imgsz = vox3D * loadVol * (nhdr->bitpix / 8);
    THIS_UINT8 *outbuf = (THIS_UINT8 *) malloc(imgsz);
    size_t num = 1;
    if (gzBytes == 0) {
        fseek(pFile, 0, SEEK_SET);
        fseek(pFile, skipBytes, SEEK_SET);
        if (fsz < (skipBytes+imgsz)) {
            NSLog(@"File %@ too small (%lld) to be NIfTI image with %dx%dx%dx%d voxels (%d bit, %g offset)", imgname, fsz, nhdr->dim[1],nhdr->dim[2],nhdr->dim[3],nhdr->dim[4], nhdr->bitpix, nhdr->vox_offset );
            free(outbuf);
            return 0;
        }
        num = fread( outbuf, imgsz, 1, pFile);
        #pragma unused(num) //we need to increment the input file position, but we do not care what the value is
        fclose(pFile);
    } else {
        fclose(pFile);
        if ((gzBytes > 0) && (fsz < (skipBytes+gzBytes)) ) {
            NSLog(@"File %@ too small (%lld) to be NIfTI image", imgname, fsz);
            free(outbuf);
            return 0;
        }
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:imgname];
        if (gzBytes == K_gzBytes_headercompressed )
            gzBytes = fsz;
        else {
            [fileHandle seekToFileOffset:skipBytes];
            skipBytes = 0;
        }
        if (gzBytes == K_gzBytes_headeruncompressed)
            gzBytes = fsz-skipBytes;
        NSData *data = [fileHandle readDataOfLength:gzBytes];
        if (!data)
            num = -1;
        else {
            data = ungz(data, imgsz+skipBytes);
            [data getBytes:outbuf range:NSMakeRange(skipBytes,imgsz)];
        }
    } //if image data gz compressed
    if (swapEndian) outbuf = swapByteOrderX (outbuf, nhdr);
    return outbuf;
}

void readTag(NSData *data, uint32_t* offset, uint32_t* itemType, uint32_t* itemBytes, uint32_t* itemOffset) {
    uint32_t *data32 = (uint32_t *)data.bytes;
    *itemType = data32[ *offset >> 2];
    *itemBytes = data32[ (*offset >> 2) + 1];
    if (*itemType > 65535) { //small data element format
        *itemBytes = *itemType >> 16;
        *itemType = *itemType & 65535;
        *itemOffset = *offset + 4;
        *offset = *offset + 8;
    } else {
        *itemOffset = *offset + 8;
        *offset = *offset + 8 +  (trunc( (*itemBytes + 7) /8) * 8 );
    }
    //printf("itemType %d itemBytes %d nextTag @ %d\n", *itemType, *itemBytes, *offset);
}//readTag()

uint32_t readTagNoSkip(NSData *data, uint32_t* offset, uint32_t* itemType, uint32_t* itemBytes, uint32_t* itemOffset) {
    uint32_t offsetIn = *offset;
    readTag(data, offset, itemType, itemBytes, itemOffset);
    uint32_t ret = *offset;
    *offset = offsetIn + 8;
    return ret;
    //printf("itemType %d itemBytes %d nextTag @ %d\n", *itemType, *itemBytes, *offset);
} //readTagNoSkip()

uint32_t readUI32(NSData *data, uint32_t offset, uint32_t index) {
    uint32_t *data32 = (uint32_t *)data.bytes;
    return data32[ (offset >> 2) + index]; // >> 2 as we are these are 32-bit items
} //readUI32()

/*unsigned char *  readMat (NSString * fname, NSString * tagname, int *nx, int *ny, int *nz, int *dataType){
    //https://www.mathworks.com/help/pdf_doc/matlab/matfile_format.pdf
#define miINT8 1
#define miUINT8 2
#define miINT16 3
#define miUINT16 4
#define miINT32  5
#define miUINT32 6
#define miDOUBLE 9
#define miMATRIX  14
#define miCOMPRESSED  15
    *nx = 0; *ny = 0; *nz = 1; *dataType = 0;
    unsigned char *  ret = NULL;
    //next: open file
    FILE *f =fopen([fname cStringUsingEncoding:1],"rb");
    if (!f) {
        printf("Unable to open %s\n", [fname cStringUsingEncoding:1]);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long fBytes = ftell(f);
    if (fBytes <= 200) {
        printf("Unable to open or too small: %s\n", [fname cStringUsingEncoding:1]);
        return NULL; //read failure
    }
    //next: read header
    fseek(f, 0, SEEK_SET);
    uint16_t buf[64];
    fread(buf, 1, 128, f); //read 128-byte header (64 16-bit ints)
    if ((buf[0] != 16717) || (buf[1] != 19540)) {
        printf("Not a Matlab 5.0 file: %s\n", [fname cStringUsingEncoding:1]);
        fclose(f);
        return NULL;
    }
    if ((buf[62] != 256) || (buf[63] != 19785)) {
        printf("Not a little-endian Matlab 5.0 file\n");
        fclose(f);
        return NULL;
    }
    //Next: read tags
    uint32_t tag[2];
    uint32_t tagBytes;
    while ( ftell(f) < fBytes) {
        fread(tag, 1, 8, f); //read 8-byte long tag (2 32-bit integers)
        //printf("@ tag position %ld/%ld dataType %d dataBytes %d\n", ftell(f)-8, fBytes, tag[0], tag[1]);
        tagBytes = tag[1];
        if (tag[0] > 65535) tagBytes = tag[0] >> 16; //small element format
        if (tag[0] == miCOMPRESSED) {
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fname];
            [fileHandle seekToFileOffset:ftell(f)];
            NSData *data = [fileHandle readDataOfLength:tagBytes];
            //data = ungzX(data);
            data = ungz(data, NSIntegerMax);
            if (data.length >= 56) {
                uint32_t itemType, itemBytes,  itemOffset, tagType, offsetBytes = 0;
                readTagNoSkip(data, &offsetBytes, &tagType, &itemBytes,  &itemOffset); //flag
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //flag
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //dimension
                //uint32_t off = offsetBytes;
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //name
                //NSString *string = [NSString initWithData:data encoding:NSUTF8StringEncoding] ;
                NSData *dataStr = [data subdataWithRange:NSMakeRange(itemOffset, itemBytes)];
                NSString *thisTagname = [NSString stringWithUTF8String:[dataStr bytes]];
                //NSLog(@"---> %@ %dx%dx%d", thisTagname, dims[1], dims[2], dims[3]);
                if ( [thisTagname caseInsensitiveCompare: tagname] == NSOrderedSame ) {
                    //NSLog(@">>>> %@ %d %d", thisTagname, tagType, itemBytes);
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //field name
                    //printf("%dx%d\n", itemType, itemBytes);
                    uint32_t fieldNameLength = readUI32(data, itemOffset, 0);
                    //printf("%dx%d\n", fieldNameLength, itemBytes);
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //field names
                    if (fieldNameLength < 1) goto gotoDone;
                    int numfields = itemBytes / fieldNameLength;
                    if (numfields < 1) goto gotoDone;
                    //printf("%dx%d\n", itemType, itemBytes);
                    int datIndex = -1;
                    for (int i = 0; i < numfields; i++) {
                        dataStr = [data subdataWithRange:NSMakeRange(itemOffset+(i * fieldNameLength), fieldNameLength)];
                        thisTagname = [NSString stringWithUTF8String:[dataStr bytes]];
                        if ( [thisTagname caseInsensitiveCompare: @"dat"] == NSOrderedSame )
                            datIndex = i;
                    }
                    if (datIndex < 0) goto gotoDone; //
                    //printf("%dx%d\n", datIndex, itemBytes);
                    int indx = 0;
                    while (indx < datIndex) {
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //skipped field's overall tag
                        indx ++;
                    }
                    readTagNoSkip(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's overall tag
                    if (itemType != miMATRIX) goto gotoDone;
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's array flags
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's dimension
                    *nx = readUI32(data, itemOffset, 0);
                    *ny = readUI32(data, itemOffset, 1);
                    if (itemBytes > 8) *nz = readUI32(data, itemOffset, 2);
                    if (itemBytes > 12) goto gotoDone; //can only read up to 3 dimensions
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's name [EMPTY :UNUSED]
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's matrix data
                    //printf("%d : %d\n", itemType, itemBytes );
                    *dataType = itemType;
                    if (itemType == miINT8)
                        *dataType = miINT8;
                    else if (itemType == miUINT8)
                        *dataType = DT_UINT8;
                    else if (itemType == miINT16)
                        *dataType = DT_INT16;
                    else if (itemType == miUINT16)
                        *dataType = DT_UINT16;
                    else if (itemType == miINT32)
                        *dataType = DT_INT32;
                    else if (itemType == miUINT32)
                        *dataType = DT_UINT32;
                    else if (itemType == miINT32)
                        *dataType = DT_INT32;
                    else if (itemType == miDOUBLE)
                        *dataType = DT_FLOAT64;
                    if (itemBytes < 1) goto gotoDone;
                    ret = (unsigned char  *) malloc(itemBytes);
                    [data getBytes:ret range:NSMakeRange(itemOffset, itemBytes)];
                    goto gotoDone;
                }
            } //data length >= 56 bytes (valid)
        }//compressed data
        fseek(f, ftell(f)+tagBytes, SEEK_SET);
    }
gotoDone:
    fclose(f);
    return ret;
} //readMat() */

#define miINT8 1
#define miUINT8 2
#define miINT16 3
#define miUINT16 4
#define miINT32  5
#define miUINT32 6
#define miDOUBLE 9
#define miMATRIX  14
#define miCOMPRESSED  15

double readItem(NSData *data, uint32_t offset, uint32_t index,  uint32_t type) {
    if (type == miINT8) {
        int8_t *data8 = (int8_t *)data.bytes;
        return data8[ offset + index];
    } else if (type == miUINT8) {
            uint8_t *data8 = (uint8_t *)data.bytes;
            return data8[ offset + index];
    } else if (type == miINT16) {
        int16_t *data16 = (int16_t *)data.bytes;
        return data16[ (offset >> 1) + index];
    } else if (type == miUINT16) {
        uint16_t *data16 = (uint16_t *)data.bytes;
        return data16[ (offset >> 1) + index];
    } else if (type == miINT32) {
        int32_t *data32 = (int32_t *)data.bytes;
        return data32[ (offset >> 2) + index]; // >> 2 as we are these are 32-bit items
    } else if (type == miUINT32) {
        uint32_t *data32 = (uint32_t *)data.bytes;
        return data32[ (offset >> 2) + index]; // >> 2 as we are these are 32-bit items
    } else if (type == miDOUBLE) {
        double_t *data64 = (double_t *)data.bytes;
        return data64[ (offset >> 3) + index]; // >> 3 as we are these are 64-bit items
    }
    return 0;
} //readItem()


unsigned char *  readMat (NSString * fname, NSString * tagname, int *nx, int *ny, int *nz, int *dataType, NSMutableArray * tagnamelist, double * mat){
    //https://www.mathworks.com/help/pdf_doc/matlab/matfile_format.pdf

    //mat = NULL;
    *nx = 0; *ny = 0; *nz = 1; *dataType = 0;
    unsigned char *  ret = NULL;
    //next: open file
    FILE *f =fopen([fname cStringUsingEncoding:1],"rb");
    if (!f) {
        printf("Unable to open %s\n", [fname cStringUsingEncoding:1]);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long fBytes = ftell(f);
    if (fBytes <= 200) {
        printf("Unable to open or too small: %s\n", [fname cStringUsingEncoding:1]);
        return NULL; //read failure
    }
    //next: read header
    fseek(f, 0, SEEK_SET);
    uint16_t buf[64];
    fread(buf, 1, 128, f); //read 128-byte header (64 16-bit ints)
    if ((buf[0] != 16717) || (buf[1] != 19540)) {
        printf("Not a Matlab 5.0 file: %s\n", [fname cStringUsingEncoding:1]);
        fclose(f);
        return NULL;
    }
    if ((buf[62] != 256) || (buf[63] != 19785)) {
        printf("Not a little-endian Matlab 5.0 file\n");
        fclose(f);
        return NULL;
    }
    //Next: read tags
    uint32_t tag[2];
    uint32_t tagBytes;
    while ( ftell(f) < fBytes) {
        fread(tag, 1, 8, f); //read 8-byte long tag (2 32-bit integers)
        //printf("@ tag position %ld/%ld dataType %d dataBytes %d\n", ftell(f)-8, fBytes, tag[0], tag[1]);
        tagBytes = tag[1];
        if (tag[0] > 65535) tagBytes = tag[0] >> 16; //small element format
        if (tag[0] == miCOMPRESSED) {
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fname];
            [fileHandle seekToFileOffset:ftell(f)];
            NSData *data = [fileHandle readDataOfLength:tagBytes];
            //data = ungzX(data);
            data = ungz(data, NSIntegerMax);
            if (data.length >= 56) {
                uint32_t itemType, itemBytes,  itemOffset, tagType, offsetBytes = 0;
                readTagNoSkip(data, &offsetBytes, &tagType, &itemBytes,  &itemOffset); //flag
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //flag
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //dimension
                //uint32_t off = offsetBytes;
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //name
                //NSString *string = [NSString initWithData:data encoding:NSUTF8StringEncoding] ;
                NSData *dataStr = [data subdataWithRange:NSMakeRange(itemOffset, itemBytes)];
                NSString *thisTagname = [NSString stringWithUTF8String:[dataStr bytes]];
                //NSLog(@"---> %@ %dx%dx%d", thisTagname, dims[1], dims[2], dims[3]);
                //if ( [thisTagname caseInsensitiveCompare: tagname] == NSOrderedSame ) {
                //NSLog(@">>>> %@ %d %d", thisTagname, tagType, itemBytes);
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //field name
                //NSLog(@"%dx%d\n", itemType, itemBytes);
                uint32_t fieldNameLength = readUI32(data, itemOffset, 0);
                //NSLog(@"> %dx%d\n", fieldNameLength, itemBytes);
                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //field names
                if (fieldNameLength < 1) goto gotoDone;
                int numfields = itemBytes / fieldNameLength;
                if (numfields < 1) goto gotoDone;
                //NSLog(@" %dx%d\n", numfields, itemBytes);
                
                //printf("%dx%d\n", itemType, itemBytes);
                int hdrIndex = -1;
                int datIndex = -1;
                for (int i = 0; i < numfields; i++) {
                    dataStr = [data subdataWithRange:NSMakeRange(itemOffset+(i * fieldNameLength), fieldNameLength)];
                    NSString *subfieldname = [NSString stringWithUTF8String:[dataStr bytes]];
                    if ( [subfieldname caseInsensitiveCompare: @"dat"] == NSOrderedSame )
                        datIndex = i;
                    if ( [subfieldname caseInsensitiveCompare: @"hdr"] == NSOrderedSame )
                        hdrIndex = i;
                }
                if (datIndex >= 0) [tagnamelist addObject: thisTagname];
                if ((datIndex >= 0) && ( [thisTagname caseInsensitiveCompare: tagname] == NSOrderedSame )) {
                    
                    if (hdrIndex >= 0) {
                        uint32_t tagStartOffsetBytes = offsetBytes;
                        int indx = 0;
                        while (indx < hdrIndex) {
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //skipped field's overall tag
                            indx ++;
                        }
                        //uint32_t tagEndOffsetBytes =
                        readTagNoSkip(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's overall tag
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //array flags
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //dimensions
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //array name
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //number of structure subfields
                        uint32_t nSubfields = readUI32(data, itemOffset, 0);
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //
                        int nameBytes = itemBytes/nSubfields;
                        indx = -1;
                        for (int i = 0; i < nSubfields; i++) {
                            dataStr = [data subdataWithRange:NSMakeRange(itemOffset+(i*nameBytes), nameBytes )];
                            NSString *subfieldname = [NSString stringWithUTF8String:[dataStr bytes]];
                            if ( [subfieldname caseInsensitiveCompare: @"mat"] == NSOrderedSame )
                                indx = i;
                        }
                        if (indx >= 0) {
                            int x = 0;
                            while (x < indx) {
                                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //skipped field's overall tag
                                x ++;
                            }
                            readTagNoSkip(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset);
                            if (itemType == miMATRIX) {
                                
                                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's array flags
                                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's dimension
                                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's name [EMPTY :UNUSED]
                                readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's name Matrix
                                for (int i = 0; i < 16; i++) mat[i] = readItem(data, itemOffset, i, itemType);
                                /*if (itemBytes == 128) {
                                    //NSLog(@"--- %d %d ",  itemType, itemBytes);
                                    //mat = (double  *) malloc(128);
                                    //if (mat == NULL) NSLog(@"xxxx");
                                    
                                    
                                    [data getBytes:mat range:NSMakeRange(itemOffset, itemBytes)];
                                    NSLog(@"%g %g", mat[0],mat[1]);
                                }*/
                                //dataStr = [data subdataWithRange:NSMakeRange(itemOffset, itemBytes)];
                                //NSString *tTagname = [NSString stringWithUTF8String:[dataStr bytes]];
                                //NSLog(@"hdr %d %d '%@'", itemType, itemBytes, tTagname);
                                
                            }
                        }
                        /*NSLog(@"---hdr %d %d", itemType, itemBytes);
                        if (itemType == miMATRIX) {
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's array flags
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's dimension
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's name [EMPTY :UNUSED]
                            //readTagNoSkip(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's overall tag
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's matrix data
                            NSLog(@"hdr %d %d", itemType, itemBytes);
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's matrix data
                            dataStr = [data subdataWithRange:NSMakeRange(itemOffset, itemBytes)];
                            NSString *tTagname = [NSString stringWithUTF8String:[dataStr bytes]];
                            NSLog(@"hdr %d %d '%@'", itemType, itemBytes, tTagname);
                            readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's matrix data
                            
                            

                        }*/
                        
                        
                        
                        offsetBytes = tagStartOffsetBytes;
                    }
                    //printf("%dx%d\n", datIndex, itemBytes);
                    //if ( [thisTagname caseInsensitiveCompare: tagname] == NSOrderedSame ) {
                    int indx = 0;
                    while (indx < datIndex) {
                        readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //skipped field's overall tag
                        indx ++;
                    }
                    readTagNoSkip(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's overall tag
                    if (itemType != miMATRIX) goto gotoDone;
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's array flags
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's dimension
                    *nx = readUI32(data, itemOffset, 0);
                    *ny = readUI32(data, itemOffset, 1);
                    if (itemBytes > 8) *nz = readUI32(data, itemOffset, 2);
                    if (itemBytes > 12) goto gotoDone; //can only read up to 3 dimensions
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's name [EMPTY :UNUSED]
                    readTag(data, &offsetBytes, &itemType, &itemBytes,  &itemOffset); //desired field's matrix data
                    //printf("%d : %d\n", itemType, itemBytes );
                    *dataType = itemType;
                    if (itemType == miINT8)
                        *dataType = miINT8;
                    else if (itemType == miUINT8)
                        *dataType = DT_UINT8;
                    else if (itemType == miINT16)
                        *dataType = DT_INT16;
                    else if (itemType == miUINT16)
                        *dataType = DT_UINT16;
                    else if (itemType == miINT32)
                        *dataType = DT_INT32;
                    else if (itemType == miUINT32)
                        *dataType = DT_UINT32;
                    else if (itemType == miINT32)
                        *dataType = DT_INT32;
                    else if (itemType == miDOUBLE)
                        *dataType = DT_FLOAT64;
                    if (itemBytes < 1) goto gotoDone;
                    ret = (unsigned char  *) malloc(itemBytes);
                    [data getBytes:ret range:NSMakeRange(itemOffset, itemBytes)];
                    goto gotoDone;
                }
            } //data length >= 56 bytes (valid)
        }//compressed data
        fseek(f, ftell(f)+tagBytes, SEEK_SET);
    }
gotoDone:
    fclose(f);
    return ret;
} //readMat()

/*int promptInteger(int defVal)  {
    NSString *prompt = @"Enter desired modality (1=lesion, 2=cbf, 3=rest, 4=i3mT1, 5=i3mT2, 6=fa, 7=dti, 8=md, 9=ttp, 10=cbv)";
    NSString *defaultValue =  [NSString stringWithFormat:@"%d", defVal];
    NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:defaultValue];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        //NSInteger nsInt = [input intValue];
        //return [input stringValue];
        return (int)[input intValue];
    }
    return defVal;
}*/

NSString * listString ( NSArray * list) {
    NSString *str = @"";
    if (list.count < 1) return str;
    for (int i = 0; i < list.count; i++) {
        str = [str stringByAppendingString: @" "];
        str = [str stringByAppendingString: [list objectAtIndex: i]];
    }
    return str;
} //listString()

/*
NSString* promptModality(NSMutableArray * list)  {
    NSString *prompt = [@"Enter desired modality. Your options are: " stringByAppendingString:  listString(list) ];
    NSString *defaultValue =  (NSString *)[list objectAtIndex: 0];
    NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:defaultValue];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        return [input stringValue];
    }
    return defaultValue;
}// promptModality()*/

NSString* promptModality(NSMutableArray * list)  {
    NSString *prompt = [@"Enter desired modality. Your options are: " stringByAppendingString:  listString(list) ];
    NSString *defaultValue =  (NSString *)[list objectAtIndex: 0];
    NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    //NSArray * langChoices = [[NSArray alloc] initWithObjects:@"English", @"French", @"German", @"Spanish", nil];
    NSPopUpButton * tmpPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [tmpPopup addItemsWithTitles:list];
    [alert setAccessoryView:tmpPopup];
    //NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    //[input setStringValue:defaultValue];
    //[alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        //NSLog(@"--->%ld", (long)tmpPopup.indexOfSelectedItem);
        return (NSString *)[list objectAtIndex: tmpPopup.indexOfSelectedItem];
        //[input validateEditing];
        //return [input stringValue];
    }
    return defaultValue;
}// promptModality()


NSUInteger indexOfCaseInsensitiveString ( NSArray * list, NSString * item) {
    if (list.count < 1) return 0;//NSNotFound;
    NSUInteger index = 0;
    for (NSString *object in list) {
        if ([object caseInsensitiveCompare:item] == NSOrderedSame)
            return index;
        index++;
    }
    return 0;// NSNotFound;
} //indexOfCaseInsensitiveString()

unsigned char * nii_readMat(NSString * fname, struct nifti_1_header *nhdr)
//To Do - Handle >3D images, read matrix for image
{
    double matx[16];
    for (int i = 0; i < 16; i++) matx[i] = 0.0;
    matx[0] = INFINITY;
    //matx[5] = 1.0;
    //matx[10] = 1.0;
    double * mat = matx;//(double  *) malloc(128);
    NSString *tagModality = [[NSUserDefaults standardUserDefaults] stringForKey:@"matlabModality"];
    //NSString *tagIsBG = [[NSUserDefaults standardUserDefaults] stringForKey:@"matlabBackground"];
    //bool tagIsBG =[[NSUserDefaults standardUserDefaults] boolForKey:@"matlabBackground"];
    
    //NSLog(@" --->%d<---", tagIsBG);
    NSMutableArray * tagnamelist = [[NSMutableArray alloc] init];
    int nx = 0; int ny = 0; int nz = 0; int dataType = 0;
    unsigned char * img = NULL;
    NSUInteger flags = [[[ NSApplication sharedApplication ] currentEvent ] modifierFlags ];
    
    //NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    //bool specialKeys = ((flags & NSCommandKeyMask) == NSCommandKeyMask) || ((flags & NSControlKeyMask) == NSControlKeyMask) ;
    bool specialKeys = (flags & NSCommandKeyMask) == NSCommandKeyMask;
    bool altKey = (flags & NSAlternateKeyMask) == NSAlternateKeyMask;
    //NSLog(@"%lu -> %d", flags, altKey);
    
    //NSLog(@"%lu -> %d", flags, specialKeys);
    if (altKey)
        img = readMat(fname, @"T1", &nx, &ny, &nz, &dataType, tagnamelist, mat);
    else if ((tagModality.length > 0) && (!specialKeys)) //read desired modality
        img = readMat(fname, tagModality, &nx, &ny, &nz, &dataType, tagnamelist, mat);
    if (img == NULL) { //search all possible modalities
        tagModality = @"impossible"; //retrieve list of ALL modalities...
        img = readMat(fname, tagModality, &nx, &ny, &nz, &dataType, tagnamelist, mat);
        if (tagnamelist.count < 1) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:[@"There are no NiiStat format images in " stringByAppendingString:[fname lastPathComponent]] ];
            [alert runModal];
            return NULL;
        }
        //NSUInteger indx = indexOfCaseInsensitiveString ( tagnamelist, modality);
        tagModality = (NSString *)[tagnamelist objectAtIndex: 0];
        if (specialKeys)
            tagModality = promptModality(tagnamelist);
        tagModality = (NSString *)[tagnamelist objectAtIndex: indexOfCaseInsensitiveString ( tagnamelist, tagModality)]; //get spelling right...
        [[NSUserDefaults standardUserDefaults] setObject:tagModality  forKey:@"matlabModality"];
        img = readMat(fname, tagModality, &nx, &ny, &nz, &dataType, tagnamelist, mat);
        if (img == NULL) //never happens: we exit if list.count < 1, and indexOfCaseInsensitiveString will select first item
            return NULL;
    }
    //determine distance between voxels and spatial transformation matrices
    if (mat[0] == INFINITY) {
        NSLog(@"Error: unable to read matrix");
        for (int i = 0; i < 16; i++) matx[i] = 0.0;
        matx[0] = 1.0;
        matx[5] = 1.0;
        matx[10] = 1.0;
        
    }
    vec4 v1 = {1.0, 1.0, 1.0, 0.0};
    mat44 m;
    LOAD_MAT44(m, mat[0],mat[4],mat[8],mat[12], mat[1],mat[5],mat[9],mat[13], mat[2],mat[6],mat[10],mat[14]);
    vec4 v = nifti_vect44mat44_mul(v1, m );
    NSLog(@"importing matlab %dx%dx%d %d [%g %g %g %g; %g %g %g %g; %g %g %g %g]", nx, ny, nz, dataType, mat[0],mat[4],mat[8],mat[12], mat[1],mat[5],mat[9],mat[13], mat[2],mat[6],mat[10],mat[14]);
    nhdr->dim[1] = nx;
    nhdr->dim[2] = ny;
    nhdr->dim[3] = nz;
    nhdr->srow_x[0] = mat[0];
    nhdr->srow_y[0] = mat[1];
    nhdr->srow_z[0] = mat[2];
    nhdr->srow_x[1] = mat[4];
    nhdr->srow_y[1] = mat[5];
    nhdr->srow_z[1] = mat[6];
    nhdr->srow_x[2] = mat[8];
    nhdr->srow_y[2] = mat[9];
    nhdr->srow_z[2] = mat[10];
    nhdr->srow_x[3] = mat[12]+v.v[0];
    nhdr->srow_y[3] = mat[13]+v.v[1];
    nhdr->srow_z[3] = mat[14]+v.v[2];
    nhdr->pixdim[1] = sqrt(pow(mat[0],2) + pow(mat[1],2) + pow(mat[2],2));
    nhdr->pixdim[2] = sqrt(pow(mat[4],2) + pow(mat[5],2) + pow(mat[6],2));
    nhdr->pixdim[3] = sqrt(pow(mat[8],2) + pow(mat[9],2) + pow(mat[10],2));
    nhdr->datatype = dataType;
    nhdr->vox_offset = 0.0;
    convertForeignToNifti(nhdr);
    [tagModality getCString:nhdr->descrip maxLength:79 encoding:NSUTF8StringEncoding];
    return img;
} //nii_readMat()

unsigned char * nii_readForeign(NSString * fname, struct nifti_1_header *niiHdr, int skipVol, int loadVol) {
	NSString *ext =[fname pathExtension];
    //unsigned char * img = NULL;
    int OK = EXIT_FAILURE;
    long gzBytes = 0;
    bool swapEndian = false;
    NSString* imgname = fname;
    clearNifti(niiHdr);
    //NSLog(@"%-- d %dx%dx%dx%d",niiHdr->dim[0], niiHdr->dim[1], niiHdr->dim[2], niiHdr->dim[3],  niiHdr->dim[4]);
    if ([ext rangeOfString:@"HEAD" options:NSCaseInsensitiveSearch].location != NSNotFound)
        OK = afni_readhead(fname, &imgname, niiHdr, &gzBytes, &swapEndian);
    else if ([ext rangeOfString:@"PIC" options:NSCaseInsensitiveSearch].location != NSNotFound)
        OK = nii_readpic(fname, niiHdr);
    else if (([ext rangeOfString:@"MHA" options:NSCaseInsensitiveSearch].location != NSNotFound) || ([ext rangeOfString:@"MHD" options:NSCaseInsensitiveSearch].location != NSNotFound))
        OK = nii_readmha(fname, &imgname, niiHdr, &gzBytes, &swapEndian);
    else if (([ext rangeOfString:@"NHDR" options:NSCaseInsensitiveSearch].location != NSNotFound) || ([ext rangeOfString:@"NRRD" options:NSCaseInsensitiveSearch].location != NSNotFound))
        OK = nii_readnrrd(fname, &imgname, niiHdr, &gzBytes, &swapEndian);
    else if (([ext rangeOfString:@"MGH" options:NSCaseInsensitiveSearch].location != NSNotFound) || ([ext rangeOfString:@"MGZ" options:NSCaseInsensitiveSearch].location != NSNotFound))
        OK = nii_readmgh(fname,  niiHdr, &gzBytes, &swapEndian);
    if (OK == EXIT_SUCCESS) { //we have found a header
        if (![[NSFileManager defaultManager] fileExistsAtPath:imgname]) { //if basename is /path/img.mhd and imgname is img.raw, set imgname to /path/img.raw
            imgname = [[fname stringByDeletingLastPathComponent] stringByAppendingPathComponent: [imgname lastPathComponent]];
            if (![[NSFileManager defaultManager] fileExistsAtPath:imgname]) {
                NSLog(@"Unable to find a file named '%@'", imgname);
                return 0;
            }
        }
        //NSLog(@"%d %dx%dx%dx%d",niiHdr->dim[0], niiHdr->dim[1], niiHdr->dim[2], niiHdr->dim[3],  niiHdr->dim[4]);
        return nii_readImg(imgname, niiHdr, gzBytes, swapEndian, skipVol, loadVol);
    }
    if ( [ext caseInsensitiveCompare: @"MAT"] == NSOrderedSame )
        return nii_readMat(fname,  niiHdr);
    if ([[NSImage alloc] initWithContentsOfFile:fname] != NULL) //last resort - is this an image format that OSX can read?
        return nii_readBitmap(fname,  niiHdr);
    return NULL;
} //nii_readForeign()

/*unsigned char * nii_readForeignC(char * fname, struct nifti_1_header *niiHdr, int skipVol, int loadVol) {
    NSString *fnameNS = [NSString stringWithCString:fname encoding:NSASCIIStringEncoding];
    return nii_readForeign(fnameNS, niiHdr, skipVol, loadVol);
}*/