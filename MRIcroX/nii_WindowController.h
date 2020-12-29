//
//  nii_WindowController.h
//  MRIcroX
//
//  Created by Chris Rorden on 9/19/12.
//  Copyright 2012 University of South Carolina. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "nii_GLView.h"
#import "nii_timelineView.h"

//window file owner must be nii_WindowController
//window must have Outlets/Delagate linked to FileOwner
//window Outlets/ReferencingOutlets must also be linked to file owner for cascading

@interface nii_WindowController : NSWindowController {


    IBOutlet NSWindow *theWindow;
    IBOutlet NSTextField *darkEdit;
    IBOutlet NSTextField *brightEdit;
    IBOutlet NSPopUpButton *layerDrop;
    IBOutlet NSPopUpButton *colorDrop;
    IBOutlet NSPopUpButton *modeDrop;
    IBOutlet NSPanel *headerWindow;
    IBOutlet NSSplitView *theSplitter;
    IBOutlet NSSlider *gammaSlider;
    //IBOutlet NSSplitView *theSplitter;
    IBOutlet nii_timelineView *niiTimeline;
    IBOutlet nii_GLView *niiGL;
    NSTimer* timelineTimer; //4D graph timer
    NSString* mosaicStr;
}
-(void) updatePrefs:(id)sender;

-(void) showWindowPost:(id)sender;
- (IBAction)modeChange:(id)sender;
- (IBAction)darkEditChange:(id)sender;
- (IBAction)brightEditChange:(id)sender;
- (IBAction)layerDropChange:(id)sender;
- (IBAction)colorDropChange:(id)sender;
- (IBAction)infoClick:(id)sender;
- (IBAction)gammaSlide:(id)sender;
- (IBAction) saveTimelineAsPDF: (id) sender;
- (IBAction) saveTimelineAsText: (id) sender;
- (IBAction) openDocument: (id) sender;
- (IBAction)open:(id)sender;
- (BOOL) isActiveKey;
- (BOOL) openDocumentFromFileName: (NSString *)file_name;
- (IBAction) openDiffusionWC: (id) sender;
- (IBAction) closeOverlays: (id) sender;
- (IBAction) addOverlay: (id) sender;
- (IBAction) removeHaze: (id) sender;
- (IBAction) doSharpen: (id) sender;



- (IBAction) changeBackgroundColor: (id) sender;
- (void)windowWillClose:(NSNotification *)notification;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;
-(void) setXYZmmWC: (float) x Y: (float) y Z: (float) z;
- (IBAction) volumePrior: (id) sender;
- (IBAction) volumeNext: (id) sender;


@end
