//  MRIcroXAppDelegate.m
//
//  Created by Chris Rorden on 9/19/12.
//  Copyright 2012 University of South Carolina. All rights reserved.

#import "MRIcroAppDelegate.h"
#import "nii_WindowController.h"
#include "nii_foreignx.h"
#include "nii_io.h" //for MY_DEBUG define
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>


@implementation MRIcroXAppDelegate
@synthesize yokeMenu;
@synthesize importMenu;


-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender
{
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    saveIniFile (opts); //save preferences
#endif
    return NSTerminateNow;
}

- (void)createNewDocument:(id)sender
{//http://stackoverflow.com/questions/9393709/automatic-reference-counting-arc-is-great-but
    //http://stackoverflow.com/questions/9412063/arc-nib-files-and-releasing-top-level-objects
    //http://www.cocoabuilder.com/archive/cocoa/109092-retain-cycle-problem-with-bindings-nswindowcontroller.html#109092
    [windowArray addObject:[[nii_WindowController alloc] initWithWindowNibName:@"MainWindow"]];
    [[ windowArray  lastObject] showWindow:nil];
    [[ windowArray  lastObject] showWindowPost:nil];
}

- (void)newDocument:(id)sender
{ //create blank document
  
    //NSLog(@"AppDel newDoc");
 [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"defaultFilename"];
 //   [[NSUserDefaults standardUserDefaults] setObject:@"/Users/rorden/desktop/ch256.nii" forKey:@"defaultFilename"];
    [self createNewDocument: sender];
}

- (IBAction)windowWillCloseX:(id)sender {
    [windowArray removeObjectIdenticalTo: sender  ];
}

-(void) openImageInActiveWindowIfPossible:(NSString *)file
{
    //NSLog(@"AppDel openImageInActiveWindowIfPossible %@", file);
    [[NSUserDefaults standardUserDefaults] setObject:file forKey:@"defaultFilename"];
    int numWin = (int)[windowArray count];
    //NSLog(@"++AppDel openImageInActiveWindowIfPossible %d", numWin );
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  ((flags & NSShiftKeyMask) || (numWin < 1)) {
        //NSLog(@"AppDel NewDocument %@", file);
        [self createNewDocument: self];//self was sender
        return;
    }
    for (int i = 0; i < numWin; i++)
        if ([[ windowArray  objectAtIndex: i] isActiveKey]) {
            [[ windowArray  objectAtIndex: i] openDocumentFromFileName: file ];//self was sender
            return;
        }
    [[ windowArray  objectAtIndex: 0] openDocumentFromFileName: file ];//none of the windows was key -send to first
}

-(void) openImagesInActiveWindowIfPossible:(NSArray *)files
{
    //NSLog(@"AppDel openImageInActiveWindowIfPossible %@", file);
    [[NSUserDefaults standardUserDefaults] setObject:[ files  objectAtIndex: 0] forKey:@"defaultFilename"];
    int numWin = (int)[windowArray count];
    //NSLog(@"++AppDel openImageInActiveWindowIfPossible %d", numWin );
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    if  ((flags & NSShiftKeyMask) || (numWin < 1)) {
        [self createNewDocument: self];//self was sender
        return;
    }
    for (int i = 0; i < numWin; i++)
        if ([[ windowArray  objectAtIndex: i] isActiveKey]) {
            [[ windowArray  objectAtIndex: i] openDocumentFromFileNames: files ];//self was sender
            return;
        }
    [[ windowArray  objectAtIndex: 0] openDocumentFromFileNames: files ];//none of the windows was key -send to first
}

- (BOOL)processFile:(NSString *)file
{ //load named document - e.g. drag and drop
    //NSLog(@"AppDel processFile %@", file);
    
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDir]) {
        if (isDir) return NO; //file exists but is directory
    } else
        return NO; //file does not exist
    [self openImageInActiveWindowIfPossible: file];
    //[[NSUserDefaults standardUserDefaults] setObject:file forKey:@"defaultFilename"];
    //[self createNewDocument: self];
    return  YES; //success!
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{ //load named document
    //NSLog(@"AppDel openFile");
    return [self processFile:filename];
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{ //load named documents
    //NSLog(@"AppDel openFiles");
    [self openImagesInActiveWindowIfPossible: filenames];
    /*for (NSString *filename in filenames) {
        NSLog(@"AppDel openFiles: %@", filename);
        [self application:sender openFile:filename];
    }*/
}

-(IBAction) openDocument: (id) sender
{
    NSLog(@"AppDel openDoc");
    [self openImageInActiveWindowIfPossible:@"~"];
}

- (id)init
{
    [[NSUserDefaults standardUserDefaults] registerDefaults: \
     [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey: \
      @"NSDisabledCharacterPaletteMenuItem"]];
    self = [super init];
    /*if (self) {
        for (int i = 0; i < 13; i++)
        [self newDocumentWithPreviousImage:self];
    }*/
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification*)aNotification
{
    windowArray = [[NSMutableArray alloc] init];
}

- (IBAction) openDiffusion: (id) sender
{ //this is only called when no windows are open: otherwise the nii_WindowController's openDiffusion is called
    int numWin = (int)[windowArray count];
    if (numWin < 1) {
        [self createNewDocument: sender]; //create a new window
        [[ windowArray  objectAtIndex: 0] openDiffusionWC: sender];
        return;
    }
    for (int i = 0; i < numWin; i++) {
        if ([[ windowArray  objectAtIndex: i] isActiveKey]) {
            [[ windowArray  objectAtIndex: i] openDiffusionWC: sender];
            return;
        }
    }
}

- (IBAction)showAppPrefs:(id)sender {
    
    //show application preferences window - if possible position immediately to the left of the active window
    NSPoint pos = {0,0};
    int numWin = (int)[windowArray count];
    for (int i = 0; i < numWin; i++) {
        if ([[ windowArray  objectAtIndex: i] isActiveKey]) {
            NSRect myFrame = [[[ windowArray  objectAtIndex: i] window] frame] ;
            pos.x = myFrame.origin.x;
            pos.y = myFrame.origin.y;
            //NSPoint theOrigin = myFrame.origin;
            //return;
        }
    }
    pos.x = pos.x - _prefWin.frame.size.width;
    if (pos.x > 0) [_prefWin setFrameOrigin : pos];
    [_prefWin orderFront: sender];
}

- (void)niiNotification:(NSNotification *) notification
{
    //NSLog(@"Got notified: %@", notification);
    if ([yokeMenu state] == 0) return; //no yoking... so no need to read messages
    int numWin = (int)[windowArray count];
    if (numWin < 2) return; //if only one window, there are no other windows to yoke to...
	if(notification) {
		NSDictionary *tmpDict = [notification userInfo];
        float xmm = [[tmpDict objectForKey:@"x"] floatValue];
        float ymm = [[tmpDict objectForKey:@"y"] floatValue];
        float zmm = [[tmpDict objectForKey:@"z"] floatValue];
        //NSLog(@"delegate: mouse clicked at = %f x %f x %f",xmm, ymm, zmm);
        for (int i = 0; i < numWin; i++)
            [[ windowArray  objectAtIndex: i] setXYZmmWC: xmm Y: ymm Z: zmm];
	}
}

- (NSColor *)colorForKey:(NSString *)key
{
    NSData  *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (data == nil)
        return nil;
    NSColor *color= [NSUnarchiver unarchiveObjectWithData:data];
    if( ! [color isKindOfClass:[NSColor class]] )
        color = nil;
    return color;
}

- (void)setColor:(NSColor *)color forKey:(NSString *)key
{
    NSData *data = [NSArchiver archivedDataWithRootObject:color];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
}

- (void) updateThemeMode {
 /*   if ([[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"]) {
        self.prefWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        self.dcm2niiWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        self.theTextView.textColor = [NSColor blackColor];
        self.theTextView.backgroundColor = [NSColor grayColor];
    } else {
        self.prefWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        self.dcm2niiWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        self.theTextView.textColor = [NSColor blackColor];
        self.theTextView.backgroundColor = [NSColor whiteColor];
    }*/
}

-(void)setDefaults: (bool) forceReset
{
    //NSLog(@"%d", (unsigned long)NSBottomTabsBezelBorder);
    if (forceReset) {
        [[NSUserDefaults standardUserDefaults] setPersistentDomain:[NSDictionary dictionary] forName:[[NSBundle mainBundle] bundleIdentifier]];
        [[NSUserDefaults standardUserDefaults]synchronize ];
    }
    /*NSDictionary *userDefaultsDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:YES], @"showCrosshair", @"showCube",@"showInfo",nil,
        [NSNumber numberWithInt:0], @"NumberKey",nil];*/
    //[NSNumber numberWithInt: 1], @"matModality",
    
    NSDictionary *userDefaultsDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:YES], @"showCube",
        [NSNumber numberWithBool:YES], @"xBarGap",
        [NSNumber numberWithBool:YES], @"showInfo",
        [NSNumber numberWithBool:YES], @"showOrient",
        [NSNumber numberWithBool:YES], @"orthoOrient",
        [NSNumber numberWithBool:YES], @"loadFewVolumes",
        [NSNumber numberWithBool:NO], @"viewRadiological",
        [NSNumber numberWithBool:YES], @"advancedRender",
        [NSNumber numberWithBool:YES], @"blackBackground",
        [NSNumber numberWithBool:YES], @"dicomWarn",
        [NSNumber numberWithBool:YES], @"isSmooth2D",
        [NSNumber numberWithBool:YES], @"retinaResolution",
        [NSNumber numberWithInt:-1], @"startupStandard",
        [NSNumber numberWithInt:2], @"startupMode",
                                          nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsDefaults];
    [[NSUserDefaults standardUserDefaults]synchronize ];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"orthoOrient"]; //ALWAYS REST on launch
    
    
    NSColor *clr =[self colorForKey:@"xBarColor"];
    if (clr == nil)
        [self setColor: [NSColor colorWithCalibratedRed:0.4 green:0.4 blue:1.0 alpha:1.0] forKey:@"xBarColor"];
    clr =[self colorForKey:@"colorBarTextColor"];
    if (clr == nil)
        [self setColor: [NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0] forKey:@"colorBarTextColor"];
    //NSLog(@" %@",userDefaultsDefaults);
    _pref3dOrientCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"showCube"];
    _prefCrosshairCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"xBarGap"];
    _prefCoordinateCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"showInfo"];
    _prefOrientCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"showOrient"];
    _prefLoadOrientCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"orthoOrient"];
    //_prefLoadFewVolumesCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadFewVolumes"];
    _prefLoadFewVolumesCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadFewVolumes"];
    _prefRetinaCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"retinaResolution"];
    _prefRadiologicalCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"viewRadiological"];
    _prefAdvancedRenderCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"advancedRender"];
    _prefBlackBackgroundCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"blackBackground"];
    _prefDicomCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"dicomWarn"];
    //_prefDicomCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"dicomWarn"];
    
    _pref2dSmoothCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"isSmooth2D"];
    
    [self updateThemeMode];
}

- (IBAction)prefResetClick:(id)sender {
    [[NSColorPanel sharedColorPanel] orderOut:nil]; //close color panel if open
    [self setDefaults:true];
    [self prefChange: sender];
}

- (IBAction)other2niiClick:(id)sender {
    /*NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    openPanel.title = @"Choose files to convert";
    openPanel.showsResizeIndicator = YES;
    openPanel.showsHiddenFiles = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = YES;*/
    #ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setTitle: @"Select output folder (cancel to use input folder)"];
    [openDlg setCanChooseFiles:YES];
    openDlg.allowsMultipleSelection = YES;
    [openDlg setCanChooseDirectories:NO];
    [openDlg setPrompt:@"Select"];
    NSInteger isOKButton = [openDlg runModal];
    NSArray* files = [openDlg URLs];
    //NSString* outdir = @"";
    if ((isOKButton != NSFileHandlingPanelOKButton) || ([files count] < 1)) return;
    for (int i = 0; i < files.count; i++){
        //NSLog(@"%lu", (unsigned long)files.count);
        //outdir = [[files objectAtIndex:0] path];
        NSString* fname = [[files objectAtIndex:i] path];
        struct nifti_1_header niiHdr;
        unsigned char * img = NULL;
        img = nii_readForeignx(fname, &niiHdr, 0, 1);
        if (img != NULL) {
            //NSLog(@"read %@", fname);
            const char * nf = [fname UTF8String];
            nii_saveNIIx((char *) nf, niiHdr,img, opts);
            free(img);
        } //img loaded
    } //for each file
#endif
} //other2niiClick()

/*
- (IBAction)loadAtlas:(id)sender {
    NSLog(@"atlas select");
    NSMenuItem *itm = (NSMenuItem *)sender;
    NSString *templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/atlas"];
    NSString *atlasURL = [[templatePath stringByAppendingString:@"/"] stringByAppendingString: itm.title];
    NSLog(@"atlas selected is: %@", atlasURL);
    [self openImageInActiveWindowIfPossible: atlasURL];
}

- (void) addAtlasToRecentFolder {
    NSString *templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/atlas"];
    //NSLog(@"atlas directory is: %@", templatePath);
    BOOL isDir = NO;
    if (!([[NSFileManager defaultManager] fileExistsAtPath:templatePath isDirectory:&isDir] && isDir)) return;
    //NSLog(@"atlas directory exists: %@", templatePath);
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:templatePath error:nil];
    NSArray *niiFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
    NSMenu  *mainMenu = [[NSApplication sharedApplication] mainMenu];
    NSMenu  *fileMenu = [[mainMenu itemAtIndex:1] submenu];
    //NSLog(@">>>: %@", fileMenu.title);
    //NSMenuItem  *atlasMenu = [fileMenu itemAtIndex:3];
    NSMenu  *atlasMenu = [[fileMenu itemAtIndex:3] submenu];
    //NSLog(@">>>: %@", atlasMenu.title);
    //NSLog(@">>>: %d", (int) niiFiles.count);
    for (int i = 0; i < niiFiles.count; i++) {
        //NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:@"Tutorial" action:@selector(actionTutorial:) keyEquivalent:@"T"];
        //NSMenuItem* item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Random" action:@selector(menuSelected:) keyEquivalent:@"0"];
        NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:niiFiles[i] action:@selector(loadAtlas:) keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:i];
        [atlasMenu addItem:item];
    }
}

- (IBAction)loadStandard:(id)sender {
    //NSLog(@"atlas select");
    NSMenuItem *itm = (NSMenuItem *)sender;
    NSString *templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/standard"];
    NSString *atlasURL = [[templatePath stringByAppendingString:@"/"] stringByAppendingString: itm.title];
    //NSLog(@"atlas selected is: %@", atlasURL);
    [self openImageInActiveWindowIfPossible: atlasURL];
}

- (void) addStandardToRecentFolder {
    NSString *templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/standard"];
    BOOL isDir = NO;
    if (!([[NSFileManager defaultManager] fileExistsAtPath:templatePath isDirectory:&isDir] && isDir)) return;
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:templatePath error:nil];
    NSArray *niiFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
    NSMenu  *mainMenu = [[NSApplication sharedApplication] mainMenu];
    NSMenu  *fileMenu = [[mainMenu itemAtIndex:1] submenu];
    NSMenu  *atlasMenu = [[fileMenu itemAtIndex:4] submenu];
    for (int i = 0; i < niiFiles.count; i++) {
        NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:niiFiles[i] action:@selector(loadStandard:) keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:i];
        [atlasMenu addItem:item];
    }
}*/


- (IBAction)loadTemplate:(id)sender {
    //NSLog(@"atlas select");
    NSMenuItem *itm = (NSMenuItem *)sender;
    NSString *templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/standard"];
    if (itm.tag < 0)
        templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/atlas"];
    NSString *fnm = [[templatePath stringByAppendingString:@"/"] stringByAppendingString: itm.title];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fnm]) {
        NSLog(@"Unable to find file named: %@", fnm);
        return;
    }
    if (![[NSFileManager defaultManager] isReadableFileAtPath:fnm] ) {
        NSLog(@"Unable to read file named: %@", fnm);
        return;
    }
    if (itm.tag >= 0) {
        [[NSUserDefaults standardUserDefaults] setInteger:(int)itm.tag forKey:@"startupStandard"];
        //NSLog(@"startupStandard: %d", (int)itm.tag);
    }
    [self openImageInActiveWindowIfPossible: fnm];
}

//-(void) setRightMouseDragXY: (int) x Y: (int) y isMag: (bool) mag isSwipe: (bool) swipe;

- (void) populateTemplateMenus: (bool) isAtlas {
    NSMenu  *mainMenu = [[NSApplication sharedApplication] mainMenu];
    NSMenu  *fileMenu = [[mainMenu itemAtIndex:1] submenu];
    NSMenu  *atlasMenu = [[fileMenu itemAtIndex:4] submenu];
    NSString *templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/standard"];
    if (isAtlas) {
        templatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/atlas"];
        atlasMenu = [[fileMenu itemAtIndex:3] submenu];
    }
    BOOL isDir = NO;
    if (!([[NSFileManager defaultManager] fileExistsAtPath:templatePath isDirectory:&isDir] && isDir)) return;
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:templatePath error:nil];
    NSArray *niiFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
    niiFiles = [niiFiles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (int i = 0; i < niiFiles.count; i++) {
        NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:niiFiles[i] action:@selector(loadTemplate:) keyEquivalent:@""];
        [item setTarget:self];
        if (isAtlas)
            [item setTag:-1];
        else
            [item setTag:i];
        [atlasMenu addItem:item];
    }
}

/*- (void) addStandardToRecentFolder {
    NSString *appFolderPath = [[NSBundle mainBundle] resourcePath];
    //NSLog(@"app Directory is: %@", appFolderPath);
    NSString *templatePath = [appFolderPath stringByAppendingString: @"/standard"];
    //NSLog(@"standard directory is: %@", templatePath);
    BOOL isDir = NO;
    if (!([[NSFileManager defaultManager] fileExistsAtPath:templatePath isDirectory:&isDir] && isDir)) return;
    //NSLog(@"standard directory exists: %@", templatePath);
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:templatePath error:nil];
    NSArray *niiFiles = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
    //niiFiles = [niiFiles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSSortDescriptor* sortOrder = [NSSortDescriptor sortDescriptorWithKey: @"self" ascending: NO];
    niiFiles = [niiFiles sortedArrayUsingDescriptors: [NSArray arrayWithObject: sortOrder]];
    //NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    //niiFiles=[niiFiles sortedArrayUsingDescriptors:@[sort]];
    for (int i = 0; i < niiFiles.count; i++) {
        //NSString *fnm = [[templatePath stringByAppendingString:@"/"] stringByAppendingString: niiFiles[i]];
        //if (![[NSFileManager defaultManager] isReadableFileAtPath:fnm] ) continue;
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath:[[templatePath stringByAppendingString:@"/"] stringByAppendingString: niiFiles[i]]]];
    }
}*/

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
{
    return YES;
}

#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
- (void) dcm2niiApplicationDidFinishLaunching:(NSNotification *)aNotification {
    //[self logVideoMemoryCurrentRenderer ];
    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    BOOL inSandbox = (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
    if (inSandbox) return;
    //re-direct printf statements to appear in the text view component
    //Here we use Grand Central Dispatch, alternatively we could use NSNotification as described here:
    //   http://stackoverflow.com/questions/2406204/what-is-the-best-way-to-redirect-stdout-to-nstextview-in-cocoa
    NSPipe* pipe = [NSPipe pipe];
    NSFileHandle* pipeReadHandle = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], fileno(stdout));
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_event_handler(source, ^{
        void* data = malloc(4096);
        ssize_t readResult = 0;
        do
        {
            errno = 0;
            readResult = read([pipeReadHandle fileDescriptor], data, 4096);
        } while (readResult == -1 && errno == EINTR);
        if (readResult > 0) {
            //AppKit UI should only be updated from the main thread
            dispatch_async(dispatch_get_main_queue(),^{
                NSString* stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                [[[_theTextView textStorage] mutableString] appendString:stdOutString];
                //[_theTextView setNeedsDisplay:YES];
                [_theTextView setNeedsDisplay:YES];
                //[_theTextView display];
            });
        }
        else{free(data);}
    });
    dispatch_resume(source);
    //read and display preferences
    const char *appPath = [[[NSBundle mainBundle] bundlePath] UTF8String];
    readIniFile (&opts, &appPath);
    [self showPrefs];
    fflush(stdout); //GUI buffers printf, display all results
    //finally, remove any bizarre options that XCode appends to Edit menu
    NSMenu* edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"orderFrontCharacterPalette:"))
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"startDictation:"))
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] isSeparatorItem])
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_6
    //NSLog(@"yyyy");
#endif

} //end dcm2niiApplicationDidFinishLaunching()
#endif



/*- (void) vectTest {
    const int vL = 10000;

    const int vN = 1024;
    NSLog(@"loops %d array size: %d", vL, vN);
    float * vA = (float *)malloc(vN * sizeof(float));
    float * vB = (float *)malloc(vN * sizeof(float));
    float * vC = (float *)malloc(vN * sizeof(float));
    for (long i = 0; i < vN; ++i) {
        vA[i] = (float) (rand()) +1;
        vB[i] = (float) (rand()) +1;
        vC[i] = 1/vB[i];
    }

    
    NSDate *startTime;
    //standard computation
    startTime = [NSDate date];
    for (long l = 0; l < vL; ++l) {
        for (long i = 0; i < vN; ++i)
            vA[i] = vA[i] * vB[i];
        for (long i = 0; i < vN; ++i)
            vA[i] = vA[i] * vC[i];
    }
    float mulTime = 1000.0*[[NSDate date] timeIntervalSinceDate: startTime];
    startTime = [NSDate date];
    for (long l = 0; l < vL; ++l) {
        for (long i = 0; i < vN; ++i)
            vA[i] = vA[i] / vB[i];
        for (long i = 0; i < vN; ++i)
            vA[i] = vA[i] / vC[i];
    }
    float divTime = 1000.0*[[NSDate date] timeIntervalSinceDate: startTime];
    NSLog(@"mul = %1f div %1f", mulTime, divTime);
    
    free(vA);
    free(vB);
    free(vC);
}*/

- (void) glDidFinishLaunching
{
    static NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {0};
    
    /*
     if ([[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"])
     theWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
     else
     theWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
     self.prefWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.dcm2niiWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    //self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];*/
    
    /*NSOpenGLPixelFormatAttribute pixelFormatAttributes[] =
    {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
        NSOpenGLPFAColorSize    , 24                           ,
        NSOpenGLPFAAlphaSize    , 8                            ,
        NSOpenGLPFADoubleBuffer ,
        NSOpenGLPFAAccelerated  ,
        NSOpenGLPFANoRecovery   ,
        0
    };*/
    /*NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes] autorelease];
    [self setView:[[[NSOpenGLView alloc] initWithFrame:[[[self window] contentView] bounds] pixelFormat:pixelFormat] autorelease]];
    [[[self window] contentView] addSubview:[self view]];*/
    
    //[self vectTest];
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    
    //NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:glAttributes];
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    [openGLContext makeCurrentContext];
    GLint virtualScreen = [openGLContext currentVirtualScreen];
    // Since this may be called from outside the display loop, make sure
    // the context is current so the GL calls all work properly.
    [openGLContext makeCurrentContext];
    // Use the current virtual screen index to interrogate the pixel format
    // for its display mask and renderer id.
    // Note, "pixelFormat" is the NSOpenGLPixelFormat that your OpenGL context
    // is created from, typically created in your OpenGL view's -initWithFrame:
    GLint displayMask;
    GLint rendererID;
    [pixelFormat getValues:&displayMask forAttribute:NSOpenGLPFAScreenMask forVirtualScreen:virtualScreen];
    [pixelFormat getValues:&rendererID  forAttribute:NSOpenGLPFARendererID forVirtualScreen:virtualScreen];
    // Get renderer info for all renderers that match the display mask.
    GLint i, nrend = 0;
    CGLRendererInfoObj rend;
    CGLQueryRendererInfo((GLuint)displayMask, &rend, &nrend);
    GLint videoMemory = 0;
    for (i = 0; i < nrend; i++) {
        GLint thisRendererID;
        
        CGLDescribeRenderer(rend, i, kCGLRPRendererID, &thisRendererID);
        // See if this is the one we want
        if (thisRendererID == rendererID) {
            CGLDescribeRenderer(rend, i, kCGLRPVideoMemoryMegabytes, &videoMemory);
            #ifdef MY_DEBUG //defined in nii_io.h
            NSLog(@"%@", [NSString stringWithCString:(const char *)glGetString(GL_RENDERER)  encoding:NSASCIIStringEncoding]);
            NSLog(@"Renderer ID = 0x%x", thisRendererID);
            NSLog(@"Video Memory = %d MB", videoMemory);
            #endif
        }
    }
    CGLDestroyRendererInfo(rend);
    const int kMinVRAM = 250;
    if (videoMemory < kMinVRAM) {
        NSString *str = [NSString stringWithFormat:@"This software requires %dmb of video memory. If you are using a virtual machine try adjusting the graphics settings", kMinVRAM];
        NSAlert *alert = [NSAlert alertWithMessageText: @"Insufficient video memory"
                                         defaultButton: @"OK"
                                       alternateButton: @""
                                           otherButton: @""
                             informativeTextWithFormat: @"%@",str ];
        [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        [alert runModal];
        videoMemory = 0;
        exit(0);
    }
}

/*- (void)imgLoad
{
    NSArray * imageReps = [NSBitmapImageRep imageRepsWithContentsOfFile:@"/Users/rorden/desktop/t1-head.tif"];
    if (imageReps.count < 1) {
        NSLog(@"Invalid image");
        return;
    }
    NSInteger maxwidth = 0;
    NSInteger minwidth = 65535;

    int indx = 0;
    for (int i = 0; i < imageReps.count; i++) {
        NSBitmapImageRep *rep = [imageReps objectAtIndex: i];
        if (rep.pixelsWide < minwidth) minwidth = rep.pixelsWide;
        if (rep.pixelsWide > maxwidth) {
            indx = i;
            maxwidth = rep.pixelsWide;
            //NSLog(@"Width from NSBitmapImageRep: %ld %ld %ld", rep.pixelsWide, rep.pixelsHigh, rep.bitsPerSample);
        }
    }
    NSBitmapImageRep *rep = [imageReps objectAtIndex: indx];
    NSLog(@"Width from NSBitmapImageRep: %ld %ld %ld %ld %ld", rep.pixelsWide, rep.pixelsHigh, rep.samplesPerPixel, rep.bitsPerPixel, imageReps.count);
    
    //int w = [rep pixelsWide];
    //int h = [rep pixelsHigh];
    //int alphaInt = (int)[rep hasAlpha];
    //int m = [rep samplesPerPixel]; // no, I don't know why I used "m"
    unsigned char *img = [rep bitmapData];
    
    long nPix = [rep pixelsWide] * [rep pixelsHigh] * [rep samplesPerPixel] * ((rep.bitsPerPixel+7) /8);
    NSLog(@"range %ld ", nPix);
    int mx = 0;
    int mn = 255;
    for (int p = 0; p < nPix; p++) {
        if (img[p] > mx) mx = img[p];
        if (img[p] < mn) mn = img[p];
    }
    NSLog(@"range %d %d", mn, mx);
    
}*/


/*As of OSX 10.10, 16-bit JPEG 2000 images converted to 8 bit!
 - (void)imgLoad
{
 ///
    //NSArray * imageReps = [NSBitmapImageRep imageRepsWithContentsOfFile:@"/Users/rorden/desktop/j2k/flame-median-all.tiff"];
    NSArray * imageReps = [NSBitmapImageRep imageRepsWithContentsOfFile:@"/Users/rorden/desktop/manix.jp2"];
     if (imageReps.count < 1) {
         NSLog(@"Invalid image");
         return;
     }
    NSInteger maxwidth = 0;
    int indx = 0;
    for (int i = 0; i < imageReps.count; i++) {
        NSBitmapImageRep *rep = [imageReps objectAtIndex: i];
        if (rep.pixelsWide > maxwidth) {
            indx = i;
            maxwidth = rep.pixelsWide;
            //NSLog(@"Width from NSBitmapImageRep: %ld %ld %ld", rep.pixelsWide, rep.pixelsHigh, rep.bitsPerSample);
        }
    }
    NSBitmapImageRep *rep = [imageReps objectAtIndex: indx];
    NSLog(@"Width from NSBitmapImageRep: %ld %ld %ld %ld", rep.pixelsWide, rep.pixelsHigh, rep.bitsPerPixel, (long)rep.bitsPerSample);
}*/


/*int jpls_skip (const char *fn, int skipBytes, bool verbose) {
    int dimX, dimY, bits, frames;
    unsigned char * img = decode_JPEG_SOF_0XC3 (fn, skipBytes, verbose, &dimX, &dimY, &bits, &frames);
    if (img == NULL) return EXIT_FAILURE;
    NSLog(@" X*Y %d*%d %d-bits %d-frames", dimX, dimY, bits, frames);
    
    char* yourFilePath  = "/Users/rorden/Desktop/512x400.img";
    FILE* pFile = fopen(yourFilePath,"wb");
    if (! pFile) return EXIT_FAILURE;
    if (bits == 16)
        fwrite(img, dimX*dimY*frames*2, 1, pFile);
    else
        fwrite(img, dimX*dimY*frames, 1, pFile);
    fclose(pFile);
    
    free(img);
    return EXIT_SUCCESS;
}*/

/*NSString * listString ( NSArray * list) {
    NSString *str = @"";
    if (list.count < 1) return str;
    for (int i = 0; i < list.count; i++) {
        str = [str stringByAppendingString: @" "];
        str = [str stringByAppendingString: [list objectAtIndex: i]];
    }
    return str;// NSNotFound;
}*/

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

-(void)detectSandbox {
    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    BOOL inSandbox = (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
    //NSLog(@"%d", inSandbox);
    if (inSandbox)
        [importMenu setHidden:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    //[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:[[NSApplication sharedApplication] delegate]] ;
    /*
    //Detect High-Definition Screen
    NSArray<NSScreen *> * screens = [NSScreen screens];
    
    for ( NSScreen * screen in screens ) {
        if ( [screen canRepresentDisplayGamut:NSDisplayGamutP3] )
            NSLog(@"Display: P3 Capable");
        else
            NSLog(@"Display: P3 Not supported");
        NSLog(@"Display scale %g", screen.backingScaleFactor);
    }
    */
    [self detectSandbox];
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    //[self imgLoad ];
    //NSString *niiFile = @"/Users/rorden/Downloads/comp/fubar/25943524";
    //NSString *niiFile = @"/Users/rorden/Downloads/comp/fubar/outC";
    //[ self processFile: niiFile];
    //NSString *niiFile = @"/Users/rorden/Desktop/c/t1-head_lzw.tiff";
    //[ self processFile: niiFile];
    /*NSMutableArray * list = [[NSMutableArray alloc] init];
    [list addObject:@"fx"];
    [list addObject:@"cbf"];
    [list addObject:@"t1"];
    NSLog(@"%@", listString(list));*/
    //NSString *tag = @"i3mT2";
    /*
    NSString *tag = @"lesion";
    NSString *temp = @"/Users/rorden/Desktop/c/LM1010.mat";
    int nx = 0; int ny = 0; int nz = 0; int dataType = 0;
    unsigned char * img = readMat(temp, tag, &nx, &ny, &nz, &dataType);
    if (img != NULL) {
        NSLog(@" %dx%dx%d %d", nx, ny, nz, dataType);
            free(img);
    }*/
    #if defined(__APPLE__)
     //OSX specific features
    #endif
    [self glDidFinishLaunching];
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    [self dcm2niiApplicationDidFinishLaunching: aNotification];
#undef MY_DCM_TEST
//#define MY_DCM_TEST
    #ifdef MY_DCM_TEST
        //opts.isVerbose = true;
        [_dcm2niiWindow orderFront: aNotification];
        [_dcm2niiWindow makeKeyWindow];
    //NSString *temp = @"/Users/rorden/Downloads/RGB";
    //[self processDicomFile:temp];
    #endif
#else
    [importMenu setHidden: true];
#endif
    [self populateTemplateMenus: TRUE];
    [self populateTemplateMenus: FALSE];
    //Yuck - with XCode either a whole menu is auto enabled or not, you can not manually set a single item if the menu is automatic
    //NSMenu* fileMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"File"] submenu];
    //[fileMenu setAutoenablesItems: NO];
    //[[fileMenu itemWithTag: 13] setEnabled: YES];
    //[fileMenu removeItemAtIndex: [edit numberOfItems] - 1];
    NSMenu* edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"orderFrontCharacterPalette:"))
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"startDictation:"))
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] isSeparatorItem])
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(niiNotification:) name:@"niiChanged" object:nil];
    [self setDefaults:false];
    /*NSColor *clr =[self colorForKey:@"xBarColor"];
    if (clr == nil)
        [self setColor: [NSColor colorWithCalibratedRed:0.3 green:0.3 blue:1.0 alpha:1.0] forKey:@"xBarColor"];
    clr =[self colorForKey:@"colorBarTextColor"];
    if (clr == nil)
        [self setColor: [NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0] forKey:@"colorBarTextColor"];
    //NSLog(@"r/g/b %f %f %f", clr.redComponent, clr.greenComponent, clr.blueComponent);
    _pref3dOrientCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"showCube"];
    _prefCrosshairCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"xBarGap"];
    _prefCoordinateCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"showInfo"];*/
    
    //reopen last file.... http://www.cocoawithlove.com/2008/05/open-previous-document-on-application.html
    // beware, check if we have access (sandboxed apps will not be able to do this!)
    //bool result = (!access([file_name UTF8String], R_OK) );
    //[self openPreviousFile];
    
    //NSInvocationOperation* op = [[NSInvocationOperation alloc]initWithTarget:self selector:@selector(openNewDocumentIfNeeded) object:nil];
    //[[NSOperationQueue mainQueue] addOperation: op];
    
    //TODO:
    // open -a MRIcro /Users/chrisrorden/Desktop/a/brik/a.HEAD
    //Does not behave at expected if App is not already running:
    // application:openFileis called before applicationDidFinishLaunching:
    //We need something like
    // if (img != NULL) return; //image loaded prior to applicationDidFinishLaunching
    if ((int)[windowArray count] > 0) return;
    NSMenu  *mainMenu = [[NSApplication sharedApplication] mainMenu];
    NSMenu  *fileMenu = [[mainMenu itemAtIndex:1] submenu];
    NSMenu  *atlasMenu = [[fileMenu itemAtIndex:4] submenu];
    if (atlasMenu == NULL) return;
    if (atlasMenu.numberOfItems < 1) return;
    int itm = (int) atlasMenu.numberOfItems - 1;
    NSUserDefaults *defaults= [NSUserDefaults standardUserDefaults];
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:@"startupStandard"]){
        //int itm2 = [[NSUserDefaults standardUserDefaults] boolForKey:@"startupStandard"];
        int itm2 = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"startupStandard"];
        if ((itm2 >= 0) && (itm2 < itm))
            itm = itm2;
    }
    NSMenuItem *imgMenu = [atlasMenu itemAtIndex: itm];
    if (imgMenu != NULL) {
        //NSLog(@"loading startup template %@", imgMenu.title);
        [self loadTemplate: imgMenu ];
    }
}


- (IBAction)closePopupX
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
}

- (IBAction)restartNotify;
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:@"Restart suggested"];
    notification.informativeText = @"Reason: Retina setting changed";
    notification.soundName = NULL;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    [NSTimer scheduledTimerWithTimeInterval: 4.5  target:self selector: @selector(closePopupX) userInfo:self repeats:NO];
}


- (IBAction)prefChange:(id)sender {
    //NSLog(@"Got it %ld", (long)_pref3dOrientCheck.state );
    //[[NSUserDefaults standardUserDefaults] setObject:@"~" forKey:@"defaultFilename"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_pref3dOrientCheck.state forKey:@"showCube"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefCrosshairCheck.state forKey:@"xBarGap"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefCoordinateCheck.state forKey:@"showInfo"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefOrientCheck.state forKey:@"showOrient"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefLoadOrientCheck.state forKey:@"orthoOrient"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefLoadFewVolumesCheck.state forKey:@"loadFewVolumes"];
    bool prevRet = [[NSUserDefaults standardUserDefaults] boolForKey:@"retinaResolution"];
    bool newRet = _prefRetinaCheck.state;
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefRetinaCheck.state forKey:@"retinaResolution"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefRadiologicalCheck.state forKey:@"viewRadiological"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefAdvancedRenderCheck.state forKey:@"advancedRender"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_prefBlackBackgroundCheck.state forKey:@"blackBackground"];
    
    //[[NSUserDefaults standardUserDefaults] setBool:(bool)_prefDicomCheck.state forKey:@"dicomWarn"];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)_pref2dSmoothCheck.state forKey:@"isSmooth2D"];
    
    //_prefBlackBackgroundCheck.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"blackBackground"];
    //NSLog(@"render %ld -> %ld",(long)_prefAdvancedRenderCheck.state,  (long)[[NSUserDefaults standardUserDefaults] boolForKey:@"advancedRender"] );
    //NSLog(@"Got it %ld -> %ld",(long)_prefDicomCheck.state,  (long)[[NSUserDefaults standardUserDefaults] boolForKey:@"dicomWarn"] );
    [self updateThemeMode];
    int numWin = (int)[windowArray count];
    if (numWin < 1) return;
    for (int i = 0; i < numWin; i++)
        [[ windowArray  objectAtIndex: i] updatePrefs:nil];
    if (prevRet != newRet)
        [self restartNotify];
}

/*- (void)changeTextColor:(id)sender {
    [self setColor: [sender color] forKey:@"colorBarTextColor"];
    [self prefChange: sender];
}

- (IBAction)prefTextColorChange:(id)sender {
    NSColor *clr =[self colorForKey:@"colorBarTextColor"];
    if (clr == nil)
        clr = [NSColor blueColor];
    NSColorPanel *panel = [NSColorPanel sharedColorPanel];
    [panel orderFront:nil];
    [panel setAction:@selector(changeTextColor:)];
    [panel setColor: clr];
    [panel setTarget:self];
    [panel makeKeyAndOrderFront:self];
}*/

- (void)changeColorForBackground:(id)sender {
    [self setColor: [sender color] forKey:@"xBarColor"];
    /*NSColor *clr = [sender color];
    NSData *theData=[NSArchiver archivedDataWithRootObject:clr];
    [[NSUserDefaults standardUserDefaults] setObject:theData forKey:@"xBarColor"];*/
    [self prefChange: sender];
}

- (IBAction)prefColorChange:(id)sender {
    /*NSColor *clr = [NSColor orangeColor];
    NSData *theData=[[NSUserDefaults standardUserDefaults] dataForKey:@"xBarColor"];
    if (theData != nil) {
        clr =(NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
        //NSLog(@"r/g/b %f %f %f", clr.redComponent, clr.greenComponent, clr.blueComponent);
    };*/
    NSColor *clr =[self colorForKey:@"xBarColor"];
    if (clr == nil)
        clr = [NSColor orangeColor];
    clr = [clr colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColorPanel *panel = [NSColorPanel sharedColorPanel];
    panel.mode = NSRGBModeColorPanel;
    //panel.colorSpace = NSRGBColorSpaceModel;
    [panel orderFront:nil];
    [panel setAction:@selector(changeColorForBackground:)];
    [panel setColor: clr];
    [panel setTarget:self];
    [panel makeKeyAndOrderFront:self];
    //isFontPanel = NO;
}

- (void)dealloc
{
    [windowArray removeAllObjects]; // all the stored Horse objects have their retain counts reduced to 0
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    #if !__has_feature(objc_arc)
    [super dealloc];
    #endif
}

- (IBAction)yokeClick:(id)sender {
    if ([yokeMenu state] == 0)
        [yokeMenu setState:1];
    else
        [yokeMenu setState:0];
}

- (IBAction)dcm2niiClick:(id)sender {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    BOOL inSandbox = (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
    if (inSandbox) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Import finds and converts 2D DICOM images to 3D and 4D NIfTI images. This process is not compatible with the App Store sandbox rules. Solutions (1) Download the beta release of MRIcro (which does not use a sandbox), or (2) Download the standalone dcm2nii application." ];
        [alert runModal];
        return;
    }
    if (_dcm2niiWindow.isKeyWindow)
        [_dcm2niiWindow close];
    else {
        [_dcm2niiWindow orderFront: sender];
        [_dcm2niiWindow makeKeyWindow];
    }
#else
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Import finds and converts 2D DICOM images to 3D and 4D NIfTI images. This process is not compatible with the App Store sandbox rules. Solutions (1) Download the beta release of MRIcro (which does not use a sandbox), or (2) Download the standalone dcm2nii application." ];
    [alert runModal];
#endif
}

- (IBAction)prefDicomCheck:(id)sender {
}

-(void) showExampleFilename {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    char niiFilename[1024];
    nii_createDummyFilename(niiFilename, opts);
    [self.theTextView setString: [NSString stringWithFormat:@"%s\nVersion %s (%lu-bit MacOS)\n", niiFilename,kDCMvers, sizeof(size_t)*8 ]];
    [self.theTextView setNeedsDisplay:YES];
    //[[self theTextView] setFont:[NSFont boldSystemFontOfSize:6.0]];
    //[[self theTextView] setFont:[NSFont systemFontOfSize:0.0]];
    //[[self theTextView] setFont:[NSFont fontWithName:@"DoesNotExist" size:11]];
    //NSFont *oldFont = self.theTextView.font;
    //NSLog(@"%@",oldFont.familyName);
#endif
}

-(void)showPrefs {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    _compressCheck.state = opts.isGz;
    _verboseCheck.state = opts.isVerbose;
    
    //NSString *title = [NSString stringWithCString:opts.filename encoding:NSASCIIStringEncoding];
    //[_outputFilenameEdit setStringValue:title];
    [_outputFilenameEdit setStringValue:[NSString stringWithCString:opts.filename encoding:NSASCIIStringEncoding]];
    NSString *outdir = [NSString stringWithCString:opts.outdir encoding:NSASCIIStringEncoding];
    if ([outdir length] < 1)
        [_folderButton setTitle:@"input folder"];
    else if ([outdir length] > 40)
        [_folderButton setTitle:[NSString stringWithFormat:@"%@%@", @"...",[outdir substringFromIndex:[outdir length]-36]]];
    else
        [_folderButton setTitle:outdir];
    [self showExampleFilename];

#endif
}

- (IBAction)outputFolderClick:(id)sender {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    //http://stackoverflow.com/questions/5621513/cocoa-select-choose-file-panel
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setTitle: @"Select output folder (cancel to use input folder)"];
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setPrompt:@"Select"];
    NSInteger isOKButton = [openDlg runModal];
    NSArray* files = [openDlg URLs];
    NSString* outdir = @"";
    if ((isOKButton == NSFileHandlingPanelOKButton)  && ([files count] > 0))
        outdir = [[files objectAtIndex:0] path];
    strcpy(opts.outdir, [outdir cStringUsingEncoding:1]);
    [self showPrefs];
    #endif
}

- (void)controlTextDidChange:(NSNotification *)notification {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    //user has changed text field, 1: get desired file name mask
    NSTextField *textField = [notification object];
    //next: display example of what the provided filename mask will generate
    strcpy(opts.filename, [[textField stringValue] cStringUsingEncoding:1]);
    [self showExampleFilename];
#endif
}

- (IBAction)compressCheckClick:(id)sender {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    opts.isGz = _compressCheck.state;
    [self showExampleFilename];
    #endif
}

- (IBAction)verboseCheckClick:(id)sender {
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    if (_verboseCheck.state)
        opts.isVerbose = 2;//_verboseCheck.state;
    else
         opts.isVerbose = 0;
    [self showExampleFilename];
#endif
}

- (void) processDicomFile: (NSString*) fname
{
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    //convert folder (DICOM) or file (PAR/REC) to NIFTI format
    [_theTextView setString: @""];//clear display
    struct TDCMopts optsTemp;
    optsTemp = opts; //conversion may change values like the outdir (if not specified)
    strcpy(optsTemp.indir, [fname cStringUsingEncoding:NSUTF8StringEncoding]); //2015 folder with umlaut
    //strcpy(optsTemp.indir, [fname cStringUsingEncoding:1]);
    optsTemp.isCrop = true; //2016: crop 3D images
    clock_t start = clock();
    nii_loadDir (&(optsTemp));
    printf("required %fms\n", ((double)(clock()-start))/1000);
    fflush(stdout); //GUI buffers printf, display all results
    #endif
}

- (IBAction)selectDicomClick:(id)sender {
        NSOpenPanel* openDlg = [NSOpenPanel openPanel];
        [openDlg setTitle: @"Select folder that contains DICOM images"];
        [openDlg setCanChooseFiles:NO];
        [openDlg setCanChooseDirectories:YES];
        [openDlg setPrompt:@"Select"];
        //CR2019 NSOKButton -> NSModalResponseOK https://github.com/google/google-api-objectivec-client/issues/76
        if ([openDlg runModal] != NSModalResponseOK ) return;
        NSArray* files = [openDlg URLs];
        if ([files count] < 1) return;
        [self processDicomFile: [[files objectAtIndex:0] path] ];
}

@end

