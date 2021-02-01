//
//  MRIcroXAppDelegate.h
//  MRIcroX
//
//  Created by Chris Rorden on 9/19/12.
//  Copyright 2012 University of South Carolina. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "nii_WindowController.h"
#ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
#import "nii_dicom_batch.h"
#endif
//#import <jasper/jasper.h>
//#import <jasper.h>

//static NSMutableArray * windowArray;

@interface MRIcroXAppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate> {
    //@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
    #ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    struct TDCMopts opts;
    #endif
    dispatch_source_t source;
    NSMutableArray * windowArray;
    NSWindow *_prefWin;
    __unsafe_unretained NSButton *_prefCrosshairCheck;
    __unsafe_unretained NSButton *_prefCoordinateCheck;
    __unsafe_unretained NSButton *_pref3dOrientCheck;
    __weak NSButton *_prefDicomCheck;
    __weak NSButton *_prefLoadOrientCheck;
    __weak NSButton *_prefBlackBackgroundCheck;
    __unsafe_unretained NSWindow *_dcm2niiWindow;
@private
    //__weak IBOutlet NSMenu *importMenu;
    __unsafe_unretained NSMenuItem *yokeMenu;
}
@property (unsafe_unretained) IBOutlet NSMenuItem *yokeMenu;
@property (unsafe_unretained) IBOutlet NSMenuItem *diffusionMenu;
@property (weak) IBOutlet NSMenuItem *importMenu;
@property (weak) IBOutlet NSButton *verboseCheck;
@property (weak) IBOutlet NSButton *compressCheck;
@property (weak) IBOutlet NSTextField *outputFilenameEdit;
@property (weak) IBOutlet NSButton *folderButton;
- (IBAction)outputFolderClick:(id)sender;
- (IBAction)compressCheckClick:(id)sender;
- (IBAction)verboseCheckClick:(id)sender;
- (IBAction)selectDicomClick:(id)sender;
- (IBAction)windowWillCloseX:(id)sender;
- (IBAction)prefChange:(id)sender;
- (IBAction)prefColorChange:(id)sender;
- (IBAction)prefResetClick:(id)sender;
- (IBAction)other2niiClick:(id)sender;
- (IBAction)dcm2niiClick:(id)sender;
- (IBAction)yokeClick:(id)sender;
- (IBAction)openDiffusion:(id)sender;
- (IBAction)showAppPrefs:(id)sender;
//- (IBAction)showPrefs:(id)sender;
- (void)setColor:(NSColor *)color forKey:(NSString *)key;
- (void) processDicomFile: (NSString*) fname;
- (NSColor *)colorForKey:(NSString *)key;
-(void) showExampleFilename;



@property (unsafe_unretained) IBOutlet NSButton *pref3dOrientCheck;
@property (unsafe_unretained) IBOutlet NSButton *prefCoordinateCheck;
@property (unsafe_unretained) IBOutlet NSButton *prefCrosshairCheck;
@property (unsafe_unretained) IBOutlet NSTextView *theTextView;
@property (unsafe_unretained) IBOutlet NSWindow *prefWindow;
@property (weak) IBOutlet NSButton *prefOrientCheck;
@property (weak) IBOutlet NSButton *prefLoadFewVolumesCheck;
@property (weak) IBOutlet NSButton *prefRetinaCheck;
@property (weak) IBOutlet NSButton *prefDarkModeCheck;
@property (weak) IBOutlet NSButton *prefRadiologicalCheck;
@property (weak) IBOutlet NSButton *prefDicomCheck;
@property (weak) IBOutlet NSButton *pref2dSmoothCheck;

@property (weak) IBOutlet NSButtonCell *prefAdvancedRenderCheck;

@property (strong) IBOutlet NSWindow *prefWin;
@property (weak) IBOutlet NSButton *prefLoadOrientCheck;
//@property (weak) IBOutlet NSButton *prefLoad4DCheck;
//@property (weak) IBOutlet NSButton *prefDicomCheck;
@property (weak) IBOutlet NSButton *prefBlackBackgroundCheck;
@property (unsafe_unretained) IBOutlet NSWindow *dcm2niiWindow;
@end
