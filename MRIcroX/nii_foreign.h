//Convert foreign (non-DICOM) formats to NIfTI
#ifndef _NII_FOREIGN_
#define _NII_FOREIGN_

#ifdef  __cplusplus
extern "C" {
#endif

#include "nifti1.h"
#import <Foundation/Foundation.h>
    
//unsigned char * nii_readForeignC(char * fname, struct nifti_1_header *niiHdr, int skipVol, int loadVol);
unsigned char * nii_readForeign(NSString * fname, struct nifti_1_header *niiHdr, int skipVol, int loadVol);

#ifdef  __cplusplus
}
#endif

#endif