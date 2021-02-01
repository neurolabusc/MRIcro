#import <OpenGL/gl.h>
#import <Cocoa/Cocoa.h>
#import "nii_img.h"
#import "nii_timelineView.h"
#import <QuartzCore/QuartzCore.h>
//#include <OpenGL/gl.h>
//#import "GLString.h"



@interface nii_GLView : NSOpenGLView
{
	//NSMutableDictionary * stanStringAttrib;
	//GLString * infoStringTex;
  //CVDisplayLinkRef displayLink;
  //  CAShapeLayer *shapeLayer;
  NSPoint startPoint;
    CAShapeLayer *shapeLayer;

  @private
    nii_img *gNiiImg;
    float screenShotScaleFactor;
    //float retinaScaleFactor;
}

typedef struct   {
    int activeOverlay[MAX_OVERLAY]; // true if overlay active
	double viewMin, viewMax;
	int colorScheme;
} LayerValues;

//-(NSString *) getImageName;
-(LayerValues) getLayerValues: (int) index;
-(NSString *) getHeaderFilename;
-(NSString *) getHeaderInfo;
-(GraphStruct) getTimelineGL;
-(bool) isTimelineUpdateNeededGL;
-(void)skipNumberOfVolumesGL: (int) skip;
-(void) setAzimElevOrient: (int) orient;
-(int) getNumberOfVolumesGL;
-(void) setXYZmmGL: (float) x Y: (float) y Z: (float) z;
-(void) changeXYZvoxelGL: (int) x Y: (int) y Z: (int) z;
///////////////////////////////////////////////////////////////////////////////
// File IO
///////////////////////////////////////////////////////////////////////////////
// Default open function, called when using File > Open dialog, but also when
// files (of correct type) are dragged to the dock icon 
- (IBAction) closeOverlaysGL: (id) sender;
- (IBAction) addOverlayGL: (id) sender;
- (IBAction) openDiffusionGL: (id) sender;
- (BOOL) openOverlayFromFileNameGL: (NSString *)file_name;
//- (BOOL) checkSandAccess: (NSString *)file_name;
//- (IBAction) openDocumentGL: (id) sender;
- (IBAction) copy: (id) sender;
- (IBAction) saveDocumentAs: (id) sender;
- (void)saveScreenshotFromFileName:(NSString *) file_name;
- (void) deallocGL;
- (BOOL) openDocumentFromFileNameGL: (NSString *)file_name; //returns TRUE on success
//- (void) prepareOpenGL;
///////////////////////////////////////////////////////////////////////////////
// Mouse and Keyboard Input
///////////////////////////////////////////////////////////////////////////////
/*

 - (void) keyDown:(NSEvent *)event;
- (void) keyUp:(NSEvent *)event;
 - (void) mouseUp:(NSEvent *)event;
 - (void) mouseMoved:(NSEvent *)event;
  - (void) rightMouseUp:(NSEvent *)event;
 - (void) otherMouseDown:(NSEvent *)event;
  - (void)otherMouseDragged:(NSEvent *)event;
 - (void) otherMouseUp:(NSEvent *)event;

  - (void) mouseUp:(NSEvent *)event;
 */
- (void) mouseDown:(NSEvent *)event;
- (void) mouseDragged:(NSEvent *)event;

- (void) rightMouseDown:(NSEvent *)event;
- (void) rightMouseDragged:(NSEvent *)event;
- (void) scrollWheel:(NSEvent *)event;
- (void) magnifyWithEvent:(NSEvent *)event;
- (void) swipeWithEvent:(NSEvent*)event;

- (void) viewDidMoveToWindow;
// OpenGL apps like to think of (0,0) being the top left corner, cocoa apps
// think of (0,0) as the bottom left corner. This simple flips the y coordinate
// according to the current height
// Inputs:
//   location  point of click according to Cocoa
// Returns
//   point of click according to with y coordinate flipped
- (void) setContrast:(NSPoint)value;
-(void) makeMosaicGL:(NSString *)mosStr;
-(void) setViewGamma: (float) gamma;
-(void) setFontScale: (float) scale;
//-(void) forceRecalc;
-(void) setViewMinMaxForLayer: (double) min Max: (double) max Layer: (int) layer;
-(void) resetClip;
-(void) ShowAlert: (NSString *)theMessage Title: (NSString *) theTitle;
-(bool) removeHaze;
-(bool) sharpen;
-(void) updatePrefs;
- (void) setDisplayMode:(NSInteger)mode;
- (void) setColorScheme:(NSInteger)colorScheme;
- (void) setColorSchemeForLayer:(NSInteger)colorScheme Layer: (int) layer;
-(void) setBackgroundColor: (double) red Green: (double) green Blue: (double) blue;
-(void)getBackgroundColor:(double*)red Green:(double*)green Blue:(double*)blue;

///////////////////////////////////////////////////////////////////////////////
// OpenGL
///////////////////////////////////////////////////////////////////////////////
// Called whenever openGL context changes size
- (void) reshape;
-(void) refreshGL; //refresh image
// Main display or draw function, called when redrawn
//- (void) drawFrame;
// Set initial OpenGL state (current context is set)
// called after context is created
//- (void) prepareOpenGL;
// this can be a troublesome call to do anything heavyweight, as it is called
// on window moves, resizes, and display config changes.  So be careful of
// doing too much here.  window resizes, moves and display changes (resize,
// depth and display config change)






///////////////////////////////////////////////////////////////////////////////
// Cocoa
///////////////////////////////////////////////////////////////////////////////
- (BOOL) acceptsFirstResponder;
- (BOOL) becomeFirstResponder;
- (BOOL) resignFirstResponder;
- (void) awakeFromNib;

@property (retain) NSMutableDictionary *twoFingersTouches;

@end
