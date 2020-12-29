//
//  nii_colorbar.h
//  MRIpro
//
//  Created by Chris Rorden on 9/2/12.
//  Copyright 2012 U South Carolina. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "nii_io.h"
#include "nii_definetypes.h"
#import "GLString.h"

#ifndef MRIpro_nii_clr_h
#define MRIpro_nii_clr_h

#ifdef  __cplusplus
extern "C" {
#endif
    //void drawVolumeLabel(NII_PREFS* prefs);
    //void drawColorBar(NII_PREFS* prefs);
    void drawColorBarTex(NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib);
    void drawHistogram(NII_PREFS* prefs, int Lft, int Wid, int Ht);
    //void drawVolumeLabelTex(NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib);
    //void textArrow (float X, float Y, float Sz, char* NumStr, int orient , NII_PREFS* prefs);
#ifdef  __cplusplus
}
#endif


#endif
