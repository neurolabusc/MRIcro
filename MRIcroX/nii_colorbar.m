//
//  nii_colorbar.m
//  MRIpro
//
//  Created by Chris Rorden on 9/2/12.
//  Copyright 2012 U South Carolina. All rights reserved.
//

#import "nii_colorbar.h"
#include "nii_io.h"
#import "nii_definetypes.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>



int const kTextNoArrow = 0;
int const kVertTextLeft = 1;
int const kHorzTextBottom = 2;
int const kVertTextRight = 3;
int const kHorzTextTop = 4;
/*float printHt (float Sz)
{
    return Sz * 14;//14-pixel tall font
}
void nDec ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,0);
    glVertex2f(2,0);
    glVertex2f(0,2);
    glVertex2f(2,2);
    glEnd();
}

void n0 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(2,2);
    glVertex2f(0,12);
    glVertex2f(0,2);
    glVertex2f(2,12);
    glVertex2f(2,0);
    glVertex2f(2,2);
    glVertex2f(7,0);
    glVertex2f(7,2);
    glVertex2f(9,2);
    glVertex2f(7,12);
    glVertex2f(9,12);
    glVertex2f(7,14);
    glVertex2f(2,12);
    glVertex2f(2,14);
    glVertex2f(0,12);
    glEnd();
}


void n1 () //1
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(6,0);
    glVertex2f(0,0);
    glVertex2f(6,2);
    glVertex2f(0,2);
    glVertex2f(4,2);
    glVertex2f(2,2);
    glVertex2f(4,14);
    glVertex2f(2,14);
    glVertex2f(2,12);
    glVertex2f(0,13);
    glVertex2f(0,11);
    glEnd();
}

void n2 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(9,2);
    glVertex2f(9,0);
    glVertex2f(2,2);
    glVertex2f(0,0);
    glVertex2f(2,8);
    glVertex2f(0,6);
    glVertex2f(2,8);
    glVertex2f(9,8);
    glVertex2f(0,6);
    glVertex2f(7,6);
    glVertex2f(9,8);
    glVertex2f(7,14);
    glVertex2f(9,12);
    glVertex2f(2,14);
    glVertex2f(2,12);
    glVertex2f(0,12);
    glVertex2f(2,11);
    glVertex2f(0,11);
    glEnd();
}

void n3 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(2,2);
    glVertex2f(0,4);
    glVertex2f(0,2);
    glVertex2f(2,4);
    glVertex2f(2,0);
    glVertex2f(2,2);
    glVertex2f(7,0);
    glVertex2f(7,2);
    glVertex2f(9,2);
    glVertex2f(7,6);
    glVertex2f(9,6);
    glVertex2f(8,7);
    glVertex2f(2,6);
    glVertex2f(2,8);
    glVertex2f(7,8);
    glVertex2f(7,6);
    glVertex2f(9,8);
    glVertex2f(7,14);
    glVertex2f(9,12);
    glVertex2f(2,14);
    glVertex2f(2,12);
    glVertex2f(0,12);
    glVertex2f(2,11);
    glVertex2f(0,11);
    glEnd();
}

void n4 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,14);
    glVertex2f(2,14);
    glVertex2f(0,8);
    glVertex2f(2,8);
    glVertex2f(2,6);
    glVertex2f(9,8);
    glVertex2f(9,6);
    glVertex2f(9,14);
    glVertex2f(9,0);
    glVertex2f(7,14);
    glVertex2f(7,0);
    glEnd();
}

void n5 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(9,12);
    glVertex2f(9,14);
    glVertex2f(2,12);
    glVertex2f(0,14);
    glVertex2f(2,6);
    glVertex2f(0,8);
    glVertex2f(2,6);
    glVertex2f(9,6);
    glVertex2f(0,8);
    glVertex2f(7,8);
    glVertex2f(9,6);
    glVertex2f(7,0);
    glVertex2f(9,2);
    glVertex2f(2,0);
    glVertex2f(2,2);
    glVertex2f(0,2);
    glVertex2f(2,4);
    glVertex2f(0,4);
    glEnd();
}

void n6 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(7,12);
    glVertex2f(9,11);
    glVertex2f(9,12);
    glVertex2f(7,11);
    glVertex2f(7,14);
    glVertex2f(7,12);
    glVertex2f(2,14);
    glVertex2f(2,12);
    glVertex2f(0,12);
    glVertex2f(2,8);
    glVertex2f(0,8);
    glVertex2f(0,6);
    glVertex2f(7,8);
    glVertex2f(7,6);
    glVertex2f(2,6);
    glVertex2f(2,8);
    glVertex2f(0,6);
    glVertex2f(2,0);
    glVertex2f(0,2);
    glVertex2f(7,0);
    glVertex2f(7,2);
    glVertex2f(9,2);
    glVertex2f(7,6);
    glVertex2f(9,6);
    glVertex2f(7,8);
    glEnd();
}

void n7 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,11);
    glVertex2f(0,14);
    glVertex2f(2,11);
    glVertex2f(2,12);
    glVertex2f(0,14);
    glVertex2f(7,14);
    glVertex2f(2,12);
    glVertex2f(9,12);
    glVertex2f(7,12);
    glVertex2f(4,0);
    glVertex2f(2,0);
    glEnd();
}

void n8 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(2,2);
    glVertex2f(0,6);
    glVertex2f(0,2);
    glVertex2f(2,6);
    glVertex2f(2,0);
    glVertex2f(2,2);
    glVertex2f(7,0);
    glVertex2f(7,2);
    glVertex2f(9,2);
    glVertex2f(7,6);
    glVertex2f(9,6);
    glVertex2f(8,7);
    glVertex2f(2,6);
    glVertex2f(2,8);
    glVertex2f(7,8);
    glVertex2f(7,6);
    glVertex2f(9,8);
    glVertex2f(7,14);
    glVertex2f(9,12);
    glVertex2f(2,14);
    glVertex2f(2,12);
    glVertex2f(0,12);
    glVertex2f(2,8);
    glVertex2f(0,8);
    glVertex2f(1,7);
    glVertex2f(2,8);
    glVertex2f(2,6);
    glVertex2f(0,6);
    glEnd();
}

void nMinus ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,7);
    glVertex2f(0,9);
    glVertex2f(9,7);
    glVertex2f(9,9);
    glEnd();
}

void nSlash ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,0);
    glVertex2f(2,0);
    glVertex2f(7,12);
    glVertex2f(9,12);
    glEnd();
}

void nEqual ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,7);
    glVertex2f(0,9);
    glVertex2f(9,7);
    glVertex2f(9,9);
    glEnd();
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,2);
    glVertex2f(0,4);
    glVertex2f(9,2);
    glVertex2f(9,4);
    glEnd();
}

void nE ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(9,0);
    glVertex2f(0,0);
    glVertex2f(9,2);
    glVertex2f(0,2);
    glVertex2f(2,2);
    glVertex2f(0,11);
    glVertex2f(2,9);//7
    glVertex2f(9,11);
    glVertex2f(9,9);
    glVertex2f(9,5);
    glVertex2f(7,9);
    glVertex2f(7,5);
    glVertex2f(7,7);
    glVertex2f(2,5);
    glVertex2f(2,7);
    glEnd();
}

void nX ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,9);
    glVertex2f(2,9);
    glVertex2f(7,0);
    glVertex2f(9,0);
    glEnd();
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(0,0);
    glVertex2f(2,0);
    glVertex2f(7,9);
    glVertex2f(9,9);
    glEnd();
}

void n9 ()
{
    glBegin(GL_TRIANGLE_STRIP);
    glVertex2f(2,2);
    glVertex2f(0,4);
    glVertex2f(0,2);
    glVertex2f(2,4);
    glVertex2f(2,0);
    glVertex2f(2,2);
    glVertex2f(7,0);
    glVertex2f(7,2);
    glVertex2f(9,2);
    glVertex2f(7,6);
    glVertex2f(9,6);
    glVertex2f(9,8);
    glVertex2f(2,6);
    glVertex2f(2,8);
    glVertex2f(7,8);
    glVertex2f(7,6);
    glVertex2f(9,8);
    glVertex2f(7,14);
    glVertex2f(9,12);
    glVertex2f(2,14);
    glVertex2f(2,12);
    glVertex2f(0,12);
    glVertex2f(2,8);
    glVertex2f(0,8);
    glVertex2f(2,6);
    glEnd();
}
#define CHAR_TO_INT 48

int printWidInt (int c)
{
    switch(c) {
        case -4: return 4; break; // ","
        //case -3: return 10; break; // "-"
        case -2: return 4;  break; // "."
        case 1: return 8; break; // "1"
        default: return 10; break;
    }
}

float printWid (float Sz, char* NumStr)
{
    int i,c;
    float result = 0.0;
    int len = (int)strlen(NumStr);
    if (len < 1) return result;
    for (i = 0; i < len; i++) {
        c = NumStr[i] - CHAR_TO_INT;//ascii '0'..'9' = 48..58
        result = result + printWidInt(c);
    }
    //result = result -1;//last character does not have a gap
    result = result * Sz;
    return result;
}

void printXY (float X, float Y, float Sz, char* NumStr, float red, float green, float blue)
//draws numerical strong with 18-pixel tall characters. If Sz=2.0 then characters are 36-pixel tall
//Unless you use multisampling, fractional sizes will not look good...
{
    int i,c;
    int len = (int) strlen(NumStr);
    if (len < 1) return;
    glLoadIdentity();
    glTranslatef(X,Y,0.0); //pixelspace space
    glScalef(Sz ,Sz,0.0);
    glTranslatef(1,0,0.0);//put blank pixel space before character
    glColor4f (red, green, blue, 1.0);
    for (i = 0; i < len; i++) {
        c = NumStr[i] - CHAR_TO_INT;//ascii '0'..'9' = 48..58
        switch(c) {
            case -16:  break; // SPACE
            case -4: nDec(); break; // ","
            case -2: nDec(); break; // "."
            case -1: nSlash(); break; // "/"
            case 0: n0(); break;
            case 1: n1(); break;
            case 2: n2(); break;
            case 3: n3(); break;
            case 4: n4(); break;
            case 5: n5(); break;
            case 6: n6(); break;
            case 7: n7(); break;
            case 8: n8(); break;
            case 9: n9(); break;
            case 13: nEqual(); break;
            case 21: nE(); break;
            case 53: nE(); break;
            case 72: nX(); break;
            default: nMinus(); break;
        }
        glTranslatef(printWidInt(c),0,0);
    }
}

void textArrow (float X, float Y, float Sz, char* NumStr, int orient , NII_PREFS* prefs)
//orient code 1=left,2=top,3=right,4=bottom
{
    float lW,lH,lW2,lH2,T;
    int border = 2;
    int border2 = border * 2;
    int len = (int) strlen(NumStr);
    if (len < 1) return;
    glLoadIdentity();
    lH = printHt(Sz);
    lH2 = (lH/2.0);
    lW = printWid(Sz,NumStr);
    lW2 = (lW/2.0)+2.0;
    if (orient == -kHorzTextBottom) {
        //NSLog(@"x");
        Y = Y - lH - lH2- border2;
        orient = kHorzTextBottom;
    }
    //float red = 0; float green = 0.5; float blue = 0.8;
    glColor4f (prefs->colorBarBorderColor[0],prefs->colorBarBorderColor[1],prefs->colorBarBorderColor[2], 0.9);
    switch(orient) {
        case kTextNoArrow: { //1
            glBegin(GL_TRIANGLE_STRIP);
            glVertex2f(X,Y-lH2-border);
            glVertex2f(X+lW+border2,Y-lH2-border);
            glVertex2f(X,Y+lH2+border);
            glVertex2f(X+lW+border2,Y+lH2+border);
            glEnd();
            printXY (X+1,Y-lH2+1,Sz, NumStr,prefs->colorBarTextColor[0], prefs->colorBarTextColor[1], prefs->colorBarTextColor[2]);
            break;
        }
        case kVertTextLeft: { //1
            glBegin(GL_TRIANGLE_STRIP);
            glVertex2f(X-lH2-lW-border2,Y+lH2+border);
            glVertex2f(X-lH2-lW-border2,Y-lH2-border);
            glVertex2f(X-lH2,Y+lH2+border);
            glVertex2f(X-lH2,Y-lH2-border);
            glVertex2f(X,Y);
            glEnd();
            
            printXY (X-lW-lH2-1,Y-lH2,Sz, NumStr,prefs->colorBarTextColor[0], prefs->colorBarTextColor[1], prefs->colorBarTextColor[2]);
            break;
        }
        case kVertTextRight: { //3
            glBegin(GL_TRIANGLE_STRIP);
            glVertex2f(X+lH2+lW+border2,Y+lH2+border);
            glVertex2f(X+lH2+lW+border2,Y-lH2-border);
            glVertex2f(X+lH2,Y+lH2+border);
            glVertex2f(X+lH2,Y-lH2-border);
            glVertex2f(X,Y);
            glEnd();
            printXY (X+lH2+1,Y-lH2+1,Sz, NumStr,prefs->colorBarTextColor[0], prefs->colorBarTextColor[1], prefs->colorBarTextColor[2]);
            break;
        }
        case 4: { //bottom
            
            glBegin(GL_TRIANGLE_STRIP);
            glVertex2f(X-lW2,Y-lH-border2-lH2);
            glVertex2f(X-lW2,Y-lH2);
            glVertex2f(X+lW2,Y-lH-border2-lH2);
            glVertex2f(X+lW2,Y-lH2);
            glVertex2f(X-lW2,Y-lH2);
            glVertex2f(X,Y);
            glEnd();
            printXY (X-lW2+1,Y-lH-lH2,Sz, NumStr,prefs->colorBarTextColor[0], prefs->colorBarTextColor[1], prefs->colorBarTextColor[2]);
            break;
        }
        default: { //2 or 4 = kHorzTextBottom OR kHorzTextTop
            if (orient == kHorzTextTop)
                T = Y-lH-border2-lH2;
            else
                T = Y;
            glBegin(GL_TRIANGLE_STRIP);
            glVertex2f(X-lW2,T+lH+border2+lH2);
            glVertex2f(X-lW2,T+lH2);
            glVertex2f(X+lW2,T+lH+border2+lH2);
            glVertex2f(X+lW2,T+lH2);
            glVertex2f(X-lW2,T+lH2);
            glVertex2f(X,T);
            glEnd();
            printXY (X-lW2+1,T+lH2+1,Sz, NumStr,prefs->colorBarTextColor[0], prefs->colorBarTextColor[1], prefs->colorBarTextColor[2]);
        } //default
    }//case
}//proc textArrow 
 */

typedef struct  {
    float L,T,R,B;
} TUnitRect;

void sortSingle (float *lo, float *hi)
{
    if ( *lo > *hi) {
        float temp = *lo;
        *lo = *hi;
        *hi = temp;
    }
}

int colorBarPos(TUnitRect lU)
{
    int result = 0;
    sortSingle(&lU.L,&lU.R);
    sortSingle(&lU.B,&lU.T);
    if (fabs(lU.R-lU.L) > fabs(lU.B-lU.T)) { //wide bars
        if ((lU.B+lU.T) >1)
            result = kHorzTextTop;
        else
            result = kHorzTextBottom;
    } else { //high bars
        if ((lU.L+lU.R) >1)
            result = kVertTextLeft;
        else
            result = kVertTextRight;
    }
    return result;
}


float nicenum(float x, float round) {
    //see http://tog.acm.org/resources/GraphicsGems/gems/Label.c
    float nf;//nice, rounded fraction
    int expv = floor(log10(x));
    float f = x/pow(10.0, expv); //f = x/expt(10.0, expv); // between 1 and 10
    if (round) {
        if (f<1.5) nf = 1.;
        else if (f<3.) nf = 2.;
        else if (f<7.) nf = 5.;
        else nf = 10.;
    } else {
        if (f<=1.) nf = 1.;
        else if (f<=2.) nf = 2.;
        else if (f<=5.) nf = 5.;
        else nf = 10.;
    }
    return nf*pow(10.0, expv);
} //nicenum()

/*void drawColorBarText(float lMin, float lMax, TUnitRect lU, float lBorder, NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib)
{
#define NTICK 8			// desired number of tick marks
    if (lMin == lMax) return;
    int lOrient,lStepPosScrn;
    float lBarLength,lScrnL,lScrnT,lRange;
    sortSingle(&lU.L,&lU.R);
    sortSingle(&lU.B,&lU.T);
    lOrient = colorBarPos(lU);
    sortSingle(&lMin,&lMax);
    //next: compute increment
    lRange = nicenum(lMax-lMin, 0);
    float d = nicenum(lRange/(NTICK-1), 1);
    int nfrac = MAX(-floor(log10(d)), 0);	// # of fractional digits to show
    lRange = (lMax-lMin);
    float graphmin = floor(lMin/d)*d;
    float graphmax = ceil(lMax/d)*d;
    lScrnL = lU.L * prefs->scrnWid;
    if (lOrient ==  kVertTextRight)
        lScrnL = lU.R * prefs->scrnWid;
    lScrnT = (lU.B) * prefs->scrnHt;
    if (lOrient ==  kHorzTextTop)
        lScrnT = ((lU.B) * prefs->scrnHt);
    if (lOrient ==  kHorzTextBottom)
        lScrnT = ((lU.T) * prefs->scrnHt);
    if ((lOrient == kVertTextLeft) || (lOrient == kVertTextRight)) //vertical bars
        lBarLength = prefs->scrnHt * fabs(lU.B-lU.T);
    else
        lBarLength = prefs->scrnWid * fabs(lU.L-lU.R);
    //NSLog(@"%g..%g %g..%g %g", lMin, lMax, graphmin, graphmax, lRange);
    for (float x = graphmin; x < (graphmax+.5*d); x += d) {
        if ((x >= lMin) && (x <= lMax)) {
            lStepPosScrn = round( fabs(x - lMin)/lRange*lBarLength);
            NSString *formatString = [NSString stringWithFormat:@"%%.%df", nfrac];
            NSString * string = [NSString stringWithFormat:formatString, x];
            [glStrTex setString:string withAttributes:stanStrAttrib];
            if ((lOrient == kVertTextLeft) || (lOrient == kVertTextRight))
                [glStrTex drawLeftOfPoint:NSMakePoint (lScrnL-(lBorder* prefs->scrnWid),lScrnT+ lStepPosScrn)];
            else
                [glStrTex drawBelowPoint:NSMakePoint (lScrnL+ lStepPosScrn,lScrnT)];
        }
    } //for each marker
    glLoadIdentity();
}*/

void drawColorBarText(float lMin, float lMax, TUnitRect lU, float lBorder, NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib)
{
    #define NTICK 5			// desired number of tick marks
    int lOrient,lPower,lSteps,lStep,lDecimals,lStepPosScrn;
    float lBarLength,lScrnL,lScrnT,lStepPos,l1stStep,lRange,lStepSize;
    sortSingle(&lU.L,&lU.R);
    sortSingle(&lU.B,&lU.T);
    lOrient = colorBarPos(lU);
    sortSingle(&lMin,&lMax);
    //next: compute increment
    lRange = fabs(lMax - lMin);
    if (lRange < 0.000001) return;
    //lStepSize = (lRange / NTICK);
    lStepSize = nicenum(lRange, NTICK);
    lStepSize = (lStepSize / NTICK);
    lPower = 0;
    while (lStepSize >= 10) {
        lStepSize = lStepSize/10;
        lPower++;
    }
    while (lStepSize < 1) {
        lStepSize = lStepSize * 10;
        lPower--;
    }
    lStepSize = round(lStepSize) * pow(10,lPower);
    if (lPower < 0)
        lDecimals = abs(lPower);
    else
        lDecimals = 0;
    l1stStep = trunc((lMin)  / lStepSize)*lStepSize;
    lScrnL = lU.L * prefs->scrnWid;
    if (lOrient ==  kVertTextRight)
        lScrnL = lU.R * prefs->scrnWid;
    lScrnT = (lU.B) * prefs->scrnHt;
    if (lOrient ==  kHorzTextTop)
        lScrnT = ((lU.B) * prefs->scrnHt);
    if (lOrient ==  kHorzTextBottom)
        lScrnT = ((lU.T) * prefs->scrnHt);
    if (l1stStep < (lMin))
        l1stStep = l1stStep+lStepSize;
    //lSteps = trunc( abs((lMax+0.0001)-l1stStep) / lStepSize)+1;
    lSteps = trunc( (fabs(lMax-l1stStep)+0.0001) / lStepSize)+1;
    //NSLog(@"Colorbar %f..%f range %f stepsize %f steps %d",lMin,lMax, lRange, lStepSize, lSteps);
    if ((lOrient == kVertTextLeft) || (lOrient == kVertTextRight)) //vertical bars
        lBarLength = prefs->scrnHt * fabs(lU.B-lU.T);
    else
        lBarLength = prefs->scrnWid * fabs(lU.L-lU.R);
    for (lStep = 1; lStep <= lSteps; lStep++) {
        lStepPos = l1stStep+((lStep-1)*lStepSize);
        lStepPosScrn = round( fabs(lStepPos-lMin)/lRange*lBarLength);
            NSString *formatString = [NSString stringWithFormat:@"%%.%df", lDecimals];
            NSString * string = [NSString stringWithFormat:formatString, lStepPos];
            [glStrTex setString:string withAttributes:stanStrAttrib];
            if ((lOrient == kVertTextLeft) || (lOrient == kVertTextRight))
                [glStrTex drawLeftOfPoint:NSMakePoint (lScrnL-2-(lBorder* prefs->scrnWid),lScrnT+ lStepPosScrn)];
            else
                [glStrTex drawBelowPoint:NSMakePoint (lScrnL+ lStepPosScrn,lScrnT)];
    }
    glLoadIdentity();
}

void setRGBColor (uint32_t clr)
{
    glColor4ub((clr) & 0xff, (clr >> 8) & 0xff, (clr >> 16) & 0xff, (255) & 0xff);
}

void drawBorder(TUnitRect lU, NII_PREFS* prefs)
{
    sortSingle(&lU.L,&lU.R);
    sortSingle(&lU.B,&lU.T);
    lU.L = round(lU.L*prefs->scrnWid) - prefs->colorBarBorderPx;
    lU.R = round(lU.R*prefs->scrnWid) + prefs->colorBarBorderPx;
    lU.T = round(lU.T*prefs->scrnHt)  + prefs->colorBarBorderPx;
    lU.B = round(lU.B*prefs->scrnHt)  - prefs->colorBarBorderPx;
    glColor4f(prefs->colorBarBorderColor[0], prefs->colorBarBorderColor[1], prefs->colorBarBorderColor[2], 0.9);
    glBegin(GL_POLYGON);
    glVertex2f(lU.L,lU.B);
    glVertex2f(lU.L,lU.T);
    glVertex2f(lU.R,lU.T);
    glVertex2f(lU.R,lU.B);
    glEnd();//POLYGON
}

void drawCLUTx (TUnitRect lU, tRGBAlut lut, NII_PREFS* prefs)
{
    sortSingle(&lU.L,&lU.R);
    sortSingle(&lU.B,&lU.T);
    lU.L = round(lU.L*prefs->scrnWid);
    lU.R = round(lU.R*prefs->scrnWid);
    lU.T = round(lU.T*prefs->scrnHt);
    lU.B = round(lU.B*prefs->scrnHt);
    float lW = fabs(lU.L-lU.R);
    float lH = fabs(lU.T-lU.B);
    glDisable (GL_TEXTURE_3D);
    if (lW > lH) //wide colorbar
    {
        float lN = lU.L; //horizontal position
        float lFrac = lW/254;
        setRGBColor(lut[1]);
        for (int i = 2; i < 256; i++)
        {
            setRGBColor(lut[i]);
            glBegin(GL_POLYGON);
            glVertex2f(lN,lU.B);
            glVertex2f(lN,lU.T);
            lN = lN + lFrac;
            setRGBColor(lut[i]);
            glVertex2f(lN,lU.T);
            glVertex2f(lN,lU.B);
            glEnd();//POLYGON
        }
    } else { //tall colorbar
        //int lR = lU.L+lW; //right
        float lN = lU.B; //vertical position
        float lFrac = lH/254;
        setRGBColor(lut[1]);
        for (int i = 2; i < 256; i++)
        {
            glBegin(GL_POLYGON);
            glVertex2f(lU.L, lN);
            glVertex2f(lU.R, lN);
            lN = lN + lFrac;
            setRGBColor(lut[i]);
            glVertex2f(lU.R,lN);
            glVertex2f(lU.L,lN);
            glEnd();//POLYGON
        }
    } //if long or tall colorbar
}

TUnitRect uOffset (TUnitRect lU, float lX, float lY)
{
    lU.L = lU.L+lX;
    lU.T = lU.T+lY;
    lU.R = lU.R+lX;
    lU.B = lU.B+lY;
    return lU;
}

void drawCLUT(TUnitRect lU, NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib)
{
    TUnitRect lU2;
    float lBorder = 0;//xxx prefs->colorBarBorder;
    float lX,lY,lMin,lMax;
    int openOverlays = 0;
    for (int i = 0; i < MAX_OVERLAY; i++) 
        if (prefs->overlays[i].datatype != DT_NONE) openOverlays++;
    //Enter2D;
    glEnable (GL_BLEND);//allow border to be translucent
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    if (openOverlays < 1) {
        drawBorder(lU,prefs);
        drawCLUTx(lU,prefs->lut, prefs);
        //if (TRUE) //lPrefs.ColorbarText then
            drawColorBarText(prefs->viewMin,prefs->viewMax, lU,lBorder,prefs, glStrTex, stanStrAttrib);
        glDisable (GL_BLEND);
        return;
    }
    if (fabs(lU.R-lU.L) > fabs(lU.B-lU.T)) { //wide bars
        lX = 0;
        lY = fabs(lU.B-lU.T)+lBorder;
        if ((lU.B+lU.T) >1) 
            lY = -lY;
    } else { //high bars
        lX = fabs(lU.R-lU.L)+lBorder;
        lY = 0;
        if ((lU.L+lU.R) >1)
            lX = -lX;
    }
    //next - draw a border - do this once for all overlays, so
    //semi-transparent regions do not display regions of overlay
    lU2 = lU;
    if (openOverlays > 1) {
        for (int i = 2; i <= openOverlays; i++) { 
            if (lX < 0) 
                lU2.L = lU2.L + lX;
            else
                lU2.R = lU2.R + lX;
            if (lY > 0)
                lU2.T = lU2.T + lY;
            else
                lU2.B = lU2.B + lY;
        }
    }
    drawBorder(lU2, prefs);
    lU2 = lU;
    for (int i = 0; i < MAX_OVERLAY; i++) { 
        if (prefs->overlays[i].datatype != DT_NONE) {
            drawCLUTx(lU2,prefs->overlays[i].lut, prefs);
            lU2 = uOffset(lU2,lX,lY);
        }
    }

    //if (FALSE) return;
    lU2 = lU;
    for (int i = 0; i < MAX_OVERLAY; i++) { 
        if (prefs->overlays[i].datatype != DT_NONE) {
            lMin = prefs->overlays[i].viewMin;
            lMax = prefs->overlays[i].viewMax;
            sortSingle(&lMin,&lMax);
            drawColorBarText(lMin,lMax, lU2,lBorder,prefs, glStrTex, stanStrAttrib);
            lU2 = uOffset(lU2,lX,lY);
        }
    }
    glDisable (GL_BLEND);
}

void drawColorBarTex(NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib)
{
    TUnitRect lU;
    lU.L = prefs->colorBarPos[0];
    lU.T = prefs->colorBarPos[1];
    lU.R = prefs->colorBarPos[2];
    lU.B = prefs->colorBarPos[3];
    drawCLUT(lU,  prefs, glStrTex, stanStrAttrib);
}

void drawColorBar(NII_PREFS* prefs)
{
    TUnitRect lU;
    lU.L = prefs->colorBarPos[0];
    lU.T = prefs->colorBarPos[1];
    lU.R = prefs->colorBarPos[2];
    lU.B = prefs->colorBarPos[3];
    //drawCLUT(lU,  prefs, NULL, NULL);
}

void drawHistogram(NII_PREFS* prefs, int Lft, int Wid, int Ht)
{
    #define kBorder 32
    int WidB = Wid - kBorder - kBorder;
    int HtB = Ht - kBorder - kBorder;
    if ((HtB < 4) || (WidB < 4)) return;
    glColor4f(prefs->colorBarBorderColor[0], prefs->colorBarBorderColor[1], prefs->colorBarBorderColor[2], 0.9);
    float ymax = 0.0;
    for (int i = 0; i < MAX_HISTO_BINS; i++)
        if ((prefs->histo[i] > 0) && (prefs->histo[i] > ymax))
            ymax = prefs->histo[i];
    if (ymax <= 0) return;
    ymax = log(ymax);
    glBegin (GL_TRIANGLE_STRIP);
    for (int i = 0; i < MAX_HISTO_BINS; i++) {
        int x = round( (float)i / (float)MAX_HISTO_BINS * (float)WidB);
        float y = 0.0;
        if (prefs->histo[i] > 0)
            y = log(fabsf(prefs->histo[i]))/ymax * (float)HtB;
        if (y < 1) y = 1;
        glVertex3f (x+Lft+kBorder, y+kBorder, 0);
        glVertex3f (x+Lft+kBorder, 0+kBorder, 0);
    }
    glEnd();
    if ((prefs->viewMin >= prefs->fullMin) && (prefs->viewMin <= prefs->fullMax) && (prefs->viewMax >= prefs->fullMin) && (prefs->viewMax <= prefs->fullMax)) {
        glColor4f(1.0, 0.0, 0.0, 0.5);
        glLineWidth(1.0);
        float range = fabs( prefs->fullMax - prefs->fullMin);
        float xpos = ((prefs->viewMin - prefs->fullMin)/range) * WidB;
        glBegin(GL_LINES);
        glVertex3f(xpos+Lft+kBorder, kBorder-2, 0.0);
        glVertex3f(xpos+Lft+kBorder, kBorder+HtB, 0);
        glEnd();
        xpos = ((prefs->viewMax - prefs->fullMin)/range) * WidB;
        glBegin(GL_LINES);
        glVertex3f(xpos+Lft+kBorder, kBorder-2, 0.0);
        glVertex3f(xpos+Lft+kBorder, kBorder+HtB, 0);
        glEnd();
    }
}

/*void drawVolumeLabel(NII_PREFS* prefs)
{
    float fontSize = 1;
    int left = 0;
    int top = round(printHt(fontSize) / 2.0f) +1;  //text vertically centered, so half text height
    int vol = prefs->currentVolume;
    int nvol = prefs->numVolumes;
    char lS[255] = { '\0' };
    if (prefs->numVolumes < 2)
        sprintf(lS, "%gx%gx%g=%g",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), defuzzz(prefs->mouseIntensity ) );
    else
        sprintf(lS, "%gx%gx%g=%g %d/%d",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), defuzzz(prefs->  mouseIntensity ),  vol, nvol);
    glEnable (GL_BLEND);//allow border to be translucent
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    textArrow (left, top, fontSize, lS, kTextNoArrow, prefs);
    glLoadIdentity();
    glDisable (GL_BLEND);
}

float  defuzzz(float x)
{
    if (fabs(x) < 1.0E-6) return 0.0;
    return x;
}

void drawVolumeLabelTex(NII_PREFS* prefs, GLString * glStrTex, NSMutableDictionary * stanStrAttrib)
{
    NSString * string;
    if (prefs->numVolumes < 2)
        string = [NSString stringWithFormat:@"%gx%gx%g=%g",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), defuzzz(prefs->mouseIntensity)];
    else
        string = [NSString stringWithFormat:@"%gx%gx%g=%g %d/%d",  defuzzz(prefs->mm[1]), defuzzz(prefs->mm[2]), defuzzz(prefs->mm[3]), defuzzz(prefs->  mouseIntensity ),  prefs->currentVolume, prefs->numVolumes];
    [glStrTex setString:string withAttributes:stanStrAttrib];
    [glStrTex drawAtPoint:NSMakePoint (6, 24)];
}*/





