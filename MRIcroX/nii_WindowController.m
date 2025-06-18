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

@implementation NSAlert (Cat)

-(NSInteger) runModalSheetForWindow:(NSWindow *)aWindow
{
    [self beginSheetModalForWindow:aWindow completionHandler:^(NSModalResponse returnCode)
        { [NSApp stopModalWithCode:returnCode]; } ];
    NSInteger modalCode = [NSApp runModalForWindow:[self window]];
    return modalCode;
}

-(NSInteger) runModalSheet {
    return [self runModalSheetForWindow:[NSApp mainWindow]];
}

@end

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
    /*
if ([[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"])
theWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
else
theWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
     */
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
    //[niiGL forceRecalc]; return; //Flicker test
    NSString *message = [niiGL getHeaderInfo];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Header Information"];
    [alert setInformativeText:message];
    [alert addButtonWithTitle:@"OK"];
    //[alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        /*if (returnCode == NSAlertSecondButtonReturn) {
            NSLog(@"Cancelled!");
            return;
        }*/
    }];
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
    
    //[[[NSApp mainMenu] itemWithTag:4]  setEnabled:NO];
    //NSMenu  *mainMenu = [[NSApplication sharedApplication] mainMenu];
    //retinaScaleFactorNSMenu  *viewMenu = [[mainMenu itemAtIndex:4] submenu];
    //NSMenu  *atlasMenu = [[fileMenu itemAtIndex:4] submenu];
    //[[viewMenu itemAtIndex:4]  setEnabled:NO];
    //[[viewMenu itemWithTag:4]  setEnabled:NO];
    //- (BOOL)validateMenuItem:(NSMenuItem *)item
    //[[[NSApp mainMenu] itemWithTitle:@"File"]  setEnabled:NO];
    //NSMenuItem *item1 = [[NSMenuItem alloc] initWith..];
    
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

NSArray * niiFileTypesW () {
    NSArray *fileTypes = [NSArray arrayWithObjects:
                          @"dcm", @"nii", @"MAT",@"NII",@"hdr", @"HDR",  @"GZ", @"gz",@"voi", @"MGH", @"mgh",  @"MGZ", @"mgz", @"MHA", @"mha",  @"MHD", @"mhd",@"HEAD", @"head", @"nrrd", @"nhdr", nil];
    fileTypes = [fileTypes arrayByAddingObjectsFromArray:[NSImage imageFileTypes]];
    return fileTypes;
}

-(IBAction) openDocument: (id) sender
{
    //NSLog(@"winCon openDoc");
    NSOpenPanel *openPanel  = [NSOpenPanel openPanel];
    openPanel.title = @"Choose a background image";
    /*NSArray *fileTypes = [NSArray arrayWithObjects:
    @"dcm", @"nii", @"MAT",@"NII",@"hdr", @"HDR",  @"GZ", @"gz",@"voi", @"MGH", @"mgh",  @"MGZ", @"mgz", @"MHA", @"mha",  @"MHD", @"mhd",@"HEAD", @"head", @"nrrd", @"nhdr", nil];
    fileTypes = [fileTypes arrayByAddingObjectsFromArray:[NSImage imageFileTypes]];
    [openPanel setAllowedFileTypes:fileTypes];*/
    [openPanel setAllowedFileTypes:niiFileTypesW()];
    openPanel.allowsMultipleSelection = TRUE;
    
    //[openPanel allowsMultipleSelection: TRUE];
    //[openPanel setAllowedFileTypes:[NSImage imageFileTypes]];
    NSInteger result    = [openPanel runModal];
    if(result != NSOKButton) return;
    //if (![self checkSandAccess: [[openPanel URL] path]]) return;
    //openPanel.filenames
    [self openDocumentFromFileNames: openPanel.filenames ];
    //NSLog(@"%@", openPanel.filenames);
    //[self openDocumentFromFileNames: openPanel.URLs ];
    //[self openDocumentFromFileName: [[openPanel URL] path]] ;

    /*
    
    //openDocumentFromFileNames: (NSArray *)files
    [self stopEverything];
    [niiGL openDocumentGL:  sender];
    [self updateEverything];
    */
}

- (IBAction) addOverlay: (id) sender {
    [niiGL addOverlayGL:  sender];
    [self updateToolbar];
}
/*
- (IBAction)open:(id)sender 
{
    //NSLog(@"winCon open");
    [self stopEverything];
    [niiGL openDocumentGL:  sender];
    [self updateEverything];
}*/

- (BOOL) openDocumentFromFileName: (NSString *)file_name
{
    //NSLog(@"winCon openDocumentFromFileName --> %@", file_name);
    [self stopEverything];
    BOOL ret = [niiGL openDocumentFromFileNameGL:  file_name];
    [self updateEverything];
    return ret;
}


- (void)removeAllNiiFiles: (NSString *)path
{
    NSFileManager  *manager = [NSFileManager defaultManager];
    // grab all the files in the dir
    NSArray *allFiles = [manager contentsOfDirectoryAtPath:path error:nil];
    // filter the array for only .nii files
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.nii'"];
    NSArray *niiFiles = [allFiles filteredArrayUsingPredicate:fltr];
    // use fast enumeration to iterate the array and delete the files
    for (NSString *niiFile in niiFiles) {
       NSError *error = nil;
       [manager removeItemAtPath:[path stringByAppendingPathComponent:niiFile] error:&error];
       NSAssert(!error, @"Assertion: SQLite file deletion shall never throw an error.");
    }
}

- (NSArray *)findAllNiiFiles: (NSString *)path
{
    NSFileManager  *manager = [NSFileManager defaultManager];
    // grab all the files in the dir
    NSArray *allFiles = [manager contentsOfDirectoryAtPath:path error:nil];
    // filter the array for only .nii files
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.nii'"];
    return [allFiles filteredArrayUsingPredicate:fltr];
}

- (BOOL) openDocumentFromFileNames: (NSArray *)files
{
    //NSLog(@"winCon FromFilenames");
    int numberOfFiles = (int)[files count];
    if (numberOfFiles < 1) return FALSE;
    int nDICOM = 0;
    [self stopEverything];
    bool OK = FALSE;
    #ifndef STRIP_DCM2NII
    BOOL *isDICOM = (BOOL*)malloc(files.count * sizeof(BOOL) );
    #endif
    for (int i = 0; i < files.count; i++){
        NSString* fname = [files objectAtIndex:i];
        
        #ifndef STRIP_DCM2NII
        isDICOM[i] = FALSE;
        char fnameC[1024] = {""};
        strcat(fnameC,[fname cStringUsingEncoding:1]);
        if (isDICOMfile(fnameC) > 0) {
            nDICOM ++;
            isDICOM[i] = TRUE;
            continue;
        }
        #endif
        OK = [niiGL openDocumentFromFileNameGL:fname];
        if (OK) break;
        NSLog(@"Unable to open dropped file: %@", fname);
    }
    #ifndef STRIP_DCM2NII
    if ((!OK) &&  (nDICOM > 0)) {
        //NSLog(@"%d DICOMs", nDICOM);
        //https://nshipster.com/temporary-files/
        NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath: NSTemporaryDirectory() isDirectory: YES];
        //NSString *temporaryFilename = [[[NSProcessInfo processInfo] globallyUniqueString] stringByAppendingString: @".txt"];
        NSString *temporaryFilename = @"dcmstrs.txt";
        NSURL *temporaryFileURL =[temporaryDirectoryURL URLByAppendingPathComponent:temporaryFilename];
        //NSLog(@"TempFile %@", temporaryFileURL);
        NSString *dcmStrs = @"";
        for (int i = 0; i < files.count; i++){
            if (!isDICOM[i]) continue;
            NSString* fname = [files objectAtIndex:i];
            //dcmStrs = [dcmStrs stringByAppendingString: fname];
            dcmStrs = [dcmStrs stringByAppendingString: [NSString stringWithFormat: @"%@\n", fname]];
            
        }
        //NSLog(@">>%@", dcmStrs);
        NSError * error = NULL;
        //BOOL ok = [string writeToURL:URL atomically:YESencoding:NSUnicodeStringEncoding error:&error];
        BOOL ok = [dcmStrs writeToURL:temporaryFileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (!ok) NSLog(@"Unable to write file %@", temporaryFileURL);
        [self removeAllNiiFiles: [temporaryDirectoryURL path]];
        struct TDCMopts opts;
        readIniFile(&opts, NULL); //set default preferences
        opts.isOnlySingleFile = true;
        opts.isCreateBIDS = false;
        opts.isGz = false;
        //NSString *myString = temporaryFileURL.absoluteString;
        //NSString *urlString = [myURL absoluteString];
        //temporaryFileURL
        const char *cString = [[temporaryFileURL path ] UTF8String];
        strcpy(opts.indir, cString);
        strcpy(opts.filename, "%s_%p");
        nii_loadDir(&opts);
        NSArray * niis = [self findAllNiiFiles: [temporaryDirectoryURL path]];
        //NSLog(@"DICOM series: %d", (int) niis.count );
        //[_seriesSelectWin orderFront: sender];
        if (niis.count > 0) {
            int idx = 0;
            if (niis.count > 1) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Select DICOM image"];
                //[alert setInformativeText:@"Series"];
                //[alert addButtonWithTitle:@"A"];
                //[alert addButtonWithTitle:@"B"];
                //[alert addButtonWithTitle:@"C"];
                for (int i = 0; i < niis.count; i++){
                    NSString* nii= [niis objectAtIndex:i];
                    [alert addButtonWithTitle: nii];
                }
                //[alert addButtonWithTitle:@"Cancel"];
                [alert setAlertStyle:NSWarningAlertStyle];
                NSInteger returnCode = [alert runModalSheetForWindow:theWindow];
                idx = (int)(returnCode - NSAlertFirstButtonReturn);
            }
            NSString* nii= [niis objectAtIndex:idx];
            nii = [[temporaryDirectoryURL path] stringByAppendingPathComponent:nii];
            //NSLog(@">> %@", nii);
            OK = [niiGL openDocumentFromFileNameGL:nii];
            
            /*for (int i = 0; i < niis.count; i++){
                NSString* nii= [niis objectAtIndex:i];
                nii = [[temporaryDirectoryURL path] stringByAppendingPathComponent:nii];
                //NSLog(@">> %@", nii);
                OK = [niiGL openDocumentFromFileNameGL:nii];
                if (OK) break;
            }*/
        }
        [self removeAllNiiFiles: [temporaryDirectoryURL path]];
    }
    free(isDICOM);
    #endif

    [self updateMostThings];
    return OK;
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

- (IBAction)modeChange:(id)sender {
    [niiGL resetClip];
    int mode = (int)[modeDrop indexOfSelectedItem];
    [niiGL setDisplayMode: mode];
    [[NSUserDefaults standardUserDefaults] setInteger: mode forKey:@"startupMode"];
    //NSLog(@"startupMode: %d", mode);
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
    int idx = (int)[sender indexOfSelectedItem];
    [niiGL setColorSchemeForLayer: [sender indexOfSelectedItem]  Layer: (int)[layerDrop indexOfSelectedItem]];
    if (idx < 20) return; //CT_color schemes
    if (idx == 20) {//CT_airways
        darkEdit.doubleValue = -643;
        brightEdit.doubleValue = -235;
    }
    if (idx == 21) {//CT_bone
        darkEdit.doubleValue = 180;
        brightEdit.doubleValue = 600;
    }
    if (idx == 22) {//CT_head
        darkEdit.doubleValue = -590;
        brightEdit.doubleValue = 600;
    }
    if (idx == 23) {//CT_kidneys
        darkEdit.doubleValue = 114;
        brightEdit.doubleValue = 302;
    }
    if (idx == 24) {//CT_soft_tissue
        darkEdit.doubleValue = -10;
        brightEdit.doubleValue = 110;
    }
    if (idx == 25) {//CT_surface
        darkEdit.doubleValue = -600;
        brightEdit.doubleValue = 100;
    }
    [self darkEditChange: sender];
    
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
    //NSLog(@"winCon Drag");
    BOOL OK = FALSE;
    if (! [[pboard types] containsObject:NSFilenamesPboardType] ) return FALSE;
    NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
    OK = [self openDocumentFromFileNames: files];
    return OK;
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

- (void)handleScreenChanges:(NSNotification *) notification {
    //NSLog(@"Screen changed %g", [[NSApp mainWindow] backingScaleFactor]); //e.g. move from retina display to non-retina display
    //[niiGL setFontScale: [theWindow backingScaleFactor] ];
    [niiGL reshape];
    
    NSArray<NSScreen *> * screens = [NSScreen screens];
    NSScreen * screen = screens.firstObject;
    [niiGL setFontScale: [screen backingScaleFactor]];
    //NSLog(@"Screen change %g %g", [screen backingScaleFactor], [theWindow backingScaleFactor]);
   
}
- (void)windowDidLoad {
    //NSLog(@"WindowDidLoad");
    //selector(handleDisplayChanges(notification:))
    //NSWindowDidChangeScreenNotification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleScreenChanges:)
                                                 name:NSWindowDidChangeScreenNotification
                                               object:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(niiNotificationUpdateToolbar:) name:@"niiUpdate" object:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDisplayChanges:) name:@"niiMosaic" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(niiNotificationUpdateMosaic:) name:@"niiMosaic" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(niiNotificationUpdateToolbar:) name:@"niiUpdate" object:nil];
    [theWindow registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    if ([@"~" isEqualToString: [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultFilename"]]) {
        [self openDocument: self];
        //[niiGL openDocumentGL:  self];
    }
    //[theWindow setAutodisplay: YES];
    [super windowDidLoad];
    //optional: set display mode
    NSUserDefaults *defaults= [NSUserDefaults standardUserDefaults];
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:@"startupMode"]){
        //int itm2 = [[NSUserDefaults standardUserDefaults] boolForKey:@"startupStandard"];
        int mode = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"startupMode"];
        if ((mode >= 0) && (mode < modeDrop.numberOfItems)) {
            [modeDrop selectItemAtIndex:mode];
            [niiGL setDisplayMode: mode];
            //NSLog(@"mode set %d", mode);
        }
    }
    //[theWindow setContentMinSize : NSMakeSize(10.0, 10.0)];
    NSArray<NSScreen *> * screens = [NSScreen screens];
    NSScreen * screen = screens.firstObject;
    [niiGL setFontScale: [screen backingScaleFactor]];
    //NSLog(@"Screen scale %g %g", [screen backingScaleFactor], [theWindow backingScaleFactor]);
   
    //NSLog(@"Screen scale %g", [theWindow backingScaleFactor]); //e.g. move from retina display to non-retina display
    //[niiGL setFontScale: [theWindow backingScaleFactor] ];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self stopTimer];
    [niiGL deallocGL];
    //NSLog(@"windowWillClose %d\n", (int)[ [[NSApp sharedApplication] window] count]);
    //[ [[NSApplication sharedApplication] delegate] ]
    //[windowArray removeObjectIdenticalTo: self  ];
    //MRIcroXAppDelegate *thedelegate = [NSApp delegate];
    MRIcroXAppDelegate *thedelegate = (MRIcroXAppDelegate*)[NSApp delegate];
    [thedelegate windowWillCloseX:self];
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
    //NSLog(@">>>>");
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

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    int mode = (int)[modeDrop indexOfSelectedItem];
    //NSLog(@"startupMode: %d", mode);
    bool isMode3D = (mode == 1) || (mode == 2);
    if ((item.tag > 0) && (item.tag < 7))
        return isMode3D;
    bool isImg4D = [niiGL getNumberOfVolumesGL] > 1;
    if (item.tag > 6)
        return isImg4D;
    
    return YES;
}
- (IBAction) orientChange: (NSMenuItem *) sender {
    [niiGL setAzimElevOrient: (int) sender.tag];
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
