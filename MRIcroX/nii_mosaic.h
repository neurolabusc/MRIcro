#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

/*http://www.otierney.net/objective-c.html
NSString *str = @"v 0.1 10 s 20 30";
mosaicObj *mos = [[mosaicObj alloc] init];
[mos str2Mosaic:str];
[mos prepMosaic]
 [mos reportMosaic];
 
[mos release]; <- only if you do not have ARC enabled*/
const int kMaxMosaicDim = 12;

@interface mosaicObj: NSObject {

    @public
    //int Rows, Cols;
    float HOverlap,VOverlap;
    double Slice[kMaxMosaicDim][kMaxMosaicDim];
    bool SliceIsMM, isLabel;
    NSPoint TotalSizeInPixels;
    NSPoint Pos[kMaxMosaicDim][kMaxMosaicDim];
    int Orient[kMaxMosaicDim][kMaxMosaicDim];
}
-(void) str2Mosaic:(NSString*) list;
//-(void) reportMosaic;
-(void) prepMosaic: (int) dim1 Y: (int) dim2 Z: (int) dim3; //provide size of volume X,Y,Z in voxels

@end