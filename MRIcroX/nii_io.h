//
//  nii_io.h
//  MRIpro
//
//  Created by Chris Rorden on 8/14/12.
//  Copyright (c) 2012 U South Carolina. All rights reserved.
//

#include "nifti1.h"  // defines struct nifti_1_header
//#import "nii_definetypes.h" //tRGBAlut lut;
#import "nifti1_io_core.h"


#ifndef MRIpro_nii_io_h
#define MRIpro_nii_io_h


//#undef MY_DEBUG  //use "define" for verbose comments or "undef" for silent mode
//#define MY_DEBUG  //use "define" for verbose comments or "undef" for silent mode
#define MY_GLFONTS
#ifdef  __cplusplus
extern "C" {
#endif


/* added by KF pending discussion w/ Mark */
typedef unsigned char   THIS_UINT8; 
typedef char            THIS_INT8;
typedef unsigned short  THIS_UINT16;
typedef short           THIS_INT16;
typedef unsigned int    THIS_UINT32;
typedef int             THIS_INT32;
typedef unsigned long   THIS_UINT64;
typedef long            THIS_INT64;
typedef float           THIS_FLOAT32;
typedef double          THIS_FLOAT64;
    typedef uint32_t tRGBAlut[256];
    
typedef struct {                /*!< Image storage struct **/
    int ndim ;                    /*!<DEPRECATED USE DIM last dimension greater than 1 (1..7) */
    int nx ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int ny ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int nz ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int nt ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int nu ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int nv ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int nw ;                      /*!<DEPRECATED USE DIM dimensions of grid array             */
    int dim[8] ;                  /*!< dim[0]=ndim, dim[1]=nx, etc.         */
    size_t nvox ;                    /*!< number of voxels = nx*ny*nz*...*nw   */
    int nbyper ;                  /*!< bytes per voxel, matches datatype    */
    int datatype ;                /*!< type of data in voxels: DT_* code    */
    
    float dx ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float dy ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float dz ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float dt ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float du ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float dv ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float dw ;                    /*!<DEPRECATED USE DIM grid spacings      */
    float pixdim[8] ;             /*!< pixdim[1]=dx, etc. */
    
    float scl_slope ;             /*!< scaling parameter - slope        */
    float scl_inter ;             /*!< scaling parameter - intercept    */
    
    float cal_min ;               /*!< calibration parameter, minimum   */
    float cal_max ;               /*!< calibration parameter, maximum   */
    
    int qform_code ;              /*!< codes for (x,y,z) space meaning  */
    int sform_code ;              /*!< codes for (x,y,z) space meaning  */
    
    int freq_dim  ;               /*!< indexes (1,2,3, or 0) for MRI    */
    int phase_dim ;               /*!< directions in dim[]/pixdim[]     */
    int slice_dim ;               /*!< directions in dim[]/pixdim[]     */
    
    int   slice_code  ;           /*!< code for slice timing pattern    */
    int   slice_start ;           /*!< index for start of slices        */
    int   slice_end   ;           /*!< index for end of slices          */
    float slice_duration ;        /*!< time between individual slices   */
    
    /*! quaternion transform parameters
     [when writing a dataset, these are used for qform, NOT qto_xyz]   */
    float quatern_b , quatern_c , quatern_d ,
    qoffset_x , qoffset_y , qoffset_z ,
    qfac      ; //DEPRECATED USE qto_xyz
    
    mat44 qto_xyz ;               /*!< qform: transform (i,j,k) to (x,y,z) */
    mat44 qto_ijk ;               /*!< qform: transform (x,y,z) to (i,j,k) */
    
    mat44 sto_xyz ;               /*!< sform: transform (i,j,k) to (x,y,z) */
    mat44 sto_ijk ;               /*!< sform: transform (x,y,z) to (i,j,k) */
    
    float toffset ;               /*!< time coordinate offset */
    
    int xyz_units  ;              /*!< dx,dy,dz units: NIFTI_UNITS_* code  */
    int time_units ;              /*!< dt       units: NIFTI_UNITS_* code  */
    
    int nifti_type ;              /*!< 0==ANALYZE, 1==NIFTI-1 (1 file),
                                   2==NIFTI-1 (2 files),
                                   3==NIFTI-ASCII (1 file) */
    int   intent_code ;           /*!< statistic type (or something)       */
    float intent_p1 ;             /*!< intent parameters                   */
    float intent_p2 ;             /*!< intent parameters                   */
    float intent_p3 ;             /*!< intent parameters                   */
    char  intent_name[16] ;       /*!< optional description of intent data */
    char descrip[80]  ;           /*!< optional text to describe dataset   */
    char aux_file[24] ;           /*!< auxiliary filename                  */
    tRGBAlut lut;
    //THIS_UINT32 lut[256] ;           /*!< auxiliary filename                  */
    
    char *fname ;                 /*!< header filename (.hdr or .nii)         */
    char *iname ;                 /*!< image filename  (.img or .nii)         */
    long long   iname_offset ;          /*!< offset into iname where data starts    */
    int   swapsize ;              /*!< swap unit in image data (might be 0)   */
    int   byteorder ;             /*!< byte order on disk (MSB_ or LSB_FIRST) */
    int   rawvols; /*number of volumes in file, regardless of number of volumes loaded */
    bool isDICOM, isCustomLUT, isINT16_was_UINT16;
    void *data ;                  /*!< pointer to data: nbyper*nvox bytes     */
} nifti_image ;
static const int K_gzBytes_skipRead = -3 ;
static const int K_gzBytes_headercompressed = -2 ;
static const int K_gzBytes_headeruncompressed = -1 ;
    
typedef struct 
{
    nifti_image *niftiptr;
} FSLIO;
//    mat33 nifti_mat33_inverse( mat33 R );
//mat44 nifti_mat44_inverse( mat44 R );
//void nifti_mat44_to_quatern( mat44 R , float *qb, float *qc, float *qd, float *qx, float *qy, float *qz, float *dx, float *dy, float *dz, float *qfac );

FSLIO *FslInit(void);
NSData * ungz(NSData* data, NSInteger DecompBytes);
int FslReadVolumes(FSLIO* fslio, char* filename, int skipVol, int loadVol);
void* FslReadAllVolumes(FSLIO* fslio, char* filename, int maxNumVolumes);
nifti_image* nifti_convert_nhdr2nim(struct nifti_1_header nhdr, const char * fname);
int FslClose(FSLIO *fslio);
void nifti_image_infodump( const nifti_image *nim );
int nii_readhdr(const char * fname);
NSString * NewFileExt(NSString *oldname, NSString *newx);
    bool checkSandAccessX (NSString *file_name);
    
#ifdef  __cplusplus
}
#endif


#endif