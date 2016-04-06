
#include "nii_mosaic.h"
#import <Cocoa/Cocoa.h>
#import <stdio.h>

@implementation mosaicObj

-(void) str2Mosaic:(NSString*) list
{
    for (int r = 0; r < kMaxMosaicDim; r++)
            for (int c = 0; c < kMaxMosaicDim; c++)
                Orient[r][c] =0;
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    int sliceOrient = 1; //1=axial, 2=coronal, 3=sag, 4 = sagflip
    bool readVOverlap = false;
    bool readHOverlap = false;
    HOverlap = 0;
    VOverlap = 0;
    isLabel = false;
    int nRow = 0;
    int nCol = 0;
    NSArray *rowItems = [list componentsSeparatedByString:@";"];
    for (NSString *row in rowItems) {
        NSArray *listItems = [row componentsSeparatedByString:@" "];
        nRow ++;
        nCol = 0;
        for (NSString *myItem in listItems) {
            // do something with object
            NSNumber * myNumber = [f numberFromString: myItem];
            if (myNumber != nil) {
                //NSLog(@"number %@",myNumber); //logs 123.0000
                float fval = [myNumber floatValue];
                if (readVOverlap) {
                    VOverlap  = fval;
                    readVOverlap = false;
                } else if (readHOverlap) {
                    HOverlap  = fval;
                    readHOverlap = false;
                } else if (sliceOrient >= 0) {
                    nCol ++;
                    if ((nCol < kMaxMosaicDim) && (nRow < kMaxMosaicDim)) {
                        Orient[nRow][nCol] =sliceOrient;
                        Slice[nRow][nCol] =fval;
                    }
                }
            }else {
                if ([myItem rangeOfString:@"a" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    sliceOrient = 1; //NSLog(@"ax %@",myItem);
                else if ([myItem rangeOfString:@"c" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    sliceOrient = 2; //NSLog(@"cor %@",myItem);
                else if ([myItem rangeOfString:@"s" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    sliceOrient = 3; //NSLog(@"sag %@",myItem);
                else if ([myItem rangeOfString:@"z" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    sliceOrient = 4; //NSLog(@"revSag %@",myItem);
                else if ([myItem rangeOfString:@"h" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    readHOverlap = true;
                else if ([myItem rangeOfString:@"v" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    readVOverlap = true;
                else if ([myItem rangeOfString:@"l" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    if ([myItem rangeOfString:@"-" options:NSCaseInsensitiveSearch].location != NSNotFound)
                        isLabel = false;
                    else
                        isLabel = true;
                }
            }
        } //for each item in row
    } //for each row
    #if !__has_feature(objc_arc)
        [f release];
    #endif
}

/*-(void) reportMosaic
{
    float maxSlice = -INFINITY;
    float minSlice = INFINITY;
    int maxR = 0;
    int maxC = 0;
    for (int r = 0; r < kMaxMosaicDim; r++)
        for (int c = 0; c < kMaxMosaicDim; c++)
            if (Orient[r][c] > 0) { //slice at this position
                if (r > maxR) maxR = r;
                if (c > maxC) maxC = c;
                float slicePos = Slice[r][c];
                if (slicePos > maxSlice) maxSlice = slicePos;
                if (slicePos < minSlice) minSlice = slicePos;
            }
    NSLog(@" rows %d, cols %d, minSlice %f max slice %f", maxR,maxC,minSlice, maxSlice);
}*/

-(void) prepMosaic: (int) dim1 Y: (int) dim2 Z: (int) dim3; //provide size of volume X,Y,Z in voxels
{
    
    
    //first pass: determine if slices are fractions or mm
    //const int xyzSz[4] = {0, 91, 109, 91};
    TotalSizeInPixels  = NSMakePoint(0, 0);
    if ((HOverlap < -1) || (HOverlap  >1) || (VOverlap < -1) || (VOverlap  >1) ){
        NSLog(@"drawMosaic exiting: HOverlap and VOverlap must be in the range -1..1");
        return;
    }
    float maxSlice = -INFINITY;
    float minSlice = INFINITY;
    float maxX = 0;
    NSPoint sz = NSMakePoint(0, 0);
    NSPoint startpos = NSMakePoint(0, 0);
    NSPoint endpos = NSMakePoint(0, 0);
    for (int r = (kMaxMosaicDim-1); r >= 0; r--) {
    //for (int r = 0; r <kMaxMosaicDim; r++) {
        float maxY = 0;
        startpos.x = 0;
        for (int c = 0; c < kMaxMosaicDim; c++) {
            if (Orient[r][c] > 0) { //slice at this position
                float slicePos = Slice[r][c];
                if (slicePos > maxSlice) maxSlice = slicePos;
                if (slicePos < minSlice) minSlice = slicePos;
                if (Orient[r][c] == 1) //axial, wid=[1], ht=[2]
                    sz = NSMakePoint(dim1, dim2);
                else if (Orient[r][c] == 2) //coronal, wid=[1], ht=[3]
                    sz = NSMakePoint(dim1, dim3);
                else  //sagittal, wid=[2], ht=[3]
                    sz = NSMakePoint(dim2, dim3);
                //NSLog(@"Slice at x=%f y=%f", startpos.x, startpos.y);
                Pos[r][c] = NSMakePoint(startpos.x, startpos.y);
                endpos.x = startpos.x + sz.x;
                startpos.x = startpos.x + round(sz.x * (1.0- fabs(HOverlap)));
                if (sz.y > maxY) maxY = sz.y;
            } //orient > 0
        }//each column
        if (endpos.x > maxX) maxX = endpos.x;
        if (maxY >0 ) {
            endpos.y = startpos.y + maxY; //
            startpos.y = startpos.y + round(maxY * (1.0- fabs(VOverlap)));
            //NSLog(@"offset %f ht %f",round(maxY * (1.0- fabs(VOverlap))),endpos.y);
        }
    }//each row
    if (maxSlice < minSlice) {
        NSLog(@"drawMosaic exiting: bogus mosaic");
        return;
    }
    //NSLog(@"bmp = wid:%f  ht:%f overlap:%f", maxX, endpos.y, VOverlap);
    //NSLog(@"V= %f, H=%f",VOverlap,HOverlap);
    TotalSizeInPixels  = NSMakePoint(maxX, endpos.y);
    SliceIsMM = ((maxSlice > 1.0) || (minSlice < 0.0));
}

@end