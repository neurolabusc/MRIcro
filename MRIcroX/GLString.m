//
// File:		GLString.m
//				(Originally StringTexture.m)
//
// Abstract:	Uses Quartz to draw a string into an OpenGL texture
//
// Version:		1.1 - Antialiasing option, Rounded Corners to the frame
//					  self contained OpenGL state, performance enhancements,
//					  other bug fixes.
//				1.0 - Original release.
//				
//
// Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Inc. ("Apple")
//				in consideration of your agreement to the following terms, and your use,
//				installation, modification or redistribution of this Apple software
//				constitutes acceptance of these terms.  If you do not agree with these
//				terms, please do not use, install, modify or redistribute this Apple
//				software.
//
//				In consideration of your agreement to abide by the following terms, and
//				subject to these terms, Apple grants you a personal, non - exclusive
//				license, under Apple's copyrights in this original Apple software ( the
//				"Apple Software" ), to use, reproduce, modify and redistribute the Apple
//				Software, with or without modifications, in source and / or binary forms;
//				provided that if you redistribute the Apple Software in its entirety and
//				without modifications, you must retain this notice and the following text
//				and disclaimers in all such redistributions of the Apple Software. Neither
//				the name, trademarks, service marks or logos of Apple Inc. may be used to
//				endorse or promote products derived from the Apple Software without specific
//				prior written permission from Apple.  Except as expressly stated in this
//				notice, no other rights or licenses, express or implied, are granted by
//				Apple herein, including but not limited to any patent rights that may be
//				infringed by your derivative works or by other works in which the Apple
//				Software may be incorporated.
//
//				The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
//				WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
//				WARRANTIES OF NON - INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
//				PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION
//				ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//
//				IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
//				CONSEQUENTIAL DAMAGES ( INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//				SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//				INTERRUPTION ) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
//				AND / OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER
//				UNDER THEORY OF CONTRACT, TORT ( INCLUDING NEGLIGENCE ), STRICT LIABILITY OR
//				OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Copyright ( C ) 2003-2007 Apple Inc. All Rights Reserved.
//

#import "GLString.h"

// The following is a NSBezierPath category to allow
// for rounded corners of the border

#pragma mark -
#pragma mark NSBezierPath Category

@implementation NSBezierPath (RoundRect)

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect cornerRadius:(float)radius {
    NSBezierPath *result = [NSBezierPath bezierPath];
    [result appendBezierPathWithRoundedRect:rect cornerRadius:radius];
    return result;
}

- (void)appendBezierPathWithRoundedRect:(NSRect)rect cornerRadius:(float)radius {
    if (!NSIsEmptyRect(rect)) {
		if (radius > 0.0) {
			// Clamp radius to be no larger than half the rect's width or height.
			float clampedRadius = MIN(radius, 0.5 * MIN(rect.size.width, rect.size.height));
			NSPoint topLeft = NSMakePoint(NSMinX(rect), NSMaxY(rect));
			NSPoint topRight = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
			NSPoint bottomRight = NSMakePoint(NSMaxX(rect), NSMinY(rect));
			[self moveToPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect))];
			[self appendBezierPathWithArcFromPoint:topLeft     toPoint:rect.origin radius:clampedRadius];
			[self appendBezierPathWithArcFromPoint:rect.origin toPoint:bottomRight radius:clampedRadius];
			[self appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight    radius:clampedRadius];
			[self appendBezierPathWithArcFromPoint:topRight    toPoint:topLeft     radius:clampedRadius];
			[self closePath];
		} else {
			// When radius == 0.0, this degenerates to the simple case of a plain rectangle.
			[self appendBezierPathWithRect:rect];
		}
    }
}
@end

#pragma mark -
#pragma mark GLString

// GLString follows

@implementation GLString

#pragma mark -
#pragma mark Deallocs

/*- (void) deleteTexture
{
	if (texName && cgl_ctx) {
		(*cgl_ctx->disp.delete_textures)(cgl_ctx->rend, 1, &texName);
		texName = 0; // ensure it is zeroed for failure cases
		cgl_ctx = 0;
	}
}*/

- (void) dealloc
{
	//[self deleteTexture];
}

#pragma mark -
#pragma mark Initializers



// designated initializer
- (id) initWithAttributedString:(NSAttributedString *)attributedString withTextColor:(NSColor *)text withBoxColor:(NSColor *)box withBorderColor:(NSColor *)border
{
	if (!(self = [super init])) return nil;
	cgl_ctx = NULL;
	texName = 0;
	texSize.width = 0.0f;
	texSize.height = 0.0f;
	string = attributedString;
	textColor = text;
	boxColor = box;
	borderColor = border;
	staticFrame = NO;
	antialias = YES;
	marginSize.width = 4.0f; // standard margins
	marginSize.height = 2.0f;
	cRadius = 4.0f;
    retinaScaleFactor = 1.0f;
    //isBPS16 = FALSE;
    //retinaScaleFactor = 1.0f;
    /*if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)]) {
        NSArray *screens = [NSScreen screens];
        for (int i = 0; i < [screens count]; i++) {
            float s = [[screens objectAtIndex:i] backingScaleFactor];
            if (s > retinaScaleFactor)
                retinaScaleFactor = s;
        }
    } //RetinaX 2016*/
	requiresUpdate = YES;
	// all other variables 0 or NULL
	return self;
}

- (id) initWithString:(NSString *)aString withAttributes:(NSDictionary *)attribs withTextColor:(NSColor *)text withBoxColor:(NSColor *)box withBorderColor:(NSColor *)border
{
	return [self initWithAttributedString:[[NSAttributedString alloc] initWithString:aString attributes:attribs] withTextColor:text withBoxColor:box withBorderColor:border];
}

// basic methods that pick up defaults
- (id) initWithAttributedString:(NSAttributedString *)attributedString;
{
	return [self initWithAttributedString:attributedString withTextColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f] withBorderColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]];
}

- (id) initWithString:(NSString *)aString withAttributes:(NSDictionary *)attribs
{
	return [self initWithAttributedString:[[NSAttributedString alloc] initWithString:aString attributes:attribs] withTextColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f] withBorderColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]];
}

/*-(NSSize) setFrameSize
{
    NSSize fs = [string size]; // current string size
    fs = [string size]; // current string size
    fs.width += marginSize.width * 2.0f; // add padding
    fs.height += marginSize.height * 2.0f;
    fs.width *= retinaScaleFactor;
    fs.height *= retinaScaleFactor;
    return fs;
}*/


- (NSSize) frameSize
{
    if ((NO == staticFrame) && (0.0f == frameSize.width) && (0.0f == frameSize.height)) { // find frame size if we have not already found it
        frameSize = [string size]; // current string size
        frameSize.width += marginSize.width * 2.0f; // add padding
        frameSize.height += marginSize.height * 2.0f;
        frameSizeScaled.x = frameSize.width;//2021 * retinaScaleFactor;
        frameSizeScaled.y = frameSize.height;//2021 * retinaScaleFactor;
        //NSLog(@">>retina %g ", retinaScaleFactor);
        //if (isBPS16) {
            frameSizeScaled.x *= retinaScaleFactor;
            frameSizeScaled.y *= retinaScaleFactor;
        //}
    }
    return frameSize;
}

//#define MY_GL_TEXTURE_2D //use "GL_TEXTURE_2D" or "GL_TEXTURE_RECTANGLE_EXT"

- (void) genTexture; // generates the texture without drawing texture to current context
{
	NSImage * image;
	NSBitmapImageRep * bitmap;
	if ((NO == staticFrame) && (0.0f == frameSize.width) && (0.0f == frameSize.height)) { // find frame size if we have not already found it
        [self frameSize];
	}
    image = [[NSImage alloc] initWithSize:frameSize];
    [image lockFocus];
	[[NSGraphicsContext currentContext] setShouldAntialias:antialias ];
    if ([boxColor alphaComponent]) { //background for text
		[boxColor set];
		NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(NSMakeRect (0.0f, 0.0f, frameSize.width, frameSize.height) , 0.5, 0.5)
														cornerRadius:cRadius];
		[path fill];
	}
	if ([borderColor alphaComponent]) {
		[borderColor set];
		NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(NSMakeRect (0.0f, 0.0f, frameSize.width, frameSize.height), 0.5, 0.5) 
														cornerRadius:cRadius];
		[path setLineWidth:1.0f];
		[path stroke];
	}
	[textColor set];
	[string drawAtPoint:NSMakePoint (marginSize.width, marginSize.height)]; // draw at offset position
    bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect (0.0f, 0.0f, frameSize.width, frameSize.height)];
    [image unlockFocus];
    texSize.width =  [bitmap pixelsWide];
	texSize.height = [bitmap pixelsHigh];
    int bps = (int)[bitmap bitsPerSample];
    //isBPS16 = (bps > 8);
    if (!(cgl_ctx = CGLGetCurrentContext ())) { // if we successfully retrieve a current context (required)
        NSLog (@"StringTexture -genTexture: Failure to get current OpenGL context\n");
        return;
    }
    
    //glPushAttrib(GL_TEXTURE_BIT);
    //Some monitors support more than RGBA32 (>8 bitsPerSample), in these cases we downsample to RGBA32 (8 bitsPerSample)
    // https://developer.apple.com/library/archive/samplecode/DeepImageDisplayWithOpenGL/Introduction/Intro.html#//apple_ref/doc/uid/TP40016622
    if (0 == texName) glGenTextures (1, &texName);
    #ifdef MY_GL_TEXTURE_2D
        // Set proper unpacking row length for bitmap.
        glPixelStorei(GL_UNPACK_ROW_LENGTH, (int)[bitmap pixelsWide]);
        // Set byte aligned unpacking (needed for 3 byte per pixel bitmaps).
        glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
        glEnable(GL_TEXTURE_2D);
        glBindTexture (GL_TEXTURE_2D, texName);
        int samplesPerPixel = (int)[bitmap samplesPerPixel];
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Nonplanar, RGB 24 bit bitmap, or RGBA 32 bit bitmap.
        if(![bitmap isPlanar] &&
            (samplesPerPixel == 3 || samplesPerPixel == 4))
        {
            if (bps == 8) {
            glTexImage2D(GL_TEXTURE_2D, 0,
                samplesPerPixel == 4 ? GL_RGBA8 : GL_RGB8,
                         (int)[bitmap pixelsWide],
                         (int)[bitmap pixelsHigh],
                0,
                samplesPerPixel == 4 ? GL_RGBA : GL_RGB,
                GL_UNSIGNED_BYTE,
                [bitmap bitmapData]);
            } else {
                NSBitmapImageRep *bitmap8 = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                        pixelsWide:[bitmap pixelsWide]
                                                        pixelsHigh:[bitmap pixelsHigh]
                                                     bitsPerSample:8
                                                   samplesPerPixel:4
                                                          hasAlpha:YES
                                                          isPlanar:NO
                                                    colorSpaceName:NSCalibratedRGBColorSpace
                                                       bytesPerRow:texSize.width*4
                                                      bitsPerPixel:0 ];
                // this new imagerep has (as default) a resolution of 72 dpi
                [NSGraphicsContext saveGraphicsState];
                NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap8];
                [NSGraphicsContext setCurrentContext:context];
                [bitmap drawInRect:NSMakeRect( 0, 0, [bitmap8 pixelsWide], [bitmap8 pixelsHigh] )];
                [NSGraphicsContext restoreGraphicsState];
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (int)[bitmap pixelsWide], (int)[bitmap pixelsHigh], 0, GL_RGBA, GL_UNSIGNED_BYTE, [bitmap8 bitmapData]);

            }
        }
        else
        {
            NSLog(@"GLString error");// Handle other bitmap formats.
        }
        glPixelStorei (GL_UNPACK_ALIGNMENT, 4);
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
        glDisable(GL_TEXTURE_2D);
        //glTexImage2D (target, level, internalformat, width, height, border, format, type, *pixels)
        //glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texSize.width, texSize.height, 0, [bitmap hasAlpha] ? GL_RGBA : GL_RGB, GL_UNSIGNED_BYTE, [bitmap bitmapData]);
        //}
    #else
        glBindTexture (GL_TEXTURE_RECTANGLE_EXT, texName);
        //if (NSEqualSizes(previousSize, texSize)) {
        //	glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT,0,0,0,texSize.width,texSize.height,[bitmap hasAlpha] ? //GL_RGBA : GL_RGB,GL_UNSIGNED_BYTE,[bitmap bitmapData]);
        //} else {
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
            //glTexImage2D (target, level, internalformat, width, height, border, format, type, *pixels)
        if (bps == 16) {
            NSBitmapImageRep *bitmap8 = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                    pixelsWide:[bitmap pixelsWide]
                                                    pixelsHigh:[bitmap pixelsHigh]
                                                 bitsPerSample:8
                                               samplesPerPixel:4
                                                      hasAlpha:YES
                                                      isPlanar:NO
                                                colorSpaceName:NSCalibratedRGBColorSpace
                                                   bytesPerRow:texSize.width*4
                                                  bitsPerPixel:0 ];
            // this new imagerep has (as default) a resolution of 72 dpi
            [NSGraphicsContext saveGraphicsState];
            NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap8];
            [NSGraphicsContext setCurrentContext:context];
            [bitmap drawInRect:NSMakeRect( 0, 0, [bitmap8 pixelsWide], [bitmap8 pixelsHigh] )];
            [NSGraphicsContext restoreGraphicsState];
            glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, texSize.width, texSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, [bitmap8 bitmapData]);
        } else
                glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, texSize.width, texSize.height, 0, [bitmap hasAlpha] ? GL_RGBA : GL_RGB, GL_UNSIGNED_BYTE, [bitmap bitmapData]);
        //}
    #endif
    //glPopAttrib();
	requiresUpdate = NO;
}

#pragma mark -
#pragma mark Accessors

- (GLuint) texName
{
	return texName;
}

- (NSSize) texSize
{
	return texSize;
}

- (void) setScale:(float)scale // set retina scaling
{
    retinaScaleFactor = MAX(1.0, scale);
    //NSLog(@"%g", retinaScaleFactor);
}

#pragma mark Text Color

- (void) setTextColor:(NSColor *)color // set default text color
{
	textColor = color;
	requiresUpdate = YES;
}

- (NSColor *) textColor
{
	return textColor;
}

#pragma mark Box Color

- (void) setBoxColor:(NSColor *)color // set default text color
{
	boxColor = color;
	requiresUpdate = YES;
}

- (NSColor *) boxColor
{
	return boxColor;
}

#pragma mark Border Color

- (void) setBorderColor:(NSColor *)color // set default text color
{
	borderColor = color;
	requiresUpdate = YES;
}

- (NSColor *) borderColor
{
	return borderColor;
}

#pragma mark Margin Size

// these will force the texture to be regenerated at the next draw
- (void) setMargins:(NSSize)size // set offset size and size to fit with offset
{
	marginSize = size;
	if (NO == staticFrame) { // ensure dynamic frame sizes will be recalculated
		frameSize.width = 0.0f;
		frameSize.height = 0.0f;
	}
	requiresUpdate = YES;
}

- (NSSize) marginSize
{
	return marginSize;
}

#pragma mark Antialiasing
- (BOOL) antialias
{
	return antialias;
}

- (void) setAntialias:(bool)request
{
	antialias = request;
	requiresUpdate = YES;
}


- (void) drawAtPoint:(NSPoint)point
{
    if (requiresUpdate)
        [self genTexture]; // ensure size is calculated for bounds
    if (!texName) return;
            //[self drawWithBounds:NSMakeRect (point.x, point.y, texSize.width, texSize.height)]; //RetinaX 2016
    [self drawWithBounds:NSMakeRect (point.x, point.y, texSize.width, texSize.height)];
        //[self drawWithBounds:NSMakeRect (point.x, point.y, frameSizeScaled.x, frameSizeScaled.y)];
        //[self drawWithBounds:NSMakeRect (point.x, point.y, texSize.width / retinaScaleFactor, texSize.height / retinaScaleFactor)];
    //NSLog(@" %gx%g %gx%g %g",texSize.width, texSize.height, frameSize.width,frameSize.height, retinaScaleFactor);
}

#pragma mark Frame



- (BOOL) staticFrame
{
	return staticFrame;
}

- (void) useStaticFrame:(NSSize)size // set static frame size and size to frame
{
	frameSize = size;
	staticFrame = YES;
	requiresUpdate = YES;
}

- (void) useDynamicFrame
{
	if (staticFrame) { // set to dynamic frame and set to regen texture
		staticFrame = NO;
		frameSize.width = 0.0f; // ensure frame sizes will be recalculated
		frameSize.height = 0.0f;
		requiresUpdate = YES;
	}
}

#pragma mark String

- (void) setString:(NSAttributedString *)attributedString // set string after initial creation
{
	string = attributedString;
	if (NO == staticFrame) { // ensure dynamic frame sizes will be recalculated
		frameSize.width = 0.0f;
		frameSize.height = 0.0f;
	}
	requiresUpdate = YES;
}

- (void) setString:(NSString *)aString withAttributes:(NSDictionary *)attribs; // set string after initial creation
{
	[self setString:[[NSAttributedString alloc] initWithString:aString attributes:attribs]];
}

#pragma mark -
#pragma mark Drawing

- (void) drawWithBounds:(NSRect)bounds
{
	if (requiresUpdate)
		[self genTexture];
    
    if (!texName) return;
    glPushAttrib(GL_ENABLE_BIT | GL_TEXTURE_BIT | GL_COLOR_BUFFER_BIT); // GL_COLOR_BUFFER_BIT for glBlendFunc, GL_ENABLE_BIT for glEnable / glDisable
    glUseProgram(0);
    glDisable (GL_DEPTH_TEST); // ensure text is not remove by depth buffer test.
    glEnable (GL_BLEND); // for text fading
    glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // ditto
    #ifdef MY_GL_TEXTURE_2D
            glEnable(GL_TEXTURE_2D);
            //glDisable(GL_TEXTURE_2D);
            glBindTexture(GL_TEXTURE_2D, texName);
            //glEnable (GL_TEXTURE_RECTANGLE_EXT);
            //glBindTexture (GL_TEXTURE_RECTANGLE_EXT, texName);
            glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
            glBegin(GL_QUADS);
            glTexCoord2f (0.0f, 0.0f); // draw upper left in world coordinates
            glVertex3f (bounds.origin.x, bounds.origin.y, 0.0);
            //glTexCoord2f (0.0f, texSize.height); // draw lower left in world coordinates
            glTexCoord2f (0.0f, 1.0f); // draw lower left in world coordinates
            glVertex3f (bounds.origin.x, bounds.origin.y - bounds.size.height, 0.0);
            //glTexCoord2f (texSize.width, texSize.height); // draw upper right in world coordinates
            glTexCoord2f (1.0f, 1.0f); // draw upper right in world coordinates
            glVertex3f (bounds.origin.x + bounds.size.width, bounds.origin.y - bounds.size.height, 0.0);
            //glTexCoord2f (texSize.width, 0.0f); // draw lower right in world coordinates
            glTexCoord2f (1.0, 0.0f); // draw lower right in world coordinates
            glVertex3f (bounds.origin.x + bounds.size.width, bounds.origin.y, 0.0);
            glEnd();
            glDisable(GL_TEXTURE_2D);
    #else
            glEnable (GL_TEXTURE_RECTANGLE_EXT);
            glBindTexture (GL_TEXTURE_RECTANGLE_EXT, texName);
            glBegin (GL_QUADS);
            glTexCoord2f (0.0f, 0.0f); // draw upper left in world coordinates
            glVertex2f (bounds.origin.x, bounds.origin.y);
            glTexCoord2f (0.0f, texSize.height); // draw lower left in world coordinates
            glVertex2f (bounds.origin.x, bounds.origin.y - bounds.size.height);
            glTexCoord2f (texSize.width, texSize.height); // draw upper right in world coordinates
            glVertex2f (bounds.origin.x + bounds.size.width, bounds.origin.y - bounds.size.height);
            glTexCoord2f (texSize.width, 0.0f); // draw lower right in world coordinates
            glVertex2f (bounds.origin.x + bounds.size.width, bounds.origin.y);
            glEnd ();

    #endif
    glDisable (GL_BLEND);
    glPopAttrib();
}

- (void) drawAboveLeftOfPoint:(NSPoint)point {
    [self frameSize];
    [self drawAtPoint: NSMakePoint(point.x-(frameSizeScaled.x), point.y+ (frameSizeScaled.y))];
}

- (float) drawLeftOfPoint:(NSPoint)point
{
    [self frameSize];
    [self drawAtPoint: NSMakePoint(point.x-(frameSizeScaled.x), point.y+ (0.5 * frameSizeScaled.y))];
    return frameSizeScaled.x;
}

- (void) drawRightOfPoint:(NSPoint)point
{
    [self frameSize];
    [self drawAtPoint: NSMakePoint(point.x, point.y+ (0.5 * frameSizeScaled.y))];
}

- (float) drawBelowPoint:(NSPoint)point
{
    [self frameSize];
    [self drawAtPoint: NSMakePoint(point.x-(0.5 *frameSizeScaled.x), point.y)];
    return frameSizeScaled.y;
}
@end
