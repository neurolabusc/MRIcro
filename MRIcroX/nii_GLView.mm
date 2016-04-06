#import "nii_GLView.h"
#include "nifti1.h"
#include <stdio.h>
#import "nii_render.h"
#import "nii_img.h"
#import "nii_reslice.h"
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>
#import <QuartzCore/QuartzCore.h>


#ifdef __APPLE__
#define _MACOSX
#endif

@interface nii_GLView (InternalMethods)
- (CVReturn)getFrameForTime:(const CVTimeStamp *)outputTime;
- (void)drawFrame;
//@property (nonatomic) NSPoint startPoint;
//@property (nonatomic, strong) CAShapeLayer *shapeLayer;


@end




@implementation nii_GLView
@synthesize twoFingersTouches;




-(void) ShowAlert: (NSString *)theMessage Title: (NSString *) theTitle
{
    NSBeginAlertSheet(theTitle, @"OK",NULL,NULL,[[NSApplication sharedApplication] keyWindow], self,
                      NULL, NULL, NULL,
                      @"%@"
                      , theMessage);
}

-(void) makeMosaicGL:(NSString *)mosStr
{
    [gNiiImg makeMosaic: mosStr];
   //RetinaXXX setScreenWidHtOffset
}

-(bool) isTimelineUpdateNeededGL
{
    return [gNiiImg isTimelineUpdateNeeded];
}

-(void)skipNumberOfVolumesGL: (int) skip {
    int nVol = [gNiiImg getNumberOfVolumes];
    
    if (nVol < 2) return;
    int vol = [gNiiImg getVolume];
    vol = vol + skip;
    if (vol < 1) vol = nVol;
    if (vol > nVol) vol = 1;
    [gNiiImg setVolume: vol];
    //printf("vol %d skip %d\n",vol,skip);
    [self drawFrame];
}

-(int) getNumberOfVolumesGL
{
    return [gNiiImg getNumberOfVolumes];
}

-(GraphStruct) getTimelineGL
{
    return [gNiiImg getTimeline] ;
}

-(void) updatePrefs
{
    NII_PREFS *prefs =[gNiiImg getPREFS];
    prefs->retineResolution = false;
    prefs->scrnOffsetX = 0;
    prefs->scrnOffsetY = 0;
    prefs->showCube = [[NSUserDefaults standardUserDefaults] boolForKey:@"showCube"];
    prefs->xBarGap = 3*[[NSUserDefaults standardUserDefaults] boolForKey:@"xBarGap"];
    prefs->showInfo = [[NSUserDefaults standardUserDefaults] boolForKey:@"showInfo"];
    prefs->showOrient = [[NSUserDefaults standardUserDefaults] boolForKey:@"showOrient"];
    //NSLog(@"%d zzzz %d", prefs->showOrient, prefs->showInfo);
    prefs->orthoOrient = [[NSUserDefaults standardUserDefaults] boolForKey:@"orthoOrient"];
    prefs->loadFewVolumes = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadFewVolumes"];
    prefs->viewRadiological  = [[NSUserDefaults standardUserDefaults] boolForKey:@"viewRadiological"];
    bool prev = prefs->advancedRender;
    prefs->advancedRender = [[NSUserDefaults standardUserDefaults] boolForKey:@"advancedRender"];
    prefs->dicomWarn = [[NSUserDefaults standardUserDefaults] boolForKey:@"dicomWarn"];
    
    //NSLog(@"%d ---", prefs->dicomWarn);
    NSColor * aColor =nil;
    NSData *theData=[[NSUserDefaults standardUserDefaults] dataForKey:@"xBarColor"];
    if (theData != nil) {
        aColor =(NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
        prefs->xBarColor[0] = aColor.redComponent;
        prefs->xBarColor[1] = aColor.greenComponent;
        prefs->xBarColor[2] = aColor.blueComponent;
        //prefs->xBarColor[3] = 0;
        prefs->colorBarBorderColor[0] = aColor.redComponent;
        prefs->colorBarBorderColor[1] = aColor.greenComponent;
        prefs->colorBarBorderColor[2] = aColor.blueComponent;
        //convert RGB->Y http://en.wikipedia.org/wiki/YUV
        //prefs->backColor
        [gNiiImg updateFont: aColor] ;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"blackBackground"]) {
        //prefs->backColor[0] = 0.0;
        //prefs->backColor[1] = 0.0;
        //prefs->backColor[2] = 0.0;
        [self setBackgroundColor: 0 Green: 0 Blue: 0];
    } else {
        //prefs->backColor[0] = 1.0;
        //prefs->backColor[1] = 1.0;
        //prefs->backColor[2] = 1.0;
        [self setBackgroundColor: 1 Green: 1 Blue: 1];
    }
    
    
    theData=[[NSUserDefaults standardUserDefaults] dataForKey:@"colorBarTextColor"];
    if (theData != nil) {
        aColor =(NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
        prefs->colorBarTextColor[0] = aColor.redComponent;
        prefs->colorBarTextColor[1] = aColor.greenComponent;
        prefs->colorBarTextColor[2] = aColor.blueComponent;
    }
    if (prev != prefs->advancedRender) {
        //initShaderWithFile(prefs);
        prefs->force_recalcGL = true;
    }
    prefs->force_refreshGL = true;
    [self drawFrame];
}

-(LayerValues) getLayerValues: (int) index;
{
    LayerValues ret;
    NII_PREFS *prefs =[gNiiImg getPREFS];
    if (index == 0) {
        ret.colorScheme = prefs->colorScheme;
        ret.viewMin = prefs->viewMin;
        ret.viewMax = prefs->viewMax;
    } else { //-1 since background is layer 0, so overlay 0 at index 1
        ret.colorScheme = prefs->overlays[index-1].colorScheme;
        ret.viewMin = prefs->overlays[index-1].viewMin;
        ret.viewMax = prefs->overlays[index-1].viewMax;        
    }
    for (int i = 0; i < MAX_OVERLAY; i++) {
        ret.activeOverlay[i] = (prefs->overlays[i].datatype != DT_NONE);
    }
    return ret;
}

-(void) setViewGamma: (float) gamma;
{
    NII_PREFS *prefs =[gNiiImg getPREFS];
    prefs->lut_bias = gamma;
    prefs->force_refreshGL = true;
    prefs->force_recalcGL = true;
    [self drawFrame];
}


-(void) setViewMinMaxForLayer: (double) min Max: (double) max Layer: (int) layer;
{
    [gNiiImg setViewMinMaxForLayer: min Max: max Layer: layer];
    [self drawFrame];
}

- (void) setContrast:(NSPoint)value
{
    NII_PREFS *prefs =[gNiiImg getPREFS];
    double fullWidth = prefs->nearMax - prefs->nearMin;
    double Center = (((100-value.y)/50) * (fullWidth/2.0)) + prefs->nearMin;
    double Width = ((100-value.x)/50) * fullWidth;
    [gNiiImg setViewMinMax: Center-(Width/2.0) Max: Center+(Width/2.0)];
    [self drawFrame];
}

-(IBAction) openDiffusionGL: (id) sender
{
    NSOpenPanel *openPanel  = [NSOpenPanel openPanel];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"gz", nil];
    [openPanel setTitle:@"Choose _FA image"];
    [openPanel setAllowedFileTypes:fileTypes];
    NSInteger result    = [openPanel runModal];
    if(result!= NSOKButton) return;
    //if (![self checkSandAccess: [[openPanel URL] path]]) return;
    NSString *inName = [[openPanel URL] path];
    NSString *v1Name = [inName stringByReplacingOccurrencesOfString:@"_FA" withString:@"_V1"];
    if ( (![inName isEqualToString: v1Name]) && ([[NSFileManager defaultManager] fileExistsAtPath:v1Name])) {
        [gNiiImg setLoadDTI:inName V1name: v1Name];
    } else {
        NSString *faName = [inName stringByReplacingOccurrencesOfString:@"_V1" withString:@"_FA"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:faName]) {
            [gNiiImg setLoadDTI: faName V1name: inName];
        } else {
            [self ShowAlert: @"Please select a *_FA.nii.gz image in the same folder as a *_V1.nii.gz image" Title:@"Load DTI error" ];
            //ShowAlert(@"Please select a *_FA.nii.gz image in the same folder as a *_V1.nii.gz image",@"Load DTI error");
        }
    } //if v1Name else
    [self drawFrame];
}

-(IBAction) closeOverlaysGL: (id) sender
{
    [gNiiImg closeAllOverlays];
    [self drawFrame];
}

NSArray * niiFileTypes () {
    NSArray *fileTypes = [NSArray arrayWithObjects:
                          @"dcm", @"nii", @"MAT",@"NII",@"hdr", @"HDR",  @"GZ", @"gz",@"voi", @"MGH", @"mgh",  @"MGZ", @"mgz", @"MHA", @"mha",  @"MHD", @"mhd",@"HEAD", @"head", @"nrrd", @"nhdr", nil];
    fileTypes = [fileTypes arrayByAddingObjectsFromArray:[NSImage imageFileTypes]];
    return fileTypes;
}


-(IBAction) addOverlayGL: (id) sender
{
    if ([gNiiImg isBackgroundRGB]) {
        [self ShowAlert:@"You can not load overlays on top of color images (open a grayscale background image)" Title:@"Error"];
        //ShowAlert( @"You can not load overlays on top of color images (open a grayscale background image).", @"Error");
        return;        
    }
    if ([gNiiImg nextOverlaySlot] < 0) { //-1 means no free slots
        [self ShowAlert:@"Unable to add overlays. Please make sure a background image is loaded and you have not loaded too many overlays" Title:@"Error"];
        
        //ShowAlert( @"Unable to add overlays. Please make sure a background image is loaded and you have not loaded too many overlays.", @"Error");
        return;
    }
    NSOpenPanel *openPanel  = [NSOpenPanel openPanel];
    openPanel.title = @"Choose an overlay image";
    
    /*NSArray *fileTypes = [NSArray arrayWithObjects:
                          @"dcm", @"nii", @"MAT",@"NII",@"hdr", @"HDR",  @"GZ", @"gz",@"voi", @"MGH", @"mgh",  @"MGZ", @"mgz", @"MHA", @"mha",  @"MHD", @"mhd",@"HEAD", @"head", @"nrrd", @"nhdr", nil];
    [openPanel setAllowedFileTypes:fileTypes];*/
    [openPanel setAllowedFileTypes:niiFileTypes()];
    
    NSInteger result    = [openPanel runModal];
    if(result != NSOKButton) return;
    //if (![self checkSandAccess: [[openPanel URL] path]]) return;
    [self openOverlayFromFileNameGL:[[openPanel URL] path]];
    [self drawFrame];
}

- (BOOL) openOverlayFromFileNameGL: (NSString *)file_name
{
    int overlaySlot = [gNiiImg addOverlay: file_name];
    if (overlaySlot < 0) return FALSE;
    [self drawFrame];
    return TRUE;
}

-(IBAction) openDocumentGL: (id) sender
{
    NSOpenPanel *openPanel  = [NSOpenPanel openPanel];
    openPanel.title = @"Choose a background image";
    /*NSArray *fileTypes = [NSArray arrayWithObjects:
    @"dcm", @"nii", @"MAT",@"NII",@"hdr", @"HDR",  @"GZ", @"gz",@"voi", @"MGH", @"mgh",  @"MGZ", @"mgz", @"MHA", @"mha",  @"MHD", @"mhd",@"HEAD", @"head", @"nrrd", @"nhdr", nil];
    fileTypes = [fileTypes arrayByAddingObjectsFromArray:[NSImage imageFileTypes]];
    [openPanel setAllowedFileTypes:fileTypes];*/
    [openPanel setAllowedFileTypes:niiFileTypes()];
    //[openPanel setAllowedFileTypes:[NSImage imageFileTypes]];
    NSInteger result    = [openPanel runModal];
    if(result != NSOKButton) return;
    //if (![self checkSandAccess: [[openPanel URL] path]]) return;
    [self openDocumentFromFileNameGL: [[openPanel URL] path]] ;
    [self drawFrame];
    // [self setTitle:@"Empty (Choose File/Open)"];
    //[self openDocumentFromFileName:[openPanel filename]];  // <- works, deprecated
}


/*- (void)saveScreenshotFromFileName:(NSString *) file_name //save PNG screenshot, or capture to clipboard
 {
     // Get the size of the image in a retina safe way
     NII_PREFS *prefs =[gNiiImg getPREFS];
     int q =prefs->rayCastQuality1to10;
     prefs->rayCastQuality1to10 = 10;
     prefs->force_refreshGL = true;
     [self drawFrame];
     
     NSRect backRect = [self convertRectToBacking: [self bounds]];
     int W = NSWidth(backRect);
     int H = NSHeight(backRect);
     // Create image. Note no alpha channel. I don't copy that.
     NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
     pixelsWide: W pixelsHigh: H bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO
     isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 3*W bitsPerPixel: 0];
     // The following block does the actual reading of the image
     glPushAttrib(GL_PIXEL_MODE_BIT); // Save state about reading buffers
     glReadBuffer(GL_FRONT);
     glPixelStorei(GL_PACK_ALIGNMENT, 1); // Dense packing
     glReadPixels(0, 0, W, H, GL_RGB, GL_UNSIGNED_BYTE, [rep bitmapData]);
     glPopAttrib();
     //next: use core image to flip the image so it is rightside up
     CIImage* ciimag = [[CIImage alloc] initWithBitmapImageRep: rep];
     CGAffineTransform trans = CGAffineTransformIdentity;
     trans = CGAffineTransformMakeTranslation(0.0f, H);
     trans = CGAffineTransformScale(trans, 1.0, -1.0);
     ciimag = [ciimag imageByApplyingTransform:trans];
     rep = [[NSBitmapImageRep alloc] initWithCIImage: ciimag];//get data back from core image
     if ([file_name length] < 1) { //save to clipboard
         NSImage *imag = [[NSImage alloc] init];
         [imag addRepresentation:rep];
         NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
         [pasteboard clearContents];
         NSArray *copiedObjects = [NSArray arrayWithObject:imag];
         [pasteboard writeObjects:copiedObjects];
     } else {
         NSData *data = [rep representationUsingType: NSPNGFileType properties: nil];
         [data writeToFile: file_name atomically: NO];
     }
     prefs->rayCastQuality1to10 = q;
 }*/

- (void)saveScreenshotFromFileName:(NSString *) file_name //save PNG screenshot, or capture to clipboard
{
    // Get the size of the image in a retina safe way
    
    NSRect backRect = [self convertRectToBacking: [self bounds]];
    int w = NSWidth(backRect) / screenShotScaleFactor;
    int h = NSHeight(backRect) / screenShotScaleFactor;
    //[gNiiImg updateFontScale: 1];
    int zoom = 3;
    int wz = zoom * w;
    NII_PREFS *prefs =[gNiiImg getPREFS];
    int q =prefs->rayCastQuality1to10;
    prefs->rayCastQuality1to10 = 10;
    int hz = zoom * h;
    // Create image. Note no alpha channel. I don't copy that.
    NSBitmapImageRep *repz = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
     pixelsWide: wz pixelsHigh: hz bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES
       isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 4*wz bitsPerPixel: 0];
   for (int tile = 0; tile < (zoom * zoom); tile++){
        int tilex = (tile % zoom) * w;
        int tiley = (tile / zoom) * h;
       //NSLog(@"%d %d %d",tile, tilex, tiley);
        //[gNiiImg setScreenWidHt: wz Height: hz];
       [gNiiImg setScreenWidHtOffset: wz Height: hz OffsetX: -tilex OffsetY: -tiley];
        [self drawFrame];
        // The following block does the actual reading of the image
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
            pixelsWide: w pixelsHigh: h bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO
            isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 3*w bitsPerPixel: 0];
        glPushAttrib(GL_PIXEL_MODE_BIT); // Save state about reading buffers
        glReadBuffer(GL_FRONT);
        glPixelStorei(GL_PACK_ALIGNMENT, 1); // Dense packing
       //glFlush();
       //glFinish();
       glReadPixels(0, 0, w, h, GL_RGB, GL_UNSIGNED_BYTE, [rep bitmapData]); //use RGB to skip ALPHA
        glPopAttrib();
       //glFlush();
       //glFinish();
        //next: use core image to flip the image so it is rightside up
        CIImage* ciimag = [[CIImage alloc] initWithBitmapImageRep: rep];
        CGAffineTransform trans = CGAffineTransformIdentity;
        trans = CGAffineTransformMakeTranslation(0.0f, h);
        trans = CGAffineTransformScale(trans, 1.0, -1.0);
        ciimag = [ciimag imageByApplyingTransform:trans];
        rep = [[NSBitmapImageRep alloc] initWithCIImage: ciimag];//get data back from core image
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep: repz];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext: context];
        [rep drawInRect: NSMakeRect(tilex, tiley, w, h)] ;
    }
    if ([file_name length] < 1) { //save to clipboard
        NSImage *imag = [[NSImage alloc] init];
        [imag addRepresentation:repz];
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:imag];
        [pasteboard writeObjects:copiedObjects];
    } else {
        NSData *data = [repz representationUsingType: NSPNGFileType properties: nil];
        [data writeToFile: file_name atomically: NO];
    }
    //[gNiiImg setScreenWidHt: w Height: h]; //return to base resolution
    prefs->rayCastQuality1to10 = q;
    //[gNiiImg updateFontScale: screenShotScaleFactor];
    [gNiiImg setScreenWidHtOffset: (w * retinaScaleFactor) Height: (h * retinaScaleFactor) OffsetX: 0 OffsetY: 0];
    [self drawFrame];
}
/*- (void)saveScreenshotFromFileName:(NSString *) file_name //save PNG screenshot, or capture to clipboard
{
    // Get the size of the image in a retina safe way
 
    NSRect backRect = [self convertRectToBacking: [self bounds]];
    int w = NSWidth(backRect);
    int h = NSHeight(backRect);
    int zoom = 2;
    int wz = zoom * w;
    int hz = zoom * h;
    
    // Create image. Note no alpha channel. I don't copy that.
    NSBitmapImageRep *repz = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                                     pixelsWide: wz pixelsHigh: hz bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES
                                                                       isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 4*wz bitsPerPixel: 0];
    
    // Create image. Note no alpha channel. I don't copy that.
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                                    pixelsWide: w pixelsHigh: h bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES
                                                                      isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 4*w bitsPerPixel: 0];
    for (int tile = 0; tile < (zoom * zoom); tile++){
        int tilex = (tile % zoom) * w;
        int tiley = (tile / zoom) * h;
        [gNiiImg setScreenWidHt: wz Height: hz];
        [self drawFrame];
        // The following block does the actual reading of the image
        glPushAttrib(GL_PIXEL_MODE_BIT); // Save state about reading buffers
        glReadBuffer(GL_FRONT);
        glPixelStorei(GL_PACK_ALIGNMENT, 1); // Dense packing
        glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, [rep bitmapData]);
        //glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, [rep bitmapData]);
        //glReadPixels(0, 0, w, h, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, [rep bitmapData]); //OSX-Darwin
        glPopAttrib();
        //next: use core image to flip the image so it is rightside up
        
        CIImage* ciimag = [[CIImage alloc] initWithBitmapImageRep: rep];
        
        CGAffineTransform trans = CGAffineTransformIdentity;
        trans = CGAffineTransformMakeTranslation(0.0f, h);
        trans = CGAffineTransformScale(trans, 1.0, -1.0);
        ciimag = [ciimag imageByApplyingTransform:trans];
        rep = [[NSBitmapImageRep alloc] initWithCIImage: ciimag];//get data back from core image


        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep: repz];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext: context];

        [rep drawInRect: NSMakeRect(tilex, tiley, w, h)] ;
 
    }
    if ([file_name length] < 1) { //save to clipboard
        NSImage *imag = [[NSImage alloc] init];
        [imag addRepresentation:repz];
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:imag];
        [pasteboard writeObjects:copiedObjects];
    } else {
        NSData *data = [repz representationUsingType: NSPNGFileType properties: nil];
        [data writeToFile: file_name atomically: NO];
    }
    [gNiiImg setScreenWidHt: w Height: h]; //return to base resolution
    [self drawFrame];
}*/


-(IBAction) saveDocumentAs: (id) sender //Request filename and save PNG screenshout
{
    NSSavePanel *savePanel = [NSSavePanel savePanel]; 
    [savePanel setTitle:@"Save as PNG bitmap"];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"png",nil]; // Only export PNG
    [savePanel setAllowedFileTypes:fileTypes]; 
    [savePanel setTreatsFilePackagesAsDirectories:NO]; 
    [savePanel setAllowsOtherFileTypes:NO];
    //NSInteger user_choice =  [savePanel runModalForDirectory:NSHomeDirectory() file:@""]; // <- works, deprecated
    [savePanel setNameFieldStringValue:@""];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory() ]];
    NSInteger user_choice =  [savePanel runModal];
    if(NSOKButton == user_choice)
        [self saveScreenshotFromFileName:[[savePanel URL] path]];
}

- (void)copy: (id) sender
{
    [self saveScreenshotFromFileName: @""];
}

- (void) setLoadImageX:(NSString *) file_name newWindow: (bool) isNew {
    NSUInteger iflags = [NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    bool specialKeys = (iflags == NSControlKeyMask);
    if ((specialKeys) && (!isNew))
        [self openOverlayFromFileNameGL:  file_name];
    else
        [gNiiImg setLoadImage:file_name];
    
}

- (BOOL)openDocumentFromFileNameGL:(NSString *) file_name
{
    [self setLoadImageX: file_name newWindow: false];
    //[gNiiImg setLoadImage:file_name];
    //NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    //[prefs setObject:file_name forKey:@"defaultFilename"];
    //
    [[NSUserDefaults standardUserDefaults]setObject:file_name forKey:@"defaultFilename" ];
    //[[NSUserDefaults standardUserDefaults]synchronize ];
    [self drawFrame];
     [[NSNotificationCenter defaultCenter] postNotificationName:@"niiUpdate" object:self userInfo:nil]; //notify window if document drag-dropped directly on view
    return TRUE;
}



- (void) setDisplayMode:(NSInteger)mode
{
    [gNiiImg setDisplayModeX: int(mode)];
    [self drawFrame];
}

- (void) setColorScheme:(NSInteger)colorScheme
{
    [gNiiImg setColorScheme: int(colorScheme)];
    [self drawFrame];
}

-(void) setBackgroundColor: (double) red Green: (double) green Blue: (double) blue {
    [gNiiImg setBackgroundColor: red Green: green Blue: blue];
    [self drawFrame];
}
-(void)getBackgroundColor:(double*)red Green:(double*)green Blue:(double*)blue {
    [gNiiImg getBackgroundColor: red Green: green Blue: blue];
}

- (void) setColorSchemeForLayer:(NSInteger)colorScheme Layer: (int) layer;
{
    [gNiiImg setColorSchemeForLayer: int(colorScheme) Layer: layer];
    [self drawFrame];
}

-(void) refreshGL
{
    [self drawFrame];
}

-(void) setXYZmmGL: (float) x Y: (float) y Z: (float) z {
    if ([gNiiImg setXYZmm: x Y: y Z: z]) [self drawFrame];
    //[gNiiImg setXYZmm: x Y: y Z: z];
}

-(void) changeXYZvoxelGL: (int) x Y: (int) y Z: (int) z {
    if ([gNiiImg changeXYZvoxel: x Y: y Z: z]) [self drawFrame]; //ssss
}

- (NSPoint)convertPointX:(NSPoint)aPoint fromView:(NSView *)aView;
{
    NSPoint pt = [self convertPoint: aPoint fromView: aView];
    if (self->retinaScaleFactor > 1.0) {
        pt.x *= self->retinaScaleFactor;
        pt.y *= self->retinaScaleFactor;
        
    }
    return pt;
}

- (void)marchingAntsMouseDown:(NSEvent *)event
{
    // create animation for the layer - invisible for retina?
    self->startPoint = [self convertPointX:[event locationInWindow] fromView:nil];
    self->shapeLayer = [CAShapeLayer layer];
    self->shapeLayer.lineWidth = 2.0;
    //self->shapeLayer.strokeColor = [[NSColor blackColor] CGColor];
    //self->shapeLayer.strokeColor = [[NSColor purpleColor] CGColor];
    //self->shapeLayer.strokeColor = [[NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.75 alpha:0.8] CGColor]; //colorBarBorderColor
    self->shapeLayer.strokeColor = [[NSColor colorWithCalibratedRed:0.6 green:0.0 blue:0.6 alpha:0.8] CGColor]; //colorBarBorderColor
    //[NSColor colorWithCalibratedRed:0.227f green:0.251f blue:0.337 alpha:0.8];
    self->shapeLayer.fillColor = [[NSColor clearColor] CGColor];
    self->shapeLayer.lineDashPattern = @[@10, @5];
    //[self->layer addSublayer:self.shapeLayer];
    [self.layer addSublayer:self->shapeLayer];
    CABasicAnimation *dashAnimation;
    dashAnimation = [CABasicAnimation animationWithKeyPath:@"lineDashPhase"];
    [dashAnimation setFromValue:@0.0f];
    [dashAnimation setToValue:@15.0f];
    [dashAnimation setDuration:0.75f];
    [dashAnimation setRepeatCount:HUGE_VALF];
    [self->shapeLayer addAnimation:dashAnimation forKey:@"linePhase"];
}


- (void)mouseDown:(NSEvent *)event {
    //NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSPoint location = [self convertPointX:[event locationInWindow] fromView: nil]; //RetinaX 2016
    [gNiiImg setMouseDown:location.x Y:location.y];
    [self drawFrame];
    
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  (flags & NSShiftKeyMask)
        [self marchingAntsMouseDown: event];
}

- (void)mouseDragged:(NSEvent *)event
{
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  (flags & NSShiftKeyMask){
        [self rightMouseDragged: event];
        return;
    }
    NSPoint location = [self convertPointX:[event locationInWindow] fromView:nil];
    [gNiiImg setMouseDrag: location.x Y: location.y];
    [self drawFrame];
}

- (void)mouseUp:(NSEvent *)event
{
    //[self.shapeLayer removeFromSuperlayer];
    //self.shapeLayer = nil;
    
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  (flags & NSShiftKeyMask){
        [self rightMouseUp: event];
        return;
    }
    
}

- (void)rightMouseDown:(NSEvent *)event
{
    [self mouseDown: event]; //  treat as left mouse button down event
    [self marchingAntsMouseDown: event];
        //http://stackoverflow.com/questions/20357960/drawing-selection-box-rubberbanding-marching-ants-in-cocoa-objectivec

    /*self.startPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    
    // create and configure shape layer
    */
    
 /*   // create animation for the layer
    self->startPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    self->shapeLayer = [CAShapeLayer layer];
    self->shapeLayer.lineWidth = 1.0;
    self->shapeLayer.strokeColor = [[NSColor blackColor] CGColor];
    self->shapeLayer.fillColor = [[NSColor clearColor] CGColor];
    self->shapeLayer.lineDashPattern = @[@10, @5];
    //[self->layer addSublayer:self.shapeLayer];
    [self.layer addSublayer:self->shapeLayer];
    
    CABasicAnimation *dashAnimation;
    dashAnimation = [CABasicAnimation animationWithKeyPath:@"lineDashPhase"];
    [dashAnimation setFromValue:@0.0f];
    [dashAnimation setToValue:@15.0f];
    [dashAnimation setDuration:0.75f];
    [dashAnimation setRepeatCount:HUGE_VALF];
    [self->shapeLayer addAnimation:dashAnimation forKey:@"linePhase"];*/
    
}

- (void)rightMouseDragged:(NSEvent *)event
{
    NSPoint point = [self convertPointX:[event locationInWindow] fromView:nil];
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, self->startPoint.x, self->startPoint.y);
    CGPathAddLineToPoint(path, NULL, self->startPoint.x, point.y);
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    CGPathAddLineToPoint(path, NULL, point.x, self->startPoint.y);
    CGPathCloseSubpath(path);
    // set the shape layer's path
    self->shapeLayer.path = path;
    CGPathRelease(path);
    NSPoint location = [self convertPointX:[event locationInWindow] fromView:nil];
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    [gNiiImg setRightMouseDragXY: location.x Y: location.y isMag: (flags & NSControlKeyMask) isSwipe: (flags & NSCommandKeyMask)];
    
    /*if  (flags & NSControlKeyMask)
        [gNiiImg setRightMouseDragY: location.y isMag: true];
    else
        [gNiiImg setRightMouseDragY: location.y isMag: false];*/
    /*if  (!(flags & NSControlKeyMask))
        [gNiiImg setRightMouseDragX: location.x];
    if  (!(flags & NSCommandKeyMask))
        [gNiiImg setRightMouseDragY: location.y];*/
    //[gNiiImg setRightMouseDrag: location.x Y: location.y];
    [self drawFrame];
}

- (void)rightMouseUp:(NSEvent *)event
{
    //in future Marching Ants? http://stackoverflow.com/questions/20357960/drawing-selection-box-rubberbanding-marching-ants-in-cocoa-objectivec
    [self->shapeLayer removeFromSuperlayer];
    self->shapeLayer = nil;
    NSPoint location = [self convertPointX:[event locationInWindow] fromView:nil];
    if (![gNiiImg setRightMouseUp:location.x Y:location.y]) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"niiUpdate" object:self userInfo:nil];
}

- (void)scrollWheel:(NSEvent *)event
{
    if ((event.deltaY == 0) && (event.deltaX == 0)) return;
    if ([gNiiImg setScrollWheel: event.deltaX Y: event.deltaY]) [self drawFrame];
}

- (void) rotateWithEvent:(NSEvent *)event;
{
    if (fabs(event.rotation) < 0.5) return;
    //NSLog(@"rot %@", event);
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  (flags & NSControlKeyMask) return;
    //[gNiiImg changeClipDepth: 8*event.rotation];
    [gNiiImg setMagnify: event.rotation];
    [self drawFrame];
}

- (void) magnifyWithEvent:(NSEvent *)event;
{
    if (fabs(event.magnification) < 0.01) return;
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  (flags & NSCommandKeyMask) return;
    if  (flags & NSControlKeyMask)
        [gNiiImg setMagnify: event.magnification];
    else
        [gNiiImg changeClipDepth: 200*event.magnification];
    [self drawFrame];
}

- (void)swipeWithEvent:(NSEvent *)event
{
    //NSLog(@"swipe %g %g", event.deltaX, event.deltaY);
    [gNiiImg setSwipe: event.deltaX Y: event.deltaY];
    [self drawFrame];
}//older versions of OSX?*/


/*- (void)swipeWithEvent:(NSEvent *)event
{
    NSLog(@"swipe %g %g %lu %lu", event.deltaX, event.deltaY, event.type, NSEventTypeSwipe);
    [gNiiImg setSwipe:[event deltaX] Y:[event deltaY]];
    [self drawFrame];
}//older versions of OSX?*/
/*#define kSwipeMinimumLength 0.1

-(void)beginGestureWithEvent:(NSEvent *)event
{
    //if (![self recognizeTwoFingerGestures]) return;
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
    self.twoFingersTouches = [[NSMutableDictionary alloc] init];
    for (NSTouch *touch in touches) {
        [twoFingersTouches setObject:touch forKey:touch.identity];
    }
}



- (void)endGestureWithEvent:(NSEvent *)event
{
    if (!twoFingersTouches) return;
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
    // release twoFingersTouches early
    NSMutableDictionary *beginTouches = [twoFingersTouches copy];
    self.twoFingersTouches = nil;
    NSMutableArray *magnitudesX = [[NSMutableArray alloc] init];
    NSMutableArray *magnitudesY = [[NSMutableArray alloc] init];
    for (NSTouch *touch in touches) {
        NSLog(@"-");
        NSTouch *beginTouch = [beginTouches objectForKey:touch.identity];
        if (!beginTouch) continue;
        float magnitude = touch.normalizedPosition.x - beginTouch.normalizedPosition.x;
        [magnitudesX addObject:[NSNumber numberWithFloat:magnitude]];
        magnitude = touch.normalizedPosition.y - beginTouch.normalizedPosition.y;
        [magnitudesY addObject:[NSNumber numberWithFloat:magnitude]];
    }
    // Need at least two points
    if ([magnitudesX count] < 2) return;
    float sumX = 0;
    for (NSNumber *magnitude in magnitudesX)
        sumX += [magnitude floatValue];
    float sumY = 0;
    for (NSNumber *magnitude in magnitudesY)
        sumY += [magnitude floatValue];
    // Handle natural direction in Lion
    BOOL naturalDirectionEnabled = [[[NSUserDefaults standardUserDefaults] valueForKey:@"com.apple.swipescrolldirection"] boolValue];
    if (naturalDirectionEnabled)
        sumX *= -1;
    // See if absolute sum is long enough to be considered a complete gesture
    float absoluteSumX = fabsf(sumX);
    float absoluteSumY = fabsf(sumY);
    if ((absoluteSumX < kSwipeMinimumLength) && (absoluteSumY < kSwipeMinimumLength)) return;
    if (absoluteSumX < kSwipeMinimumLength) sumX = 0;
    if (absoluteSumY < kSwipeMinimumLength) sumY = 0;
    // Handle the actual swipe
    [gNiiImg setSwipe:sumX Y:sumY];
    [self drawFrame];
}
 */

- (void) viewDidMoveToWindow
{
    // Listen to all mouse move events (not just dragging)
    [[self window] setAcceptsMouseMovedEvents:YES];
    // When view changes to this window then be sure that we start responding
    // to mouse events
    [[self window] makeFirstResponder:self];
}

- (void) drawFrame
{
    NSOpenGLContext    *currentContext = [self openGLContext];
    [currentContext makeCurrentContext];
    // must lock GL context because display link is threaded
    CGLLockContext((CGLContextObj)[currentContext CGLContextObj]);
    [gNiiImg doRedraw]; // Flush OpenGL context

    
    /*
    NSString * string = [NSString stringWithFormat:@"VX %d", 123];
    [infoStringTex setString:string withAttributes:stanStringAttrib];
    [infoStringTex drawAtPoint:NSMakePoint (32, 32)];
    string = [NSString stringWithFormat:@"Camera at (%0.1f)", 543.01];
    [infoStringTex setString:string withAttributes:stanStringAttrib];
    [infoStringTex drawAtPoint:NSMakePoint (64, 64)];*/
    
    //glFlush();
    //[currentContext flushBuffer];
    CGLUnlockContext((CGLContextObj)[currentContext CGLContextObj]);
}

- (void) reshape { //resize
    [gNiiImg setScreenWidHt: [self bounds].size.width * self->retinaScaleFactor Height: [self bounds].size.height * self->retinaScaleFactor];//RetinaX 2016
    //[gNiiImg setScreenWidHt: [self bounds].size.width Height: [self bounds].size.height];//2014
    NSOpenGLContext    *currentContext = [self openGLContext];
    [currentContext makeCurrentContext];
    // remember to lock the context before we touch it since display link is threaded
    CGLLockContext((CGLContextObj)[currentContext CGLContextObj]);
    // let the context know we've changed size
    [[self openGLContext] update];
    CGLUnlockContext((CGLContextObj)[currentContext CGLContextObj]);
    //NSLog(@"GLView->Reshape %f %f", [self bounds].size.width , [self bounds].size.height);//66666666
    //self.view.frame.size.width
    //[super reshape];
    //[gNiiImg setScreenWidHt: [self bounds].size.width Height: [self bounds].size.height];
    //[self drawFrame]; //do this immediately - don't wait for timer!
}

- (void)drawRect:(NSRect)rect 
{
    [super drawRect:rect]; //??
    [self drawFrame];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    return  YES;
}

- (BOOL)resignFirstResponder
{
    return YES;
}

- (bool) sharpen {
    bool ret = [gNiiImg sharpen];
    if (ret == FALSE) {
        //[self ShowAlert:@"This function only works on 3D grayscale data" Title:@"Unable to remove haze"];
        [self ShowAlert:@"This function only works on grayscale data" Title:@"Unable to remove haze"]; //allow displayed volume of 4D
        return ret;
    }
    [self drawFrame];
    return ret;
}


- (bool) removeHaze {
     bool ret = [gNiiImg removeHaze];
    if (ret == FALSE) {
        //[self ShowAlert:@"This function only works on 3D grayscale data" Title:@"Unable to remove haze"];
        [self ShowAlert:@"This function only works on grayscale data" Title:@"Unable to remove haze"]; //allow displayed volume of 4D
        return ret;
    }
    [self drawFrame];    
    return ret;
}

- (void) resetClip
{
    int azim = 180;
    int elev = 0;
    int depth = 0;
    [gNiiImg setClip: azim Elev: elev Depth: depth];
    [self drawFrame];
}

-(NSString *)  matToText: (mat44)m
{
    NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
    [nf setNumberStyle:NSNumberFormatterDecimalStyle];
    [nf setMaximumFractionDigits:3];
    [nf setRoundingMode:NSNumberFormatterRoundDown];
    NSString * ret;
    ret = [NSString stringWithFormat:@"[%@ %@ %@ %@; %@ %@ %@ %@; %@ %@ %@ %@]",
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[0][0]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[0][1]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[0][2]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[0][3]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[1][0]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[1][1]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[1][2]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[1][3]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[2][0]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[2][1]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[2][2]]],
           [nf stringFromNumber:[NSNumber numberWithFloat:m.m[2][3]]]];
    return ret;
}

/*-(NSString *)  matToText: (mat44)m
//this works, but gives hard to decipher scientific results for values near zero
 {
    NSString * ret;
    ret = [NSString stringWithFormat:@"[%g %g %g %g; %g %g %g %g; %g %g %g %g]",
           m.m[0][0],m.m[0][1],m.m[0][2],m.m[0][3],
           m.m[1][0],m.m[1][1],m.m[1][2],m.m[1][3],
           m.m[2][0],m.m[2][1],m.m[2][2],m.m[2][3] ];
    return ret;
}*/

-(NSString *) getHeaderFilename;
{
    NII_PREFS *prefs =[gNiiImg getPREFS];
    //return prefs->nii_prefs_fname;
    //NSLog(@"nii_GL fname = %s", prefs->nii_prefs_fname);
    return [NSString stringWithCString:prefs->nii_prefs_fname encoding:NSASCIIStringEncoding];
}

-(NSString *) getHeaderInfo
{
    FSLIO *f = [gNiiImg getFSLIO];
    NSString * ret;
    NSString *smat = [self matToText:f->niftiptr->sto_xyz];
    if (f->niftiptr->dim[0] == 3)
        ret = [NSString stringWithFormat:@"Dimensions: %dx%dx%d\nBytes per voxel: %d\nSpacing: %.3fx%.3fx%.3f\nMatrix %@",
               f->niftiptr->dim[1], f->niftiptr->dim[2], f->niftiptr->dim[3],
               f->niftiptr->nbyper,
               f->niftiptr->pixdim[1],f->niftiptr->pixdim[2],f->niftiptr->pixdim[3], smat ];
    else
        ret = [NSString stringWithFormat:@"Dimensions: %dx%dx%dx%d\nBytes per voxel: %d\nSpacing: %.3fx%.3fx%.3fx%.5f\nMatrix %@",
      f->niftiptr->dim[1], f->niftiptr->dim[2], f->niftiptr->dim[3],  f->niftiptr->dim[4],
            f->niftiptr->nbyper,
      f->niftiptr->pixdim[1],f->niftiptr->pixdim[2],f->niftiptr->pixdim[3], f->niftiptr->pixdim[4], smat  ];
    
    NSString *desc= [NSString stringWithUTF8String:f->niftiptr->descrip];
    
    desc = [desc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (desc.length > 0)
        ret = [ret stringByAppendingString:[@"\nDescription: " stringByAppendingString: desc]];
    NSString * slicecode;
    if (f->niftiptr->slice_code == NIFTI_SLICE_SEQ_INC)
        slicecode = @"\nAscending";
    else if (f->niftiptr->slice_code == NIFTI_SLICE_SEQ_DEC)
        slicecode = @"\nDescending";
    else if (f->niftiptr->slice_code == NIFTI_SLICE_ALT_INC)
        slicecode = @"\nInterleaved Ascending [1,3..2,4..]";
    else if (f->niftiptr->slice_code == NIFTI_SLICE_ALT_DEC)
        slicecode = @"\nInterleaved Descending [n,n-2..n-1,n-3..]";
    else if (f->niftiptr->slice_code == NIFTI_SLICE_ALT_INC2)
        slicecode = @"\n*Interleaved Ascending [2,4..1,3..]";
    else if (f->niftiptr->slice_code == NIFTI_SLICE_ALT_DEC2)
        slicecode = @"\n*Interleaved Descending [n-1,n-3,..n,n-2..]";
    else
        slicecode = @"";
    ret = [ret stringByAppendingString: slicecode];
     /*= @"Your String"
    NIFTI_SLICE_SEQ_INC  == sequential increasing
    NIFTI_SLICE_SEQ_DEC  == sequential decreasing
    NIFTI_SLICE_ALT_INC  == alternating increasing
    NIFTI_SLICE_ALT_DEC  == alternating decreasing
    NIFTI_SLICE_ALT_INC2 == alternating increasing #2
    NIFTI_SLICE_ALT_DEC2 == alternating decreasing #2
    f->niftiptr->slice_code*/
    //if (f->niftiptr->descrip)
    //    ret = [ret stringByAppendingString:@".png"];
    return ret;
}

/*
static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now,
                                      const CVTimeStamp *outputTime, CVOptionFlags flagsIn,
                                      CVOptionFlags *flagsOut, void *displayLinkContext)
{
    // go back to Obj-C for easy access to instance variables
#if !__has_feature(objc_arc)
    CVReturn result = [( nii_GLView *)displayLinkContext getFrameForTime:outputTime];
#else
    CVReturn result = [(__bridge nii_GLView *)displayLinkContext getFrameForTime:outputTime];
#endif
    return result;
}
*/

/*
- (id)initWithFrame:(NSRect)frameRect
{
    // context setup
    //[self  setWantsBestResolutionOpenGLSurface:YES];
    NSOpenGLPixelFormat        *windowedPixelFormat;
    NSOpenGLPixelFormatAttribute    attribs[] = {
        NSOpenGLPFAWindow,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFASingleRenderer,
        0 };
    
    windowedPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
    if (windowedPixelFormat == nil)
    {
        NSLog(@"Unable to create windowed pixel format.");
        exit(0);
    }
    //[self logVideoMemoryCurrentRendererX];
    
    self = [super initWithFrame:frameRect pixelFormat:windowedPixelFormat];
    if (self == nil)
    {
        NSLog(@"Unable to create a windowed OpenGL context.");
        exit(0);
    }
#if !__has_feature(objc_arc)
    [windowedPixelFormat release];
#endif
    // set synch to VBL to eliminate tearing
    GLint    vblSynch = 1;
    [[self openGLContext] setValues:&vblSynch forParameter:NSOpenGLCPSwapInterval];
    // set up the display link
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

#if !__has_feature(objc_arc)
    CVDisplayLinkSetOutputCallback(displayLink, MyDisplayLinkCallback, ( void *)(self));
#else
 //2015   CVDisplayLinkSetOutputCallback(displayLink, MyDisplayLinkCallback, (__bridge void *)(self));
#endif
    CGLContextObj cglContext = (CGLContextObj)[[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[self pixelFormat] CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
    return self;
}*/

/*- (void)initGL
{
    [[self openGLContext] makeCurrentContext];
    GLint one = 1;
    [[self openGLContext] setValues:&one forParameter:NSOpenGLCPSwapInterval];
        [self logVideoMemoryCurrentRendererX ];
}


- (void) prepareOpenGL
{

//     NSFont * font =[NSFont fontWithName:@"Helvetica" size:16.0];
//     stanStringAttrib = [NSMutableDictionary dictionary];
//     [stanStringAttrib setObject:font forKey:NSFontAttributeName];
//     [stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
     // ensure strings are created
     //[self infoStringTex];
 //    [self createHelpString];
    //[gNiiImg prepareOpenGL];
    [self initGL];
    //[self setupDisplayLink];
}*/

/*- (void) checkFeatures {
    [[self openGLContext] makeCurrentContext];
    GLint maxRectTextureSize;
    GLint myMaxTextureUnits;
    GLint myMaxTextureSize;
    const GLubyte * strVersion;
    const GLubyte * strExt;
    float myGLVersion;
    GLboolean isVAO, isTexLOD, isColorTable, isFence, isShade,
    isTextureRectangle;
    strVersion = glGetString (GL_VERSION); // 1
    sscanf((char *)strVersion, "%f", &myGLVersion);
    NSLog(@"%s",strVersion);
    
    strExt = glGetString (GL_EXTENSIONS); // 2
    glGetIntegerv(GL_MAX_TEXTURE_UNITS, &myMaxTextureUnits); // 3
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &myMaxTextureSize); // 4
    isVAO =
    gluCheckExtension ((const GLubyte*)"GL_APPLE_vertex_array_object",strExt); // 5
    isFence = gluCheckExtension ((const GLubyte*)"GL_APPLE_fence", strExt); // 6
    isShade =
    gluCheckExtension ((const GLubyte*)"GL_ARB_shading_language_100", strExt); // 7
    isColorTable =
    gluCheckExtension ((const GLubyte*)"GL_SGI_color_table", strExt) ||
    gluCheckExtension ((const GLubyte*)"GL_ARB_imaging", strExt); // 8
    isTexLOD =
    gluCheckExtension ((const GLubyte*)"GL_SGIS_texture_lod", strExt) ||
    (myGLVersion >= 1.2); // 9
    isTextureRectangle = gluCheckExtension ((const GLubyte*)
                                        "GL_EXT_texture_rectangle", strExt);
    if (isTextureRectangle)
        glGetIntegerv (GL_MAX_RECTANGLE_TEXTURE_SIZE_EXT, &maxRectTextureSize);
    else
        maxRectTextureSize = 0; // 10
    NSLog(@"v %f -- %d %d %d",myGLVersion, myMaxTextureUnits, myMaxTextureSize, maxRectTextureSize);
}*/

/*- (void) awakeFromNibY
{
    //[self setAcceptsTouchEvents: YES];
    gNiiImg = [nii_img alloc];
    gNiiImg = [gNiiImg init];
    [self updatePrefs];
    //self.acceptsTouchEvents = YES;
    //[[NSUserDefaults standardUserDefaults] setObject:@"/Users/cr/t1.nii" forKey:@"defaultFilename"];
    //for (int i = 0; i < 256; i++)  //test for leaks...
    //NSLog(@"BETA");
    [self setLoadImageX: [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"] newWindow: true];
    //[gNiiImg setLoadImage:[[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"] ];
    [gNiiImg setScreenWidHt: [self bounds].size.width Height: [self bounds].size.height];
    //CVDisplayLinkStart(displayLink);
    //[self logVideoMemoryCurrentRendererX];
}*/

- (void) awakeFromNib
{
    //[self setAcceptsTouchEvents: YES];

    
    gNiiImg = [nii_img alloc];
    gNiiImg = [gNiiImg init];
    [self updatePrefs];
    screenShotScaleFactor = 1.0f;
    retinaScaleFactor = 1.0f;
    float supportRetina = 1.0;
    if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)]) {
        NSArray *screens = [NSScreen screens];
        for (int i = 0; i < [screens count]; i++) {
            float s = [[screens objectAtIndex:i] backingScaleFactor];
            if (s > supportRetina)
                supportRetina = s;
        }
    }
    NII_PREFS *prefs =[gNiiImg getPREFS]; //RetinaXX
    if (prefs->retineResolution) {
        [self setWantsBestResolutionOpenGLSurface:YES];//RetinaX 2016  - (void) prepareOpenGL
        [self convertRectToBacking:[self bounds]];
        retinaScaleFactor = supportRetina;
        
    } else if (supportRetina > 1.0) {
        screenShotScaleFactor = supportRetina;
        [gNiiImg updateFontScale: screenShotScaleFactor];
    }
    
        //RetinaX 2016

    
    //NSRect hdRect = [self convertRectToBacking: [self bounds]];
    //NSRect sdRect = [self bounds];
    //NSLog(@"retinaScaleFactor %g %g", NSWidth(hdRect), NSWidth(sdRect));
    //[gNiiImg updateFont: aColor] ;
    //NSLog(@"retinaScaleFactor %g ", retinaScaleFactor);
    
    //self.acceptsTouchEvents = YES;
    //[[NSUserDefaults standardUserDefaults] setObject:@"/Users/cr/t1.nii" forKey:@"defaultFilename"];
    //for (int i = 0; i < 256; i++)  //test for leaks...
    //NSLog(@"BETA");
    [self setLoadImageX: [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"] newWindow: true];
    //[gNiiImg setLoadImage:[[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"] ];
    [gNiiImg setScreenWidHt: [self bounds].size.width Height: [self bounds].size.height];
    //CVDisplayLinkStart(displayLink);
    //[self logVideoMemoryCurrentRendererX];
}

- (void)deallocGL
{
    #if !__has_feature(objc_arc)
    [gNiiImg dealloc];
    #endif
}

- (void)dealloc
{
    //CVDisplayLinkRelease(displayLink);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

@end
