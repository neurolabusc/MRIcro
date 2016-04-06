//
//  dcm2niiWindow.m
//  dcm2
//
//  Created by Chris Rorden on 4/7/14.
//  Copyright (c) 2014 Chris Rorden. All rights reserved.
//

#import "dcm2niiWindow.h"
#import "MRIcroAppDelegate.h"


@implementation dcm2niiWindow

- (void)awakeFromNib {
    //http://stackoverflow.com/questions/8567348/accepting-dragged-files-on-a-cocoa-application
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}


- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender {
    return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

-(BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    #ifndef STRIP_DCM2NII // /BuildSettings/PreprocessorMacros/STRIP_DCM2NII
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    if (1 == filenames.count) {
        //MRIcroXAppDelegate *appDelegate = [NSApp delegate];
        //[[NSApp MRIcroXAppDelegate]  processDicomFile: [filenames lastObject]];
        [(MRIcroXAppDelegate *)[NSApp  delegate] processDicomFile:[filenames lastObject]];
        
        //[[NSApp delegate] processDicomFile: [filenames lastObject]];
        return TRUE;
    }
#endif
    return NO;
}

@end
