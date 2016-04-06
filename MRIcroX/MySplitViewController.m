//
//  MySplitViewController.m
//  NSSplitView-Part1
//
//  Created by Jeff Schilling on 12/28/09.
//  Copyright 2009 Manicwave Productions. All rights reserved.
//

#import "MySplitViewController.h"


@implementation MySplitViewController
//Apple borked this http://manicwave.com/blog/2009/12/28/unraveling-the-mysteries-of-nssplitview-part-1/

/* From the header doc 
 * Delegates that respond to this message and return a number larger than the proposed minimum position effectively declare a minimum size for the subview above or to the left of the divider in question, 
    the minimum size being the difference between the proposed and returned minimum positions. This minimum size is only effective for the divider-dragging operation during which the 
    -splitView:constrainMinCoordinate:ofSubviewAt: message is sent. NSSplitView's behavior is undefined when a delegate responds to this message by returning a number smaller than the proposed minimum.
 */
- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex;
{
    //NSLog(@"%@:%s proposedMinimum: %f",[self class], _cmd, proposedMinimumPosition);
    return proposedMinimumPosition + 200;
}


/*  Delegates that respond to this message and return a number smaller than the proposed maximum position effectively declare a minimum size for the subview below or to the right of the divider in question, 
    the minimum size being the difference between the proposed and returned maximum positions. This minimum size is only effective for the divider-dragging operation during which the
    -splitView:constrainMaxCoordinate:ofSubviewAt: message is sent. NSSplitView's behavior is undefined when a delegate responds to this message by returning a number larger than the proposed maximum.
 */
/*- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex;
{
    //NSLog(@"proposedMaximum: %f",proposedMaximumPosition);
    return proposedMaximumPosition - 100;
}*/




@end
