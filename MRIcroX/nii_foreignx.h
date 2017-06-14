//Attempt to open non-DICOM image

//Convert foreign (non-DICOM) formats to NIfTI
#ifndef _NII_FOREIGNX_
#define _NII_FOREIGNX_

#ifdef  __cplusplus
extern "C" {
#endif

#include "nifti1.h"
#import <Foundation/Foundation.h>

unsigned char * nii_readForeignx(NSString * fname, struct nifti_1_header *niiHdr, int skipVol, int loadVol);

#ifdef  __cplusplus
}
#endif

#endif