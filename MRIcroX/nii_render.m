//
//  nii_render.m
//  MRIpro
//
//  Created by Chris Rorden on 9/2/12.
//  Copyright 2012 U South Carolina. All rights reserved.
//

#import "nii_render.h"
#include "nii_io.h"
#include "nii_definetypes.h"
#import <OpenGL/glu.h>
#import <Foundation/Foundation.h>

GLuint initVertFrag(const char *vert, const char *frag)
{
#ifdef MY_DEBUG //from nii_io.h
    printf("creating new shader\n");
#endif
    GLuint fr = glCreateShader(GL_FRAGMENT_SHADER);
    if (!fr)
        return 0;
    glShaderSource(fr, 1, &frag, NULL);
    glCompileShader(fr);
    GLint status = 0;
    glGetShaderiv(fr, GL_COMPILE_STATUS, &status);
    if(!status) { //report compiling errors.
        char str[4096];
        glGetShaderInfoLog(fr, sizeof(str), NULL, str);
        NSLog(@"GLSL Fragment shader compile error.");
        NSLog(@"%s", str);
        glDeleteShader(fr);
        return 0;
    }
    GLuint ProgramID = glCreateProgram();
    glAttachShader(ProgramID, fr);
    GLuint vt = 0;
    if (strlen(vert) > 0) {
        vt = glCreateShader(GL_VERTEX_SHADER);
        if (!vt)
            return 0;
        glShaderSource(vt, 1, &vert, NULL);
        glCompileShader(vt);
        #ifdef MY_DEBUG //from nii_io.h
        glGetShaderiv(vt, GL_INFO_LOG_LENGTH, &status); //show ANY information
        if (status > 1)
        {
            char str[4096];
            glGetShaderInfoLog(vt, sizeof(str), NULL, str);
            NSLog(@"GLSL Vertex shader information.");
            NSLog(@"%s", str);
        }
        #endif
        glGetShaderiv(vt, GL_COMPILE_STATUS, &status);
        if(!status) { //report compiling errors.
            char str[4096];
            glGetShaderInfoLog(vt, sizeof(str), NULL, str);
            NSLog(@"GLSL Vertex shader compile error.");
            NSLog(@"%s", str);
            glDeleteShader(vt);
            return 0;
        }
        glAttachShader(ProgramID, vt);
    }
    glLinkProgram(ProgramID);
    glUseProgram(ProgramID);
    glDetachShader(ProgramID, fr);
    glDeleteShader(fr);
    if (strlen(vert) > 0) {
        glDetachShader(ProgramID, vt);
        glDeleteShader(vt);
    }
    glUseProgram(0);
    return ProgramID;
}

#ifdef MY_USE_GLSL_FOR_GRADIENTS

//this GLSL shader will not change our data: ensure all is working correctly
/*const char *kNothingShaderFrag =
 "uniform float coordZ, dX, dY, dZ;" \
 "uniform sampler3D intensityVol;" \
 "void main(void) {\n " \
 "  vec3 vx = vec3(gl_TexCoord[0].xy, coordZ);\n"\
 "  gl_FragColor = texture3D(intensityVol,vx);"\
 "}";*/

//this GLSL shader emulates a mild blur with a kernel [1,2,1;2,4,2,1,2,1][2,4,2;4,8,4;2,4,2][1,2,1;2,4,2,1,2,1]
// by using hardware
/*const char *kBlurShaderFrag =
"uniform float coordZ, dX, dY, dZ;" \
"uniform sampler3D intensityVol;" \
"void main(void) {\n " \
"  vec3 vx = vec3(gl_TexCoord[0].xy, coordZ);\n"\
"  vec4 samp = texture3D(intensityVol,vx+vec3(+dX,+dY,+dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(+dX,+dY,-dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(+dX,-dY,+dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(+dX,-dY,-dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,+dY,+dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,+dY,-dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,-dY,+dZ));\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,-dY,-dZ));\n"\
"  gl_FragColor = samp*0.125;"\
"}";*/
const char *kBlurShaderFrag =
"uniform float coordZ, dX, dY, dZ;" \
"uniform sampler3D intensityVol;" \
"void main(void) {\n " \
"  vec3 vx = vec3(gl_TexCoord[0].xy, coordZ);\n"\
"  float samp = texture3D(intensityVol,vx+vec3(+dX,+dY,+dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(+dX,+dY,-dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(+dX,-dY,+dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(+dX,-dY,-dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,+dY,+dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,+dY,-dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,-dY,+dZ)).a;\n"\
"      samp += texture3D(intensityVol,vx+vec3(-dX,-dY,-dZ)).a;\n"\
"  gl_FragColor.a = samp* 0.125;"\
"}";

const char *kSobelShaderFrag =
"uniform float coordZ, dX, dY, dZ;" \
"uniform sampler3D intensityVol;" \
"void main(void) {\n " \
"  vec3 vx = vec3(gl_TexCoord[0].xy, coordZ);\n"\
"  float TAR = texture3D(intensityVol,vx+vec3(+dX,+dY,+dZ)).a;\n"\
"  float TAL = texture3D(intensityVol,vx+vec3(+dX,+dY,-dZ)).a;\n"\
"  float TPR = texture3D(intensityVol,vx+vec3(+dX,-dY,+dZ)).a;\n"\
"  float TPL = texture3D(intensityVol,vx+vec3(+dX,-dY,-dZ)).a;\n"\
"  float BAR = texture3D(intensityVol,vx+vec3(-dX,+dY,+dZ)).a;\n"\
"  float BAL = texture3D(intensityVol,vx+vec3(-dX,+dY,-dZ)).a;\n"\
"  float BPR = texture3D(intensityVol,vx+vec3(-dX,-dY,+dZ)).a;\n"\
"  float BPL = texture3D(intensityVol,vx+vec3(-dX,-dY,-dZ)).a;\n"\
"  vec4 gradientSample;\n"\
"  gradientSample.r =   BAR+BAL+BPR+BPL -TAR-TAL-TPR-TPL;\n"\
"  gradientSample.g =  TPR+TPL+BPR+BPL -TAR-TAL-BAR-BAL;\n"\
"  gradientSample.b =  TAL+TPL+BAL+BPL -TAR-TPR-BAR-BPR;\n"\
"  gradientSample.a = (abs(gradientSample.r)+abs(gradientSample.g)+abs(gradientSample.b))*0.5;\n"\
"  gradientSample.rgb = normalize(gradientSample.rgb);\n"\
"  gradientSample.rgb =  (gradientSample.rgb * 0.5)+0.5;\n"\
"  gl_FragColor = gradientSample;\n"\
"}";


/*
 const char *kSobelShaderFrag =
 "uniform float coordZ, dX, dY, dZ;" \
 "uniform sampler3D intensityVol;" \
 "void main(void) {\n " \
 "  vec3 vx = vec3(gl_TexCoord[0].xy, coordZ);\n"\
 "  float TAR = texture3D(intensityVol,vx+vec3(+dX,+dY,+dZ)).a;\n"\
 "  float TAL = texture3D(intensityVol,vx+vec3(+dX,+dY,-dZ)).a;\n"\
 "  float TPR = texture3D(intensityVol,vx+vec3(+dX,-dY,+dZ)).a;\n"\
 "  float TPL = texture3D(intensityVol,vx+vec3(+dX,-dY,-dZ)).a;\n"\
 "  float BAR = texture3D(intensityVol,vx+vec3(-dX,+dY,+dZ)).a;\n"\
 "  float BAL = texture3D(intensityVol,vx+vec3(-dX,+dY,-dZ)).a;\n"\
 "  float BPR = texture3D(intensityVol,vx+vec3(-dX,-dY,+dZ)).a;\n"\
 "  float BPL = texture3D(intensityVol,vx+vec3(-dX,-dY,-dZ)).a;\n"\
 "  vec4 gradientSample = vec4 (0.0, 0.0, 0.0, 0.0);\n"\
 "  gradientSample.r =   BAR+BAL+BPR+BPL -TAR-TAL-TPR-TPL;\n"\
 "  gradientSample.g =  TPR+TPL+BPR+BPL -TAR-TAL-BAR-BAL;\n"\
 "  gradientSample.b =  TAL+TPL+BAL+BPL -TAR-TPR-BAR-BPR;\n"\
 "  gradientSample.a = (abs(gradientSample.r)+abs(gradientSample.g)+abs(gradientSample.b))*0.5;\n"\
 "  gradientSample.rgb = normalize(gradientSample.rgb);\n"\
 "  gradientSample.rgb =  (gradientSample.rgb * 0.5)+0.5;\n"\
 "  gl_FragColor = gradientSample;\n"\
 "}";*/

GLuint bindBlankGL(NII_PREFS* prefs) { //creates an empty texture in VRAM without requiring memory copy from RAM
    //later run glDeleteTextures(1,&oldHandle);
    GLuint handle;
    glGenTextures(1, &handle);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glBindTexture(GL_TEXTURE_3D, handle);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); //, GL_CLAMP_TO_BORDER) will wrap
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3], 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    //NSLog(@"--- %d %d %d\n", prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3]);
    GLenum error = glGetError();
    if (error) NSLog(@"bindBlankGL memory exhausted %d\n", error);
    return handle;
}

void performBlurSobel(NII_PREFS* prefs, bool isOverlay) {
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,prefs->frameBuffer);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);// <- REQUIRED
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, prefs->renderWid, prefs->renderHt, 0, GL_RGBA, GL_FLOAT, nil);
    glViewport(0, 0, prefs->voxelDim[1], prefs->voxelDim[2]);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluOrtho2D(0, 1, 0, 1);
    glMatrixMode(GL_MODELVIEW);
    glDisable(GL_TEXTURE_2D);
    //STEP 1: run smooth program gradientTexture -> tempTex3D
    GLuint tempTex3D = bindBlankGL(prefs);
    glUseProgram(prefs->glslprogramIntBlur);
    glActiveTexture( GL_TEXTURE1);
    if (isOverlay)
        glBindTexture(GL_TEXTURE_3D, prefs->gradientOverlay3D);//input texture is overlay
    else
        glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);//input texture is background
    //NSLog(@"%d-->%d", prefs->gradientTexture3D,prefs->gradientOverlay3D);
    //NSLog(@"%d-->%d +%d", prefs->gradientTexture3D, prefs->gradientOverlay3D, isOverlay);
    glUniform1i(glGetUniformLocation(prefs->glslprogramIntBlur, "intensityVol"), 1);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "dX"), 0.5/(float)prefs->voxelDim[1] ); //0.5 for smooth - center contributes
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "dY"), 0.5/(float)prefs->voxelDim[2]);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "dZ"), 0.5/(float)prefs->voxelDim[3]);
    int dim3 = prefs->voxelDim[3];
    for (int i = 0; i < dim3; i++) {
        float coordZ = (float)1/(float)dim3 * ((float)i + 0.5);
        glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "coordZ"), coordZ);
        glFramebufferTexture3D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_3D, tempTex3D, 0, i);//output texture
        //glClear(GL_DEPTH_BUFFER_BIT);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0);
        glVertex2f(0, 0);
        glTexCoord2f(1.0, 0);
        glVertex2f(1.0, 0.0);
        glTexCoord2f(1.0, 1.0);
        glVertex2f(1.0, 1.0);
        glTexCoord2f(0, 1.0);
        glVertex2f(0.0, 1.0);
        glEnd();
        //}
    } //for each slice
    glUseProgram(0);
    //STEP 2: run sobel program gradientTexture -> tempTex3D
    // glUseProgramObjectARB(prefs->glslprogramIntSobel);
    glUseProgram(prefs->glslprogramIntSobel);
    glActiveTexture( GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_3D, tempTex3D);//input texture
    //glEnable(GL_TEXTURE_2D);
    //glDisable(GL_TEXTURE_2D);
    //glUniform1i(glGetUniformLocation(prefs->glslprogramInt, name), value);
    glUniform1i(glGetUniformLocation(prefs->glslprogramIntSobel, "intensityVol"), 1);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel, "dX"), 1.2/(float)prefs->voxelDim[1] ); //1.0 for SOBEL - center excluded
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel, "dY"), 1.2/(float)prefs->voxelDim[2]);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel, "dZ"), 1.2/(float)prefs->voxelDim[3]);
    for (int i = 0; i < dim3; i++) {
        float coordZ = (float)1/(float)dim3 * ((float)i + 0.5);
        glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel ,"coordZ"), coordZ);
        if (isOverlay)
            glFramebufferTexture3D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_3D, prefs->gradientOverlay3D, 0, i);//output texture is overlay
        else
            glFramebufferTexture3D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_3D, prefs->gradientTexture3D, 0, i);//output texture is background
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0);
        glVertex2f(0, 0);
        glTexCoord2f(1.0, 0);
        glVertex2f(1.0, 0.0);
        glTexCoord2f(1.0, 1.0);
        glVertex2f(1.0, 1.0);
        glTexCoord2f(0, 1.0);
        glVertex2f(0.0, 1.0);
        glEnd();
    } //for each slice
    glUseProgram(0);
    //clean up:
    glDeleteTextures(1,&tempTex3D);
    glFlush();
    glFinish();//<-wait for jobs to finish: we need these to draw 
}

void doShaderBlurSobel (NII_PREFS* prefs){
    const char *vert_empty ="";
    if (!prefs->advancedRender) return; //gradients only used by advanced rendering
    if ((!prefs->glslUpdateGradientsBG) &&  (!prefs->glslUpdateGradientsOverlay)) return;
    if (prefs->glslprogramIntBlur == 0)
        prefs->glslprogramIntBlur=  initVertFrag(vert_empty, kBlurShaderFrag);
    if (prefs->glslprogramIntSobel == 0)
        prefs->glslprogramIntSobel=  initVertFrag(vert_empty, kSobelShaderFrag);
//#define MY_DEBUG
#ifdef MY_DEBUG
    NSDate *methodStart = [NSDate date];
#endif
    if (prefs->glslUpdateGradientsOverlay)
        performBlurSobel(prefs, true); //performBlur(prefs);
    if (prefs->glslUpdateGradientsBG)
        performBlurSobel(prefs, false); //performBlur(prefs);

#ifdef MY_DEBUG
    NSLog(@"glsl = %1f", (1000.0*[[NSDate date] timeIntervalSinceDate:methodStart]));
#endif
    prefs->glslUpdateGradientsBG = false;
    prefs->glslUpdateGradientsOverlay = false;
}
#else //MY_USE_GLSL_FOR_GRADIENTS
void doShaderBlurSobel (NII_PREFS* prefs){
    //done by CPU
}
#endif

GLuint bindSubGL(NII_PREFS* prefs, uint32_t *data, GLuint oldHandle) {
    GLuint handle;
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    if (oldHandle != 0) glDeleteTextures(1,&oldHandle);
    glGenTextures(1, &handle);
    glBindTexture(GL_TEXTURE_3D, handle);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); //, GL_CLAMP_TO_BORDER) will wrap
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3], 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    return handle;
}

void disableRenderBuffers ()
{
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

void drawVertex(float x, float y, float z)
{
    glColor3f(x,y,z);
    glMultiTexCoord3f(GL_TEXTURE1, x, y, z);
    glVertex3f(x,y,z);
}

void drawQuads( float x, float y, float z)
//x,y,z typically 1.
// useful for clipping
// If x=0.5 then only left side of texture drawn
// If y=0.5 then only posterior side of texture drawn
// If z=0.5 then only inferior side of texture drawn
{
    glBegin(GL_QUADS);
    //* Back side
    glNormal3f(0.0, 0.0, -1.0);
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(0.0, y, 0.0);
    drawVertex(x, y, 0.0);
    drawVertex(x, 0.0, 0.0);
    //* Front side
    glNormal3f(0.0, 0.0, 1.0);
    drawVertex(0.0, 0.0, z);
    drawVertex(x, 0.0, z);
    drawVertex(x, y, z);
    drawVertex(0.0, y, z);
    //* Top side
    glNormal3f(0.0, 1.0, 0.0);
    drawVertex(0.0, y, 0.0);
    drawVertex(0.0, y, z);
    drawVertex(x, y, z);
    drawVertex(x, y, 0.0);
    //* Bottom side
    glNormal3f(0.0, -1.0, 0.0);
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(x, 0.0, 0.0);
    drawVertex(x, 0.0, z);
    drawVertex(0.0, 0.0, z);
    //* Left side
    glNormal3f(-1.0, 0.0, 0.0);
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(0.0, 0.0, z);
    drawVertex(0.0, y, z);
    drawVertex(0.0, y, 0.0);
    //* Right side
    glNormal3f(1.0, 0.0, 0.0);
    drawVertex(x, 0.0, 0.0);
    drawVertex(x, y, 0.0);
    drawVertex(x, y, z);
    drawVertex(x, 0.0, z);
    glEnd();
}

void uniform1i(const char* name, int value, NII_PREFS* prefs )
{
    glUniform1i(glGetUniformLocation(prefs->glslprogramInt, name), value);
}

void uniform1f(const char* name, float value, NII_PREFS* prefs )
{
    glUniform1f(glGetUniformLocation(prefs->glslprogramInt, name), value);
}

void uniform3fv(const char* name, float v1, float v2, float v3, NII_PREFS* prefs)
{
    glUniform3f(glGetUniformLocation(prefs->glslprogramInt, name), v1, v2, v3);
}

const char *vert_default =
"void main() {\n"
" gl_TexCoord[1] = gl_MultiTexCoord1;\n"
" gl_Position = ftransform();\n"
"}";

//http://kbi.theelude.eu/?p=101
//#pragma optionNV(unroll count=#)
//#pragma optionNV(unroll none)
const char *frag_advanced =
"uniform int overlays;\n"
"uniform float clipPlaneDepth,  stepSize, sliceSize, viewWidth, viewHeight;\n"
"uniform vec3 clearColor,lightPosition, clipPlane;\n"
"uniform sampler3D intensityVol, gradientVol, overlayVol, overlayGradientVol;\n"
"uniform sampler2D backFace;\n"
"void main() {\n"
" float specular = 0.5;\n"
" float diffuse = 0.2;\n"
" float shininess= 20.0;\n"
" float backAlpha = 0.95;\n"
" float overShade = 0.3;\n"
" float overAlpha = 1.6;\n"
" float overDistance = 0.3;\n"
" float edgeThresh = 0.01;\n"
" float edgeExp = 0.5;\n"
" bool overClip = false;\n"
" float overAlphaFrac = overAlpha;\n"
" if (overAlphaFrac > 1.0) overAlphaFrac = 1.0;\n"
" float overLight = 0.5;\n"
" float diffuseDiv = diffuse / 4.0;\n"
" vec2 pixelCoord = gl_FragCoord.st;\n"
" pixelCoord.x /= viewWidth;\n"
" pixelCoord.y /= viewHeight; \n"
" vec3 start = gl_TexCoord[1].xyz;\n"
" vec3 backPosition = texture2D(backFace,pixelCoord).xyz;\n"
" vec3 dir = backPosition - start;\n"
" float len = length(dir);\n"
" dir = normalize(dir);\n"
" float clipStart = 0.0;\n"
" float stepSizex2 = -1.0;\n"
" float clipEnd = len;\n"
" if (clipPlaneDepth > -0.5) {\n"
"  gl_FragColor.rgb = vec3(1.0,0.0,0.0);\n"
"  bool frontface = (dot(dir , clipPlane) > 0.0);\n"
"  float disBackFace = 0.0;\n"
"  float dis = dot(dir,clipPlane);\n"
"  if (dis != 0.0  )  disBackFace = (-(clipPlaneDepth-1.0) - dot(clipPlane, start.xyz-0.5)) / dis;\n"
"  if (dis != 0.0  )  dis = (-clipPlaneDepth - dot(clipPlane, start.xyz-0.5)) / dis;\n"
"  if (overClip) {\n"
"   if (!frontface) {\n"
"    float swap = dis;\n"
"    dis = disBackFace;\n"
"    disBackFace = swap;\n"
"   }\n"
"   if (dis >= len) len = 0.0;\n"
"   backPosition =  start + dir * disBackFace;\n"
"   if (dis < len) {\n"
"    if (dis > 0.0)\n"
"    start = start + dir * dis;\n"
"    dir = backPosition - start;\n"
"    len = length(dir);\n"
"    dir = normalize(dir);  \n"
"   } else\n"
"    len = 0.0;\n"
"  } else {\n"
"   if (frontface) {\n"
"    clipStart = dis;\n"
"    clipEnd = disBackFace;\n"
"   }\n"
"   if (!frontface) {\n"
"    clipEnd = dis;\n"
"    clipStart = disBackFace;\n"
"   }\n"
"   stepSizex2 = clipStart + ( sliceSize * 3.0);\n"
"  }\n"
" }  \n"
" vec3 deltaDir = dir * stepSize;\n"
" vec4 overAcc = vec4(0.0,0.0,0.0,0.0);\n"
" vec4 ocolorSample,colorSample,gradientSample,colAcc = vec4(0.0,0.0,0.0,0.0);\n"
" float lengthAcc = 0.0;\n"
" float overAtten = 0.0;\n"
" int overDepth = 0;\n"
" int loops = int(len / stepSize);\n"
" int backDepthEnd, backDepthStart = loops;\n"
" vec3 samplePos = start.xyz + deltaDir* (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453));\n"
" vec4 prevNorm = vec4(0.0,0.0,0.0,0.0);\n"
" vec4 oprevNorm = vec4(0.0,0.0,0.0,0.0);\n"
" float opacityCorrection = stepSize/sliceSize;\n"
" vec3 lightDirHeadOn =  normalize(gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,0.0)).xyz ;\n"
" //float stepSizex2 = clipStart + ( sliceSize * 3.0);\n"
" for(int i = 0; i < loops; i++) {\n"
"  if ((lengthAcc <= clipStart) || (lengthAcc > clipEnd)) {\n"
"   colorSample.a = 0.0;\n"
"  } else {\n"
"   colorSample = texture3D(intensityVol,samplePos);\n"
"   if ((lengthAcc <= stepSizex2) && (colorSample.a > 0.01) )  colorSample.a = sqrt(colorSample.a);\n"
"   colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"   if ((colorSample.a > 0.01) && (lengthAcc > stepSizex2)  ) { \n"
"    if (backDepthStart == loops) backDepthStart = i;\n"
"    backDepthEnd = i; \n"
"    gradientSample= texture3D(gradientVol,samplePos);\n"
"    gradientSample.rgb = normalize(gradientSample.rgb*2.0 - 1.0);\n"
"    if (gradientSample.a < prevNorm.a)\n"
"     gradientSample.rgb = prevNorm.rgb;\n"
"    prevNorm = gradientSample;\n"
"    float lightNormDot = dot(gradientSample.rgb, lightDirHeadOn);\n"
"    float edgeVal = pow(1.0-abs(lightNormDot),edgeExp) * pow(gradientSample.a,0.3);\n"
"    if (edgeVal >= edgeThresh) \n"
"     colorSample.rgb = mix(colorSample.rgb, vec3(0.0,0.0,0.0), pow((edgeVal-edgeThresh)/(1.0-edgeThresh),4.0));\n"
"    lightNormDot = dot(gradientSample.rgb, lightPosition);\n"
"    if (lightNormDot > 0.0) {\n"
"     colorSample.rgb += (lightNormDot * diffuse) - diffuseDiv;\n"
"     colorSample.rgb +=   specular * pow(max(dot(reflect(lightPosition, gradientSample.rgb), dir), 0.0), shininess);\n"
"    } else\n"
"     colorSample.rgb -= diffuseDiv;\n"
"   };\n"
"  }\n"
"  if ( overlays > 0 ) {\n"
"   gradientSample= texture3D(overlayGradientVol,samplePos); \n"
"   if (gradientSample.a > 0.01) {   \n"
"    if (gradientSample.a < oprevNorm.a)\n"
"     gradientSample.rgb = oprevNorm.rgb;\n"
"    oprevNorm = gradientSample;\n"
"    gradientSample.rgb = normalize(gradientSample.rgb*2.0 - 1.0);\n"
"    ocolorSample = texture3D(overlayVol,samplePos);\n"
"    ocolorSample.a *= gradientSample.a;\n"
"    ocolorSample.a = sqrt(ocolorSample.a);\n"
"    float lightNormDot = dot(gradientSample.rgb, lightDirHeadOn);\n"
"    float edgeVal = pow(1.0-abs(lightNormDot),edgeExp) * pow(gradientSample.a,overShade);\n"
"    ocolorSample.a = pow(ocolorSample.a, 1.0 -edgeVal);\n"
"    ocolorSample.rgb = mix(ocolorSample.rgb, vec3(0.0,0.0,0.0), edgeVal);\n"
"    lightNormDot = dot(gradientSample.rgb, lightPosition);\n"
"    if (lightNormDot > 0.0)\n"
"     ocolorSample.rgb +=   overLight * specular * pow(max(dot(reflect(lightPosition, gradientSample.rgb), dir), 0.0), shininess);\n"
"    ocolorSample.a *= overAlphaFrac;\n"
"    if ( ocolorSample.a > 0.2) {\n"
"     if (overDepth == 0) overDepth = i;\n"
"     float overRatio = colorSample.a/(ocolorSample.a);\n"
"     if (colorSample.a > 0.02)\n"
"      colorSample.rgb = mix( colorSample.rgb, ocolorSample.rgb, overRatio);\n"
"     else\n"
"      colorSample.rgb = ocolorSample.rgb;\n"
"     colorSample.a = max(ocolorSample.a, colorSample.a);\n"
"    }\n"
"    ocolorSample.a = 1.0-pow((1.0 - ocolorSample.a), opacityCorrection);  \n"
"    overAcc= (1.0 - overAcc.a) * ocolorSample + overAcc;\n"
"   }\n"
"  }\n"
"  colorSample.rgb *= colorSample.a; \n"
"  colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"  samplePos += deltaDir;\n"
"  lengthAcc += stepSize;\n"
"  if ( lengthAcc >= len  )\n"
"   break;\n"
" }\n"
" colAcc.a*=backAlpha;\n"
" if ((overAcc.a > 0.01) && (overAlpha > 1.0))  {\n"
"  colAcc.a=max(colAcc.a,overAcc.a);\n"
"  if ( (overDistance > 0.0) && (overDepth > backDepthStart) && (backDepthEnd > backDepthStart)) {\n"
"   if (overDepth > backDepthEnd) overDepth = backDepthStart; \n"
"   float dx = float(overDepth-backDepthStart)/ float(backDepthEnd - backDepthStart);\n"
"   dx = pow(1.0-dx, overDistance);\n"
"   dx = pow(dx, 2.0);\n"
"   overAcc *= dx;\n"
"  }\n"
"  overAlphaFrac = overAcc.a * (overAlpha - 1.0);\n"
"  if (overAcc.a > 0.0)\n"
"  colAcc.rgb=mix(colAcc.rgb, overAcc.rgb,  overAlphaFrac);\n"
" }\n"
" if ( colAcc.a < 1.0 )\n"
"  colAcc.rgb = mix(clearColor,colAcc.rgb,colAcc.a);\n"
" if (len == 0.0) colAcc.rgb = clearColor;\n"
" gl_FragColor = colAcc;\n"
"}\n";

//Changed Dec 20 2014 to reduce glisten in clip plane
/*const char *frag_advanced =
"uniform int overlays;\n"
"uniform float clipPlaneDepth, stepSize, sliceSize, viewWidth, viewHeight;\n"
"uniform vec3 clearColor,lightPosition, clipPlane;\n"
"uniform sampler3D intensityVol, gradientVol, overlayVol, overlayGradientVol;\n"
"uniform sampler2D backFace;\n"
"void main() { \n"
" const float specular = 0.2;\n"
" const float shininess = 10.0;\n"
" const float edgeThresh = 0.01;\n"
" const float edgeExp = 0.5;\n"
" const float backAlpha = 1.0;\n"
" const float overDistance = 0.3;\n"
" const float overAlpha = 1.2;\n"
" float overAlphaFrac = 1.0;\n"
" vec3 backPosition = texture2D(backFace,vec2(gl_FragCoord.x/viewWidth,gl_FragCoord.y/viewHeight)).xyz;\n"
" vec3 start = gl_TexCoord[1].xyz;\n"
" vec3 dir = backPosition - start;\n"
" float len = length(dir);\n"
" dir = normalize(dir);\n"
" float clipStart = 0.0;\n"
" float clipEnd = len;\n"
" if (clipPlaneDepth > -0.5) { \n"
"  gl_FragColor.rgb = vec3(1.0,0.0,0.0);\n"
"  bool frontface = (dot(dir , clipPlane) > 0.0);\n"
"  float dis = dot(dir,clipPlane);\n"
"  if (dis != 0.0  )  dis = (-clipPlaneDepth - dot(clipPlane, start.xyz - 0.5)) / dis;\n"
"  if (frontface) clipStart = dis;\n"
"  if (!frontface)  clipEnd = dis;\n"
" }\n"
" vec3 deltaDir = dir * stepSize;\n"
" vec4 overAcc = vec4(0.0,0.0,0.0,0.0);\n"
" vec4 ocolorSample,colorSample,gradientSample,colAcc = vec4(0.0,0.0,0.0,0.0);\n"
" float lengthAcc = 0.0;\n"
" float overAtten = 0.0;\n"
" int overDepth = 0;\n"
" int backDepthEnd = 0;\n"
" int backDepthStart = 2147483647;\n"
" vec3 samplePos = start.xyz + deltaDir * (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453));\n"
" vec4 prevNorm = vec4(0.0,0.0,0.0,0.0);\n"
" vec4 oprevNorm = vec4(0.0,0.0,0.0,0.0);\n"
" float opacityCorrection = stepSize/sliceSize;\n"
" vec3 lightDirHeadOn =  normalize(gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,0.0)).xyz ;\n"
" float stepSizex2 = clipStart + (stepSize * 2.5);\n"
" for(int i = 0; i < int(len / stepSize); i++) { \n"
"  if ((lengthAcc <= clipStart) || (lengthAcc > clipEnd)) { \n"
"   colorSample.a = 0.0;\n"
"  } else { \n"
"   colorSample = texture3D(intensityVol,samplePos);\n"
"   if ((lengthAcc <= stepSizex2) && (colorSample.a > 0.01) )  colorSample.a = sqrt(colorSample.a);\n"
"   colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"   if ((colorSample.a > 0.01) && (lengthAcc > stepSizex2)  ) {  \n"
"    if (backDepthStart == 2147483647) backDepthStart = i;\n"
"    backDepthEnd = i;  \n"
"    gradientSample= texture3D(gradientVol,samplePos);\n"
"    gradientSample.rgb = normalize(gradientSample.rgb*2.0 - 1.0);\n"
"    if (gradientSample.a < prevNorm.a) \n"
"     gradientSample.rgb = prevNorm.rgb;\n"
"    prevNorm = gradientSample;\n"
"    float lightNormDot = dot(gradientSample.rgb, lightDirHeadOn);\n"
"    float edgeVal = pow(1.0 - abs(lightNormDot),edgeExp) * pow(gradientSample.a,0.3);\n"
"    if (edgeVal >= edgeThresh)  \n"
"     colorSample.rgb = mix(colorSample.rgb, vec3(0.0,0.0,0.0), pow((edgeVal-edgeThresh)/(1.0-edgeThresh),4.0));\n"
"    lightNormDot = dot(gradientSample.rgb, lightPosition);\n"
"    if (lightNormDot > 0.0) \n"
"     colorSample.rgb +=   specular * pow(max(dot(reflect(lightPosition, gradientSample.rgb), dir), 0.0), shininess);\n"
"   }\n"
"  }\n"
"  if ( overlays > 0 ) { \n"
"   gradientSample= texture3D(overlayGradientVol,samplePos);\n"
"   if (gradientSample.a > 0.01) {\n"
"    if (gradientSample.a < oprevNorm.a)\n"
"     gradientSample.rgb = oprevNorm.rgb;\n"
"    oprevNorm = gradientSample;\n"
"    gradientSample.rgb = normalize(gradientSample.rgb*2.0 - 1.0);\n"
"    ocolorSample = texture3D(overlayVol,samplePos);\n"
"    ocolorSample.a *= gradientSample.a;\n"
"    ocolorSample.a *= overAlphaFrac;\n"
"    ocolorSample.a = sqrt(ocolorSample.a);\n"
"    float lightNormDot = dot(gradientSample.rgb, lightDirHeadOn);\n"
"    float edgeVal = pow(1.0-abs(lightNormDot),edgeExp) * pow(gradientSample.a,0.3);\n"
"    if (edgeVal >= edgeThresh)  \n"
"     ocolorSample.rgb = mix(ocolorSample.rgb, vec3(0.0,0.0,0.0), pow((edgeVal-edgeThresh)/(1.0-edgeThresh),4.0));\n"
"    lightNormDot = dot(gradientSample.rgb, lightPosition);\n"
"    if (lightNormDot > 0.0) \n"
"     ocolorSample.rgb +=   specular * pow(max(dot(reflect(lightPosition, gradientSample.rgb), dir), 0.0), shininess);\n"
"    if ( ocolorSample.a > 0.2) { \n"
"     if (overDepth == 0) overDepth = i;\n"
"     float overRatio = colorSample.a/(ocolorSample.a);\n"
"     if (colorSample.a > 0.02) \n"
"      colorSample.rgb = mix( colorSample.rgb, ocolorSample.rgb, overRatio);\n"
"     else \n"
"      colorSample.rgb = ocolorSample.rgb;\n"
"     colorSample.a = max(ocolorSample.a, colorSample.a);\n"
"    }\n"
"    ocolorSample.a = 1.0-pow((1.0 - ocolorSample.a), opacityCorrection);\n"
"    overAcc= (1.0 - overAcc.a) * ocolorSample + overAcc;\n"
"   }\n"
"  }\n"
"  colorSample.rgb *= colorSample.a;  \n"
"  colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"  samplePos += deltaDir;\n"
"  lengthAcc += stepSize;\n"
"  if ( lengthAcc >= len  )\n"
"   break;\n"
" }\n"
" colAcc *= backAlpha;\n"
" if ((overAcc.a > 0.01) && (overAlpha > 1.0))  { \n"
"  colAcc.a=max(colAcc.a,overAcc.a);\n"
"  if ( (overDistance > 0.0) && (overDepth > backDepthStart) && (backDepthEnd > backDepthStart)) { \n"
"   if (overDepth > backDepthEnd) overDepth = backDepthStart;\n"
"   float dx = float(overDepth-backDepthStart)/ float(backDepthEnd - backDepthStart);\n"
"   dx = pow(1.0-dx, overDistance);\n"
"   dx = pow(dx, 2.0);\n"
"   overAcc *= dx;\n"
"  }\n"
"  overAlphaFrac = overAcc.a * (overAlpha - 1.0);\n"
"  if (overAcc.a > 0.0) \n"
"   colAcc.rgb=mix(colAcc.rgb, overAcc.rgb,  overAlphaFrac);\n"
" }\n"
" if ( colAcc.a < 1.0 ) \n"
"  colAcc.rgb = mix(clearColor,colAcc.rgb,colAcc.a);\n"
" if (len == 0.0) colAcc.rgb = clearColor;\n"
" gl_FragColor = colAcc;\n"
"}";*/

/* --- 1.4 advanced renderer:
  */
/*const char *frag_default =
"uniform float stepSize, sliceSize, viewWidth, viewHeight;\n"
"uniform sampler3D intensityVol;\n"
"uniform sampler2D backFace;\n"
"uniform vec3 clearColor,lightPosition, clipPlane;\n"
"uniform float clipPlaneDepth;\n"
"void main() {\n"
" vec4 colorSample,colAcc = vec4(1.0,0.0,0.0,1.0);\n"
" gl_FragColor = colAcc;\n"
"}";*/
const char *frag_default =
"uniform float stepSize, sliceSize, viewWidth, viewHeight;\n"
"uniform sampler3D intensityVol;\n"
"uniform sampler2D backFace;\n"
"uniform vec3 clearColor,lightPosition, clipPlane;\n"
"uniform float clipPlaneDepth;\n"
"void main() {\n"
" vec2 pixelCoord = gl_FragCoord.st;\n"
" pixelCoord.x /= viewWidth;\n"
" pixelCoord.y /= viewHeight;\n"
" vec3 start = gl_TexCoord[1].xyz;\n"
" vec3 backPosition = texture2D(backFace,pixelCoord).xyz;\n"
" vec3 dir = backPosition - start;\n"
" float len = length(dir);\n"
" dir = normalize(dir);\n"
" if (clipPlaneDepth > -0.5) {\n"
"  gl_FragColor.rgb = vec3(1.0,0.0,0.0);\n"
"  bool frontface = (dot(dir , clipPlane) > 0.0);\n"
"  float dis = dot(dir,clipPlane);\n"
"  if (dis != 0.0  )  dis = (-clipPlaneDepth - dot(clipPlane, start.xyz-0.5)) / dis;\n"
"  if ((frontface) && (dis > len)) len = 0.0;\n"
"  if ((!frontface) && (dis < 0.0)) len = 0.0;\n"
"  if ((dis > 0.0) && (dis < len)) {\n"
"   if (frontface) {\n"
"    start = start + dir * dis;\n"
"   } else {\n"
"    backPosition =  start + dir * (dis);\n"
"   }\n"
"   dir = backPosition - start;\n"
"   len = length(dir);\n"
"  dir = normalize(dir);\n"
"  }\n"
" }\n"
" vec3 deltaDir = dir * stepSize;\n"
" vec4 colorSample,colAcc = vec4(0.0,0.0,0.0,0.0);\n"
" float lengthAcc = 0.0;\n"
" float opacityCorrection = stepSize/sliceSize;\n"
" vec3 samplePos = start.xyz + deltaDir* (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453));\n"
" for(int i = 0; i < int(len / stepSize); i++) {\n"
"  colorSample = texture3D(intensityVol,samplePos);\n"
"  if ((lengthAcc <= stepSize) && (colorSample.a > 0.01) ) colorSample.a = sqrt(colorSample.a);\n"
"  colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"  colorSample.rgb *= colorSample.a;\n"
"  colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"  samplePos += deltaDir;\n"
"  lengthAcc += stepSize;\n"
"  if ( lengthAcc >= len || colAcc.a > 0.95 )\n"
"   break;\n"
" }\n"
" colAcc.a = colAcc.a/0.95;\n"
" if ( colAcc.a < 1.0 )\n"
"  colAcc.rgb = mix(clearColor,colAcc.rgb,colAcc.a);\n"
" gl_FragColor = colAcc;\n"
"}\n";

void initShaderWithFile (NII_PREFS* prefs) {
    if (prefs->glslprogramInt != 0) glDeleteShader(prefs->glslprogramInt);
    #ifdef  MY_USE_ADVANCED_GLSL
    if (prefs->advancedRender)
        prefs->glslprogramInt=  initVertFrag(vert_default, frag_advanced);
    else
#endif
        prefs->glslprogramInt=  initVertFrag(vert_default, frag_default);
}

float kDefaultDistance = 2.25;//2.25;

void drawUnitQuad ()
//stretches image in view space.
{
    glDisable(GL_DEPTH_TEST);
    glBegin(GL_QUADS);
        glTexCoord2f(0.0, 0.0);
        glVertex2f(0.0, 0.0);
        glTexCoord2f(1.0 ,0.0);
        glVertex2f(1.0, 0.0);
        glTexCoord2f(1.0, 1.0);
        glVertex2f(1.0, 1.0);
        glTexCoord2f(0.0, 1.0);
        glVertex2f(0.0, 1.0);
    glEnd();
    //glEnable(GL_DEPTH_TEST);
}

/*void reshapeOrtho(int l, int b, int w, int h)
{
    if (h == 0)  h = 1;
    glViewport(l, b,w,h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, 1, 0, 1,-10, 10);//gluOrtho2D(0.0, 1.0, 0.0, 1.0);
    //glOrtho(whratio*-0.5*scale,whratio*0.5*scale,-0.5*scale,0.5*scale, 0.01, kMaxDistance);
    glMatrixMode(GL_MODELVIEW);
}*/

void resize(int wx, int hx, NII_PREFS* prefs)
{
    int kMaxDistance = 40.0;
    float whratio,scale, w, h;
    w = wx;
    h = hx;
    if (h == 0) h = 1;
    //glViewport(prefs->scrnOffsetX,prefs->scrnOffsetY, w, h);
    glViewport(0,0, w, h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    //    if (prefs->perspective) {
    //        gluPerspective(40.0, w/h, 0.01, kMaxDistance);
    //    }else {
    //prefs->renderDistance = 0.5;
    if (prefs->renderDistance == 0) {
        scale = 1.0;
    } else {
        scale = 1.0/fabs(kDefaultDistance/(prefs->renderDistance+1.0));
    }
    whratio = w/h;
    glOrtho(whratio*-0.5*scale,whratio*0.5*scale,-0.5*scale,0.5*scale, 0.01, kMaxDistance);
#ifdef MY_DEBUG //from nii_io.h
    NSLog(@"Resize %dx%d rendDx=%g scale=%g",prefs->renderWid, prefs->renderHt, prefs->renderDistance, scale);
#endif
    glMatrixMode(GL_MODELVIEW);
}

// display the final image on the screen
void renderBufferToScreen (NII_PREFS* prefs)
{
    //glClearColor(1.0f, 0.1f, 0.0f, 1.0f );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glLoadIdentity();
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D,prefs->finalImage);
    //use next line instead of previous to illustrate one-pass rendering
    //glBindTexture(GL_TEXTURE_2D,prefs->backFaceBuffer);
    //reshapeOrtho(prefs->renderLeft, prefs->renderBottom, prefs->renderWid, prefs->renderHt);
    //reshapeOrtho(prefs->renderLeft - prefs->scrnOffsetX, prefs->renderBottom - prefs->scrnOffsetY, prefs->renderWid, prefs->renderHt);
    
    
    //reshapeOrtho(prefs->renderLeft, prefs->renderBottom, prefs->renderWid, prefs->renderHt);
    glViewport(prefs->scrnOffsetX+prefs->renderLeft, prefs->scrnOffsetY+prefs->renderBottom, prefs->renderWid, prefs->renderHt);
    //glViewport(prefs->renderLeft, prefs->renderBottom, prefs->renderWid, prefs->renderHt);
    
    //glViewport(prefs->renderLeft+prefs->renderLeft, prefs->renderBottom-200,prefs->renderWid,prefs->renderHt);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, 1, 0, 1,-10, 10);//gluOrtho2D(0.0, 1.0, 0.0, 1.0);
    //glOrtho(whratio*-0.5*scale,whratio*0.5*scale,-0.5*scale,0.5*scale, 0.01, kMaxDistance);
    glMatrixMode(GL_MODELVIEW);
    
    drawUnitQuad();
    glDisable(GL_TEXTURE_2D);
}

// render the backface to the offscreen buffer backFaceBuffer
void renderBackFace(NII_PREFS* prefs)
{
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, prefs->backFaceBuffer, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glEnable(GL_CULL_FACE);
    glCullFace(GL_FRONT);
    glMatrixMode(GL_MODELVIEW);
    glScalef(prefs->TexScale[1],prefs->TexScale[2],prefs->TexScale[3]);
    drawQuads(1.0,1.0,1.0);
    glDisable(GL_CULL_FACE);
}

float lerp (float p1, float p2, float frac)
{
    return round(p1 + frac * (p2 - p1));
}//linear interpolation

float computeStepSize (int quality1to10,  NII_PREFS* prefs)
{
    float f;
    f = quality1to10;
    if (f < 1)
        f = 1;
    if (f > 10)
        f = 10;
    f = f/10;
    f = lerp (prefs->renderSlices*0.25,prefs->renderSlices*2.0,f);
    if (f < 10)
        f = 10;
    return 1/f;
}

double defuzz(double x)
{
    const double fuzz = 1.0E-6;
    if (fabs(x) < fuzz) return 0.0;
    return x;
}

double degToRad(double degree)
{
    #define pi 3.14159265
    double radian = 0.0;
    radian = degree * (pi/180);
    return radian;
}

void sph2cartDeg90(float azimuth, float elevation, float* lX, float* lY, float *lZ)
//convert spherical AZIMUTH,ELEVATION,RANGE to Cartesion
//see Matlab's [x,y,z] = sph2cart(THETA,PHI,R)
// reverse with cart2sph
{
    float E,Phi,Theta;
    E = azimuth;
    while (E < 0)
        E = E + 360;   
    while (E > 360)
        E = E - 360;
    Theta = degToRad(E);
    E = elevation;
    while (E > 90)
        E = E - 90;
    while (E < -90)
        E = E + 90;
    Phi = degToRad(E);
    *lX = cos(Phi)*cos(Theta);
    *lY = cos(Phi)*sin(Theta);
    *lZ = sin(Phi);
}

void sph2cartDeg90x(float Azimuth, float Elevation, float R, float* lX, float* lY, float* lZ)
//convert spherical AZIMUTH,ELEVATION,RANGE to Cartesion
//see Matlab's [x,y,z] = sph2cart(THETA,PHI,R)
// reverse with cart2sph
{
    int n;
    float E,Phi,Theta;
    Theta = degToRad(Azimuth-90);
    E = Elevation;
    if ((E > 360) || (E < -360)) {
        n = trunc(E / 360) ;
        E = E - (n * 360);
    }
    if (((E > 89) && (E < 91)) || ((E < -269) && (E > -271)))
        E = 90;        
    if (((E > 269) && (E < 271)) || ((E < -89) && (E > -91)) )
        E = -90;
    Phi = degToRad(E);
    *lX = R * cos(Phi)*cos(Theta);
    *lY = R * cos(Phi)*sin(Theta);
    *lZ = R * sin(Phi);
}

void lightUniforms (NII_PREFS* prefs)
{
    float lX,lY,lZ,lA;
     // lMgl: array[0..15] of  GLfloat;
    //sph2cartDeg90x(0,80,1,&lX,&lY,&lZ);//0,80 are azimuth and elevation of light source
    sph2cartDeg90x(90,20,1,&lX,&lY,&lZ);//0,80 are azimuth and elevation of light source
    if (true) { //gPrefs.RayCastViewCenteredLight
        //Could be done in GLSL with following lines of code, but would be computed once per pixel, vs once per volume
        //vec3 lightPosition =  normalize(gl_ModelViewMatrixInverse * vec4(lightPosition,0.0)).xyz ;
        GLfloat lMgl[16];
        float lB,lC;
        glGetFloatv(GL_TRANSPOSE_MODELVIEW_MATRIX, lMgl);
        lA = lY;
        lB = lZ;
        lC = lX;
        lX = defuzz(lA*lMgl[0]+lB*lMgl[4]+lC*lMgl[8]);
        lY = defuzz(lA*lMgl[1]+lB*lMgl[5]+lC*lMgl[9]);
        lZ = defuzz(lA*lMgl[2]+lB*lMgl[6]+lC*lMgl[10]);
    }
    lA = sqrt(lX*lX+lY*lY+lZ*lZ);
    if (lA > 0.0) { //normalize
        lX = lX/lA;
        lY = lY/lA;
        lZ = lZ/lA;
    }
    uniform3fv("lightPosition",lX,lY,lZ, prefs);
}

void clipUniforms (NII_PREFS* prefs)
{
    float lD,lX,lY,lZ;
    sph2cartDeg90x(prefs->clipAzimuth,prefs->clipElevation,1,&lX,&lY,&lZ);
    uniform3fv("clipPlane",-lX,-lY,-lZ, prefs);
    if (prefs->clipDepth < 1)
        lD = -1;
    else
        lD = 0.5-(prefs->clipDepth/1000.0);
    uniform1f( "clipPlaneDepth", lD, prefs);
}

/*void drawFrame(float x, float y, float z)
//x,y,z typically 1.
// useful for clipping
// If x=0.5 then only left side of texture drawn
// If y=0.5 then only posterior side of texture drawn
// If z=0.5 then only inferior side of texture drawn
{
    glColor4f(1,1,1,1);
    glBegin(GL_LINE_STRIP);
    // Back side
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(0.0, y, 0.0);
    drawVertex(x, y, 0.0);
    drawVertex(x, 0.0, 0.0);
    glEnd();
    glBegin(GL_LINE_STRIP);
    // Front side
    drawVertex(0.0, 0.0, z);
    drawVertex(x, 0.0, z);
    drawVertex(x, y, z);
    drawVertex(0.0, y, z);
    glEnd();
    glBegin(GL_LINE_STRIP);
    // Top side
    drawVertex(0.0, y, 0.0);
    drawVertex(0.0, y, z);
    drawVertex(x, y, z);
    drawVertex(x, y, 0.0);
    glEnd();
    glColor4f(0.2,0.2,0.2,0);
    glBegin(GL_LINE_STRIP);
    // Bottom side
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(x, 0.0, 0.0);
    drawVertex(x, 0.0, z);
    drawVertex(0.0, 0.0, z);
    glEnd();
    glColor4f(0,1,0,0);
    glBegin(GL_LINE_STRIP);
    // Left side
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(0.0, 0.0, z);
    drawVertex(0.0, y, z);
    drawVertex(0.0, y, 0.0);
    glEnd();
    glColor4f(1,0,0,0);
    glBegin(GL_LINE_STRIP);
    // Right side
    drawVertex(x, 0.0, 0.0);
    drawVertex(x, y, 0.0);
    drawVertex(x, y, z);
    drawVertex(x, 0.0, z);
    glEnd();
}*/

void rayCasting (NII_PREFS* prefs) {
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, prefs->finalImage, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glUseProgram(prefs->glslprogramInt);
    // glUseProgramObjectARB(prefs->glslprogram);
    glActiveTexture( GL_TEXTURE0 );
    glBindTexture(GL_TEXTURE_2D, prefs->backFaceBuffer);
    glActiveTexture( GL_TEXTURE1);
    #ifdef  MY_USE_ADVANCED_GLSL
    if (prefs->advancedRender) {
        #ifdef MY_SHOW_GRADIENTS //defined in nii_render.h
            glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
        #else
            glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
        #endif
        glActiveTexture( GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
        uniform1i( "gradientVol",2, prefs );
        uniform1i( "overlayGradientVol",4, prefs );
        uniform1i( "overlays",prefs->numOverlay, prefs );
        uniform1i( "overlayVol",3, prefs );
        if (prefs->numOverlay > 0) {
            glActiveTexture( GL_TEXTURE3);
            glBindTexture(GL_TEXTURE_3D, prefs->intensityOverlay3D);
            glActiveTexture( GL_TEXTURE4);
            glBindTexture(GL_TEXTURE_3D, prefs->gradientOverlay3D);
        }
    } else
    #endif
    glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    uniform1i( "backFace", 0, prefs );		// backFaceBuffer -> texture0
    uniform3fv("clearColor",prefs->backColor[0],prefs->backColor[1],prefs->backColor[2], prefs);
    clipUniforms(prefs);
    uniform1i( "intensityVol", 1, prefs );
    //uniform1i( "loops",(2*prefs->renderSlices), prefs); //provide as uniform to allow unrolled loops
    lightUniforms(prefs);
    uniform1f( "sliceSize", 1.0/prefs->renderSlices, prefs );
    uniform1f( "stepSize", computeStepSize(prefs->rayCastQuality1to10, prefs), prefs );
    uniform1f( "viewHeight", prefs->renderHt , prefs);
    uniform1f( "viewWidth", prefs->renderWid, prefs );
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glMatrixMode(GL_MODELVIEW);
    glScalef(1.0,1.0,1.0);
    drawQuads(1.0,1.0,1.0);
    glDisable(GL_CULL_FACE);
    glUseProgram(0);
    glActiveTexture( GL_TEXTURE0 );
}

void MakeCube(float sz)
{
    float sz2;
    sz2 = sz;
    glColor4f(0.2,0.2,0.2,1);
    //GLuint idx = glGenLists(1);
    //glNewList(idx, GL_COMPILE);
    glBegin(GL_QUADS);
    // Bottom side
    glVertex3f(-sz, -sz, -sz2);
    glVertex3f(-sz, sz, -sz2);
    glVertex3f(sz, sz, -sz2);
    glVertex3f(sz, -sz, -sz2);
    glEnd();
    glColor4f(0.8,0.8,0.8,1);
    glBegin(GL_QUADS);
    // Top side
    glVertex3f(-sz, -sz, sz2);
    glVertex3f(sz, -sz, sz2);
    glVertex3f(sz, sz, sz2);
    glVertex3f(-sz, sz, sz2);
    glEnd();
    glColor4f(0,0,0.4,1);
    glBegin(GL_QUADS);
    // Front side
    glVertex3f(-sz, sz2, -sz);
    glVertex3f(-sz, sz2, sz);
    glVertex3f(sz, sz2, sz);
    glVertex3f(sz, sz2, -sz);
    glEnd();
    glColor4f(0.2,0,0.2,1);
    glBegin(GL_QUADS);
    // Back side
    glVertex3f(-sz, -sz2, -sz);
    glVertex3f(sz, -sz2, -sz);
    glVertex3f(sz, -sz2, sz);
    glVertex3f(-sz, -sz2, sz);
    glEnd();
    glColor4f(0.6,0,0,1);
    glBegin(GL_QUADS);
    // Left side
    glVertex3f(-sz2, -sz, -sz);
    glVertex3f(-sz2, -sz, sz);
    glVertex3f(-sz2, sz, sz);
    glVertex3f(-sz2, sz, -sz);
    glEnd();
    glColor4f(0,0.6,0,1);
    glBegin(GL_QUADS);
    // Right side
    glVertex3f(sz2, -sz, -sz);
    glVertex3f(sz2, sz, -sz);
    glVertex3f(sz2, sz, sz);
    glVertex3f(sz2, -sz, sz);
    glEnd();
    //glEndList();
    //glCallList(idx);
    //glDeleteLists(idx, 1);
}


void DrawCube (NII_PREFS* prefs)//Enter2D = reshapeGL
{
    glDisable(GL_DEPTH_TEST);
    //    glViewport(0, 0, width, height);
    glViewport(prefs->scrnOffsetX, prefs->scrnOffsetY, prefs->scrnWid, prefs->scrnHt);
     
    glEnable(GL_CULL_FACE);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, prefs->scrnWid, 0, prefs->scrnHt,-100, 100);//gluOrtho2D(0, width, 0, height);
    //glOrtho(0, width, 0, height,-10, 10);//gluOrtho2D(0, width, 0, height);
    glEnable(GL_DEPTH_TEST);
    glDisable (GL_LIGHTING);
    glDisable (GL_BLEND);
    float mx = prefs->renderWid;
    if (mx > prefs->renderHt) mx = prefs->renderWid;
    mx = mx *0.04f;
    //glTranslatef(1.8*mx,1.8*mx,0.5);
    glTranslatef(prefs->renderLeft+ 1.8*mx,1.8*mx,0.5);
    glRotatef(90-prefs->renderElevation,-1,0,0);
    glRotatef(prefs->renderAzimuth,0,0,1);
    MakeCube(mx);
    glDisable(GL_CULL_FACE);

    //glDisable(GL_DEPTH_TEST);
}

/*void DrawCube (NII_PREFS* prefs)
{
    glEnable(GL_CULL_FACE);
    glMatrixMode (GL_PROJECTION);
    glLoadIdentity ();
    glOrtho (0, prefs->renderWid,0, prefs->renderHt,-100,100);
    glEnable(GL_DEPTH_TEST);
    glDisable (GL_LIGHTING);
    glDisable (GL_BLEND);
    glTranslatef(36,36,0.5);
    glRotatef(90-prefs->renderElevation,-1,0,0);
    glRotatef(prefs->renderAzimuth,0,0,1);
    MakeCube(20);
    glDisable(GL_CULL_FACE);
}*/

int getMaxInt(int v1, int v2, int v3)
{
    int ret;
    if ((v1 > v2) && (v1 > v3)) //v1 biggest
        ret = v1;
    else if  (v2 > v3) //v2 > v3, v2 >= v1
        ret = v2;
    else //v3 >= v2, v3 >= v1
        ret = v3;
    return ret;
}

float getMaxFloat(float v1, float v2, float v3)
{
    float ret;
    if ((v1 > v2) && (v1 > v3)) //v1 > v2, v1 > v3
        ret = v1;
    else if  (v2 > v3) //v2 > v3, v2 >= v1
        ret = v2;
    else //v3 >= v2, v3 >= v1
        ret = v3;
    return ret;
}

void  createRender (NII_PREFS* prefs)  //InitGL
{
    initShaderWithFile(prefs);
    // Create the to FBO's one for the backside of the volumecube and one for the finalimage rendering
    glGenFramebuffersEXT(1, &prefs->frameBuffer);
    glGenTextures(1, &prefs->backFaceBuffer);
    glGenTextures(1, &prefs->finalImage);
    glGenRenderbuffersEXT(1, &prefs->renderBuffer);
}

void recalcRender (NII_PREFS* prefs)  //DisplayGL
{
    //we will want to render more points for higher resolution volumes
    prefs->renderSlices = getMaxInt(prefs->voxelDim[1],prefs->voxelDim[2],prefs->voxelDim[3]);
    if (prefs->renderSlices < 1) prefs->renderSlices = 100;
    //normalize so longest length=1.0 e.g. 25x75x100mm volume is0.25x0.75x1.0
    float maxFOV = getMaxFloat(prefs->fieldOfViewMM[1],prefs->fieldOfViewMM[2],prefs->fieldOfViewMM[3]);
    if ((prefs->fieldOfViewMM[1] > 0.0) && (prefs->fieldOfViewMM[2] > 0.0) && (prefs->fieldOfViewMM[3] > 0.0)) {
        //NSLog(@"%gx%gx%g", prefs->fieldOfViewMM[1], prefs->fieldOfViewMM[2], prefs->fieldOfViewMM[3]);
        maxFOV = sqrt(pow(prefs->fieldOfViewMM[1],2)+pow(prefs->fieldOfViewMM[2],2)+pow(prefs->fieldOfViewMM[3],2))/2.0;
    }
    if (maxFOV <= 0) maxFOV = 1;
    prefs->TexScale[1] = prefs->fieldOfViewMM[1]/maxFOV;
    prefs->TexScale[2] = prefs->fieldOfViewMM[2]/maxFOV;
    prefs->TexScale[3] = prefs->fieldOfViewMM[3]/maxFOV;
    #ifdef MY_DEBUG //from nii_io.h
    NSLog(@"%dx%dx%d max=%d FOV=%g",prefs->voxelDim[1],prefs->voxelDim[2],prefs->voxelDim[3], prefs->renderSlices, maxFOV);
    #endif
}



void  setupRender (NII_PREFS* prefs)  //InitGL
{
    // Load the vertex and fragment raycasting programs
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,prefs->frameBuffer);
    glBindTexture(GL_TEXTURE_2D, prefs->backFaceBuffer);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, prefs->renderWid, prefs->renderHt, 0, GL_RGBA, GL_FLOAT, nil);
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, prefs->backFaceBuffer, 0);
    glBindTexture(GL_TEXTURE_2D, prefs->finalImage);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, prefs->renderWid, prefs->renderHt, 0, GL_RGBA, GL_FLOAT, nil);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, prefs->renderBuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, prefs->renderWid, prefs->renderHt);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, prefs->renderBuffer);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glBindFramebufferEXT (GL_FRAMEBUFFER_EXT, prefs->frameBuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, prefs->renderBuffer);
}

void redrawRender (NII_PREFS* prefs)  //DisplayGL
{
    if ((prefs->renderHt < 1) || (prefs->renderWid < 1))
        return;
    glDisable (GL_TEXTURE_3D);//this is critical!
    #ifdef  MY_USE_ADVANCED_GLSL
    doShaderBlurSobel (prefs);
    #endif
    
    
    
    setupRender(prefs);
    resize(prefs->renderWid, prefs->renderHt, prefs);
    glClearColor(prefs->backColor[0],prefs->backColor[1],prefs->backColor[2], 0.0);
    glTranslatef(0,0,-prefs->renderDistance); //fails with close zoom - unit cube
    glTranslatef(0,0,-1.75); //make sure we do not clip a corner: unit cube so sqrt(3) = 1.732
    glRotatef(90-prefs->renderElevation,-1,0,0);
    glRotatef(prefs->renderAzimuth,0,0,1);
    glTranslatef(-prefs->TexScale[1]/2,-prefs->TexScale[2]/2,-prefs->TexScale[3]/2);
    renderBackFace(prefs);
    rayCasting(prefs);
    glActiveTexture( GL_TEXTURE0 ); //this can be called in rayCasting, but MUST be called before 2D can be done
    disableRenderBuffers();
    renderBufferToScreen(prefs);
    if (prefs->showCube)
        DrawCube(prefs);
    //glFlush();//<-this will pause until all jobs are SUBMITTED
    //glFinish;//<-this would pause until all jobs finished: generally a bad idea!
    //next, you will need to execute SwapBuffers
    
}

void initTRayCast (NII_PREFS* prefs)
{
    prefs->perspective = FALSE;
    prefs->TexScale[1] = 1;
    prefs->TexScale[2] = 1;
    prefs->TexScale[3] = 1;
    //prefs->showGradient = 0;
    prefs->rayCastQuality1to10 = 6;
    prefs->showCube = TRUE;
    prefs->clipAzimuth = 180;
    prefs->clipElevation = 0;
    prefs->clipDepth = 0;
    prefs->renderAzimuth = 110;
    prefs->renderElevation = 15;
    prefs->renderDistance = kDefaultDistance;
    prefs->renderSlices = 256;
    prefs->gradientTexture3D = 0;
    prefs->intensityTexture3D = 0;
    prefs->gradientOverlay3D = 0;
    prefs->intensityOverlay3D = 0;
    prefs->glslprogramIntBlur = 0;
    prefs->glslprogramIntSobel = 0;
    prefs->glslUpdateGradientsOverlay = false;
    prefs->glslUpdateGradientsBG = false;
    prefs->glslprogramInt = 0;
    prefs->finalImage = 0;
    prefs->renderBuffer = 0;
    prefs->frameBuffer = 0;
    prefs->backFaceBuffer = 0;
    prefs->renderLeft = 0;
    prefs->renderBottom = 0;
    prefs->displayModeGL = GL_2D_AND_3D; //options: GL_2D_AND_3D GL_2D_ONLY GL_3D_ONLY
}//initTRayCast