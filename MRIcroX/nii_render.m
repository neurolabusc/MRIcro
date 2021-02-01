//
//  nii_render.m
//  MRIpro
//
//  Created by Chris Rorden on 9/2/12.
//  Copyright 2012 U South Carolina. All rights reserved.
//

#import "nii_render.h"
#include "nii_io.h"
#include <math.h>
#include <stdio.h>
#include "nii_definetypes.h"
#import <OpenGL/glu.h>
//#include <GLKit/GLKMatrix4.h>
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

GLuint bindBlankGL(NII_PREFS* prefs) { //creates an empty texture in VRAM without requiring memory copy from RAM
    //later run glDeleteTextures(1,&oldHandle);
    GLenum error = glGetError();
    if (error) NSLog(@"bindBlankGL init error %d\n", error);
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
    //NSLog(@"voxelDim %d %d %d\n", prefs->voxelDim[1], prefs->voxelDim[2], prefs->voxelDim[3]);
    error = glGetError();
    if (error) NSLog(@"bindBlankGL memory exhausted %d\n", error);
    return handle;
}
void performBlurSobel(NII_PREFS* prefs, bool isOverlay) {
    GLsizei XSz = prefs->voxelDim[1];
    GLsizei YSz = prefs->voxelDim[2];
    int ZSz = prefs->voxelDim[3];
    GLuint fb = 0;
    //glFinish();//<-wait for jobs to finish: we need these to draw XCODE Flicker (not double-buffered?)
    glGenFramebuffersEXT(1, &fb);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fb);
    glDisable(GL_CULL_FACE);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glViewport(0, 0, XSz, YSz);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho (0, 1,0, 1, -1, 1);  //gluOrtho2D(0, 1, 0, 1);  https://www.opengl.org/sdk/docs/man2/xhtml/gluOrtho2D.xml
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glDisable(GL_BLEND);
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
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "dX"), 0.5/(float)prefs->voxelDim[1]);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "dY"), 0.5/(float)prefs->voxelDim[2]);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "dZ"), 0.5/(float)prefs->voxelDim[3]);
    for (int i = 0; i < ZSz; i++) {
        float coordZ = (float)1/(float)ZSz * ((float)i + 0.5);
        glUniform1f(glGetUniformLocation(prefs->glslprogramIntBlur, "coordZ"), coordZ);
        glFramebufferTexture3D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_3D, tempTex3D, 0, i);//output texture
        glClear(GL_DEPTH_BUFFER_BIT);  // clear depth bit (before render every layer)
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
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel, "dX"), 1.2/(float)XSz); //1.0 for SOBEL - center excluded
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel, "dY"), 1.2/(float)YSz);
    glUniform1f(glGetUniformLocation(prefs->glslprogramIntSobel, "dZ"), 1.2/(float)ZSz);
    for (int i = 0; i < ZSz; i++) {
        float coordZ = (float)1/(float)ZSz * ((float)i + 0.5);
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
    //glFinish();//<-wait for jobs to finish: we need these to draw XCODE Flicker (not double-buffered?)
    //clean up:
    glDeleteTextures(1,&tempTex3D);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,0);
    glDeleteFramebuffers(1,&fb);
    glActiveTexture( GL_TEXTURE0 );
}

/*void performBlurSobel(NII_PREFS* prefs, bool isOverlay) {
    //GLenum error = glGetError();
    //if (error) NSLog(@"Sobel init error %d\n", error);
    glFinish();//force updat
    GLuint fb = 0;
    glGenFramebuffersEXT(1, &fb);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,frameBuffer);
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
    //https://stackoverflow.com/questions/30361168/how-to-fix-my-deprecated-use-of-gluortho2d
    //GLKMatrix4 orthoMat = GLKMatrix4MakeOrtho(0.0f, 1.0f, 0.0f, 1.0f, -1.0f, 1.0f);
    //glLoadMatrix(orthoMat.m);
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
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,0);
    glDeleteFramebuffers(1,&frameBuffer);
}*/

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
        performBlurSobel(prefs, true);
    if (prefs->glslUpdateGradientsBG)
        performBlurSobel(prefs, false);
#ifdef MY_DEBUG
    NSLog(@"glsl = %1f", (1000.0*[[NSDate date] timeIntervalSinceDate:methodStart]));
#endif
    prefs->glslUpdateGradientsBG = false;
    prefs->glslUpdateGradientsOverlay = false;
    GLenum error = glGetError();
    if (error) NSLog(@"doShaderBlurSobel error %d\n", error);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
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
    //NSLog(@">>> drawQuads Start:\n");
    //glBindTexture(GL_TEXTURE_3D, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
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
    //NSLog(@">>>  drawQuads End\n");
}

void uniform1i(const char* name, int value, NII_PREFS* prefs )
{
    glUniform1i(glGetUniformLocation(prefs->glslprogramCur, name), value);
}

void uniform1f(const char* name, float value, NII_PREFS* prefs )
{
    glUniform1f(glGetUniformLocation(prefs->glslprogramCur, name), value);
}

void uniform3fv(const char* name, float v1, float v2, float v3, NII_PREFS* prefs)
{
    glUniform3f(glGetUniformLocation(prefs->glslprogramCur, name), v1, v2, v3);
}

void uniform4fv(const char* name, float v1, float v2, float v3, float v4, NII_PREFS* prefs)
{
    glUniform4f(glGetUniformLocation(prefs->glslprogramCur, name), v1, v2, v3, v4);
}

/*const char *vert_defaultOLD =
"void main() {\n"
" gl_TexCoord[1] = gl_MultiTexCoord1;\n"
" gl_Position = ftransform();\n"
"}";*/

const char *frag_advanced_CT =
"#version 120\n"
"varying vec3 vColor;\n"
"uniform vec3 rayDir;\n"
"uniform int overlays;\n"
"uniform float stepSize, sliceSize;\n"
"uniform vec3 lightPosition;\n"
"uniform vec4 clipPlane;\n"
"uniform sampler3D intensityVol, gradientVol, intensityOverlay, gradientOverlay;\n"
"uniform float clipThick = 2.0;\n"
"uniform vec3 textureSz = vec3(3.0, 2.0, 1.0);\n"
"uniform float ambient = 0.8;\n"
"uniform float diffuse = 0.3;\n"
"uniform float specular = 0.1;\n"
"uniform float shininess= 20.0;\n"
"uniform float surfaceHardness = 0.75;//CT\n"
"//uniform float backAlpha = 0.95;\n"
"uniform float overlayClip = 0.0;\n"
"uniform float overlayFuzzy = 0.5;\n"
"uniform float overlayDepth = 0.3;\n"
"vec3 GetBackPosition (vec3 startPosition) {\n"
" vec3 invR = 1.0 / rayDir;\n"
" vec3 tbot = invR * (vec3(0.0)-startPosition);\n"
" vec3 ttop = invR * (vec3(1.0)-startPosition);\n"
" vec3 tmax = max(ttop, tbot);\n"
" vec2 t = min(tmax.xx, tmax.yz);\n"
" return startPosition + (rayDir * min(t.x, t.y));\n"
"}\n"
"void fastPass (float len, vec3 dir, sampler3D vol, inout vec4 samplePos){\n"
"    vec4 deltaDir = vec4(dir.xyz * max(stepSize, sliceSize * 1.95), max(stepSize, sliceSize * 1.95));\n"
"    while  (texture3D(intensityVol,samplePos.xyz).a < 0.01) {\n"
"        samplePos += deltaDir;\n"
"        if (samplePos.a > len) return;\n"
"    }\n"
"    samplePos -= deltaDir;\n"
"}\n"
"vec4 applyClip(vec3 dir, inout vec4 samplePos, inout float len) {\n"
"    float cdot = dot(dir,clipPlane.xyz);\n"
"    if  ((clipPlane.a > 1.0) || (cdot == 0.0)) return samplePos;\n"
"    bool frontface = (cdot > 0.0);\n"
"    float dis = (-clipPlane.a - dot(clipPlane.xyz, samplePos.xyz-0.5)) / cdot;\n"
"    float  disBackFace = (-(clipPlane.a-clipThick) - dot(clipPlane.xyz, samplePos.xyz-0.5)) / cdot;\n"
"    if (((frontface) && (dis >= len)) || ((!frontface) && (dis <= 0.0))) {\n"
"        samplePos.a = len + 1.0;\n"
"        return samplePos;\n"
"    }\n"
"    if (frontface) {\n"
"        dis = max(0.0, dis);\n"
"        samplePos = vec4(samplePos.xyz+dir * dis, dis);\n"
"        len = min(disBackFace, len);\n"
"    }\n"
"    if (!frontface) {\n"
"        len = min(dis, len);\n"
"        disBackFace = max(0.0, disBackFace);\n"
"        samplePos = vec4(samplePos.xyz+dir * disBackFace, disBackFace);\n"
"    }\n"
"    return samplePos;\n"
"}\n"
"void main() {\n"
"    vec3 start = vColor;//gl_TexCoord[1].xyz;\n"
"    vec3 backPosition = GetBackPosition(start);\n"
"    vec3 dir = backPosition - start;\n"
"    float len = length(dir);\n"
"    dir = normalize(dir);\n"
"    vec4 deltaDir = vec4(dir.xyz * stepSize, stepSize);\n"
"    vec4 gradSample, colorSample;\n"
"    float bgNearest = len; //assume no hit\n"
"    vec4 colAcc = vec4(0.0,0.0,0.0,0.0);\n"
"    vec4 prevGrad = vec4(0.0,0.0,0.0,0.0);\n"
"    //background pass\n"
"    float noClipLen = len;\n"
"    vec4 samplePos = vec4(start.xyz, 0.0);\n"
"    vec4 clipPos = applyClip(dir, samplePos, len);\n"
"    float stepSizeX2 = samplePos.a + (stepSize * 2.0);\n"
"    float opacityCorrection = stepSize/sliceSize;\n"
"    //fast pass - optional\n"
"    fastPass (len, dir, intensityVol, samplePos);\n"
"    if ((textureSz.x < 1) || ((samplePos.a > len) && ( overlays < 1 ))) { //no hit\n"
"        //colAcc = vec4(0,0.0,1.0,1.0);//background\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    if (samplePos.a < clipPos.a) {\n"
"        samplePos = clipPos;\n"
"        bgNearest = clipPos.a;\n"
"        float stepSizeX2 = samplePos.a + (stepSize * 2.0);\n"
"        while (samplePos.a <= stepSizeX2) {\n"
"            colorSample = texture3D(intensityVol,samplePos.xyz);\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"            colorSample.a = clamp(colorSample.a*3.0,0.0, 1.0);\n"
"            colorSample.rgb *= colorSample.a;\n"
"            colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"            samplePos += deltaDir;\n"
"        }\n"
"    }\n"
"    //end fastpass - optional\n"
"    float ran = fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453);\n"
"    samplePos += deltaDir * ran; //jitter ray\n"
"    deltaDir = vec4(dir.xyz * stepSize, stepSize);\n"
"    vec3 defaultDiffuse = vec3(0.5, 0.5, 0.5);\n"
"    vec3 lightPositionN = normalize(lightPosition);\n"
"    vec4 gradMax  = vec4(0.0,0.0,0.0,0.0); //CT\n"
"    vec4 colorMax  = vec4(0.0,0.0,0.0,0.0); //CT\n"
"    while (samplePos.a <= len) {\n"
"        colorSample = texture3D(intensityVol,samplePos.xyz);\n"
"        if (colorSample.a > 0.0) {\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"            bgNearest = min(samplePos.a,bgNearest);\n"
"            gradSample = texture3D(gradientVol,samplePos.xyz);\n"
"            gradSample.rgb = normalize(gradSample.rgb*2.0 - 1.0);\n"
"            if (gradSample.a > gradMax.a) gradMax = gradSample; //CT\n"
"            if (colorSample.a > colorMax.a) colorMax = colorSample; //CT\n"
"            if (gradSample.a < prevGrad.a)\n"
"                gradSample.rgb = prevGrad.rgb;\n"
"            prevGrad = gradSample;\n"
"            vec3 a = colorSample.rgb * ambient;\n"
"            vec3 d = max(dot(gradSample.rgb, lightPositionN), 0.0) * colorSample.rgb * diffuse;\n"
"            float s =   specular * pow(max(dot(reflect(lightPositionN, gradSample.rgb), dir), 0.0), shininess);\n"
"            colorSample.rgb = (a + d + s) * colorSample.a;\n"
"            colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"            if ( colAcc.a > 0.95 )\n"
"                break;\n"
"        }\n"
"        samplePos += deltaDir;\n"
"    } //while samplePos.a < len\n"
"    colAcc.a = colAcc.a/0.95;\n"
" //CT\n"
" if ((samplePos.a < len) && (gradMax.a > 0.02) && (bgNearest > clipPos.a)) {\n"
"        float ambientCT = ambient * 0.65;\n"
"        float lightNormDot = dot(gradMax.rgb, lightPositionN);\n"
"        vec3 a = colorMax.rgb * ambientCT;\n"
"        vec3 d = max(lightNormDot, 0.0) * colorMax.rgb * diffuse;\n"
"        float s =   specular * pow(max(dot(reflect(lightPositionN, gradMax.rgb), dir), 0.0), shininess);\n"
"        colorMax.rgb = a + d + s;\n"
"        colAcc.rgb = mix(colAcc.rgb, colorMax.rgb,  surfaceHardness);\n"
" }\n"
"    //colAcc.a *= backAlpha;\n"
"    if ( overlays < 1 ) {\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    //overlay pass\n"
"    vec4 overAcc = vec4(0.0,0.0,0.0,0.0);\n"
"    prevGrad = vec4(0.0,0.0,0.0,0.0);\n"
"    if (overlayClip > 0)\n"
"        samplePos = clipPos;\n"
"    else {\n"
"        len = noClipLen;\n"
"        samplePos = vec4(start.xyz +deltaDir.xyz* (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453)), 0.0);\n"
"    }\n"
"    //fast pass - optional\n"
"    clipPos = samplePos;\n"
"    fastPass (len, dir, intensityOverlay, samplePos);\n"
"    if (samplePos.a > len) { //no hit\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    if (samplePos.a < clipPos.a)\n"
"        samplePos = clipPos;\n"
"    //end fastpass - optional\n"
"    float overFarthest = len;\n"
"    while (samplePos.a <= len) {\n"
"        colorSample = texture3D(intensityOverlay,samplePos.xyz);\n"
"        if (colorSample.a > 0.00) {\n"
"            if (overAcc.a < 0.3)\n"
"                overFarthest = samplePos.a;\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), stepSize/sliceSize);\n"
"            colorSample.a *=  overlayFuzzy;\n"
"            vec3 a = colorSample.rgb * ambient;\n"
"            float s =  0;\n"
"            vec3 d = vec3(0.0, 0.0, 0.0);\n"
"            //gradient based lighting http://www.mccauslandcenter.sc.edu/mricrogl/gradients\n"
"            gradSample = texture3D(gradientOverlay,samplePos.xyz); //interpolate gradient direction and magnitude\n"
"            gradSample.rgb = normalize(gradSample.rgb*2.0 - 1.0);\n"
"            //reusing Normals http://www.marcusbannerman.co.uk/articles/VolumeRendering.html\n"
"            if (gradSample.a < prevGrad.a)\n"
"                gradSample.rgb = prevGrad.rgb;\n"
"            prevGrad = gradSample;\n"
"            float lightNormDot = dot(gradSample.rgb, lightPosition);\n"
"            d = max(lightNormDot, 0.0) * colorSample.rgb * diffuse;\n"
"            s =   specular * pow(max(dot(reflect(lightPosition, gradSample.rgb), dir), 0.0), shininess);\n"
"            colorSample.rgb = a + d + s;\n"
"            colorSample.rgb *= colorSample.a;\n"
"            overAcc= (1.0 - overAcc.a) * colorSample + overAcc;\n"
"            if (overAcc.a > 0.95 )\n"
"                break;\n"
"        }\n"
"        samplePos += deltaDir;\n"
"    } //while samplePos.a < len\n"
"    overAcc.a = overAcc.a/0.95;\n"
"    float overMix = overAcc.a;\n"
"    if (((overFarthest) > bgNearest) && (colAcc.a > 0.0)) { //background (partially) occludes overlay\n"
"        float dx = (overFarthest - bgNearest)/1.73;\n"
"        dx = colAcc.a * pow(dx, overlayDepth);\n"
"        overMix *= 1.0 - dx;\n"
"    }\n"
"    colAcc.rgb = mix(colAcc.rgb, overAcc.rgb, overMix);\n"
"    colAcc.a = max(colAcc.a, overAcc.a);\n"
"    gl_FragColor = colAcc;\n"
"}";

const char *vert_default =
"#version 120\n"
"//varying vec3 TexCoord1;\n"
"varying vec3 vColor;\n"
"//uniform mat4 ModelViewProjectionMatrix;\n"
"void main() {\n"
" vColor = gl_Vertex.xyz;\n"
" //gl_TexCoord[1] = gl_MultiTexCoord1;\n"
" gl_Position = ftransform();\n"
" //gl_Position = ModelViewProjectionMatrix * vec4(gl_Vertex.xyz, 1.0);\n"
" //TexCoord1 = gl_TexCoord[1].rgb; //gl_Vertex.rgb;\n"
"}\n";

const char *frag_advanced_MR =
"#version 120\n"
"varying vec3 vColor;\n"
"uniform vec3 rayDir;\n"
"uniform int overlays;\n"
"uniform float stepSize, sliceSize;\n"
"uniform vec3 lightPosition;\n"
"uniform vec4 clipPlane;\n"
"uniform sampler3D intensityVol, gradientVol, intensityOverlay, gradientOverlay;\n"
"uniform float clipThick = 2.0;\n"
"uniform vec3 textureSz = vec3(3.0, 2.0, 1.0);\n"
"uniform float ambient = 0.8;\n"
"uniform float diffuse = 0.3;\n"
"uniform float specular = 0.1;\n"
"uniform float shininess= 20.0;\n"
"//uniform float backAlpha = 0.95;\n"
"uniform float overlayClip = 0.0;\n"
"uniform float overlayFuzzy = 0.5;\n"
"uniform float overlayDepth = 0.3;\n"
"vec3 GetBackPosition (vec3 startPosition) {\n"
" vec3 invR = 1.0 / rayDir;\n"
" vec3 tbot = invR * (vec3(0.0)-startPosition);\n"
" vec3 ttop = invR * (vec3(1.0)-startPosition);\n"
" vec3 tmax = max(ttop, tbot);\n"
" vec2 t = min(tmax.xx, tmax.yz);\n"
" return startPosition + (rayDir * min(t.x, t.y));\n"
"}\n"
"void fastPass (float len, vec3 dir, sampler3D vol, inout vec4 samplePos){\n"
"    vec4 deltaDir = vec4(dir.xyz * max(stepSize, sliceSize * 1.95), max(stepSize, sliceSize * 1.95));\n"
"    //samplePos.a = 0.0;\n"
"    while  (texture3D(intensityVol,samplePos.xyz).a < 0.01) {\n"
"        samplePos += deltaDir;\n"
"        if (samplePos.a > len) return;\n"
"    }\n"
"    samplePos -= deltaDir;\n"
"}\n"
"vec4 applyClip(vec3 dir, inout vec4 samplePos, inout float len) {\n"
"    float cdot = dot(dir,clipPlane.xyz);\n"
"    if  ((clipPlane.a > 1.0) || (cdot == 0.0)) return samplePos;\n"
"    bool frontface = (cdot > 0.0);\n"
"    float dis = (-clipPlane.a - dot(clipPlane.xyz, samplePos.xyz-0.5)) / cdot;\n"
"    float  disBackFace = (-(clipPlane.a-clipThick) - dot(clipPlane.xyz, samplePos.xyz-0.5)) / cdot;\n"
"    if (((frontface) && (dis >= len)) || ((!frontface) && (dis <= 0.0))) {\n"
"        samplePos.a = len + 1.0;\n"
"        return samplePos;\n"
"    }\n"
"    if (frontface) {\n"
"        dis = max(0.0, dis);\n"
"        samplePos = vec4(samplePos.xyz+dir * dis, dis);\n"
"        len = min(disBackFace, len);\n"
"    }\n"
"    if (!frontface) {\n"
"        len = min(dis, len);\n"
"        disBackFace = max(0.0, disBackFace);\n"
"        samplePos = vec4(samplePos.xyz+dir * disBackFace, disBackFace);\n"
"    }\n"
"    return samplePos;\n"
"}\n"
"void main() {\n"
"    vec3 start = vColor;//gl_TexCoord[1].xyz;\n"
"    vec3 backPosition = GetBackPosition(start);\n"
"    vec3 dir = backPosition - start;\n"
"    float len = length(dir);\n"
"    dir = normalize(dir);\n"
"    vec4 deltaDir = vec4(dir.xyz * stepSize, stepSize);\n"
"    vec4 gradSample, colorSample;\n"
"    float bgNearest = len; //assume no hit\n"
"    vec4 colAcc = vec4(0.0,0.0,0.0,0.0);\n"
"    vec4 prevGrad = vec4(0.0,0.0,0.0,0.0);\n"
"    //background pass\n"
"    float noClipLen = len;\n"
"    vec4 samplePos = vec4(start.xyz, 0.0);\n"
"    vec4 clipPos = applyClip(dir, samplePos, len);\n"
"    float stepSizeX2 = samplePos.a + (stepSize * 2.0);\n"
"    float opacityCorrection = stepSize/sliceSize;\n"
"    //fast pass - optional\n"
"    fastPass (len, dir, intensityVol, samplePos);\n"
"    if ((textureSz.x < 1) || ((samplePos.a > len) && ( overlays < 1 ))) { //no hit\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    if (samplePos.a < clipPos.a) {\n"
"        samplePos = clipPos;\n"
"        bgNearest = clipPos.a;\n"
"        float stepSizeX2 = samplePos.a + (stepSize * 2.0);\n"
"        while (samplePos.a <= stepSizeX2) {\n"
"            colorSample = texture3D(intensityVol,samplePos.xyz);\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"            colorSample.a = clamp(colorSample.a*3.0,0.0, 1.0);\n"
"            colorSample.rgb *= colorSample.a;\n"
"            colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"            samplePos += deltaDir;\n"
"        }\n"
"        //gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0); return;\n"
"    }\n"
"    //end fastpass - optional\n"
"    float ran = fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453);\n"
"    samplePos += deltaDir * ran; //jitter ray\n"
"    deltaDir = vec4(dir.xyz * stepSize, stepSize);\n"
"    vec3 defaultDiffuse = vec3(0.5, 0.5, 0.5);\n"
"    vec3 lightPositionN = normalize(lightPosition);\n"
"    //colAcc = vec4(0,0.2,0.0,0.0);//background\n"
"    while (samplePos.a <= len) {\n"
"        colorSample = texture3D(intensityVol,samplePos.xyz);\n"
"        if (colorSample.a > 0.0) {\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"            bgNearest = min(samplePos.a,bgNearest);\n"
"            gradSample = texture3D(gradientVol,samplePos.xyz);\n"
"            gradSample.rgb = normalize(gradSample.rgb*2.0 - 1.0);\n"
"            if (gradSample.a < prevGrad.a)\n"
"                gradSample.rgb = prevGrad.rgb;\n"
"            prevGrad = gradSample;\n"
"            vec3 a = colorSample.rgb * ambient;\n"
"            vec3 d = max(dot(gradSample.rgb, lightPositionN), 0.0) * colorSample.rgb * diffuse;\n"
"            float s =   specular * pow(max(dot(reflect(lightPositionN, gradSample.rgb), dir), 0.0), shininess);\n"
"            colorSample.rgb = (a + d + s) * colorSample.a;\n"
"            colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"            if ( colAcc.a > 0.95 )\n"
"                break;\n"
"        }\n"
"        samplePos += deltaDir;\n"
"    } //while samplePos.a < len\n"
"    colAcc.a = colAcc.a/0.95;\n"
"    //colAcc.a *= backAlpha;\n"
"    if ( overlays < 1 ) {\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    //overlay pass\n"
"    if (overlayClip > 0)\n"
"        samplePos = clipPos;\n"
"    else {\n"
"        len = noClipLen;\n"
"        samplePos = vec4(start.xyz +deltaDir.xyz* (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453)), 0.0);\n"
"    }\n"
"    //fast pass - optional\n"
"    clipPos = samplePos;\n"
"    fastPass (len, dir, intensityOverlay, samplePos);\n"
"    if (samplePos.a > len) { //no hit\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    if (samplePos.a < clipPos.a)\n"
"        samplePos = clipPos;\n"
"    //end fastpass - optional\n"
"    vec4 overAcc = vec4(0.0,0.0,0.0,0.0);\n"
"    prevGrad = vec4(0.0,0.0,0.0,0.0);\n"
"    float overFarthest = len;\n"
"    while (samplePos.a <= len) {\n"
"        colorSample = texture3D(intensityOverlay,samplePos.xyz);\n"
"        if (colorSample.a > 0.00) {\n"
"            if (overAcc.a < 0.3)\n"
"                overFarthest = samplePos.a;\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), stepSize/sliceSize);\n"
"            colorSample.a *=  overlayFuzzy;\n"
"            vec3 a = colorSample.rgb * ambient;\n"
"            float s =  0;\n"
"            vec3 d = vec3(0.0, 0.0, 0.0);\n"
"            gradSample = texture3D(gradientOverlay,samplePos.xyz); //interpolate gradient direction and magnitude\n"
"            gradSample.rgb = normalize(gradSample.rgb*2.0 - 1.0);\n"
"            if (gradSample.a < prevGrad.a)\n"
"                gradSample.rgb = prevGrad.rgb;\n"
"            prevGrad = gradSample;\n"
"            float lightNormDot = dot(gradSample.rgb, lightPosition);\n"
"            d = max(lightNormDot, 0.0) * colorSample.rgb * diffuse;\n"
"            s =   specular * pow(max(dot(reflect(lightPosition, gradSample.rgb), dir), 0.0), shininess);\n"
"            colorSample.rgb = a + d + s;\n"
"            colorSample.rgb *= colorSample.a;\n"
"            overAcc= (1.0 - overAcc.a) * colorSample + overAcc;\n"
"            if (overAcc.a > 0.95 )\n"
"                break;\n"
"        }\n"
"        samplePos += deltaDir;\n"
"    } //while samplePos.a < len\n"
"    overAcc.a = overAcc.a/0.95;\n"
"    float overMix = overAcc.a;\n"
"    if (((overFarthest) > bgNearest) && (colAcc.a > 0.0)) { //background (partially) occludes overlay\n"
"        float dx = (overFarthest - bgNearest)/1.73;\n"
"        dx = colAcc.a * pow(dx, overlayDepth);\n"
"        overMix *= 1.0 - dx;\n"
"    }\n"
"    colAcc.rgb = mix(colAcc.rgb, overAcc.rgb, overMix);\n"
"    colAcc.a = max(colAcc.a, overAcc.a);\n"
"    gl_FragColor = colAcc;\n"
"}";

const char *frag_default =
"#version 120\n"
"varying vec3 vColor;\n"
"uniform vec3 rayDir;\n"
"uniform int overlays;\n"
"uniform float stepSize, sliceSize;\n"
"//uniform vec3 lightPosition;\n"
"uniform vec4 clipPlane;\n"
"uniform sampler3D intensityVol, intensityOverlay;\n"
"uniform float clipThick = 2.0;\n"
"uniform vec3 textureSz = vec3(3.0, 2.0, 1.0);\n"
"//uniform float backAlpha = 0.95;\n"
"uniform float overlayClip = 0.0;\n"
"uniform float overlayFuzzy = 0.5;\n"
"uniform float overlayDepth = 0.3;\n"
"vec3 GetBackPosition (vec3 startPosition) {\n"
" vec3 invR = 1.0 / rayDir;\n"
" vec3 tbot = invR * (vec3(0.0)-startPosition);\n"
" vec3 ttop = invR * (vec3(1.0)-startPosition);\n"
" vec3 tmax = max(ttop, tbot);\n"
" vec2 t = min(tmax.xx, tmax.yz);\n"
" return startPosition + (rayDir * min(t.x, t.y));\n"
"}\n"
"void fastPass (float len, vec3 dir, sampler3D vol, inout vec4 samplePos){\n"
"    vec4 deltaDir = vec4(dir.xyz * max(stepSize, sliceSize * 1.95), max(stepSize, sliceSize * 1.95));\n"
"    while  (texture3D(intensityVol,samplePos.xyz).a < 0.01) {\n"
"        samplePos += deltaDir;\n"
"        if (samplePos.a > len) return;\n"
"    }\n"
"    samplePos -= deltaDir;\n"
"}\n"
"vec4 applyClip(vec3 dir, inout vec4 samplePos, inout float len) {\n"
"    float cdot = dot(dir,clipPlane.xyz);\n"
"    if  ((clipPlane.a > 1.0) || (cdot == 0.0)) return samplePos;\n"
"    bool frontface = (cdot > 0.0);\n"
"    float dis = (-clipPlane.a - dot(clipPlane.xyz, samplePos.xyz-0.5)) / cdot;\n"
"    float  disBackFace = (-(clipPlane.a-clipThick) - dot(clipPlane.xyz, samplePos.xyz-0.5)) / cdot;\n"
"    if (((frontface) && (dis >= len)) || ((!frontface) && (dis <= 0.0))) {\n"
"        samplePos.a = len + 1.0;\n"
"        return samplePos;\n"
"    }\n"
"    if (frontface) {\n"
"        dis = max(0.0, dis);\n"
"        samplePos = vec4(samplePos.xyz+dir * dis, dis);\n"
"        len = min(disBackFace, len);\n"
"    }\n"
"    if (!frontface) {\n"
"        len = min(dis, len);\n"
"        disBackFace = max(0.0, disBackFace);\n"
"        samplePos = vec4(samplePos.xyz+dir * disBackFace, disBackFace);\n"
"    }\n"
"    return samplePos;\n"
"}\n"
"void main() {\n"
"    vec3 start = vColor;//gl_TexCoord[1].xyz;\n"
"    vec3 backPosition = GetBackPosition(start);\n"
"    vec3 dir = backPosition - start;\n"
"    float len = length(dir);\n"
"    dir = normalize(dir);\n"
"    vec4 deltaDir = vec4(dir.xyz * stepSize, stepSize);\n"
"    vec4 gradSample, colorSample;\n"
"    float bgNearest = len; //assume no hit\n"
"    vec4 colAcc = vec4(0.0,0.0,0.0,0.0);\n"
"    vec4 prevGrad = vec4(0.0,0.0,0.0,0.0);\n"
"    //background pass\n"
"    float noClipLen = len;\n"
"    vec4 samplePos = vec4(start.xyz, 0.0);\n"
"    vec4 clipPos = applyClip(dir, samplePos, len);\n"
"    float stepSizeX2 = samplePos.a + (stepSize * 2.0);\n"
"    float opacityCorrection = stepSize/sliceSize;\n"
"    //fast pass - optional\n"
"    fastPass (len, dir, intensityVol, samplePos);\n"
"    if ((textureSz.x < 1) || ((samplePos.a > len) && ( overlays < 1 ))) { //no hit\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    if (samplePos.a < clipPos.a) {\n"
"        samplePos = clipPos;\n"
"        bgNearest = clipPos.a;\n"
"        float stepSizeX2 = samplePos.a + (stepSize * 2.0);\n"
"        while (samplePos.a <= stepSizeX2) {\n"
"            colorSample = texture3D(intensityVol,samplePos.xyz);\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"            colorSample.a = clamp(colorSample.a*3.0,0.0, 1.0);\n"
"            colorSample.rgb *= colorSample.a;\n"
"            colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"            samplePos += deltaDir;\n"
"        }\n"
"    }\n"
"    //end fastpass - optional\n"
"    float ran = fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453);\n"
"    samplePos += deltaDir * ran; //jitter ray\n"
"    deltaDir = vec4(dir.xyz * stepSize, stepSize);\n"
"    vec3 defaultDiffuse = vec3(0.5, 0.5, 0.5);\n"
"    //vec3 lightPositionN = normalize(lightPosition);\n"
"    //colAcc = vec4(0,0.2,0.0,0.0);//background\n"
"    while (samplePos.a <= len) {\n"
"        colorSample = texture3D(intensityVol,samplePos.xyz);\n"
"        if (colorSample.a > 0.0) {\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"            bgNearest = min(samplePos.a,bgNearest);\n"
"            colorSample.rgb *= colorSample.a;\n"
"            colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"            if ( colAcc.a > 0.95 )\n"
"                break;\n"
"        }\n"
"        samplePos += deltaDir;\n"
"    } //while samplePos.a < len\n"
"    colAcc.a = colAcc.a/0.95;\n"
"    //colAcc.a *= backAlpha;\n"
"    if ( overlays < 1 ) {\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    gl_FragColor = colAcc;\n"
"    //overlay pass\n"
"    vec4 overAcc = vec4(0.0,0.0,0.0,0.0);\n"
"    prevGrad = vec4(0.0,0.0,0.0,0.0);\n"
"    if (overlayClip > 0)\n"
"        samplePos = clipPos;\n"
"    else {\n"
"        len = noClipLen;\n"
"        samplePos = vec4(start.xyz +deltaDir.xyz* (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453)), 0.0);\n"
"    }\n"
"    //fast pass - optional\n"
"    clipPos = samplePos;\n"
"    fastPass (len, dir, intensityOverlay, samplePos);\n"
"    if (samplePos.a > len) { //no hit\n"
"        gl_FragColor = colAcc;\n"
"        return;\n"
"    }\n"
"    if (samplePos.a < clipPos.a)\n"
"        samplePos = clipPos;\n"
"    //end fastpass - optional\n"
"    float overFarthest = len;\n"
"    while (samplePos.a <= len) {\n"
"        colorSample = texture3D(intensityOverlay,samplePos.xyz);\n"
"        if (colorSample.a > 0.00) {\n"
"            if (overAcc.a < 0.3)\n"
"              overFarthest = samplePos.a;\n"
"            colorSample.a = 1.0-pow((1.0 - colorSample.a), stepSize/sliceSize);\n"
"            colorSample.a *=  overlayFuzzy;\n"
"            colorSample.rgb *= colorSample.a;\n"
"            overAcc= (1.0 - overAcc.a) * colorSample + overAcc;\n"
"            if (overAcc.a > 0.95 )\n"
"                break;\n"
"        }\n"
"        samplePos += deltaDir;\n"
"    } //while samplePos.a < len\n"
"    overAcc.a = overAcc.a/0.95;\n"
"    float overMix = overAcc.a;\n"
"    if (((overFarthest) > bgNearest) && (colAcc.a > 0.0)) { //background (partially) occludes overlay\n"
"        float dx = (overFarthest - bgNearest)/1.73;\n"
"        dx = colAcc.a * pow(dx, overlayDepth);\n"
"        overMix *= 1.0 - dx;\n"
"    }\n"
"    colAcc.rgb = mix(colAcc.rgb, overAcc.rgb, overMix);\n"
"    colAcc.a = max(colAcc.a, overAcc.a);\n"
"    gl_FragColor = colAcc;\n"
"}";


void initShaderWithFile (NII_PREFS* prefs) {
    if (prefs->glslprogramMR != 0) glDeleteShader(prefs->glslprogramMR);
    #ifdef  MY_USE_ADVANCED_GLSL
    if (prefs->glslprogramCT != 0) glDeleteShader(prefs->glslprogramCT);
    prefs->glslprogramCT=  initVertFrag(vert_default, frag_advanced_CT);
    if (prefs->advancedRender)
        prefs->glslprogramMR = initVertFrag(vert_default, frag_advanced_MR);//frag_advanced);
    else
#endif
        prefs->glslprogramMR = initVertFrag(vert_default, frag_default);
}

float kDefaultDistance = 2.25;//2.25;

/*void drawUnitQuad ()
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
}*/
/*
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
}*/

// display the final image on the screen
/*
void renderBufferToScreen (NII_PREFS* prefs)
{
    //glClearColor(1.0f, 0.1f, 0.0f, 1.0f );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    GLenum error = glGetError();
    
    glLoadIdentity();
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D,prefs->finalImage);
    //use next line instead of previous to illustrate one-pass rendering
    //glBindTexture(GL_TEXTURE_2D,prefs->backFaceBuffer);
    //reshapeOrtho(prefs->renderLeft, prefs->renderBottom, prefs->renderWid, prefs->renderHt);
    //reshapeOrtho(prefs->renderLeft - prefs->scrnOffsetX, prefs->renderBottom - prefs->scrnOffsetY, prefs->renderWid, prefs->renderHt);
    
    error = glGetError();
    if (error) NSLog(@"rayCasting 101 error %d\n", error);
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
    //glCullFace(GL_FRONT);
    glCullFace(GL_BACK);
    glMatrixMode(GL_MODELVIEW);
    glScalef(prefs->TexScale[1],prefs->TexScale[2],prefs->TexScale[3]);
    glBindTexture(GL_TEXTURE_3D, 0);
    drawQuads(1.0,1.0,1.0);
    glDisable(GL_CULL_FACE);
}
*/

float lerp (float p1, float p2, float frac)
{
    return round(p1 + frac * (p2 - p1));
}//linear interpolation

float computeStepSize (int quality1to4,  NII_PREFS* prefs) {
    float q = MAX(quality1to4 - 1.0, 0.0);
    q = MIN(q, 4);
    float slices = (float) prefs->renderSlices;
    float f = lerp(slices*0.4,slices, q/4.0);
    //NSLog(@"%g %g %g -> %g", slices*0.4, slices*1.0, q/4.0, f);
    if (f < 10.0) f = 10.0;
    //NSLog(@"%d %d -> %g", quality1to5, prefs->renderSlices, 1.0/f);
    return 1.0/f;
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
    if (prefs->clipDepth < 1)
        lD = 2.0;
    else
        lD = 0.5-(prefs->clipDepth/1000.0);
    uniform4fv("clipPlane",-lX,-lY,-lZ,lD, prefs);
    //uniform1f( "clipPlaneDepth", lD, prefs);
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
/*
void rayCasting (NII_PREFS* prefs) {
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, prefs->finalImage, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    if (prefs->colorScheme >= 16)
        prefs->glslprogramCur = prefs->glslprogramCT;
    else
        prefs->glslprogramCur = prefs->glslprogramMR;
    glUseProgram(prefs->glslprogramCur);
    // glUseProgramObjectARB(prefs->glslprogram);
    //glActiveTexture( GL_TEXTURE0 );
    //glBindTexture(GL_TEXTURE_2D, prefs->backFaceBuffer);
    uniform1i( "intensityVol", 1, prefs );
    glActiveTexture( GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    #ifdef  MY_USE_ADVANCED_GLSL
    if (prefs->advancedRender) {
        uniform1i( "gradientVol",2, prefs );
        glActiveTexture( GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
        uniform1i( "gradientOverlay",4, prefs );
        uniform1i( "overlays",prefs->numOverlay, prefs );
        uniform1i( "intensityOverlay",3, prefs );
        if (prefs->numOverlay > 0) {
            glActiveTexture( GL_TEXTURE3);
            glBindTexture(GL_TEXTURE_3D, prefs->intensityOverlay3D);
            glActiveTexture( GL_TEXTURE4);
            glBindTexture(GL_TEXTURE_3D, prefs->gradientOverlay3D);
        } else {
            glActiveTexture( GL_TEXTURE3);
            glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
            glActiveTexture( GL_TEXTURE4);
            glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
        }
    } else
    #endif
    //TO DO: ray Dir,
    uniform1i( "backFace", 0, prefs );		// backFaceBuffer -> texture0
    //uniform3fv("clearColor",prefs->backColor[0],prefs->backColor[1],prefs->backColor[2], prefs);
    clipUniforms(prefs);
    uniform3fv("textureSz",prefs->voxelDim[1],prefs->voxelDim[2],prefs->voxelDim[3], prefs);
    //uniform1i( "loops",(2*prefs->renderSlices), prefs); //provide as uniform to allow unrolled loops
    lightUniforms(prefs);
    uniform1f( "sliceSize", 1.0/(float)prefs->renderSlices, prefs );
    //uniform1f( "stepSize", computeStepSize(prefs->rayCastQuality1to4, prefs), prefs );
    uniform1f( "stepSize", computeStepSize(3, prefs), prefs );
    //uniform1f( "viewHeight", prefs->renderHt , prefs);
    //uniform1f( "viewWidth", prefs->renderWid, prefs );
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glMatrixMode(GL_MODELVIEW);
    glScalef(1.0,1.0,1.0);
    drawQuads(1.0,1.0,1.0);
    glEnable (GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glUseProgram(0);
    glActiveTexture( GL_TEXTURE0 );

}*/

void MakeCube(float sz)
{
    float sz2;
    sz2 = sz;
    glColor4f(0.2,0.2,0.2,1);
    //GLuint idx = glGenLists(1);
    //glNewList(idx, GL_COMPILE);
    float t = 0.2*sz; //thickness
    float t2 = t / 2.0;
    float m = 0.55*sz; //marginLR
    float mv = 0.3*sz; //marginTB

    // Bottom side
    glBegin(GL_QUADS);
    glVertex3f(-sz, -sz, -sz2);
    glVertex3f(-sz, sz, -sz2);
    glVertex3f(sz, sz, -sz2);
    glVertex3f(sz, -sz, -sz2);
    glEnd();
    //Bottom side "I"
    glColor4f(0,0,0,1);
    glBegin(GL_QUADS); //I
    glVertex3f(t2, -sz+mv, -sz2);
    glVertex3f(-t2, -sz+mv, -sz2);
    glVertex3f(-t2, sz-mv, -sz2);
    glVertex3f(t2, sz-mv, -sz2);
    glEnd();
    // Top side
    glColor4f(0.8,0.8,0.8,1);
    glBegin(GL_QUADS);
    glVertex3f(-sz, -sz, sz2);
    glVertex3f(sz, -sz, sz2);
    glVertex3f(sz, sz, sz2);
    glVertex3f(-sz, sz, sz2);
    glEnd();
    //Top side "S"
    glColor4f(0,0,0,1);
    glBegin(GL_QUADS); //S
    glVertex3f(sz-m-t, -sz+mv, sz2);
    glVertex3f(sz-m-t, -sz+mv+t, sz2);
    glVertex3f(-sz+m, -sz+mv+t, sz2);
    glVertex3f(-sz+m, -sz+mv, sz2);
    
    glVertex3f(sz-m-t, -t2, sz2);
    glVertex3f(sz-m-t, t2, sz2);
    glVertex3f(-sz+m+t, t2, sz2);
    glVertex3f(-sz+m+t, -t2, sz2);
    
    glVertex3f(sz-m, sz-mv-t, sz2);
    glVertex3f(sz-m, sz-mv, sz2);
    glVertex3f(-sz+m+t, sz-mv, sz2);
    glVertex3f(-sz+m+t, sz-mv-t, sz2);
    
    glVertex3f(-sz+m+t, 0-t2, sz2);
    glVertex3f(-sz+m+t, sz-mv, sz2);
    glVertex3f(-sz+m, sz-mv-t, sz2);
    glVertex3f(-sz+m, 0+t2, sz2);

    glVertex3f(sz-m, -sz+mv+t, sz2);
    glVertex3f(sz-m, -t2, sz2);
    glVertex3f(sz-m-t, t2, sz2);
    glVertex3f(sz-m-t, -sz+mv, sz2);
    glEnd();
    
    // Front side
    glColor4f(0,0,0.65,1);
    glBegin(GL_QUADS);
    glVertex3f(-sz, sz2, -sz);
    glVertex3f(-sz, sz2, sz);
    glVertex3f(sz, sz2, sz);
    glVertex3f(sz, sz2, -sz);
    glEnd();
    
    //A
    glColor4f(0.0,0.0,0.0,1);
    glBegin(GL_QUADS);


    glVertex3f(-sz+m, sz2, -sz+mv);
    glVertex3f(-t2, sz2, sz-mv);
    glVertex3f(t2, sz2, sz-mv);
    glVertex3f(-sz+m+t, sz2, -sz+mv);

    glVertex3f(sz-m, sz2, -sz+mv);
    glVertex3f(sz-m-t, sz2, -sz+mv);
    glVertex3f(-t2, sz2, sz-mv);
    glVertex3f(t2, sz2, sz-mv);
    
    glVertex3f(-sz+m+t, sz2, -t-t2);
    glVertex3f(-sz+m+t, sz2, -t2);
    glVertex3f(sz-m-t, sz2, -t2);
    glVertex3f(sz-m-t, sz2, -t-t2);
    glEnd();
    // Back side
    glColor4f(0.35,0,0.35,1);
    glBegin(GL_QUADS);
    glVertex3f(-sz, -sz2, -sz);
    glVertex3f(sz, -sz2, -sz);
    glVertex3f(sz, -sz2, sz);
    glVertex3f(-sz, -sz2, sz);
    glEnd();
    //P
    glColor4f(0.0,0.0,0.0,1);
    glBegin(GL_QUADS);
    glVertex3f(-sz+m, -sz2, -sz+mv);
    glVertex3f(-sz+m+t, -sz2, -sz+mv);
    glVertex3f(-sz+m+t, -sz2, sz-mv);
    glVertex3f(-sz+m, -sz2, sz-mv);
    
    glVertex3f(sz-m-t, -sz2, -t2);
    glVertex3f(sz-m, -sz2, -t2+t);
    glVertex3f(sz-m, -sz2, sz-mv-t);
    glVertex3f(sz-m-t, -sz2, sz-mv);

    glVertex3f(-sz+m, -sz2, sz-mv-t);
    glVertex3f(sz-m-t, -sz2, sz-mv-t);
    glVertex3f(sz-m-t, -sz2, sz-mv);
    glVertex3f(-sz+m, -sz2, sz-mv);

    glVertex3f(-sz+m, -sz2, -t2);
    glVertex3f(sz-m-t, -sz2, -t2);
    glVertex3f(sz-m-t, -sz2, t2);
    glVertex3f(-sz+m, -sz2, t2);

    glEnd();
    
    glColor4f(0.7,0,0,1);
    glBegin(GL_QUADS);
    // Left side
    glVertex3f(-sz2, -sz, -sz);
    glVertex3f(-sz2, -sz, sz);
    glVertex3f(-sz2, sz, sz);
    glVertex3f(-sz2, sz, -sz);
    glEnd();
    // L
    glColor4f(0,0,0,1);
    glBegin(GL_QUADS);
    glVertex3f(-sz2, sz-m, -sz+mv);
    glVertex3f(-sz2, sz-m-t, -sz+mv);
    glVertex3f(-sz2, sz-m-t, sz-mv);
    glVertex3f(-sz2, sz-m, sz-mv);

    glVertex3f(-sz2, -sz+m, -sz+mv);
    glVertex3f(-sz2, -sz+m, -sz+mv+t);
    glVertex3f(-sz2, sz-m-t, -sz+mv+t);
    glVertex3f(-sz2, sz-m-t, -sz+mv);
    glEnd();
    // Right side
    glColor4f(0,0.6,0,1);
    glBegin(GL_QUADS);
    glVertex3f(sz2, -sz, -sz);
    glVertex3f(sz2, sz, -sz);
    glVertex3f(sz2, sz, sz);
    glVertex3f(sz2, -sz, sz);
    glEnd();
    // R
    glColor4f(0,0,0,1);
    glBegin(GL_QUADS);
    glVertex3f(sz2, -sz+m+t, -sz+mv);
    glVertex3f(sz2, -sz+m+t, sz-mv);
    glVertex3f(sz2, -sz+m, sz-mv);
    glVertex3f(sz2, -sz+m, -sz+mv);

    glVertex3f(sz2, -sz+m, sz-mv-t);
    glVertex3f(sz2, sz-m, sz-mv-t);
    glVertex3f(sz2, sz-m-t, sz-mv);
    glVertex3f(sz2, -sz+m, sz-mv);
    
    glVertex3f(sz2, -sz+m, -t2);
    glVertex3f(sz2, sz-m-t, -t2);
    glVertex3f(sz2, sz-m, t2);
    glVertex3f(sz2, -sz+m, t2);

    glVertex3f(sz2, sz-m, t2);
    glVertex3f(sz2, sz-m, sz-mv-t);
    glVertex3f(sz2, sz-m-t, sz-mv-t);
    glVertex3f(sz2, sz-m-t, t2);
    
    glVertex3f(sz2, sz-m, -sz+mv);
    glVertex3f(sz2, sz-m-t, -t2);
    glVertex3f(sz2, sz-m-t-t, -t2);
    glVertex3f(sz2, sz-m-t, -sz+mv);

    glEnd();
}

void DrawCube (NII_PREFS* prefs)//Enter2D = reshapeGL
{
    glViewport(prefs->scrnOffsetX, prefs->scrnOffsetY, prefs->scrnWid, prefs->scrnHt);
    glEnable(GL_CULL_FACE);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    float mx = prefs->renderWid;
    if (mx > prefs->renderHt) mx = prefs->renderWid;
    mx = mx *0.04f;
    glOrtho(0, prefs->scrnWid, 0, prefs->scrnHt,-mx*2, mx*2);
    //glOrtho(0, width, 0, height,-10, 10);//gluOrtho2D(0, width, 0, height);
    //glEnable(GL_DEPTH_TEST);
    glDisable(GL_DEPTH_TEST);
    glDisable (GL_LIGHTING);
    glDisable (GL_BLEND);
    glTranslatef(prefs->renderLeft+ 1.8*mx,1.8*mx,-mx);
    glRotatef(90-prefs->renderElevation,-1,0,0);
    glRotatef(prefs->renderAzimuth,0,0,1);
    MakeCube(mx);
    glDisable(GL_CULL_FACE);
    //glDisable(GL_DEPTH_TEST);
}

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
}

void loadCube (NII_PREFS* prefs) { //TODO draw cube
    float vtx[24]  = {
          0,0,0,
          0,1,0,
          1,1,0,
          1,0,0,
          0,0,1,
          0,1,1,
          1,1,1,
          1,0,1
    };
    float idx[14] = {0,1,3,2,6,1,5,4, 6,7,3, 4, 0, 1}; //reversed winding
    if (prefs->dlBox3D != 0) glDeleteLists(prefs->dlBox3D, 1);
    prefs->dlBox3D = glGenLists(1);
    glNewList(prefs->dlBox3D, GL_COMPILE);
    glBegin(GL_TRIANGLE_STRIP);
    int nface = 14;
    for (int i = 0; i < nface; i++) {
        int v = idx[i];
        glVertex3f(vtx[v*3], vtx[(v*3)+1], vtx[(v*3)+2]);
    }
    glEnd();
    glEndList();
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


/*
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
*/
void resize2(int wx, int hx, NII_PREFS* prefs)
{
    int kMaxDistance = 40.0;
    float whratio,scale, w, h;
    w = wx;
    h = hx;
    if (h == 0) h = 1;
    //glViewport(prefs->scrnOffsetX,prefs->scrnOffsetY, w, h);
    glViewport(prefs->scrnOffsetX+prefs->renderLeft, prefs->scrnOffsetY+prefs->renderBottom, prefs->renderWid, prefs->renderHt);
    //glViewport(prefs->scrnOffsetX,prefs->scrnOffsetY, w, h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
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

/*
void ReportMat (mat44 m) {
    NSLog(@"m=[%g %g %g; %g %g %g; %g %g %g]",
          m.m[0][0],m.m[0][1],m.m[0][2],
          m.m[1][0],m.m[1][1],m.m[1][2],
          m.m[2][0],m.m[2][1],m.m[2][2]);
}

void ReportVec (vec4 v) {
    NSLog(@"v=[%g %g %g %g]",
          v.v[0],v.v[1],v.v[2],v.v[3]);
}*/

mat44 RotateX(float deg, mat44 m) {
    mat44 r;
    float radx = deg * M_PI / 180.0;
    float s = sin(radx);
    float c = cos(radx);
    //NSLog(@"%g %g %g %g", deg, radx, s, c);
    LOAD_MAT44(r,1,0,0,0, 0,c,-s,0, 0,s,c,0);
    return nifti_mat44_mul( m , r );
}

/*mat44 RotateY(float deg, mat44 m) {
    mat44 r;
    float radx = deg * M_PI / 180.0;
    float s = sin(radx); //0.374
    float c = cos(radx); //0.927
    //NSLog(@"?? %g %g %g %g", deg, radx, s, c);
    LOAD_MAT44(r,c,0,s,0, 0,1,0,0, -s,0,c,0);
    return nifti_mat44_mul( m , r );
}*/

mat44 RotateZ(float deg, mat44 m) {
    mat44 r;
    float radx = deg * M_PI / 180.0;
    float s = sin(radx); //0.374
    float c = cos(radx); //0.927
    //NSLog(@"?? %g %g %g %g", deg, radx, s, c);
    LOAD_MAT44(r,c,-s,0,0, s,c,0,0, 0,0,1,0);
    return nifti_mat44_mul( m , r );
}

vec4 addFuzz(vec4 v) {
    float kEPS = 0.0001;
    vec4 ret = v;
    if (fabs(v.v[0]) < kEPS) ret.v[0] = kEPS;
    if (fabs(v.v[1]) < kEPS) ret.v[1] = kEPS;
    if (fabs(v.v[2]) < kEPS) ret.v[2] = kEPS;
    if (fabs(v.v[3]) < kEPS) ret.v[3] = kEPS;
    return ret;
}

void drawBox(NII_PREFS* prefs) {
    //initShaderWithFile(prefs);
    if (prefs->dlBox3D == 0) loadCube(prefs);
    //dbug
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    resize2(prefs->renderWid, prefs->renderHt, prefs);
    //glViewport(prefs->scrnOffsetX, prefs->scrnOffsetY, prefs->scrnWid, prefs->scrnHt);
    //glClearColor(prefs->backColor[0],prefs->backColor[1],prefs->backColor[2], 0.0);
    //glClearColor(0.5,0.5,0.6, 0.2);
    //glClear(GL_DEPTH_BUFFER_BIT);
    //glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    mat44 m;
    LOAD_MAT44(m,1,0,0,0, 0,1,0,0, 0,0,1, 0);
    //float azi = 110;
    //float elev = 30;
    //glRotatef(90-prefs->renderElevation,-1,0,0);
    //glRotatef(prefs->renderAzimuth,0,0,1);
    mat44 r = RotateX(-(90-prefs->renderElevation),m);
    //ReportMat(r);
    m = RotateZ(prefs->renderAzimuth,r);
    mat44 mscale;
    //NSLog(@"scale %g %g %g", prefs->TexScale[1],prefs->TexScale[2],prefs->TexScale[3]);
    LOAD_MAT44(mscale,prefs->TexScale[1],0,0,0, 0,prefs->TexScale[2],0,0, 0,0,prefs->TexScale[3], 0);
    //modelMatrix *= TMat4.Scale(0.80859375, 1, 0.83984375);//
    m = nifti_mat44_mul(m,mscale);
    //ReportMat(m);
    r = nifti_mat44_inverse(m);
    vec4 rayDir = setVec4(0,0,-1);
    rayDir = nifti_vect44mat44_mul(rayDir, r );
    rayDir.v[3] = 0.0;
    rayDir = nifti_vect44_norm(rayDir);
    rayDir = addFuzz(rayDir);
    //ReportVec(rayDir);
    //glDisable (GL_BLEND);
    glTranslatef(0,0,-prefs->renderDistance*2); //fails with close zoom - unit cube
    glTranslatef(0,0,1.75); //make sure we do not clip a corner: unit cube so sqrt(3) = 1.732
    glRotatef(90-prefs->renderElevation,-1,0,0);
    glRotatef(prefs->renderAzimuth,0,0,1);
    glTranslatef(-prefs->TexScale[1]/2,-prefs->TexScale[2]/2,-prefs->TexScale[3]/2);
    glMatrixMode(GL_MODELVIEW);
    glScalef(prefs->TexScale[1],prefs->TexScale[2],prefs->TexScale[3]);
    //initShaderWithFile(prefs);
    //NSLog(@"<<<< %d %d", prefs->intensityTexture3D, prefs->gradientTexture3D);
    glEnable(GL_CULL_FACE);
    
    glEnable (GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    //glCullFace(GL_FRONT);
    glCullFace(GL_BACK);
    glEnable (GL_TEXTURE_3D);
    if (prefs->colorScheme >= 16)
        prefs->glslprogramCur = prefs->glslprogramCT;
    else
        prefs->glslprogramCur = prefs->glslprogramMR;
    glUseProgram(prefs->glslprogramCur);
    uniform1i( "intensityVol", 1, prefs );
    glActiveTexture( GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    #ifdef  MY_USE_ADVANCED_GLSL
    uniform1i( "overlays",prefs->numOverlay, prefs );
    uniform1i( "intensityOverlay",3, prefs );
    glActiveTexture( GL_TEXTURE3);
    if (prefs->numOverlay > 0) {
        glBindTexture(GL_TEXTURE_3D, prefs->intensityOverlay3D);
    } else {
        glBindTexture(GL_TEXTURE_3D, prefs->intensityTexture3D);
    }
    if (prefs->advancedRender) {
        uniform1i( "gradientVol",2, prefs );
        glActiveTexture( GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
        uniform1i( "gradientOverlay",4, prefs );
        glActiveTexture( GL_TEXTURE4);
        if (prefs->numOverlay > 0) {
            glBindTexture(GL_TEXTURE_3D, prefs->gradientOverlay3D);
        } else {
            glBindTexture(GL_TEXTURE_3D, prefs->gradientTexture3D);
        }
    }
    #endif
    clipUniforms(prefs);
    uniform3fv("rayDir",rayDir.v[0], rayDir.v[1], rayDir.v[2], prefs);//<<<
    uniform3fv("textureSz",prefs->voxelDim[1],prefs->voxelDim[2],prefs->voxelDim[3], prefs);
    lightUniforms(prefs);
    uniform1f( "sliceSize", 1.0/(float)prefs->renderSlices, prefs );
    uniform1f( "stepSize", computeStepSize(3, prefs), prefs );
    glCallList(prefs->dlBox3D);
    glUseProgram(0);
    glDisable(GL_CULL_FACE);
    glActiveTexture( GL_TEXTURE0 ); //this can be called in rayCasting, but MUST be called before 2D can be done
    GLenum error = glGetError();
    if (error) NSLog(@"drawBox init error %d\n", error);
    glDisable (GL_BLEND);
    glDisable (GL_TEXTURE_3D);
}
            
void redrawRender (NII_PREFS* prefs)  //DisplayGL
{
    //GLenum stat = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    //if (stat != GL_FRAMEBUFFER_COMPLETE) return;
    //GLenum error = glGetError();
    //if (error) NSLog(@"redrawRender init error %d\n", error);
    
    if ((prefs->renderHt < 1) || (prefs->renderWid < 1))
        return;
    //glDisable (GL_TEXTURE_3D);//this is critical!
    #ifdef  MY_USE_ADVANCED_GLSL
    doShaderBlurSobel (prefs);
    #endif
    //glDisable (GL_TEXTURE_3D);//this is critical!
    glActiveTexture( GL_TEXTURE0 ); //this can be called in rayCasting, but MUST be called before 2D can be done
 
    drawBox(prefs);
    
    if (prefs->showCube)
        DrawCube(prefs);
}

void initTRayCast (NII_PREFS* prefs)
{
    //prefs->perspective = FALSE;
    prefs->TexScale[1] = 1;
    prefs->TexScale[2] = 1;
    prefs->TexScale[3] = 1;
    //prefs->showGradient = 0;
    prefs->rayCastQuality1to4 = 3;
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
    prefs->glslprogramMR = 0;
    prefs->glslprogramCT = 0;
    prefs->dlBox3D = 0;
    prefs->glslprogramCur = 0;
    //prefs->finalImage = 0;
    //prefs->renderBuffer = 0;
    //prefs->frameBuffer = 0;
    //prefs->backFaceBuffer = 0;
    prefs->renderLeft = 0;
    prefs->renderBottom = 0;
    prefs->displayModeGL = GL_2D_AND_3D; //options: GL_2D_AND_3D GL_2D_ONLY GL_3D_ONLY
}//initTRayCast
