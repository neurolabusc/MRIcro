#include "nii_io.h"
#include "nii_definetypes.h"
#include "nii_label.h"


//see /fsl/etc/luts/fsrandlut.txt 

uint32_t makeRGB (THIS_UINT8 r, THIS_UINT8 g, THIS_UINT8 b) {
    return (r << 0)+ (g << 8) + (b << 16) + (128 << 24);
}


uint32_t desaturateRGBA (uint32_t rgba, float frac) {
    THIS_UINT8 r,g,b,a;
    r = (rgba) & 255;
    g = (rgba >> 8) & 255;
    b = (rgba >> 16) & 255;
    a = (rgba >> 24) & 255;
    //convert RGB->YUV http://en.wikipedia.org/wiki/YUV
    float y = 0.299 * r + 0.587 * g + 0.114 * b;
    r = y * (1-frac) + r * frac;
    g = y * (1-frac) + g * frac;
    b = y * (1-frac) + b * frac;
    return (r << 0)+ (g << 8) + (b << 16) + (a << 24);
}

void createlutLabel(int colorscheme, uint32_t* lut, float saturationFrac) {
//int createlut(int colorscheme, tRGBAlut lut)
    //lut[0] = makeRGB(0,0,0);
    lut[0] = 0;
    lut[1] = makeRGB(71,46,154);
    lut[2] = makeRGB(33,78,43);
    lut[3] = makeRGB(192,199,10);
    lut[4] = makeRGB(32,79,207);
    lut[5] = makeRGB(195,89,204);
    lut[6] = makeRGB(208,41,164);
    lut[7] = makeRGB(173,208,231);
    lut[8] = makeRGB(233,135,136);
    lut[9] = makeRGB(202,20,58);
    lut[10] = makeRGB(25,154,239);
    lut[11] = makeRGB(210,35,30);
    lut[12] = makeRGB(145,21,147);
    lut[13] = makeRGB(89,43,230);
    lut[14] = makeRGB(87,230,101);
    lut[15] = makeRGB(245,113,111);
    lut[16] = makeRGB(246,191,150);
    lut[17] = makeRGB(38,147,35);
    lut[18] = makeRGB(3,208,128);
    lut[19] = makeRGB(50,74,114);//makeRGB(25,37,57); <- too dark
    lut[20] = makeRGB(57,28,252);
    lut[21] = makeRGB(167,27,79);
    lut[22] = makeRGB(245,86,173);
    lut[23] = makeRGB(86,203,120);
    lut[24] = makeRGB(227,25,25);
    lut[25] = makeRGB(208,209,126);
    lut[26] = makeRGB(81,148,81);
    lut[27] = makeRGB(64,187,85);
    lut[28] = makeRGB(90,139,8);
    lut[29] = makeRGB(199,111,7);
    lut[30] = makeRGB(140,48,122);
    lut[31] = makeRGB(48,102,237);
    lut[32] = makeRGB(212,76,190);
    lut[33] = makeRGB(180,110,152);
    lut[34] = makeRGB(70,106,246);
    lut[35] = makeRGB(120,130,182);
    lut[36] = makeRGB(9,37,130);
    lut[37] = makeRGB(192,160,219);
    lut[38] = makeRGB(245,34,67);
    lut[39] = makeRGB(177,222,76);
    lut[40] = makeRGB(65,90,167);
    lut[41] = makeRGB(157,165,178);
    lut[42] = makeRGB(9,245,235);
    lut[43] = makeRGB(193,222,250);
    lut[44] = makeRGB(100,102,28);
    lut[45] = makeRGB(181,47,61);
    lut[46] = makeRGB(125,19,186);
    lut[47] = makeRGB(145,130,250);
    lut[48] = makeRGB(62,4,199);
    lut[49] = makeRGB(8,232,67);
    lut[50] = makeRGB(108,137,58);
    lut[51] = makeRGB(36,211,50);
    lut[52] = makeRGB(140,240,86);
    lut[53] = makeRGB(237,11,182);
    lut[54] = makeRGB(242,140,108);
    lut[55] = makeRGB(248,21,77);
    lut[56] = makeRGB(161,42,89);
    lut[57] = makeRGB(189,22,112);
    lut[58] = makeRGB(41,241,59);
    lut[59] = makeRGB(114,61,125);
    lut[60] = makeRGB(65,99,226);
    lut[61] = makeRGB(121,115,50);
    lut[62] = makeRGB(97,199,205);
    lut[63] = makeRGB(50,166,227);
    lut[64] = makeRGB(238,114,125);
    lut[65] = makeRGB(149,190,128);
    lut[66] = makeRGB(44,204,104);
    lut[67] = makeRGB(214,60,27);
    lut[68] = makeRGB(124,233,59);
    lut[69] = makeRGB(167,66,66);
    lut[70] = makeRGB(40,115,53);
    lut[71] = makeRGB(167,230,133);
    lut[72] = makeRGB(127,125,159);
    lut[73] = makeRGB(178,103,203);
    lut[74] = makeRGB(231,203,97);
    lut[75] = makeRGB(30,125,125);
    lut[76] = makeRGB(173,13,139);
    lut[77] = makeRGB(244,176,159);
    lut[78] = makeRGB(193,94,158);
    lut[79] = makeRGB(203,131,7);
    lut[80] = makeRGB(204,39,215);
    lut[81] = makeRGB(238,198,47);
    lut[82] = makeRGB(139,167,140);
    lut[83] = makeRGB(135,124,226);
    lut[84] = makeRGB(71,67,223);
    lut[85] = makeRGB(234,175,231);
    lut[86] = makeRGB(234,254,44);
    lut[87] = makeRGB(217,1,110);
    lut[88] = makeRGB(66,15,184);
    lut[89] = makeRGB(14,198,61);
    lut[90] = makeRGB(129,62,233);
    lut[91] = makeRGB(19,237,47);
    lut[92] = makeRGB(97,159,67);
    lut[93] = makeRGB(165,31,148);
    lut[94] = makeRGB(112,218,22);
    lut[95] = makeRGB(244,58,120);
    lut[96] = makeRGB(35,244,173);
    lut[97] = makeRGB(73,47,156);
    lut[98] = makeRGB(192,61,117);
    lut[99] = makeRGB(12,67,181);
    lut[100] = makeRGB(149,94,94);
    for (int i = 1; i <= 100; i++)
        lut[i+100] = lut[i]; //fill 101..200
    for (int i = 1; i <= 55; i++)
        lut[i+200] = lut[i]; //fill 201..255
    if ((saturationFrac < 0) || (saturationFrac >= 1.0)) return;
    for (int i = 1; i <= 255; i++)
        lut[i] = desaturateRGBA(lut[i], saturationFrac);
}

void parseNiiLabels (NSString *rawStr, NSMutableArray *lblArray) {
    NSArray *lines = [rawStr componentsSeparatedByString:@"\n"];
    if ([lines count] < 1) return;
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    //first pass: find number of indices...
    int maxIndex = -1;
    for (NSString *line in lines) {
        NSArray *fields = [line componentsSeparatedByString:@"\t"];
        if ([fields count] > 1) { //need two fields: first is index number, second is label
            int index = [[f numberFromString: fields[0]] intValue];
            if (index > maxIndex) maxIndex = index;
                } //if line has at least two fields
    } //for each line
    //NSLog(@"%lu",maxIndex);
    
    if ((maxIndex < 1) || (maxIndex > 32767)) return;
    [lblArray removeAllObjects];
    for (int i = 0; i <= maxIndex; i++) //fill array in case of missing/misordered indices
        [lblArray addObject: @""];
    //second pass: fill the array
    for (NSString *line in lines) {
        NSArray *fields = [line componentsSeparatedByString:@"\t"];
        if ([fields count] > 1) { //need two fields: first is index number, second is label
            int index = [[f numberFromString: fields[0]] intValue];
            if ((index >=0) && (index <= maxIndex)) //add item removing leading/trailing white space
                lblArray[index] = [fields[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                } //if line has at least two fields
    } //for each line
}

void readLabels (NSString *fname, int offset, int sz, NSMutableArray *lblArray) {
//read tab-delimited text where first column is an integer index and second is the region name, one row per region
    NSData *hdrdata;
    if (([[fname pathExtension] rangeOfString:@"GZ" options:NSCaseInsensitiveSearch].location != NSNotFound) ||
        ([[fname pathExtension] rangeOfString:@"VOI" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
        NSData *data = [NSData dataWithContentsOfFile:fname];
        if (!data) return;
        hdrdata = ungz(data, offset+sz);
        hdrdata = [hdrdata subdataWithRange: NSMakeRange(offset, sz)] ;
    } else {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fname];
        [fileHandle seekToFileOffset: offset];
        hdrdata = [fileHandle readDataOfLength:sz];
        if (!hdrdata) return;
    }
    if (hdrdata.length < sz) return;
    NSString* hdrString = [[NSString alloc] initWithData:hdrdata encoding:NSASCIIStringEncoding];
    parseNiiLabels(hdrString, lblArray);
    /*if ([lblArray count] >0)
        for (int i = 0; i < [lblArray count]; i++)
            NSLog(@"%d = %@",i, lblArray[i]);*/
}
