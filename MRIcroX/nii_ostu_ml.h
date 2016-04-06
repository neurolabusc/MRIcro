#import <Foundation/Foundation.h>
#include "nii_io.h"
#include "nii_definetypes.h"

#ifndef MRIpro_nii_otsu_h
#define MRIpro_nii_otsu_h

#ifdef  __cplusplus
extern "C" {
#endif

//void applyOtsuBinary (THIS_UINT8 *img8bit, int nVox, int levels);
    void maskBackground  (THIS_UINT8 *img8bit, int lXi, int lYi, int lZi, int lOtsuLevels, float lDilateVox, bool lOneContiguousObject);
    
#ifdef  __cplusplus
}
#endif

#endif