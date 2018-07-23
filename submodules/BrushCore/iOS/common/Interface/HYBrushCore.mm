//
//  HYBrushCore.m
//  HYDrawing
//
//  Created by CharlyZhang on 15/8/10.
//  Copyright (c) 2015年 Founder. All rights reserved.
//

#import "HYBrushCore.h"
#import "CZViewImpl.h"
#include "BrushesCore.h"
#import <QuartzCore/QuartzCore.h>
#include <string>

#define DOCUMENT_DIR            [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]

@interface HYBrushCore()
{
    CZViewImpl *ptrViewImpl;
    CZCanvas *canvas;
    CZPainting *painting;
    float width,height;
    NSString *paintingStorePath;
    BOOL hasInsertedBackgroundLayer;        //< for the case that insert background image on a fixed layer
}
@end

@implementation HYBrushCore

+ (HYBrushCore *) sharedInstance
{
    static HYBrushCore *brushCore_ = nil;
    
    if (!brushCore_) {
        brushCore_ = [[HYBrushCore alloc] init];
    }
    
    return brushCore_;
}

- (instancetype) init
{
    if (self = [super init])
    {
        ptrViewImpl = nullptr;
        canvas = nullptr;
        painting = nullptr;
    }
    
    return self;
}

///初始化
- (CanvasView*) initializeWithWidth:(float)w Height:(float)h ScreenScale:(float)s GLSLDirectory:(NSString*) glslDir
{
    if(!glslDir || !glslDir) return nil;
    width = w;
    height = h;
    CZShader::glslDirectory = std::string([glslDir UTF8String]);
    
    /// CZActiveState Initializaiton comes first, for it will help other initial work
    CZActiveState::getInstance()->setEraseMode(false);
    CZActiveState::getInstance()->setActiveBrush(kPencil);
    CZActiveState::getInstance()->mainScreenScale = s;
    
    ptrViewImpl = new CZViewImpl(CZRect(0,0,w,h));
    canvas = new CZCanvas(ptrViewImpl);
    painting = new CZPainting(CZSize(w*s,h*s));
    canvas->setPaiting(painting);
    
    [self setActiveBrushwatercolorPenStamp ];
    
    self.hasInitialized = YES;
    hasInsertedBackgroundLayer = NO;
    return ptrViewImpl->realView;
}

///画布管理
- (BOOL) createPaintingAt:(NSString*)path
{
    if(!self.hasInitialized)
    {
        LOG_ERROR("The brush core has not ben initialized!\n");
        return NO;
    }
    
    // save previous painting
    if(paintingStorePath) [self saveActivePaintingTo:paintingStorePath];
    
    if(!painting->restore())
    {
        LOG_ERROR("Painting restores failed!\n");
        return NO;
    }
    
    hasInsertedBackgroundLayer = NO;
    
    paintingStorePath = path;
    
    // save current painting
    return [self saveActivePaintingTo:paintingStorePath];
}

- (BOOL) createPaintingFromUrl:(NSString*)url At:(NSString*)path
{
    if(!self.hasInitialized)
    {
        LOG_ERROR("The brush core has not ben initialized!\n");
        return NO;
    }
    
    // save previous painting
    if(paintingStorePath) [self saveActivePaintingTo:paintingStorePath];
    
    // create from url
    if(![self loadActivePaintingFrom:url])
    {
        LOG_ERROR("There's no painting in that url!\n");
        return NO;
    }
    
    paintingStorePath = path;
    
    // save current painting
    return [self saveActivePaintingTo:paintingStorePath];
}

- (BOOL) loadActivePaintingFrom:(NSString*) path
{
    if (!self.hasInitialized) {
        LOG_ERROR("Brush core has not been initialized!\n");
        return NO;
    }
    
    if (!path) {
        LOG_ERROR("painting path is NULL!\n");
        return NO;
    }
    
    // save previous painting
    if(paintingStorePath) [self saveActivePaintingTo:paintingStorePath];
    paintingStorePath = path;
    
    BOOL ret = CZFileManager::getInstance()->loadPainting([path UTF8String], painting);
    if(ret) hasInsertedBackgroundLayer = (painting->getType() == CZPainting::kFixedBGLayerPainting);
    return ret;
}

- (BOOL) saveActivePaintingTo:(NSString*) path
{
    if (!self.hasInitialized) {
        LOG_ERROR("Brush core has not been initialized!\n");
        return NO;
    }
    
    if (!path) {
        LOG_ERROR("path is NULL!\n");
        return NO;
    }
    
    paintingStorePath = path;
    
    if (painting) {
        BOOL ret = CZFileManager::getInstance()->savePainting(painting, [path UTF8String]);
        return ret;
    }
    
    return NO;
}

- (BOOL) saveActivePainting
{
    if(!paintingStorePath) return NO;
    return [self saveActivePaintingTo:paintingStorePath];
}

- (BOOL) removePaintingAt:(NSString*) path
{
    if (!self.hasInitialized) {
        LOG_ERROR("Brush core has not been initialized!\n");
        return NO;
    }
    
    if (!path) {
        LOG_ERROR("path is NULL!\n");
        return NO;
    }
    BOOL ret = CZFileManager::getInstance()->removePainting([path UTF8String]);
    return ret;
}

- (UIImage*) getThumbnailOfPaintingAt:(NSString*) path
{
    if(!self.hasInitialized)
    {
        LOG_ERROR("Brush core has not been initialized!\n");
        return nil;
    }
    
    // !!! just the first layer will be rendered, if create another painting.
    BOOL isActivePainting = YES;
    if (![path isEqualToString:paintingStorePath]) {
        CZFileManager::getInstance()->loadPainting([path UTF8String], painting);
        isActivePainting = NO;
    }
    
    CZImage *thumbImage = painting->thumbnailImage(isActivePainting);
    if (!thumbImage)
    {
        if(!isActivePainting) CZFileManager::getInstance()->loadPainting([paintingStorePath UTF8String],painting);
        return nil;
    }
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(thumbImage->data, thumbImage->width, thumbImage->height, 8, thumbImage->width*4,
                                             colorSpaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
    
    UIImage *ret = [[UIImage alloc] initWithCGImage:imageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    
    CGImageRelease(imageRef);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpaceRef);
    
    delete thumbImage;
    if(!isActivePainting) CZFileManager::getInstance()->loadPainting([paintingStorePath UTF8String],painting);
    
    return ret;
}

- (NSString*) activePaintingName
{
    return [paintingStorePath lastPathComponent];
}

///恢复内核（释放资源）
- (BOOL) restoreCore
{
    if (canvas) {
        delete canvas;
        canvas = nullptr;
    }
    
    if (painting) {
        delete painting;
        painting = nullptr;
    }
    
    self.hasInitialized = NO;
    paintingStorePath = nil;
    return YES;
}

/// 绘制
- (void) draw
{
    canvas->drawView();
}

///激活橡皮
- (void) activeEraser
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorFillMode = false;
    activeState->colorPickMode = false;
    
    activeState->setEraseMode(true);
    activeState->setActiveBrush(kEraser);
}
///激活铅笔
- (void) activePencil
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorFillMode = false;
    activeState->colorPickMode = false;
    
    activeState->setEraseMode(false);
    activeState->setActiveBrush(kPencil);
}
///激活马克笔
- (void) activeMarker
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorFillMode = false;
    activeState->colorPickMode = false;
    
    activeState->setEraseMode(false);
    activeState->setActiveBrush(kMarker);
}
///激活蜡笔
- (void) activeCrayon
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorFillMode = false;
    activeState->colorPickMode = false;
    activeState->setEraseMode(false);
    activeState->setActiveBrush(kCrayon);
}
///激活水彩笔
- (void) activeWaterColorPen
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorFillMode = false;
    activeState->colorPickMode = false;
    activeState->setEraseMode(false);
    activeState->setActiveBrush(kWatercolorPen);
}

///激活倒色桶
- (void) activeBucket
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorFillMode = true;
    activeState->colorPickMode = false;
}
///激活颜色拾取器
- (void) activeColorPicker
{
    CZActiveState *activeState = CZActiveState::getInstance();
    activeState->colorPickMode = true;
    activeState->colorFillMode = false;
}

///获取当前绘制颜色
- (UIColor*)getActiveStatePaintColor
{
    CZColor myColor = CZActiveState::getInstance()->getPaintColor();
    UIColor *ret = [UIColor colorWithRed:myColor.red green:myColor.green blue:myColor.blue alpha:myColor.alpha];
    return ret;
}
///设置当前绘制颜色
- (void) setActiveStateColor:(UIColor*)color
{
    CGFloat r,g,b,a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    CZColor pc(r,g,b,a);
    CZActiveState::getInstance()->setPaintColor(pc);
}

///设置挑选颜色
- (void) setActiveStateSwatchColor:(UIColor*)color atIndex:(NSInteger)index
{
    if(color){
        CGFloat r,g,b,a;
        [color getRed:&r green:&g blue:&b alpha:&a];
        CZColor *c = new CZColor(r,g,b,a);
        CZActiveState::getInstance()->setSwatch(c, (int)index);
    }
    else {
        CZActiveState::getInstance()->setSwatch(NULL, (int)index);
    }
}
- (void) setActiveStatePaintColorAtIndex:(NSInteger)index
{
    CZActiveState::getInstance()->setPaintColorAsSwatch(int(index));
}

- (UIColor*) getColorFromActiveStateSwatchAtIndex:(NSInteger)index
{
    CZColor *c = CZActiveState::getInstance()->getSwatch((int)index);
    if (c)  return [UIColor colorWithRed:c->red green:c->green blue:c->blue alpha:c->alpha];
    else    return nil;
}

#pragma mark -
///图片编辑
- (void) beginPhotoPlacement:(UIImage*) photo withTransform:(CGAffineTransform) trans
{
    CZImage *photoImg = [self producedFromImage:photo];
    CZAffineTransform photoTrans = CZAffineTransform(trans.a, trans.b, trans.c, trans.d, trans.tx, trans.ty);
    canvas->beginPlacePhoto(photoImg, photoTrans);
}

- (BOOL) setPhotoTransform:(CGAffineTransform)trans
{
    CZAffineTransform photoTrans = CZAffineTransform(trans.a, trans.b, trans.c, trans.d, trans.tx, trans.ty);
    canvas->setPhotoTransform(photoTrans);
    return YES;
}

- (void) endPhotoPlacement:(BOOL) renderToLayer
{
    canvas->endPlacePhoto(renderToLayer);
}

- (NSInteger) renderImage:(UIImage*)image withTransform:(CGAffineTransform)transform newLayer:(BOOL)flag
{
    int ret = painting->getActiveLayerIndex();
    
    if (flag) {
        ret = painting->addNewLayer();
        if (ret < 0) return (NSInteger)ret;
    }
    
    CZImage *brushImg = [self producedFromImage:image];
    
    CZAffineTransform trans = CZAffineTransform(transform.a,transform.b,transform.c,transform.d,transform.tx,transform.ty);

    
    painting->getActiveLayer()->renderImage(brushImg, trans);
    canvas->drawView();
    
    return (NSInteger)ret;
}

#pragma mark -
///操作图层
- (BOOL) setActiveLayerTransform:(CGAffineTransform)transform
{
    CZAffineTransform trans(transform.a,transform.b,transform.c,transform.d,transform.tx,transform.ty);
    painting->getActiveLayer()->setTransform(trans);
    canvas->drawView();
    return YES;
}

- (BOOL) renderActiveLayerWithTransform:(CGAffineTransform)transform
{
    CZAffineTransform trans(transform.a,transform.b,transform.c,transform.d,transform.tx,transform.ty);
    painting->getActiveLayer()->transform(trans, false);
    CZAffineTransform identityTrans = CZAffineTransform::makeIdentity();
    painting->getActiveLayer()->setTransform(identityTrans);
    canvas->drawView();
    return YES;
}

- (BOOL) setActiveLayerLinearInterprolation:(BOOL)flag
{
    painting->getActiveLayer()->enableLinearInterprolation(flag);
    return YES;
}

///绘制背景
- (void) renderBackground:(UIImage*)image
{
    CZImage* backgroundImg = [self producedFromImage:image];
    
    painting->getActiveLayer()->renderBackground(backgroundImg);
    canvas->drawView();
}

- (void) renderBackgroundInFixedLayer:(UIImage*)image
{
    int originalIdx = painting->getActiveLayerIndex();
    
    if(!hasInsertedBackgroundLayer)
    {
        int fixedIdx = painting->addNewLayer();
        painting->moveLayer(fixedIdx, 0);
        originalIdx = fixedIdx;
        hasInsertedBackgroundLayer = YES;
        painting->setType(CZPainting::kFixedBGLayerPainting);
    }
    
    painting->setActiveLayer(0);
    
    CZImage* backgroundImg = [self producedFromImage:image];
    painting->getActiveLayer()->renderBackground(backgroundImg);
    painting->setActiveLayer(originalIdx);
    
    canvas->drawView();
    delete backgroundImg;
}

- (NSInteger) getLayersNumber
{
    return NSInteger(painting->getLayersNumber());
}

- (UIImage*) getLayerThumbnailOfIndex:(NSInteger)index
{
    int layersNum = painting->getLayersNumber();
    
    CZLayer *layer = painting->getLayer(int(layersNum - 1 - index));
    if (!layer)         return nil;
    CZImage *thumbImage = layer->getThumbnailImage();
    if (!thumbImage)    return nil;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(thumbImage->data, thumbImage->width, thumbImage->height, 8, thumbImage->width*4,
                                             colorSpaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
    
    UIImage *ret = [[UIImage alloc] initWithCGImage:imageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    
    CGImageRelease(imageRef);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpaceRef);
    
    return ret;
}

- (NSInteger) addNewLayer
{
    int layersNum = painting->getLayersNumber();
    return NSInteger(layersNum - 1 - painting->addNewLayer());
}

- (NSInteger) duplicateActiveLayer
{
    int layersNum = painting->getLayersNumber();
    NSInteger ret = NSInteger(layersNum - 1 - painting->duplicateActiveLayer());
    canvas->drawView();
    return ret;
}

- (NSInteger) setActiveLayer:(NSInteger)idx
{
    int layersNum = painting->getLayersNumber();
    return NSInteger(layersNum - 1 - painting->setActiveLayer(int(layersNum - 1 -idx)));
}

- (NSInteger) getActiveLayerIndex
{
    int layersNum = painting->getLayersNumber();
    return NSInteger(layersNum - 1 - painting->getActiveLayerIndex());
}

- (BOOL) moveLayerFrom:(NSInteger)fromIdx to:(NSInteger)toIdx
{
    int layersNum = painting->getLayersNumber();
    
    BOOL ret = painting->moveLayer(int(layersNum - 1 - fromIdx), int(layersNum - 1 - toIdx));
    canvas->drawView();
    return ret;
}

- (BOOL) deleteActiveLayer
{
    BOOL ret = painting->deleteActiveLayer();
    canvas->drawView();
    return ret;
};

- (BOOL) restoreDeletedLayer
{
    BOOL ret = painting->restoreDeletedLayer();
    canvas->drawView();
    return ret;
}

- (void) setVisibility:(BOOL)visible ofLayer:(NSInteger) index
{
    int layersNum = painting->getLayersNumber();

    CZLayer *layer = painting->getLayer(layersNum - 1 - int(index));
    layer->setVisiblility(visible);
    canvas->drawView();
}
- (BOOL) isVisibleOfLayer:(NSInteger)index
{
    int layersNum = painting->getLayersNumber();
    
    CZLayer *layer = painting->getLayer(layersNum - 1 - int(index));
    if (layer) return layer->isVisible();
    else       return NO;
}
- (void) setLocked:(BOOL)locked ofLayer:(NSInteger) index
{
//    NSLog(@"set locked %d",locked);
    int layersNum = painting->getLayersNumber();
    
    CZLayer *layer = painting->getLayer(layersNum - 1 - int(index));
    layer->setLocked(locked);
}
- (BOOL) isLockedofLayer:(NSInteger)index
{
    int layersNum = painting->getLayersNumber();
    
    CZLayer *layer = painting->getLayer(layersNum - 1 - int(index));
    return layer->isLocked();
}
- (void) setActiveLayerOpacity:(float)opacity
{
    CZLayer *layer = painting->getActiveLayer();
    layer->setOpacity(opacity);
    canvas->drawView();
}
- (float) getOpacityOfLayer:(NSInteger)index
{
    int layersNum = painting->getLayersNumber();
    
    CZLayer *layer = painting->getLayer(layersNum - 1 - int(index));
    return layer->getOpacity();
}

- (BOOL) clearLayer:(NSInteger)index
{
    int layersNum = painting->getLayersNumber();
    
    CZLayer *layer = painting->getLayer(int(layersNum - 1 - index));
    
    BOOL ret = layer->clear();
    canvas->drawView();
    return ret;
}

#pragma mark -
- (void)setActiveBrushwatercolorPenStamp
{
    UIImage *image = [UIImage imageNamed:@"BrushesCoreResources.bundle/stamp_images/watercolorPen.png"];
    CZImage *stampImage = [self producedFromImage:image];
    
    CZActiveState *activeState = CZActiveState::getInstance();
    
    int idx = activeState->setActiveBrush(kWatercolorPen);
    activeState->setActiveBrushStamp(stampImage);
    activeState->setActiveBrush(idx);
}

///笔触大小
- (void) setActiveBrushSize:(float) value
{
    CZBrush *pBrush = CZActiveState::getInstance()->getActiveBrush();
    if (pBrush)
        pBrush->weight.value = value;
    else
        LOG_ERROR("Active Brush is NULL\n");
}

- (float) getActiveBrushSize
{
    CZBrush *pBrush = CZActiveState::getInstance()->getActiveBrush();
    if (pBrush)
        return pBrush->weight.value;
    else
        LOG_ERROR("Active Brush is NULL\n");
    
    return 1.0f;
}

///画板
- (float) getCanvasScale
{
    return canvas->getScale();
}

- (CGPoint) convertToPainting:(CGPoint)pt
{
    CZ2DPoint p(pt.x, pt.y);
    CZ2DPoint po = canvas->transformToPainting(p);
    return CGPointMake(po.x, po.y);
}

- (CGSize) getPaintingSize
{
    CZSize size = painting->getDimensions();
    return CGSizeMake(size.width, size.height);
}

- (UIImage*) getThumbnailOfPainting
{
    CZImage *thumbImage = painting->thumbnailImage();
    if (!thumbImage)    return nil;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(thumbImage->data, thumbImage->width, thumbImage->height, 8, thumbImage->width*4,
                                             colorSpaceRef, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
    
    UIImage *ret = [[UIImage alloc] initWithCGImage:imageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    
    CGImageRelease(imageRef);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpaceRef);
    
    delete thumbImage;
    return ret;
}

/// undo & redo
- (BOOL) canUndo
{
    return YES;
}

- (NSMutableDictionary *)redoFragmentDic {
    if (!_redoFragmentDic) {
        _redoFragmentDic = [NSMutableDictionary dictionary];
    }
    return _redoFragmentDic;
}

- (NSMutableDictionary *)undoFragmentDic {
    if (!_undoFragmentDic) {
        _undoFragmentDic = [NSMutableDictionary dictionary];
    }
    return _undoFragmentDic;
}

- (void)restoreUndoFragments {
    CZLayer *layer = painting->getActiveLayer();
    NSString *layer_key = [NSString stringWithFormat:@"%d",painting->getActiveLayerIndex()];
    NSMutableArray *undof = [NSMutableArray array];
    if (layer->undoFragment) {
        [undof addObject:[NSValue valueWithPointer:layer->undoFragment]];
        if (layer->undoFragment_1) {
            [undof addObject:[NSValue valueWithPointer:layer->undoFragment_1]];
            if (layer->undoFragment_2) {
                [undof addObject:[NSValue valueWithPointer:layer->undoFragment_2]];
                if (layer->undoFragment_3) {
                    [undof addObject:[NSValue valueWithPointer:layer->undoFragment_3]];
                    if (layer->undoFragment_4) {
                        [undof addObject:[NSValue valueWithPointer:layer->undoFragment_4]];
                        if (layer->undoFragment_5) {
                            [undof addObject:[NSValue valueWithPointer:layer->undoFragment_5]];
                            if (layer->undoFragment_6) {
                                [undof addObject:[NSValue valueWithPointer:layer->undoFragment_6]];
                                if (layer->undoFragment_7) {
                                    [undof addObject:[NSValue valueWithPointer:layer->undoFragment_7]];
                                    if (layer->undoFragment_8) {
                                        [undof addObject:[NSValue valueWithPointer:layer->undoFragment_8]];
                                        if (layer->undoFragment_9) {
                                            [undof addObject:[NSValue valueWithPointer:layer->undoFragment_9]];
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    [self.undoFragmentDic setValue:undof forKey:layer_key];
}

- (BOOL) undoPaintingOfLayer:(NSInteger)idx
{
    int layersNum = painting->getLayersNumber();
    CZLayer *layer = painting->getLayer(int(layersNum - 1 - idx));
    NSLog(@"undo layer index：%d", painting->getActiveLayerIndex());
    if (layer == nullptr) return NO;
    if (_isAllowRedo) {
        NSString *layer_key = [NSString stringWithFormat:@"%d",painting->getActiveLayerIndex()];
        NSMutableArray *undof = [self.undoFragmentDic valueForKey:layer_key];
        NSInteger count = undof.count;
        if (count>0) {
            
        }
        else {
            
        }
        if (count>0) {
            NSValue *value = undof.firstObject;
            layer->undoFragment = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>1) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_1 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>2) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_2 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>3) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_3 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>4) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_4 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>5) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_5 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>6) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_6 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>7) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_7 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>8) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_8 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
        if (count>9) {
            NSValue *value = undof.firstObject;
            layer->undoFragment_9 = (CZPaintingFragment*)value.pointerValue;
            [undof removeObjectAtIndex:0];
        }
    }
    BOOL result = layer->undoAction();
    NSString *layer_key = [NSString stringWithFormat:@"%d",painting->getActiveLayerIndex()];
    NSMutableArray *redof = [NSMutableArray array];
    if (layer->redoFragment) {
        [redof addObject:[NSValue valueWithPointer:layer->redoFragment]];
        if (layer->redoFragment_1) {
            [redof addObject:[NSValue valueWithPointer:layer->redoFragment_1]];
            if (layer->redoFragment_2) {
                [redof addObject:[NSValue valueWithPointer:layer->redoFragment_2]];
                if (layer->redoFragment_3) {
                    [redof addObject:[NSValue valueWithPointer:layer->redoFragment_3]];
                    if (layer->redoFragment_4) {
                        [redof addObject:[NSValue valueWithPointer:layer->redoFragment_4]];
                        if (layer->redoFragment_5) {
                            [redof addObject:[NSValue valueWithPointer:layer->redoFragment_5]];
                            if (layer->redoFragment_6) {
                                [redof addObject:[NSValue valueWithPointer:layer->redoFragment_6]];
                                if (layer->redoFragment_7) {
                                    [redof addObject:[NSValue valueWithPointer:layer->redoFragment_7]];
                                    if (layer->redoFragment_8) {
                                        [redof addObject:[NSValue valueWithPointer:layer->redoFragment_8]];
                                        if (layer->redoFragment_9) {
                                            [redof addObject:[NSValue valueWithPointer:layer->redoFragment_9]];
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    [self.redoFragmentDic setValue:redof forKey:layer_key];
    canvas->drawView();
    return result;
}

- (BOOL) redoPaintingOfLayer:(NSInteger)idx
{
    int layersNum = painting->getLayersNumber();
    CZLayer *layer = painting->getLayer(int(layersNum - 1 - idx));
    NSLog(@"redo layer index：%d", painting->getActiveLayerIndex());
    if (layer == nullptr) return NO;
    if (_isAllowRedo) {
        layer->canRedo = true;
        NSString *layer_key = [NSString stringWithFormat:@"%d",painting->getActiveLayerIndex()];
        NSMutableArray *redof = [self.redoFragmentDic valueForKey:layer_key];
        NSInteger count = redof.count;
        if (count>0) {
            layer->redo_ind = (int)count-1;
        }
        else {
            
        }
        if (count>9) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_9 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>8) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_8 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>7) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_7 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>6) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_6 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>5) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_5 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>4) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_4 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>3) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_3 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>2) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_2 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>1) {
            NSValue *value = redof.lastObject;
            layer->redoFragment_1 = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        if (count>0) {
            NSValue *value = redof.lastObject;
            layer->redoFragment = (CZPaintingFragment*)value.pointerValue;
            [redof removeLastObject];
        }
        
        
        // 此处需要一个方法，对redo新建的layer里面的所有fragment进行复制
    }
    BOOL result = layer->redoAction();
    canvas->drawView();
    return result;
}

#pragma mark - !Adjust Brush Stamp

- (void) setIntentity4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->intensity.value = v;
}

- (float) intentity4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->intensity.value;
}

- (void) setAngle4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->angle.value = v;
}

- (float) angle4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->angle.value;
}

- (void) setSpacing4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->spacing.value = v;
}

- (float) spacing4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->spacing.value;
}

- (void) setDynamicIntensity4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->intensityDynamics.value = v;
}

- (float) dynamicIntensity4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->intensityDynamics.value;
}

- (void) setJitter4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->rotationalScatter.value = v;
}

- (float) jitter4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->rotationalScatter.value;
}

- (void) setScatter4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->positionalScatter.value = v;
}

- (float) scatter4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->positionalScatter.value;
}

- (void) setDynamicWeight4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->weightDynamics.value = v;
}

- (float) dynamicWeight4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->weightDynamics.value;
}

- (void) setDynamicAngle4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    brush->angleDynamics.value = v;
}

- (float) dynamicAngle4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    return brush->angleDynamics.value;
}

- (void) setBristleDentity4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    if(brush->isInStampGeneratingMode() == false) return;
    CZBristleGenerator *gen = dynamic_cast<CZBristleGenerator *>(brush->getGenerator());
    if (!gen) return ;
    
    gen->bristleDensity.value = v;
    gen->propertiesChanged();
    brush->generatorChanged(gen);
    painting->clearLastBrush();
}

- (float) bristleDentity4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    CZBristleGenerator *gen = dynamic_cast<CZBristleGenerator *>(brush->getGenerator());
    if (!gen) return 0.0f;
    
    return gen->bristleDensity.value;
}

- (void) setBristleSize4ActiveBrush:(float)v
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    if(brush->isInStampGeneratingMode() == false) return;
    CZBristleGenerator *gen = dynamic_cast<CZBristleGenerator *>(brush->getGenerator());
    if (!gen) return ;
    
    gen->bristleSize.value = v;
    gen->propertiesChanged();
    brush->generatorChanged(gen);
    painting->clearLastBrush();
}

- (float) bristleSize4ActiveBrush
{
    CZBrush *brush = CZActiveState::getInstance()->getActiveBrush();
    CZBristleGenerator *gen = dynamic_cast<CZBristleGenerator *>(brush->getGenerator());
    if (!gen) return 0.0f;
    
    return gen->bristleSize.value;
}

- (void) setCurrentBrushStamp:(UIImage*) image
{
    CZImage *brushImg = [self producedFromImage:image];
    
    if(brushImg)
    {
        CZActiveState::getInstance()->setActiveBrushStamp(brushImg);
        painting->clearLastBrush();
    }
    else
        LOG_ERROR("image is nil!\n");
}

#pragma mark - Private
- (CZImage*)producedFromImage:(UIImage*)image
{
    if(image == nil) return nullptr;
    
    CGImageRef img = image.CGImage;
    
    size_t width = CGImageGetWidth(img);
    size_t height = CGImageGetHeight(img);
    
    size_t rowByteSize = width *  4;
    unsigned char *data = new unsigned char[height * rowByteSize];
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, width, height, 8, rowByteSize,
                                                 colorSpaceRef,
                                                 kCGImageAlphaPremultipliedLast);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), img);
    CGContextRelease(context);
    
    CGColorSpaceRelease(colorSpaceRef);
    CZImage *retImg = new CZImage((int)width,(int)height,RGBA_BYTE,data);
    delete [] data;
    
    
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(img);
    
    if (alphaInfo == kCGImageAlphaNone ||
        alphaInfo == kCGImageAlphaNoneSkipLast ||
        alphaInfo == kCGImageAlphaNoneSkipFirst){
        retImg->hasAlpha = false;
    }
    else {
        retImg->hasAlpha = true;
    }
    
    return retImg;
}

/// 析构
- (void) dealloc {
    [self restoreCore];
}
@end
