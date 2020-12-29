//
//  nii_WindowController.m
//  MRIcroX
//
//  Created by Chris Rorden on 9/19/12.
//  Copyright 2012 University of South Carolina. All rights reserved.
//

#import "nii_WindowController.h"
#import "nii_GLView.h"
#import "nii_timelineView.h"
#import "MRIcroAppDelegate.h"

#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>

@implementation nii_WindowController

- (NSString *)inputDialog: (NSString *)prompt defaultValue: (NSString *)defaultValue {
    NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:defaultValue];
    //[input autorelease];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        return [input stringValue];
    } else if (button == NSAlertAlternateReturn) {
        return nil;
    } else {
        //NSAssert1(NO, @"Invalid input dialog button %d", button);
        return nil;
    }
}

- (void)niiNotificationUpdateMosaic:(NSNotification *) notification
{
    if (notification.object != niiTimeline) return; //message from a different image window
    //NSString *def = @"V 0.1 A 0.5 S 0.5; C 0.4 0.6";//666 decimal separator in germany
    mosaicStr = [self inputDialog: @"Describe desired mosaic (e.g. 'V 0.5 A 0.5 S 0.5; C 0.4 0.6')" defaultValue:mosaicStr];
    if (mosaicStr == nil) {
        NSLog(@"Error");
        mosaicStr =@"V 0.1 A 0.5 S 0.5; C 0.4 0.6";
        return;
    }
    //NSLog(@"%@", def);
    [niiGL makeMosaicGL: mosaicStr];
    [niiTimeline pasteFromClipboard];
    theWindow.backgroundColor = [NSColor blackColor];// [NSColor colorWithCalibratedRed:0.227f green:0.251f blue:0.337 alpha:0.8];xxx
    
    [niiGL reshape];
}

- (void)niiNotificationUpdateToolbar:(NSNotification *) notification
{
    //if (notification.object == niiGL) NSLog(@"Thats my baby");
    //if (notification.object != niiGL) NSLog(@"Thats an imposter");
    if (notification.object != niiGL) return; //message from a different image window
    //NSLog(@"Got notified: %@", notification);
    [self updateEverything]; //refresh filename in titlebar if drag/drop of image
    [niiGL refreshGL];
}

-(void) showWindowPost:(id)sender {
   // NSLog(@"update!");
   [self updateEverything];
}

-(void) updateThemeMode {
if ([[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"])
theWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
else
theWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
}

-(void) updatePrefs:(id)sender {
    [self updateThemeMode];
    [niiGL updatePrefs];
}

-(void) stopTimer {
    if (timelineTimer == nil) {
            //NSLog(@"Timer already stopped");
    } else {
        [timelineTimer invalidate];
        timelineTimer = nil;
    }
}

-(void) updateTimeline {
    GraphStruct graph = [niiGL getTimelineGL];
    if (graph.timepoints > 1) {
        [niiTimeline updateData: graph];
        free(graph.data);
    }
}

- (void)timelineTimerTick:(NSTimer *)timer {
    if (![niiGL isTimelineUpdateNeededGL]) return;
    if (niiTimeline.bounds.size.height < 5) return;
    [self updateTimeline];
}

-(void) startTimer {
    if (timelineTimer == nil) {
        float theInterval = 1.0/6.0;
        timelineTimer = [NSTimer scheduledTimerWithTimeInterval:theInterval target:self selector:@selector(timelineTimerTick:) userInfo:nil repeats:YES];
    }
}

-(void) updateTimelineTimer {
    //NSLog(@"winCon Vols %d",[niiGL getNumberOfVolumesGL]);
    if ([niiGL getNumberOfVolumesGL] < 2) {
        [self stopTimer];
        [niiTimeline enable: FALSE];
        return;
    }
    [self startTimer];
    [niiTimeline enable: TRUE];
}

- (IBAction)gammaSlide:(id)sender {
    //NSLog(@"Got it %g", gammaSlider.floatValue);
    [niiGL setViewGamma: gammaSlider.floatValue];
    
    //-(void) setViewGamma: (float) gamma;
    //NSLog(@"Got it %@", [NSString stringWithFormat:@"End Value: %@", [gammaSlider value]]);
    
}

- (IBAction)infoClick:(id)sender { //
    NSString *message = [niiGL getHeaderInfo];
    NSBeginAlertSheet(@"Header Information", @"OK",NULL,NULL,theWindow, self,
                      NULL, NULL, NULL,
                      @"%@"
                      , message
                      );
}

- (void) setTitle {
    NSString *fname = [niiGL getHeaderFilename];
    if (([fname  length] < 2) && ([fname rangeOfString:@"@" options:NSCaseInsensitiveSearch].location != NSNotFound))
        [theWindow setTitle:@"Empty (Choose File/Open)"];
    else
        [theWindow setTitle: fname];
    /*if ([fname  length] > 1) {
        [theWindow setTitle: fname];
    } else {
        [theWindow setTitle:@"Empty (Choose File/Open)"];
    }*/
    fname = [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"];
    if ([fname  length] > 1)
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath:fname]];

}

- (void)updateToolbar {
    int layer = (int) [layerDrop indexOfSelectedItem];
    LayerValues val = [niiGL getLayerValues: layer];
    //WARNING layerDrop 0..MAX_OVERLAY = background..maxoverlay, while active 0..MAXOVERLAY-1
    for (int i = 0; i < MAX_OVERLAY; i++) {
        [[layerDrop itemAtIndex:i+1] setEnabled:val.activeOverlay[i]] ;
    }
    
    
    if ((layer > 0) && (! val.activeOverlay[layer-1]))
    { //selected background image no longer exists!
        [layerDrop selectItemAtIndex: 0];
        val = [niiGL getLayerValues: 0];
    }
    //printf("666 -> current=%d  %g..%g %d\n",layer,val.viewMin,val.viewMax,val.colorScheme);
    [darkEdit setDoubleValue: val.viewMin];
    [brightEdit setDoubleValue: val.viewMax];
    [colorDrop selectItemAtIndex: val.colorScheme];
}

- (void)updateEverything { //on loading new image
    [self updateThemeMode];
    [self setTitle];
    [self updateTimelineTimer];
    [self updateToolbar];
}

- (void)updateMostThings { //on window becoming active
    [self updateTimelineTimer];
    [self updateToolbar];
}

-(void) stopEverything {
    [self stopTimer];
}


-(void) setXYZmmWC: (float) x Y: (float) y Z: (float) z {
   [niiGL setXYZmmGL: x Y: y Z: z]; //Yoke
}
-(IBAction) openDocument: (id) sender
{
    //NSLog(@"winCon openDoc");
    [self stopEverything];
    [niiGL openDocumentGL:  sender];
    [self updateEverything];
}


- (IBAction)open:(id)sender 
{
    //NSLog(@"winCon open");
    [self stopEverything];
    [niiGL openDocumentGL:  sender];
    [self updateEverything];
}

- (BOOL) openDocumentFromFileName: (NSString *)file_name
{
    //NSLog(@"winCon openDocumentFromFileName --> %@", file_name);
    
    [self stopEverything];
    BOOL ret = [niiGL openDocumentFromFileNameGL:  file_name];
    [self updateEverything];
    return ret;
}

- (IBAction) openDiffusionWC: (id) sender
{
    
    [self stopEverything];
    [niiGL openDiffusionGL:  sender];
    [self updateEverything];
}

- (IBAction) saveTimelineAsPDF: (id) sender
{
    if ([niiGL getNumberOfVolumesGL] <2) {
        NSBeginAlertSheet(@"Error", @"OK",NULL,NULL,theWindow, self,
                          NULL, NULL, NULL,
                          @"%@", @"Only able to save timelines for 4D data (e.g. raw fMRI or DTI)");
        return;
    }
    if (niiTimeline.bounds.size.height < 2) {
        NSBeginAlertSheet(@"Error", @"OK",NULL,NULL,theWindow, self,
                          NULL, NULL, NULL,
                          @"%@", @"You must display the timeline before saving to disk (pull the split panel at the bottom of the window).");
        ;
        NSView* upperView = [[theSplitter subviews] objectAtIndex:0];
        if (upperView.frame.size.height > 300)
            [theSplitter setPosition:upperView.frame.size.height-100 ofDividerAtIndex:0];
        [self updateTimeline];
        return;
    }
    [niiTimeline savePDF];
    [niiTimeline saveTab];
}

- (IBAction) saveTimelineAsText: (id) sender {
    //This is currently unused - "saveTimelineAsPDF" saves as PDF and Text
        [niiTimeline saveTab];
}

- (IBAction) closeOverlays: (id) sender {
    [niiGL closeOverlaysGL:  sender];
    [self updateToolbar];
}

- (IBAction) addOverlay: (id) sender {
    [niiGL addOverlayGL:  sender];
    [self updateToolbar];
}

- (IBAction)modeChange:(id)sender {
    [niiGL resetClip];
    [niiGL setDisplayMode: (int)[modeDrop indexOfSelectedItem]];
}

- (IBAction)darkEditChange:(id)sender {
    [niiGL setViewMinMaxForLayer: [darkEdit doubleValue] Max: [brightEdit doubleValue] Layer: (int)[layerDrop indexOfSelectedItem]];
}

- (IBAction)brightEditChange:(id)sender {
    [self darkEditChange: sender];
}

- (IBAction)layerDropChange:(id)sender {
    [self updateToolbar];
}

- (IBAction)colorDropChange:(id)sender {
    [niiGL setColorSchemeForLayer: [sender indexOfSelectedItem]  Layer: (int)[layerDrop indexOfSelectedItem]];
    
}

- (IBAction) saveDocumentAs: (id) sender {
    [niiGL saveDocumentAs: sender];
}

-(NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender {
    return NSDragOperationGeneric;
}

-(BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender {
    return YES;
}

bool containsString (NSString *string, NSString *substring) {
    NSRange textRange;
    textRange =[string rangeOfString:substring];
    if(textRange.location != NSNotFound)
        return TRUE;
    else
        return FALSE;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
   //UInt32 carbonModifiers = GetCurrentKeyModifiers();
    //[NSEvent modifierFlags];
    //NSEvent *theEvent =
    /*NSUInteger iflags = [NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    if( iflags == NSCommandKeyMask ){
        NSLog(@"xxxxx");
    }*/
    
    
    //NSUInteger iflags = [NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    //bool specialKeys = (iflags == NSControlKeyMask);
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard
                          propertyListForType:NSFilenamesPboardType];
        int numberOfFiles = (int)[files count];
        if (numberOfFiles>0) {
            
            
            /*NSString *ext = [[[files objectAtIndex:0] pathExtension] uppercaseString];
            if (containsString(ext, @"NII") || containsString(ext, @"HDR")
                || containsString(ext, @"MHA") || containsString(ext, @"MHD")
                || containsString(ext, @"HEAD")
                || containsString(ext, @"MGH") || containsString(ext, @"MGZ")
                || containsString(ext, @"NRRD") || containsString(ext, @"NHDR")
                || containsString(ext, @"IMG") || containsString(ext, @"GZ")
                || containsString(ext, @"DCM")) {*/
            [self stopEverything];
            [niiGL openDocumentFromFileNameGL:  [files objectAtIndex:0]];
            /*NSLog(@"MAT --->%@", ext);
            NSString *ext = [[[files objectAtIndex:0] pathExtension] uppercaseString];
            if (containsString(ext, @"MAT")) {
                NSLog(@"MAT --->%d", specialKeys);
                //[[NSUserDefaults standardUserDefaults] setObject:tagModality  forKey:@"matlabBackground"];
                [[NSUserDefaults standardUserDefaults] setBool:specialKeys forKey:@"matlabBackground"];
                [niiGL openDocumentFromFileNameGL:  [files objectAtIndex:0]];
                [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"matlabBackground"];
                //if (specialKeys)
                //        [niiGL openOverlayFromFileNameGL:  [files objectAtIndex:0]];
            } else if (specialKeys)
                    [niiGL openOverlayFromFileNameGL:  [files objectAtIndex:0]];
            else
                [niiGL openDocumentFromFileNameGL:  [files objectAtIndex:0]];*/
            [self updateMostThings];
            //}
        }
    }
    return YES;
}

- (id)initWithWindow:(NSWindow *)window {
    //[self logVideoMemoryCurrentRenderer ];
    self = [super initWithWindow:window];
    mosaicStr= @"L V 0.1 A 0.5 S 0.5; C 0.4 0.6";
    
    if (self) {
        timelineTimer = nil; //off
    }
    return self;
}

- (void)windowDidLoad {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(niiNotificationUpdateMosaic:) name:@"niiMosaic" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(niiNotificationUpdateToolbar:) name:@"niiUpdate" object:nil];
    [theWindow registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    if ([@"~" isEqualToString: [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"]]) {
        [niiGL openDocumentGL:  self];
    }
    //[theWindow setAutodisplay: YES];
    [super windowDidLoad];
    //[theWindow setContentMinSize : NSMakeSize(10.0, 10.0)];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self stopTimer];
    [niiGL deallocGL];
    //NSLog(@"windowWillClose %d\n", (int)[ [[NSApp sharedApplication] window] count]);
    //[ [[NSApplication sharedApplication] delegate] ]
    //[windowArray removeObjectIdenticalTo: self  ];
    MRIcroXAppDelegate *delegate = [NSApp delegate];
    [delegate windowWillCloseX:self];
}

- (IBAction) changeBackgroundColor: (id) sender {
    double red, green, blue;
    [niiGL getBackgroundColor: &red Green: &green Blue: &blue];
    if ((red+green+blue) > 1.5) {
        [niiGL setBackgroundColor: 0 Green: 0 Blue: 0];
    } else {
        [niiGL setBackgroundColor: 1.0 Green: 1.0 Blue: 1.0];
    }
}

- (IBAction) removeHaze: (id) sender {
    [niiGL removeHaze];
}

- (IBAction) doSharpen: (id) sender {
    [niiGL sharpen];
}

- (BOOL) isActiveKey {
    //NSLog(@"order %hhd %ld", [theWindow isKeyWindow],(long)[theWindow orderedIndex]);
    //return [theWindow isKeyWindow];
    return ([theWindow orderedIndex] == 1);
}

- (void)windowDidResignKey:(NSNotification *)notification {
    [self stopTimer];
    //NSLog(@"bye");
    //[theWindow setAutodisplay: NO];
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    [theWindow setAutodisplay: NO];
    [self updateMostThings];
    [theWindow setAutodisplay: YES];
}

- (IBAction) volumePrior: (id) sender {
    [niiGL skipNumberOfVolumesGL: -1];
}

- (IBAction) volumeNext: (id) sender {
    [niiGL skipNumberOfVolumesGL: 1];
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString*   const   character   =   [theEvent charactersIgnoringModifiers];
    unichar     const   code        =   [character characterAtIndex:0];
    
    switch (code)
    {
            //http://stackoverflow.com/questions/6000133/how-to-handle-arrow-key-event-in-cocoa-app
        case NSUpArrowFunctionKey:
        {
            //NSLog(@"Up");
            [niiGL  changeXYZvoxelGL:0 Y: 0 Z: 1];
            //[niiGL setBackgroundColor: 1.0 Green: 1.0 Blue: 1.0];
            break;
        }
        case NSDownArrowFunctionKey:
        {
            //NSLog(@"Down");
            [niiGL  changeXYZvoxelGL:0 Y: 0 Z: -1];
            break;
        }
        case NSLeftArrowFunctionKey:
        {
            //NSLog(@"Left");
            [niiGL  changeXYZvoxelGL:-1 Y: 0 Z: 0];
            //[self navigateToPreviousImage];
            break;
        }
        case NSRightArrowFunctionKey:
        {
            //NSLog(@"Right");
            [niiGL  changeXYZvoxelGL:1 Y: 0 Z: 0];
            //[self navigateToNextImage];
            break;
        }
        case NSHomeFunctionKey:
        {
            //NSLog(@"PageUp");
            [niiGL  changeXYZvoxelGL:0 Y: -1 Z: 0];
            //[self navigateToNextImage];
            break;
        }
        case NSEndFunctionKey:
        {
            //NSLog(@"PageDown");
            [niiGL  changeXYZvoxelGL:0 Y: 1 Z: 0];
            //[self navigateToNextImage];
            break;
        }
            
    }
}
@end
