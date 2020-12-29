//
//  nii_reslice.h
//  MRIpro
//
//  Created by Chris Rorden on 9/2/12.
//  Copyright 2012 U South Carolina. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "nii_io.h"

#ifndef MRIpro_nii_reslice_h
#define MRIpro_nii_reslice_h

#ifdef  __cplusplus
extern "C" { 
#endif
    
    int reslice2Targ (FSLIO* lDest, FSLIO* lSrc, bool lTrilinearInterpolation);
    

#ifdef  __cplusplus
}
#endif


#endif

