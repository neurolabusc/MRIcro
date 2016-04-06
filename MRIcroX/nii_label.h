#import <Foundation/Foundation.h>
#include "nii_io.h"
#include "nii_definetypes.h"

#ifndef MRIpro_nii_label_h
#define MRIpro_nii_label_h

#ifdef  __cplusplus
extern "C" {
#endif
    void createlutLabel(int colorscheme, uint32_t* lut, float saturationFrac);
    void readLabels (NSString *fname, int offset, int sz, NSMutableArray *lblArray);
    
    
#ifdef  __cplusplus
}
#endif

#endif