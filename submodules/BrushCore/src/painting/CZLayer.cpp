
///  \file CZLayer.cpp
///  \brief This is the file implements the class CZLayer.
///
///
///
///  \version	1.0.0
///	 \author	Charly Zhang<chicboi@hotmail.com>
///  \date		2014-10-15
///  \note

#include "CZLayer.h"
#include "../CZUtil.h"
#include "CZPainting.h"
#include "../CZActiveState.h"
#include "../CZDefine.h"
#include "CZTypedData.h"
#include <string>

#define MAX_THUMBNAIL_DIMMENSION 360

using namespace std;

static string CZVisibleKey = "visible";
static string CZLockedKey = "locked";
static string CZOpacityKey = "opacity";
static string CZImageDataKey = "layerImage";

CZPaintingFragment::CZPaintingFragment(const CZPaintingFragment &other) {
    data = new CZImage();
    bounds = CZRect();
    data = (*other.data).copy();
    bounds.size.width = other.bounds.size.width;
    bounds.size.height = other.bounds.size.height;
    bounds.origin.x = other.bounds.origin.x;
    bounds.origin.y = other.bounds.origin.y;
}

CZLayer::CZLayer(CZPainting* paiting_) : ptrPainting(paiting_)
{
    visible = true;
    alphaLocked = false;
    locked =  false;
    colorBalance = NULL;
    hueSaturation = NULL;
    clipWhenTransformed = false;
    ptrGLContext = NULL;
    transformMat = CZAffineTransform::makeIdentity();
    
    blendMode = kBlendModeNormal;
    opacity = 1.0f;
    isSaved = kSaveStatusUnsaved;
    image = NULL;
    myTexture = NULL;
    hueChromaLuma = NULL;
    
    thumbnailImg = NULL;
    
    if (ptrPainting)
    {
        ptrGLContext = ptrPainting->getGLContext();
        myTexture = ptrPainting->generateTexture(image);
        hueChromaLuma = ptrPainting->generateTexture();
    }
    
    uuid = CZUtil::generateUUID();
    
    undoFragment = undoFragment_1 = undoFragment_2 = undoFragment_3 = undoFragment_4 = undoFragment_5 = undoFragment_6 = undoFragment_7 = undoFragment_8 = undoFragment_9 = NULL;
    redoFragment = redoFragment_1 = redoFragment_2 = redoFragment_3 = redoFragment_4 = redoFragment_5 = redoFragment_6 = redoFragment_7 = redoFragment_8 = redoFragment_9 = NULL;
    undo_ind = 0;
    redo_ind = 0;
    didUndo  = false;
    
    canRedo = canUndo = false;
}
CZLayer::~CZLayer()
{
    ptrGLContext->setAsCurrent();
    delete myTexture;
    delete hueChromaLuma;
    
    if(image) { delete image; image = NULL;}
    if(colorBalance) { delete colorBalance; colorBalance = NULL;}
    if(hueSaturation) { delete hueSaturation; hueSaturation = NULL;}
    if(uuid)	{	delete []uuid; uuid = NULL;	}
    clearThumbnailImage();
    if (undoFragment) { delete undoFragment; undoFragment = NULL; }
    if (undoFragment_1) { delete undoFragment_1; undoFragment_1 = NULL; }
    if (undoFragment_2) { delete undoFragment_2; undoFragment_2 = NULL; }
    if (undoFragment_3) { delete undoFragment_3; undoFragment_3 = NULL; }
    if (undoFragment_4) { delete undoFragment_4; undoFragment_4 = NULL; }
    if (undoFragment_5) { delete undoFragment_5; undoFragment_5 = NULL; }
    if (undoFragment_6) { delete undoFragment_6; undoFragment_6 = NULL; }
    if (undoFragment_7) { delete undoFragment_7; undoFragment_7 = NULL; }
    if (undoFragment_8) { delete undoFragment_8; undoFragment_8 = NULL; }
    if (undoFragment_9) { delete undoFragment_9; undoFragment_9 = NULL; }
    if (redoFragment) { delete redoFragment; redoFragment = NULL; }
    if (redoFragment_1) { delete redoFragment_1; redoFragment_1 = NULL; }
    if (redoFragment_2) { delete redoFragment_2; redoFragment_2 = NULL; }
    if (redoFragment_3) { delete redoFragment_3; redoFragment_3 = NULL; }
    if (redoFragment_4) { delete redoFragment_4; redoFragment_4 = NULL; }
    if (redoFragment_5) { delete redoFragment_5; redoFragment_5 = NULL; }
    if (redoFragment_6) { delete redoFragment_6; redoFragment_6 = NULL; }
    if (redoFragment_7) { delete redoFragment_7; redoFragment_7 = NULL; }
    if (redoFragment_8) { delete redoFragment_8; redoFragment_8 = NULL; }
    if (redoFragment_9) { delete redoFragment_9; redoFragment_9 = NULL; }
    undo_ind = 0;
    redo_ind = 0;
}

/// 图层的图像数据
CZImage *CZLayer::imageData()
{
    CZRect bounds = ptrPainting->getBounds();
    return imageDataInRect(bounds);
}

/// 生成特定矩形区域的图像数据
CZImage *CZLayer::imageDataInRect(const CZRect &rect)
{
    if(!ptrPainting)
    {
        LOG_ERROR("ptrPainting is null\n");
        return NULL;
    }
    
    if(rect.isZeroRect()) return NULL;
    
    ptrGLContext->setAsCurrent();
    
    int w = rect.size.width;
    int h = rect.size.height;
    int x = rect.origin.x;
    int y = rect.origin.y;
    
    CZFbo fbo;
    fbo.setColorRenderBuffer(w, h);
    
    /// 开始fbo
    fbo.begin();
    
    CZSize paintingSize = ptrPainting->getDimensions();
    glViewport(0, 0, paintingSize.width, paintingSize.height);
    
    CZMat4 projMat,transMat;
    projMat.SetOrtho(0,paintingSize.width,0,paintingSize.height,-1.0f,1.0f);
    transMat.SetTranslation(-x, -y, 0);
    projMat = projMat * transMat;
    
    // use shader program
    CZShader *shader = ptrPainting->getShader("nonPremultipliedBlit");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return NULL;
    }
    
    shader->begin();
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"),1,GL_FALSE,projMat);
    glUniform1i(shader->getUniformLocation("texture"), (GLuint) 0);
    glUniform1f(shader->getUniformLocation("opacity"), 1.0f); // fully opaque
    
    glActiveTexture(GL_TEXTURE0);
    // Bind the texture to be used
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    // clear the buffer to get a transparent background
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // set up premultiplied normal blend
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
    
    CZImage *ret = fbo.produceImageForCurrentState();
    
    fbo.end();
    
    return ret;
}

/// 绘制图层
void CZLayer::basicBlit(CZMat4 &projection)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return;
    }
    
    // use shader program
    CZShader *shader = ptrPainting->getShader("blit");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    shader->begin();
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), opacity);
    
    
    // Bind the texture to be used
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    /// 配置绘制模式
    configureBlendMode();
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
}
/// 绘制图层（考虑移动转换、颜色调整等）
void CZLayer::blit(CZMat4 &projection)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return;
    }
    
    if(!transformMat.isIdentity())
    {
        blit(projection,transformMat);
        return;
    }
    
    // use shader program
    CZShader *shader = NULL;
    
    if (colorBalance)
        shader = ptrPainting->getShader("colorBalanceBlit");
    else if(hueSaturation)
        shader = ptrPainting->getShader("blitFromHueChromaLuma");
    else
        shader = ptrPainting->getShader("blit");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    shader->begin();
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), opacity);
    
    if(colorBalance)
    {
        glUniform1f(shader->getUniformLocation("redShift"), colorBalance->redShift);
        glUniform1f(shader->getUniformLocation("greenShift"), colorBalance->greenShift);
        glUniform1f(shader->getUniformLocation("blueShift"), colorBalance->blueShift);
        glUniform1i(shader->getUniformLocation("premultiply"), 1);
    }
    else if (hueSaturation)
    {
        glUniform1f(shader->getUniformLocation("hueShift"), hueSaturation->hueShift);
        glUniform1f(shader->getUniformLocation("saturationShift"), hueSaturation->saturationShift);
        glUniform1f(shader->getUniformLocation("brightnessShift"), hueSaturation->brightnessShift);
        glUniform1i(shader->getUniformLocation("premultiply"), 1);
    }
    
    // Bind the texture to be used
    glActiveTexture(GL_TEXTURE0);
    if (hueSaturation)
        glBindTexture(GL_TEXTURE_2D, hueChromaLuma->texId);
    else
        glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    /// 配置绘制模式
    configureBlendMode();
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
}
/// 叠加擦除纹理
void CZLayer::blit(CZMat4 &projection, CZTexture *maskTexture)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return;
    }
    
    if (maskTexture == NULL)
    {
        LOG_ERROR("maskTexture is NULL\n");
        return;
    }
    
    // use shader program
    CZShader *shader = ptrPainting->getShader("blitWithEraseMask");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    shader->begin();
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"),1,GL_FALSE,projection);
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), opacity);
    glUniform1i(shader->getUniformLocation("mask"), 1);
    
    // Bind the texture to be used
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, maskTexture->texId);
    
    /// 配置绘制模式
    configureBlendMode();
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
}
/// 叠加绘制纹理
void CZLayer::blit(CZMat4 &projection, CZTexture *maskTexture, CZColor &bgColor)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return;
    }
    
    if (maskTexture == NULL)
    {
        LOG_ERROR("maskTexture is NULL\n");
        return;
    }
    
    // use shader program
    CZShader *shader = ptrPainting->getShader("blitWithMask");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    shader->begin();
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), opacity);
    glUniform4f(shader->getUniformLocation("color"), bgColor.red, bgColor.green, bgColor.blue, bgColor.alpha);
    glUniform1i(shader->getUniformLocation("mask"), 1);
    glUniform1i(shader->getUniformLocation("lockAlpha"), alphaLocked);
    
    // Bind the texture to be used
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, maskTexture->texId);
    
    /// 配置绘制模式
    configureBlendMode();
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
}

/// 将绘制的笔画合并到当前图层
void CZLayer::commitStroke(CZRect &bounds, CZColor &color, bool erase, bool undoable)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL!\n");
        return;
    }
    
    if (undoable) registerUndoInRect(bounds);
    
    //ptrPainting->beginSuppressingNotifications();
    
    isSaved = kSaveStatusUnsaved;
    
    ptrGLContext->setAsCurrent();
    
    CZFbo fbo;
    fbo.setTexture(myTexture);
    
    fbo.begin();
    
    CZShader *shader = erase ? ptrPainting->getShader("compositeWithEraseMask") : ptrPainting->getShader("compositeWithMask");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    shader->begin();
    
    CZMat4 projection;
    CZSize size = ptrPainting->getDimensions();
    projection.SetOrtho(0,size.width,0,size.height,-1.0f, 1.0f);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    // temporarily turn off linear interpolation to work around "emboss" bug
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, ptrPainting->activePaintTexture->texId);
    
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1i(shader->getUniformLocation("mask"), 1);
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    glUniform1i(shader->getUniformLocation("lockAlpha"), alphaLocked);
    
    if (!erase)
    {
        glUniform4f(shader->getUniformLocation("color"), color.red, color.green, color.blue, color.alpha);
    }
    
    glBlendFunc(GL_ONE, GL_ZERO);
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    // turn linear interpolation back on
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    CZCheckGLError();
    
    fbo.end();
    
    clearThumbnailImage();
    
}

/// 调整颜色
void CZLayer::commitColorAdjustments()
{
    /*
     WDShader *shader = nil;
     
     if (self.colorBalance) {
     shader = [self.painting getShader:@"colorBalanceBlit"];
     } else if (self.hueSaturation) {
     shader = [self.painting getShader:@"blitFromHueChromaLuma"];
     } else {
     return;
     }
     
     [self modifyWithBlock:^{
     // handle viewing matrices
     GLfloat proj[16];
     // setup projection matrix (orthographic)
     mat4f_LoadOrtho(0, self.painting.width, 0, self.painting.height, -1.0f, 1.0f, proj);
     
     glUseProgram(shader.program);
     
     glActiveTexture(GL_TEXTURE0);
     if (self.hueSaturation) {
     glBindTexture(GL_TEXTURE_2D, self.hueChromaLuma);
     } else {
     glBindTexture(GL_TEXTURE_2D, self.textureName);
     }
     
     glUniform1i(shader->locationForUniform:@"texture"], 0);
     glUniformMatrix4fv(shader->locationForUniform:@"modelViewProjectionMatrix"], 1, GL_FALSE, proj);
     
     if (self.colorBalance) {
     glUniform1f(shader->:@"redShift"], colorBalance_.redShift);
     glUniform1f(shader->locationForUniform:@"greenShift"], colorBalance_.greenShift);
     glUniform1f(shader->locationForUniform:@"blueShift"], colorBalance_.blueShift);
     glUniform1i(shader->locationForUniform:@"premultiply"], 0);
     } else {
     glUniform1f(shader->locationForUniform:@"hueShift"], hueSaturation_.hueShift);
     glUniform1f(shader->locationForUniform:@"saturationShift"], hueSaturation_.saturationShift);
     glUniform1f(shader->locationForUniform:@"brightnessShift"], hueSaturation_.brightnessShift);
     glUniform1i(shader->locationForUniform:@"premultiply"], 0);
     }
     
     glBlendFunc(GL_ONE, GL_ZERO);
     
     glBindVertexArrayOES(self.painting.quadVAO);
     glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
     
     // unbind VAO
     glBindVertexArrayOES(0);
     } newTexture:NO undoBits:YES];
     
     self.colorBalance = nil;
     self.hueSaturation = nil;
     */
}

/// 合并另以图层
bool CZLayer::merge(CZLayer *layer)
{
    return true;
}

/// clear
bool CZLayer::clear()
{
    CZRect rect = ptrPainting->getBounds();
    registerUndoInRect(rect);
    
    //ptrPainting->beginSuppressingNotifications();
    
    isSaved = kSaveStatusUnsaved;
    
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL!\n");
        return false;
    }
    
    ptrGLContext->setAsCurrent();
    
    CZFbo fbo;
    fbo.setTexture(myTexture);
    
    fbo.begin();
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    fbo.end();
    
    clearThumbnailImage();
    
    return true;
}

/// 将图像经过变换后绘制
void CZLayer::renderImage(CZImage* img, CZAffineTransform &trans)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return;
    }
    
    if (img == NULL)
    {
        LOG_WARN("image is NULL!\n");
        return;
    }
    
    /// register undo fragment
    CZRect rect(0,0,img->width,img->height);
   
    CZRect newRect = trans.applyToRect(rect);
    registerUndoInRect(newRect);
    
    bool hasAlpha = img->hasAlpha;
    
    ptrGLContext->setAsCurrent();
    CZTexture *tex = CZTexture::produceFromImage(img);
    
    CZShader *shader = NULL;
    shader = hasAlpha ? ptrPainting->getShader("unPremultipliedBlit") : ptrPainting->getShader("nonPremultipliedBlit");
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    CZFbo fbo;
    fbo.setTexture(myTexture);
    
    fbo.begin();
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    shader->begin();
    
    CZMat4 projection;
    CZSize size = ptrPainting->getDimensions();
    projection.SetOrtho(0,size.width,0,size.height,-1.0f, 1.0f);
    
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), 1.0f);
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,tex->texId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    /// render image
    CZUtil::drawRect(rect,trans);
    
    shader->end();
    
    fbo.end();
    
    delete tex;
    
    CZCheckGLError();
    
    clearThumbnailImage();
}

void CZLayer::renderBackground(CZImage *img)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return;
    }
    
    if (img == NULL)
    {
        LOG_WARN("image is NULL!\n");
        return;
    }
    
    CZRect rect = ptrPainting->getBounds();
    /// register undo fragment
    registerUndoInRect(rect);
    
    bool hasAlpha = img->hasAlpha;
    
    ptrGLContext->setAsCurrent();
    CZTexture *tex = CZTexture::produceFromImage(img);
    
    CZShader *shader = NULL;
    shader = hasAlpha ? ptrPainting->getShader("unPremultipliedBlit") : ptrPainting->getShader("nonPremultipliedBlit");
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    CZFbo fbo;
    fbo.setTexture(myTexture);
    
    fbo.begin();
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    shader->begin();
    
    CZMat4 projection;
    CZSize size = ptrPainting->getDimensions();
    projection.SetOrtho(0,size.width,0,size.height,-1.0f, 1.0f);
    
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), 1.0f);
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,tex->texId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    /// render background
    
    CZAffineTransform trans = CZAffineTransform::makeIdentity();
    CZUtil::drawRect(rect,trans);

    shader->end();
    
    fbo.end();
    
    delete tex;
    
    CZCheckGLError();
    
    clearThumbnailImage();
}

/// transform layer
bool CZLayer::transform(CZAffineTransform &trans, bool undoable)
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return false;
    }
    
//    if (undoable) {
//        [self registerUndoInRect:self.painting.bounds];
//    } // otherwise assume caller is naturally invertible (flip, etc.) and handles its own undo
    
    CZFbo fbo;
    CZTexture *newTex = ptrPainting->generateTexture();
    fbo.setTexture(newTex);
    
    fbo.begin();
    
    CZShader *shader =  ptrPainting->getShader("nonPremultipliedBlit");
    
    shader->begin();
    
    CZSize paintingSize = ptrPainting->getDimensions();
    CZMat4 projMat,transMat;
    projMat.SetOrtho(0,paintingSize.width,0,paintingSize.height,-1.0f,1.0f);
    
    transMat.LoadFromAffineTransform(transformMat);
    projMat = projMat * transMat;
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"),1,GL_FALSE,projMat);
    glUniform1i(shader->getUniformLocation("texture"), (GLuint) 0);
    glUniform1f(shader->getUniformLocation("opacity"), 1.0f); // fully opaque
    
    glActiveTexture(GL_TEXTURE0);
    // Bind the texture to be used
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // set up premultiplied normal blend
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
    
    fbo.end();
    
    CZCheckGLError();
    
    delete myTexture;
    myTexture = newTex;
    
    return true;
}

CZLayer* CZLayer::duplicate()
{
    CZLayer *newLayer = new CZLayer(ptrPainting);
    
    newLayer->setVisiblility(visible);
    newLayer->setLocked(locked);
    newLayer->setAlphaLocked(alphaLocked);
    newLayer->setBlendMode(blendMode);
    newLayer->setOpacity(opacity);
    newLayer->thumbnailImg = thumbnailImg->copy();
    
    ptrGLContext->setAsCurrent();
    
    CZFbo fbo;
    fbo.setTexture(newLayer->myTexture);
    
    /// 开始fbo
    fbo.begin();
    
    CZSize paintingSize = ptrPainting->getDimensions();
    glViewport(0, 0, paintingSize.width, paintingSize.height);
    
    CZMat4 projMat;
    projMat.SetOrtho(0,paintingSize.width,0,paintingSize.height,-1.0f,1.0f);
    
    // use shader program
    CZShader *shader = ptrPainting->getShader("nonPremultipliedBlit");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return NULL;
    }
    
    shader->begin();
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"),1,GL_FALSE,projMat);
    glUniform1i(shader->getUniformLocation("texture"), (GLuint) 0);
    glUniform1f(shader->getUniformLocation("opacity"), 1.0f); // fully opaque
    
    glActiveTexture(GL_TEXTURE0);
    // Bind the texture to be used
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    glBlendFunc(GL_ONE, GL_ZERO);
    
    GL_BIND_VERTEXARRAY(ptrPainting->getQuadVAO());
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GL_BIND_VERTEXARRAY(0);
    
    shader->end();
    
    fbo.end();
    
    return newLayer;
}

void CZLayer::enableLinearInterprolation(bool flag)
{
    if (myTexture)
    {
        ptrGLContext->setAsCurrent();
        myTexture->enableLinearInterprolation(flag);
    }
}

/// 设置转换矩阵
bool CZLayer::setTransform(CZAffineTransform &trans)
{
    if(transformMat == trans) return false;
    
    transformMat = trans;
    return true;
}
/// 获取转换矩阵
CZAffineTransform& CZLayer::getTransform()
{
    return transformMat;
}
/// 设置混合模式
bool CZLayer::setBlendMode(BlendMode &bm)
{
    if(bm == blendMode) return false;
    
    blendMode = bm;
    return true;
}
/// 获取混合模式
BlendMode CZLayer::getBlendMode()
{
    return blendMode;
}
/// 设置不透明度
bool CZLayer::setOpacity(float o)
{
    if(opacity == o) return false;
    
    opacity = CZUtil::Clamp(0.0f,1.0f,o);
    return true;
}
/// 获取不透明度
float CZLayer::getOpacity()
{
    return opacity;
}
/// 设置调整颜色
bool CZLayer::setColorBalance(CZColorBalance *cb)
{
    if(cb && *cb ==  *colorBalance) return false;
    
    colorBalance = cb;
    return true;
}
/// 设置色调调整
bool CZLayer::setHueSaturation(CZHueSaturation *hs)
{
    return true;
}
/// 设置图层图像
///
///		\param img - 设置的图像
///		\ret	   - 若img不为空，则设置陈宫
///		\note 调用此函数将覆盖之前对该层的所有绘制
///             Layer own this img
bool CZLayer::setImage(CZImage *img)
{
    if(img == NULL)
    {
        LOG_ERROR("image is NULL\n");
        return false;
    }
    
    if(image) delete image;
    
    image = img;
    
    ptrGLContext->setAsCurrent();
   
    CZRect bounds = ptrPainting->getBounds();
    GLint xoffset = (GLint)bounds.getMinX();
    GLint yoffset = (GLint)bounds.getMinY();
    GLsizei width = (GLsizei)bounds.size.width;
    GLsizei height = (GLsizei)bounds.size.height;
    
    myTexture->modifyWith(image,xoffset,yoffset,width,height);

    return true;
}

/// 撤销操作
bool CZLayer::undoAction()
{
    didUndo = true;
    if (canUndo && undoFragment && undo_ind==0)
    {
        /// save redo PaintingFragment
        if (redoFragment) delete redoFragment;
        CZImage *currentImg = imageDataInRect(undoFragment->bounds);
        redoFragment = new CZPaintingFragment(*undoFragment);
        redoFragment->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment = NULL;
        if (!undoFragment_1) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_1 && undo_ind==1) {
        /// save redo PaintingFragment
        if (redoFragment_1) delete redoFragment_1;
        CZImage *currentImg = imageDataInRect(undoFragment_1->bounds);
        redoFragment_1 = new CZPaintingFragment(*undoFragment_1);
        redoFragment_1->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_1->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_1->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_1->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_1 = NULL;
        if (!undoFragment_2) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_2 && undo_ind==2) {
        /// save redo PaintingFragment
        if (redoFragment_2) delete redoFragment_2;
        CZImage *currentImg = imageDataInRect(undoFragment_2->bounds);
        redoFragment_2 = new CZPaintingFragment(*undoFragment_2);
        redoFragment_2->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_2->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_2->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_2->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_2 = NULL;
        if (!undoFragment_3) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_3 && undo_ind==3) {
        /// save redo PaintingFragment
        if (redoFragment_3) delete redoFragment_3;
        CZImage *currentImg = imageDataInRect(undoFragment_3->bounds);
        redoFragment_3 = new CZPaintingFragment(*undoFragment_3);
        redoFragment_3->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_3->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_3->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_3->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_3 = NULL;
        if (!undoFragment_4) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_4 && undo_ind==4) {
        /// save redo PaintingFragment
        if (redoFragment_4) delete redoFragment_4;
        CZImage *currentImg = imageDataInRect(undoFragment_4->bounds);
        redoFragment_4 = new CZPaintingFragment(*undoFragment_4);
        redoFragment_4->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_4->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_4->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_4->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_4 = NULL;
        if (!undoFragment_5) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_5 && undo_ind==5) {
        /// save redo PaintingFragment
        if (redoFragment_5) delete redoFragment_5;
        CZImage *currentImg = imageDataInRect(undoFragment_5->bounds);
        redoFragment_5 = new CZPaintingFragment(*undoFragment_5);
        redoFragment_5->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_5->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_5->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_5->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_5 = NULL;
        if (!undoFragment_6) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_6 && undo_ind==6) {
        /// save redo PaintingFragment
        if (redoFragment_6) delete redoFragment_6;
        CZImage *currentImg = imageDataInRect(undoFragment_6->bounds);
        redoFragment_6 = new CZPaintingFragment(*undoFragment_6);
        redoFragment_6->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_6->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_6->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_6->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_6 = NULL;
        if (!undoFragment_7) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_7 && undo_ind==7) {
        /// save redo PaintingFragment
        if (redoFragment_7) delete redoFragment_7;
        CZImage *currentImg = imageDataInRect(undoFragment_7->bounds);
        redoFragment_7 = new CZPaintingFragment(*undoFragment_7);
        redoFragment_7->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_7->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_7->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_7->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_7 = NULL;
        if (!undoFragment_8) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_8 && undo_ind==8) {
        /// save redo PaintingFragment
        if (redoFragment_8) delete redoFragment_8;
        CZImage *currentImg = imageDataInRect(undoFragment_8->bounds);
        redoFragment_8 = new CZPaintingFragment(*undoFragment_8);
        redoFragment_8->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_8->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_8->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_8->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_8 = NULL;
        if (!undoFragment_9) {
            redo_ind = undo_ind;
            undo_ind=0;
            return false;
        }
    }
    else if (canUndo && undoFragment_9 && undo_ind==9) {
        /// save redo PaintingFragment
        if (redoFragment_9) delete redoFragment_9;
        CZImage *currentImg = imageDataInRect(undoFragment_9->bounds);
        redoFragment_9 = new CZPaintingFragment(*undoFragment_9);
        redoFragment_9->data = currentImg;
        canRedo = true;
        
        /// take undo action
        GLint xoffset = (GLint)undoFragment_9->bounds.getMinX();
        GLint yoffset = (GLint)undoFragment_9->bounds.getMinY();
        
        myTexture->modifyWith(undoFragment_9->data,xoffset,yoffset);
        canUndo = true;
//        undoFragment_9 = NULL;
        redo_ind = undo_ind;
        undo_ind=0;
        return false;
    }
    else {
        redo_ind = undo_ind;
        undo_ind=0;
        return false;
    }
    redo_ind = undo_ind;
    undo_ind++;
    return true;
}

/// 重做操作
bool CZLayer::redoAction()
{
    if (canRedo && redoFragment_9 && redo_ind==9)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_9->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_9->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_9->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_9 = NULL;
    }
    else if (canRedo && redoFragment_8 && redo_ind==8)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_8->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_8->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_8->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_8 = NULL;
    }
    else if (canRedo && redoFragment_7 && redo_ind==7)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_7->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_7->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_7->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_7 = NULL;
    }
    else if (canRedo && redoFragment_6 && redo_ind==6)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_6->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_6->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_6->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_6 = NULL;
    }
    else if (canRedo && redoFragment_5 && redo_ind==5)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_5->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_5->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_5->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_5 = NULL;
    }
    else if (canRedo && redoFragment_4 && redo_ind==4)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_4->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_4->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_4->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_4 = NULL;
    }
    else if (canRedo && redoFragment_3 && redo_ind==3)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_3->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_3->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_3->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_3 = NULL;
    }
    else if (canRedo && redoFragment_2 && redo_ind==2)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_2->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_2->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_2->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_2 = NULL;
    }
    else if (canRedo && redoFragment_1 && redo_ind==1)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment_1->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment_1->bounds.getMinY();
        
        myTexture->modifyWith(redoFragment_1->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
//        redoFragment_1 = NULL;
    }
    else if (canRedo && redoFragment && redo_ind==0)
    {
        /// take redo action
        GLint xoffset = (GLint)redoFragment->bounds.getMinX();
        GLint yoffset = (GLint)redoFragment->bounds.getMinY();

        myTexture->modifyWith(redoFragment->data,xoffset,yoffset);
        canRedo = true;
        canUndo = true;
        undo_ind = redo_ind;
        redo_ind = 0;
        return false;
    }
    else {
        undo_ind = redo_ind;
        redo_ind = 0;
        return false;
    }
    undo_ind = redo_ind;
    redo_ind--;
    return true;
}

void CZLayer::resetUndoAndRedoEnvironment(int undo_i) {
    if (didUndo) {
        LOG_DEBUG("undo index:%d\n", undo_i);
        switch (undo_i) {
            case 1:{
                
                if (undoFragment_1) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_1); // copy constructor
                }
                
                
                if (undoFragment_2) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_2); // copy constructor
                }
                
                
                if (undoFragment_3) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_3); // copy constructor
                }
                
                
                if (undoFragment_4) {
                    if (undoFragment_3) {
                        delete undoFragment_3;
                    }
                    undoFragment_3 = new CZPaintingFragment(*undoFragment_4); // copy constructor
                }
                
                
                if (undoFragment_5) {
                    if (undoFragment_4) {
                        delete undoFragment_4;
                    }
                    undoFragment_4 = new CZPaintingFragment(*undoFragment_5); // copy constructor
                }
                
                
                if (undoFragment_6) {
                    if (undoFragment_5) {
                        delete undoFragment_5;
                    }
                    undoFragment_5 = new CZPaintingFragment(*undoFragment_6); // copy constructor
                }
                
                
                if (undoFragment_7) {
                    if (undoFragment_6) {
                        delete undoFragment_6;
                    }
                    undoFragment_6 = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
                
                if (undoFragment_8) {
                    if (undoFragment_7) {
                        delete undoFragment_7;
                    }
                    undoFragment_7 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_8) {
                        delete undoFragment_8;
                    }
                    undoFragment_8 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                break;
            }
            case 2:{
                
                if (undoFragment_2) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_2); // copy constructor
                }
                
                
                if (undoFragment_3) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_3); // copy constructor
                }
                
                
                if (undoFragment_4) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_4); // copy constructor
                }
                
                
                if (undoFragment_5) {
                    if (undoFragment_3) {
                        delete undoFragment_3;
                    }
                    undoFragment_3 = new CZPaintingFragment(*undoFragment_5); // copy constructor
                }
                
                
                if (undoFragment_6) {
                    if (undoFragment_4) {
                        delete undoFragment_4;
                    }
                    undoFragment_4 = new CZPaintingFragment(*undoFragment_6); // copy constructor
                }
                
                
                if (undoFragment_7) {
                    if (undoFragment_5) {
                        delete undoFragment_5;
                    }
                    undoFragment_5 = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
                
                if (undoFragment_8) {
                    if (undoFragment_6) {
                        delete undoFragment_6;
                    }
                    undoFragment_6 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_7) {
                        delete undoFragment_7;
                    }
                    undoFragment_7 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                // right move 2, so 8.9 is useless, so take duplicate undoFrame NULL
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 3:{
                
                if (undoFragment_3) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_3); // copy constructor
                }
                
                
                if (undoFragment_4) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_4); // copy constructor
                }
                
                
                if (undoFragment_5) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_5); // copy constructor
                }
                
                
                if (undoFragment_6) {
                    if (undoFragment_3) {
                        delete undoFragment_3;
                    }
                    undoFragment_3 = new CZPaintingFragment(*undoFragment_6); // copy constructor
                }
                
                
                if (undoFragment_7) {
                    if (undoFragment_4) {
                        delete undoFragment_4;
                    }
                    undoFragment_4 = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
               
                if (undoFragment_8) {
                    if (undoFragment_5) {
                        delete undoFragment_5;
                    }
                    undoFragment_5 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_6) {
                        delete undoFragment_6;
                    }
                    undoFragment_6 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                // right move 3, so 7.8.9 is useless, so take duplicate undoFrame NULL
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 4:{
                
                if (undoFragment_4) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_4); // copy constructor
                }
                
                
                if (undoFragment_5) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_5); // copy constructor
                }
                
                
                if (undoFragment_6) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_6); // copy constructor
                }
                
                
                if (undoFragment_7) {
                    if (undoFragment_3) {
                        delete undoFragment_3;
                    }
                    undoFragment_3 = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
                
                if (undoFragment_8) {
                    if (undoFragment_4) {
                        delete undoFragment_4;
                    }
                    undoFragment_4 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_5) {
                        delete undoFragment_5;
                    }
                    undoFragment_5 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                undoFragment_6 = NULL;
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 5:{
                
                if (undoFragment_5) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_5); // copy constructor
                }
                
                
                if (undoFragment_6) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_6); // copy constructor
                }
                
                
                if (undoFragment_7) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
                
                if (undoFragment_8) {
                    if (undoFragment_3) {
                        delete undoFragment_3;
                    }
                    undoFragment_3 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_4) {
                        delete undoFragment_4;
                    }
                    undoFragment_4 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                undoFragment_5 = NULL;
                undoFragment_6 = NULL;
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 6:{
                
                if (undoFragment_6) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_6); // copy constructor
                }
                
                
                if (undoFragment_7) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
                
                if (undoFragment_8) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_3) {
                        delete undoFragment_3;
                    }
                    undoFragment_3 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                undoFragment_4 = NULL;
                undoFragment_5 = NULL;
                undoFragment_6 = NULL;
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 7:{
                
                if (undoFragment_7) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_7); // copy constructor
                }
                
                
                if (undoFragment_8) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_2) {
                        delete undoFragment_2;
                    }
                    undoFragment_2 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                undoFragment_3 = NULL;
                undoFragment_4 = NULL;
                undoFragment_5 = NULL;
                undoFragment_6 = NULL;
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 8:{
                
                if (undoFragment_8) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_8); // copy constructor
                }
                
                
                if (undoFragment_9) {
                    if (undoFragment_1) {
                        delete undoFragment_1;
                    }
                    undoFragment_1 = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                undoFragment_2 = NULL;
                undoFragment_3 = NULL;
                undoFragment_4 = NULL;
                undoFragment_5 = NULL;
                undoFragment_6 = NULL;
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            case 9:{
                
                if (undoFragment_9) {
                    if (undoFragment) {
                        delete undoFragment;
                    }
                    undoFragment = new CZPaintingFragment(*undoFragment_9); // copy constructor
                }
                undoFragment_1 = NULL;
                undoFragment_2 = NULL;
                undoFragment_3 = NULL;
                undoFragment_4 = NULL;
                undoFragment_5 = NULL;
                undoFragment_6 = NULL;
                undoFragment_7 = NULL;
                undoFragment_8 = NULL;
                undoFragment_9 = NULL;
                break;
            }
            default:
                break;
        }
        
//        undoFragment = undoFragment_1 = undoFragment_2 = undoFragment_3 = undoFragment_4 = undoFragment_5 = undoFragment_6 = undoFragment_7 = undoFragment_8 = undoFragment_9 = NULL;
//        redoFragment = redoFragment_1 = redoFragment_2 = redoFragment_3 = redoFragment_4 = redoFragment_5 = redoFragment_6 = redoFragment_7 = redoFragment_8 = redoFragment_9 = NULL;
        undo_ind = 0;
        redo_ind = 0;
        didUndo  = false;
    }
}

/// 切换可见性
void CZLayer::toggleVisibility()
{
    visible = !visible;
}
/// 切换alpha锁定
void CZLayer::toggleAlphaLocked()
{
    alphaLocked = !alphaLocked;
}
/// 切换图层锁定
void CZLayer::toggleLocked()
{
    locked = !locked;
}
/// 设置可见性
void CZLayer::setVisiblility(bool flag)
{
    visible = flag;
}
/// 设置alpha锁定
void CZLayer::setAlphaLocked(bool flag)
{
    alphaLocked = flag;
}
/// 设置图层锁定
void CZLayer::setLocked(bool flag)
{
    locked = flag;
}
/// 是否被锁住图层
bool CZLayer::isLocked()
{
    return locked;
};
/// 是否被锁住alpha
bool CZLayer::isAlphaLocked()
{
    return alphaLocked;
}
/// 是否可见
bool CZLayer::isVisible()
{
    return visible;
}

/// 是否可编辑
bool CZLayer::isEditable()
{
    return (!locked && visible);
}

/// 获取编号
char *CZLayer::getUUID()
{
    return uuid;
}

/// 填充
bool CZLayer::fill(CZColor &c, CZ2DPoint &p)
{
    CZSize size = ptrPainting->getDimensions();
    if(p.x >= size.width || p.x < 0
       || p.y >= size.height || p.y <0)
    {
        LOG_ERROR("fill center is beyond the painting range!\n");
        return false;
    }
    
    /// get the original texture data
    CZImage *img = imageData();
    CZImage *inverseImg = img->modifyDataFrom((int)p.x,(int)p.y,c.red,c.green,c.blue,c.alpha,modifiedRect);
    
    /// fill the area and save undo fragment
    if(inverseImg)
    {
        ptrGLContext->setAsCurrent();
        myTexture->modifyWith(img,modifiedRect.origin.x,modifiedRect.origin.y);
        
        if (undoFragment) delete undoFragment;;
        undoFragment = new CZPaintingFragment(inverseImg,modifiedRect);
        
        canUndo = true;
    }
    
    delete img;
    
    clearThumbnailImage();
    
    return true;
}

/// get thumbnail image
CZImage* CZLayer::getThumbnailImage()
{
    if (ptrPainting == NULL)
    {
        LOG_ERROR("ptrPainting is NULL\n");
        return NULL;
    }

    if (!thumbnailImg)
    {
        // make sure the painting's context is current
        ptrGLContext->setAsCurrent();
        
        CZSize size = ptrPainting->getDimensions();
        
        float aspectRatio = size.width / size.height;
        
        GLuint width,height;
    
        // figure out the width and height of the thumbnail
        if (aspectRatio > 1.0)
        {
            width = (GLuint) MAX_THUMBNAIL_DIMMENSION;
            height = floorf(1.0 / aspectRatio * width);
        }
        else
        {
            height = (GLuint) MAX_THUMBNAIL_DIMMENSION;
            width = floorf(aspectRatio * height);
        }
        
        float s = CZActiveState::getInstance()->mainScreenScale;
        width *= s;
        height *= s;
        
        CZFbo fbo;
        fbo.setColorRenderBuffer(width, height);
        
        fbo.begin();
        
        CZShader *shader = ptrPainting->getShader("blit");
        
        shader->begin();
        
        GLsizei viewportWidth = CZUtil::Max(width, size.width);
        GLsizei viewportHeight = CZUtil::Max(height, size.height);
        glViewport(0, 0, viewportWidth, viewportHeight);
        
        // figure out the projection matrix
        CZMat4 projMat,effectiveProj,final;
        // setup projection matrix (orthographic)
        projMat.SetOrtho(0, size.width, 0, size.height, -1.0f, 1.0f);
        
        CZAffineTransform scale = CZAffineTransform::makeFromScale((float) width / viewportWidth,
                                                                   (float) height / viewportHeight);
        effectiveProj.LoadFromAffineTransform(scale);
        final = projMat * effectiveProj;
        
        glUniform1i(shader->getUniformLocation("texture"), 0);
        glUniform1f(shader->getUniformLocation("opacity"), 1.0f);
        glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, final);
        
        glActiveTexture(GL_TEXTURE0);
        // Bind the texture to be used
        glBindTexture(GL_TEXTURE_2D, myTexture->texId);
        
        // clear the buffer to get a transparent background
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        // set up premultiplied normal blend
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        
        glBindVertexArrayOES(ptrPainting->getQuadVAO());
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glBindVertexArrayOES(0);
        
        // color buffer should now have layer contents
        
        thumbnailImg = fbo.produceImageForCurrentState();
        
        CZCheckGLError();
        
        fbo.end();
    }
    
    return thumbnailImg;
}

/// 实现coding的接口
void CZLayer::update(CZDecoder *decoder_, bool deep /* = false */)
{
    /*
     // avoid setting these if they haven't changed, to prevent unnecessary notifications
     BOOL visible = [decoder decodeBooleanForKey:WDVisibleKey];
     if (visible != self.visible) {
     self.visible = visible;
     }
     BOOL locked = [decoder decodeBooleanForKey:WDLockedKey];
     if (locked != self.locked) {
     self.locked = locked;
     }
     BOOL alphaLocked = [decoder decodeBooleanForKey:WDAlphaLockedKey];
     if (alphaLocked != self.alphaLocked) {
     self.alphaLocked = alphaLocked;
     }
     
     WDBlendMode blendMode = (WDBlendMode) [decoder decodeIntegerForKey:WDBlendModeKey];
     blendMode = WDValidateBlendMode(blendMode);
     if (blendMode != self.blendMode) {
     self.blendMode = blendMode;
     }
     
     
     uuid_ = [decoder decodeStringForKey:WDUUIDKey];
     
     id opacity = [decoder decodeObjectForKey:WDOpacityKey];
     self.opacity = opacity ? [opacity floatValue] : 1.f;
     
     if (deep) {
     [decoder dispatch:^{
     loadedImageData_ = [[decoder decodeDataForKey:WDImageDataKey] decompress];
     self.isSaved = kWDSaveStatusSaved;
     }];
     }
     */
}
void CZLayer::encode(CZCoder *coder_, bool deep /* = false */)
{
    if(coder_ == nullptr)
    {
        LOG_ERROR("coder is NULL\n");
        return;
    }
    
    coder_->encodeBoolean(visible, CZVisibleKey);
    coder_->encodeBoolean(locked, CZLockedKey);
    
    if (opacity != 1.f) coder_->encodeFloat(opacity, CZOpacityKey);
    
    if (deep)
    {
        CZImage *img = imageData();
        coder_->encodeImage(img, CZImageDataKey);
        delete img;
//        CZTypedData *typedData = CZTypedData::produceTypedData(img, "image/brushes-layer", true, kSaveStatusSaved);
//        coder_->encodeDataProvider(typedData, CZImageDataKey);
    }
}

/// 配置混合模式
void CZLayer::configureBlendMode()
{
    switch (blendMode) 
    {
        case kBlendModeMultiply:
            glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
            break;
        case kBlendModeScreen:
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);
            break;
        case kBlendModeExclusion:
            glBlendFuncSeparate(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            break;
        default: // WDBlendModeNormal
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // premultiplied blend
            break;
    }
}

/// 将纹理转换后绘制			
void CZLayer::blit(CZMat4 &projection, const CZAffineTransform &trans)
{
    // use shader program
    CZShader *shader = ptrPainting->getShader("blit");
    
    if (shader == NULL)
    {
        LOG_ERROR("cannot find the assigned shader!\n");
        return;
    }
    
    shader->begin();
    
    glUniformMatrix4fv(shader->getUniformLocation("mvpMat"), 1, GL_FALSE, projection);
    glUniform1i(shader->getUniformLocation("texture"), 0);
    glUniform1f(shader->getUniformLocation("opacity"), opacity);
    
    // Bind the texture to be used
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, myTexture->texId);
    
    /// 配置绘制模式
    configureBlendMode();
    
    CZSize size = ptrPainting->getDimensions();
    CZRect rect(0,0,size.width,size.height);
    
    if (clipWhenTransformed) 
    {
        glEnable(GL_STENCIL_TEST);
        glClearStencil(0);
        glClear(GL_STENCIL_BUFFER_BIT);
        
        // All drawing commands fail the stencil test, and are not drawn, but increment the value in the stencil buffer.
        glStencilFunc(GL_NEVER, 0, 0);
        glStencilOp(GL_INCR, GL_INCR, GL_INCR);
        
        CZUtil::drawRect(rect,CZAffineTransform::makeIdentity());
        
        // now, allow drawing, except where the stencil pattern is 0x1 and do not make any further changes to the stencil buffer
        glStencilFunc(GL_EQUAL, 1, 1);
        glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    }
    
    CZUtil::drawRect(rect, trans);
    
    if (clipWhenTransformed) 
        glDisable(GL_STENCIL_TEST);
    
    shader->end();
    
    CZCheckGLError();
}

/// 注册撤销操作
static int i = 0;
void CZLayer::registerUndoInRect(CZRect &rect)
{
    resetUndoAndRedoEnvironment(undo_ind);
    if (undoFragment_9) {
        delete undoFragment_9;
    }
    if (undoFragment_8) {
        undoFragment_9 = new CZPaintingFragment(*undoFragment_8); // copy constructor
    }
    
    if (undoFragment_8) {
        delete undoFragment_8;
    }
    if (undoFragment_7) {
        undoFragment_8 = new CZPaintingFragment(*undoFragment_7); // copy constructor
    }
    
    if (undoFragment_7) {
        delete undoFragment_7;
    }
    if (undoFragment_6) {
        undoFragment_7 = new CZPaintingFragment(*undoFragment_6); // copy constructor
    }
    
    if (undoFragment_6) {
        delete undoFragment_6;
    }
    if (undoFragment_5) {
        undoFragment_6 = new CZPaintingFragment(*undoFragment_5); // copy constructor
    }
    
    if (undoFragment_5) {
        delete undoFragment_5;
    }
    if (undoFragment_4) {
        undoFragment_5 = new CZPaintingFragment(*undoFragment_4); // copy constructor
    }
    
    if (undoFragment_4) {
        delete undoFragment_4;
    }
    if (undoFragment_3) {
        undoFragment_4 = new CZPaintingFragment(*undoFragment_3); // copy constructor
    }
    
    if (undoFragment_3) {
        delete undoFragment_3;
    }
    if (undoFragment_2) {
        undoFragment_3 = new CZPaintingFragment(*undoFragment_2); // copy constructor
    }
    
    if (undoFragment_2) {
        delete undoFragment_2;
    }
    if (undoFragment_1) {
        undoFragment_2 = new CZPaintingFragment(*undoFragment_1); // copy constructor
    }
    
    if (undoFragment_1) {
        delete undoFragment_1;
    }
    if (undoFragment) {
        undoFragment_1 = new CZPaintingFragment(*undoFragment); // copy constructor
    }
    
    if (undoFragment) delete undoFragment;
    
    CZRect newRect = rect.intersectWith(ptrPainting->getBounds());
    CZImage *currentImg = imageDataInRect(newRect);
    undoFragment = new CZPaintingFragment(currentImg,newRect);
    
    canUndo = true;
    i++;
}

void CZLayer::registerUndosInRect(CZRect &rect) {
    
}

void CZLayer::clearThumbnailImage()
{
    delete thumbnailImg;
    thumbnailImg = NULL;
}
