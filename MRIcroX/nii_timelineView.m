//
//  nii_timelineView.m
//  PDF
//
//  Created by Chris Rorden on 9/24/12.
//  Copyright (c) 2012 Chris Rorden. All rights reserved.
//
#import "nii_timelineView.h"

@implementation nii_timelineView

GraphStruct gGraph;

- (void) pasteFromClipboard
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *classArray = [NSArray arrayWithObject:[NSImage class]];
    NSDictionary *options = [NSDictionary dictionary];
    BOOL ok = [pasteboard canReadObjectForClasses:classArray options:options];
    if (ok) {
        NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
        NSImage *image = [objectsToPaste objectAtIndex:0];
        [self setImage:image];
    }
}

- (void)mouseDown:(NSEvent *)event
{
    if ((gGraph.lines < 1) || (gGraph.timepoints < 2) || (gGraph.enabled == FALSE)) { //3D mode
        [[NSNotificationCenter defaultCenter] postNotificationName:@"niiMosaic" object:self userInfo:nil]; //notify window if document drag-dropped directly on view
        return; //66666666
    }
    gGraph.blackBackground = !gGraph.blackBackground;
    [self display];
}

-(void) saveTabFromFileName:(NSString *)fName
{
    if ((gGraph.lines < 1) || (gGraph.timepoints < 1) ) return;
    NSMutableString* tabString = [NSMutableString string];
    //add first line header
    for (int time = 0; time < gGraph.timepoints; time++)
        [tabString appendString:[NSString stringWithFormat: @"%.8g\t", gGraph.verticalScale*time]];
    [tabString appendString:@"\n"];
    //add data columns and rows...
    int i = 0;
    for (int line = 0; line < gGraph.lines; line++) {
        for (int time = 0; time < gGraph.timepoints; time++) {
            [tabString appendString:[NSString stringWithFormat: @"%.8g\t", gGraph.data[i]]];
            i++;
        }
        [tabString appendString:@"\n"];
    }
    [tabString writeToFile: fName
                atomically: NO
                  encoding: NSUTF8StringEncoding
                     error: nil];
} //NSURL *outURL = [[NSURL alloc] initFileURLWithPath:file_name];

- (void)saveTab
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setTitle:@"Save as tab-delimited text"];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"tab",nil]; // Only export PNG
    [savePanel setAllowedFileTypes:fileTypes];
    [savePanel setTreatsFilePackagesAsDirectories:NO];
    [savePanel setAllowsOtherFileTypes:NO];
    //NSInteger user_choice =  [savePanel runModalForDirectory:NSHomeDirectory() file:@""]; // <- works, deprecated
    [savePanel setNameFieldStringValue:@""];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory() ]];
    NSInteger user_choice =  [savePanel runModal];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if(NSOKButton == user_choice)
        [self saveTabFromFileName:[[savePanel URL] path]];
#pragma clang diagnostic pop
}

- (void)savePDFFromFileName:(NSString *)fname
{
    NSRect r = [self bounds];
    NSData *data = [self dataWithPDFInsideRect:r];
    [data writeToFile:fname atomically:YES];
}

- (void)savePDF
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setTitle:@"Save as pdf"];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"pdf",nil]; // Only export PNG
    [savePanel setAllowedFileTypes:fileTypes];
    [savePanel setTreatsFilePackagesAsDirectories:NO];
    [savePanel setAllowsOtherFileTypes:NO];
    //NSInteger user_choice =  [savePanel runModalForDirectory:NSHomeDirectory() file:@""]; // <- works, deprecated
    [savePanel setNameFieldStringValue:@""];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory() ]];
    NSInteger user_choice =  [savePanel runModal];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if(NSOKButton == user_choice)
    {
        [self savePDFFromFileName:[[savePanel URL] path]];
    }
#pragma clang diagnostic pop
}

- (void)rightMouseDown:(NSEvent *)event
{
    [self savePDF];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
         //[super setImageAlignment:NSImageAlignBottomLeft]; //NSImageAlignCenter;
        [self setImageScaling:NSImageScaleProportionallyDown]; //NSScaleNone or NSScaleToFit or NSScaleProportionally
        //NSScaleToFit does not respect aspect ratio, see http://stackoverflow.com/questions/13750234/confused-about-nsimageview-scaling
    }
    return self;
}


typedef struct   {
    float axisMin, axisMax, axisRange, tickSpacing, tickMin;
    int decimals;
} AxisStruct;

float  defuz(float x)
{
    if (fabs(x) < 1.0E-6) return 0.0;
    return x;
}

AxisStruct setAxis (float min, float max)
{
    AxisStruct ret;
    float range = fabs(max-min);
    if (range == 0.0) { //no variation...
        if (min == 0) {
            min = -0.1;
            max = 0.1;
        } else {
            min = min - fabs(min/10.0);
            max = max + fabs(max/10.0);
        }
        range = fabs(max-min);
    }
    float const kDesiredSteps = 4.0;
    float tickSpacing = (range / kDesiredSteps);
    int power = 0;
    while (tickSpacing >= 10) {
        tickSpacing = tickSpacing/10;
        power++;
    }
    while (tickSpacing < 1) {
        tickSpacing = tickSpacing * 10;
        power--;
    }
    tickSpacing = round(tickSpacing) * pow(10,power);
    //NSLog(@" %d %f", power, tickSpacing);
    if (power < 0)
        ret.decimals = abs(power);
    else
        ret.decimals = 0;
    ret.axisMin = (trunc( (min- (0.999*tickSpacing))  / tickSpacing) * tickSpacing);
    ret.axisMax = (trunc( (max+ (0.999*tickSpacing))  / tickSpacing) * tickSpacing);
    ret.axisRange = ret.axisMax - ret.axisMin;
    ret.tickSpacing = tickSpacing;
    return ret;
}

NSPoint setPoint (float x, float y, float xmin, float xrange, float ymin, float yrange, NSRect graphRect)
{
    NSPoint ret;
    ret.x = (((x-xmin)/xrange) * graphRect.size.width)+graphRect.origin.x;
    ret.y = (((y-ymin)/yrange) * graphRect.size.height)+graphRect.origin.y;
    //NSLog(@" %f %f", (y-ymin)/yrange, ret.y);
    return ret;
}

void setColor (int lineIndex)
{
    lineIndex = lineIndex % 9;
    switch(lineIndex) {
        case 0: [[NSColor blueColor] set]; break;
        case 1: [[NSColor redColor] set]; break;
        case 2: [[NSColor purpleColor] set]; break;
        case 3: [[NSColor grayColor] set]; break;
        case 4: [[NSColor cyanColor] set]; break;
        case 5: [[NSColor greenColor] set]; break;
        case 6: [[NSColor magentaColor] set]; break;
        case 7: [[NSColor orangeColor] set]; break;
        default: [[NSColor blackColor] set]; break;
    }
}

- (void) drawRect:(NSRect) rect {
    if (self.image.size.width > 1) {
        if ((gGraph.lines < 1) || (gGraph.timepoints < 2) || (gGraph.enabled == FALSE)) {
            [super drawRect:rect];
            return; //66666666
        }
        [self setImage:nil]; //if timeline is available, clear 3D image.
    } //image loaded
    //    if ((rect.size.width < 1) || (rect.size.height < 1) )  return; //XCode does this automatically
	int const kSmallFontSize = 10;
    NSColor *textColor = [NSColor blackColor];
    [[NSColor whiteColor] set];
    if (gGraph.blackBackground) {
        textColor = [NSColor whiteColor];
        [[NSColor blackColor] set];
    }
    NSMutableDictionary *textDict = [[NSMutableDictionary alloc] init];
	[textDict setValue:textColor forKey:NSForegroundColorAttributeName];
	[textDict setValue:[NSFont systemFontOfSize:kSmallFontSize] forKey:NSFontAttributeName];
    //draw background
    NSRectFill( rect );
    if ((gGraph.lines < 1) || (gGraph.timepoints < 2) || (gGraph.enabled == FALSE)) {
        [@"Click here to create a mosaic of your 3D image. Graphs only available for 4D data (e.g. raw fMRI)." drawAtPoint:NSMakePoint(1, 1 ) withAttributes:textDict];
        #if !__has_feature(objc_arc)
        [textDict release];
        #endif
        return;
    }
    int const kTitleFontSize = 12;
    int const kVertAxisWidth = 50;
    int const kBorder = 8;
    int const kTickSize = kBorder / 4;
    NSRect graphRect;
    graphRect.origin.x = kTitleFontSize+kBorder+kVertAxisWidth; //graph LEFT
    graphRect.origin.y = kTitleFontSize+kBorder+kSmallFontSize; //graph BOTTOM
    graphRect.size.width = rect.size.width - graphRect.origin.x - kBorder;
    graphRect.size.height = rect.size.height - graphRect.origin.y - kBorder;
    NSPoint centerPoint;
    if ((graphRect.size.width < 5) || (graphRect.size.height < 5)) {
        #if !__has_feature(objc_arc)
        [textDict release];
        #endif
        return;
    }
    [self setToolTip:[NSString stringWithFormat:@" X=%.0f Y=%.0f", rect.size.width, rect.size.height]];
    NSString *string;
    NSSize stringSize;
    //find range
    float max = gGraph.data[0];
    float min = max;
    for (int i = 0; i < (gGraph.lines*gGraph.timepoints); i++) {
        if (gGraph.data[i] > max) max = gGraph.data[i];
        if (gGraph.data[i] < min) min = gGraph.data[i];
    }
    //draw lines...
    AxisStruct a = setAxis(min, max);
    int pos = 0;
    for (int line = 0; line < gGraph.lines; line++) {
        NSBezierPath* path = [NSBezierPath bezierPath];
        [path moveToPoint:setPoint(0, gGraph.data[pos], 0, (gGraph.timepoints-1), a.axisMin, a.axisRange, graphRect)];
        pos ++;
        for (int time = 1; time < gGraph.timepoints; time++) {
            [path lineToPoint:setPoint(time, gGraph.data[pos], 0, (gGraph.timepoints-1), a.axisMin, a.axisRange, graphRect)];
            pos ++;
        }
        setColor (line);
        [path stroke];
    } //for each line
    //draw red translucent marker at selected timepoint
    #ifdef MY_DEBUG //from nii_io.h
        NSLog(@"nii_timeline timepoint %d",gGraph.selectedTimepoint);
    #endif
    if (gGraph.selectedTimepoint > 1) {
        int kCurrentWidth = 6; //width of tick mark showing current time - ideally an even number
        NSPoint currentPos = setPoint(gGraph.selectedTimepoint-1, 0, 0, (gGraph.timepoints-1), a.axisMin, a.axisRange, graphRect);
        //note "gGraph.selectedTimepoint-1" as graph is indexed from zero
        NSRect currentRect;
        currentRect.origin.x = currentPos.x- (kCurrentWidth/2.0f); //graph LEFT
        currentRect.origin.y = graphRect.origin.y; //graph BOTTOM
        currentRect.size.width = kCurrentWidth;
        currentRect.size.height = graphRect.size.height;
        NSColor *currentColor = [NSColor colorWithCalibratedRed:0.9f green:0.0f blue:0.3f alpha:0.55f];
        [currentColor set];
        //NSRectFill( currentRect ); //<- this is always opaque, regardless of color
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSRectFillUsingOperation(currentRect, NSCompositeSourceOver);
#pragma clang diagnostic pop
    }
    //draw vertical ticks and labels
    if (a.tickSpacing > 0.0) {
        float vPos = a.axisMin;
        NSPoint pt;
        bool first = TRUE;
        NSBezierPath* path = [NSBezierPath bezierPath];
        while (vPos <= a.axisMax) {
            //tick position
            pt = setPoint(0, vPos, 0, (gGraph.timepoints-1), a.axisMin, a.axisRange, graphRect);
            //tick line
            if (first)
                [path moveToPoint:pt];
            else
                [path lineToPoint:pt];
            first = FALSE;
            pt.x = pt.x - kTickSize;
            [path lineToPoint:pt];
            pt.x = pt.x + kTickSize;
            [path lineToPoint:pt];
            //tick title
            //char lS[255] = { '\0' };
            //sprintf(lS, "%-.*f",  a.decimals, vPos);
            //string = [NSString stringWithFormat:@"%s", lS];
            //string = [NSString stringWithFormat: formatString, vPos];
            string = [NSString stringWithFormat: @"%g", defuz(vPos)];//defuzz
            stringSize = [string sizeWithAttributes:textDict];
            pt.x = pt.x -kTickSize -kTickSize - (stringSize.width);
            pt.y = pt.y -(stringSize.height / 2.0);
            [string drawAtPoint:pt withAttributes:textDict];
            //next tick
            vPos += a.tickSpacing;
        }
        [textColor set];
        [path stroke];
    } //vertical ticks and titles
    //draw horizontal ticks and titles...
    float hStart = 0;
    float hEnd = (gGraph.timepoints-1);
    if (gGraph.verticalScale != 0.0)
        hEnd = hEnd * fabs(gGraph.verticalScale);
    float hRange = hEnd-hStart;
    a = setAxis(hStart, hEnd);
    //formatString = [NSString stringWithFormat: @"%%.%dg",a.decimals ];
    if (a.tickSpacing > 0.0) {
        float hPos = a.axisMin;
        NSPoint pt;
        NSBezierPath* path = [NSBezierPath bezierPath];
        pt = setPoint(0, 0, hStart, hRange, 0, 1, graphRect);
        [path moveToPoint:pt];
        while (hPos <= hEnd) {
            if (hPos >= hStart) {
                //tick position
                pt = setPoint(hPos, 0, hStart, hRange, 0, 1, graphRect);
                //tick line
                [path lineToPoint:pt];
                pt.y = pt.y - kTickSize;
                [path lineToPoint:pt];
                pt.y = pt.y + kTickSize;
                [path lineToPoint:pt];
                //tick title
                //char lS[255] = { '\0' };
                //sprintf(lS, "%-.*f",  a.decimals, hPos);
                //string = [NSString stringWithFormat:@"%s", lS];
                //string = [NSString stringWithFormat: formatString, hPos];
                string = [NSString stringWithFormat: @"%g", defuz(hPos)];//defuzz
                stringSize = [string sizeWithAttributes:textDict];
                pt.x = pt.x  - (stringSize.width / 2.0);
                pt.y = pt.y - kTickSize -(stringSize.height);
                [string drawAtPoint:pt withAttributes:textDict];
            }
            //next tick
            hPos += a.tickSpacing;
        }
        pt = setPoint(hEnd, 0, hStart, hRange, 0, 1, graphRect);
        //tick line
        [path lineToPoint:pt];
        [textColor set];
        [path stroke];
    }
    //draw graph border
    //[[NSColor blackColor] set];
    //NSFrameRect(graphRect);
    //Draw titles...
    //NSMutableDictionary *titleDict = [[NSMutableDictionary alloc] init];
    //[titleDict setValue:textColor forKey:NSForegroundColorAttributeName];
	//[titleDict setValue:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	//[drawStringAttributes setValue:[NSFont fontWithName:@"Arial" size:kTitleFontSize] forKey:NSFontAttributeName];
    [textDict setValue:[NSFont boldSystemFontOfSize:kTitleFontSize] forKey:NSFontAttributeName];
    //Horizontal title....
	string = [NSString stringWithFormat:@"%@", @"Time"];
    stringSize = [string sizeWithAttributes:textDict];
	centerPoint.x = graphRect.origin.x + (graphRect.size.width / 2) - (stringSize.width / 2);
	centerPoint.y = 0;//rect.size.height / 2 - (stringSize.height / 2);
	[string drawAtPoint:centerPoint withAttributes:textDict];
    //End with vertical Title - rotation transforms X/Y directions....
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform rotateByDegrees:90];
    [transform concat]; // sets the transform in the (new) current
	string = [NSString stringWithFormat:@"%@", @"Intensity"];
	stringSize = [string sizeWithAttributes:textDict];
	centerPoint.x = rect.size.height / 2 - (stringSize.height / 2);;//(rect.size.width / 2) - (stringSize.width / 2);
	centerPoint.y = -kTitleFontSize-4;//rect.size.height / 2 - (stringSize.height / 2);
	[string drawAtPoint:centerPoint withAttributes:textDict];
#if !__has_feature(objc_arc)
    [textDict release];
#endif
}

//typedef struct   {
//    float axisMin, axisMax, tickSpacing, tickMin;
//    int decimals;
//} AxisStruct;
//
//AxisStruct setAxis (float min, float max)

/*-(void) changeData: (int) timepoints SelectedTimepoint: (int) selectedTimepoint Lines: (int) lines VerticalScale: (float) verticalScale Data: (float*) data;
 {
 gGraph.selectedTimepoint = selectedTimepoint;
 gGraph.timepoints = timepoints;
 gGraph.verticalScale = verticalScale;
 gGraph.lines = lines;
 if ((gGraph.lines*gGraph.timepoints) < 1) { //passed empty set...
 [self display];
 gGraph.data = (float *) realloc(gGraph.data , sizeof(float));
 return; //empty
 
 }
 gGraph.data = (float *) realloc(gGraph.data ,gGraph.timepoints*gGraph.lines*sizeof(float));
 for (int i = 0; i < (gGraph.lines*gGraph.timepoints); i++)
 gGraph.data[i] = data[i];
 [self display];
 }*/

-(void) updateData: (GraphStruct) graph
{
    gGraph.timepoints = graph.timepoints;
    gGraph.selectedTimepoint = graph.selectedTimepoint;
    gGraph.verticalScale = graph.verticalScale;
    gGraph.lines = graph.lines;
    if ((gGraph.lines*gGraph.timepoints) < 1) { //passed empty set...
        [self display];
        //gGraph.data = (float *) realloc(gGraph.data , sizeof(float));
        return; //empty
        
    }
    free(gGraph.data);
    gGraph.data = (float *) malloc(gGraph.timepoints*gGraph.lines*sizeof(float));
    //NSLog(@"Timeline malloc %lu",gGraph.timepoints*gGraph.lines*sizeof(float));
    //gGraph.data = (float *) realloc(gGraph.data ,gGraph.timepoints*gGraph.lines*sizeof(float));
    for (int i = 0; i < (gGraph.lines*gGraph.timepoints); i++)
        gGraph.data[i] = graph.data[i];
    [self display];
}

-(void) enable: (bool) on;
{
    gGraph.enabled = on;
    [self display];
}

- (void) awakeFromNib
{
    gGraph.blackBackground = TRUE;
    gGraph.timepoints = 2;
    gGraph.verticalScale = 2.0;
    gGraph.selectedTimepoint = 0;
    gGraph.lines = 1;
    gGraph.data = (float *) malloc(gGraph.timepoints*gGraph.lines*sizeof(float));
    //NSLog(@"Timeline malloc %lu",gGraph.timepoints*gGraph.lines*sizeof(float));
    for (int i = 0; i < (gGraph.lines*gGraph.timepoints); i++)
        gGraph.data[i] = 0;//-(0.2 + (i*i))/70.0;
}

@end
