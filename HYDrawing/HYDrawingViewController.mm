//
//  HYDrawingViewController.m
//  HYDrawing
//
//  Created by 李 雷川 on 15/7/16.
//  Copyright (c) 2015年 Founder. All rights reserved.
//

#import "HYDrawingViewController.h"
#import "HYBrushCore.h"
#import "BottomBarView.h"
#import "HYMenuViewController.h"
#import "DDPopoverBackgroundView.h"
#import "Macro.h"
#import "WDColorPickerController.h"
#import "ZXHLayersViewController.h"
#import "ZXHEditableTipsView.h"
#import "CanvasView.h"
#import "CliperView.h"
#import "ZXHShapeBoxController.h"
#import "ZXHCanvasBackgroundController.h"
#import "ZXHPaintingListController.h"
#import "TransformOverlayer.h"
#import "SettingViewController.h"
#import "BrushSizePannelView.h"
#import "MBProgressHUD.h"
#import "PaintingNameManager.h"
#import "Actions.h"
#import "UIImage+Resize.h"
#import "NSArray+JSON.h"
#import "ZXHResourcePicturesController.h"

extern NSString *CZActivePaintColorDidChange;
extern NSString* LayersCountChange;
extern NSString *CZCanvasDirtyNotification;
extern NSString *LayersOperation;

@interface HYDrawingViewController ()<
BottomBarViewDelegate,UIPopoverControllerDelegate,WDColorPickerControllerDelegate,CanvasViewDelegate, BrushSizePannelViewDelegate, PaintingListControllerDelegate,
SettingViewControllerDelegate, ResourceImageSelectDelegate,UIPopoverPresentationControllerDelegate>
{
    UIPopoverController *popoverController;
    UIPopoverPresentationController *popoverPController;
    BottomBarView *bottomBarView;
    BrushSizePannelView *brushSizePannelView;
    UIPopoverController *layersPopoverController;
    UIPopoverController *picturePopoverController;
    UIPopoverController *menuPopoverController;
    // 图层
    ZXHLayersViewController *_layersViewController;
    UIBarButtonItem *pictureItem;
	
	// Setting
	UIBarButtonItem *settingItem;
	// Video
	UIBarButtonItem *videoItem;
	// Share
	UIBarButtonItem *shareItem;
	
    // 图形
    ZXHShapeBoxController *_shapeBoxController;
    UIPopoverController *_shapeBoxPopoverController;
    // 背景图选择
    UIPopoverController *_canvasBgPopoverController;
    ZXHCanvasBackgroundController *_canvasBackgroundController;
	
	/*2016-04-11 在线图片资源*/
	ZXHResourcePicturesController *_resourcePicturesController;
    
    ///
    UIPopoverController *_listPopoverController;
    
    BottomBarButtonType activeButton;
    
    MBProgressHUD       *hud;
    
    TransformOverlayer *transformOverlayer;
    
    // undo & redo
    Actions *preAction;
    NSMutableArray *undoActions;
    NSMutableArray *redoActions;
    UIBarButtonItem *undoItem, *redoItem;
    
    // test saving and loading
    BOOL isClosed;
    
}

@property (nonatomic,strong) WDColorPickerController* colorPickerController;
@property (nonatomic,strong) UIPopoverController *settingPopoverController;                 //< seting popover controller
@end

@implementation HYDrawingViewController

#pragma mark - Properties

- (WDColorPickerController*) colorPickerController {
    if (!_colorPickerController) {
        _colorPickerController = [[WDColorPickerController alloc] initWithNibName:@"ColorPicker" bundle:nil];
        _colorPickerController.delegate = self;
    }
    return _colorPickerController;
}

- (UIPopoverController*) settingPopoverController {
    if (!_settingPopoverController) {
        
        SettingViewController *settingCtrl =  [[SettingViewController alloc]init];
        settingCtrl.delegate = self;
        _settingPopoverController = [[UIPopoverController alloc] initWithContentViewController:settingCtrl];
        _settingPopoverController.backgroundColor = kBorderColor;
    }
    
    return _settingPopoverController;
}

#pragma mark 设置barItem是否可用
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"layersCount"]) {
        if (_layersViewController.layersCount == 10) {
            pictureItem.enabled = NO;
        }else{
            pictureItem.enabled = YES;
        }
    }
}

#pragma mark - ViewController 

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 导航栏橙色背景
    //    self.navigationController.navigationBar.barTintColor = kBackgroundColor;
    
    /**
     *  navBar 图片色 iOS7
     */
    self.navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    
    /**
     * Mioto迁移不需要的item
     
    // close
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc]initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(closeBrush:)];
    // load
    UIBarButtonItem *loadItem = [[UIBarButtonItem alloc]initWithTitle:@"Load" style:UIBarButtonItemStylePlain target:self action:@selector(loadBrush:)];
    */
    
    // Painting List
    UIBarButtonItem *listItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"menu"] style:UIBarButtonItemStylePlain target:self action:@selector(showPaintingList:)];
	
    /**
     * Mioto迁移不需要的item
	// 图片资源
	UIBarButtonItem *resourceItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"nav_button_resource"] style:UIBarButtonItemStylePlain target:self action:@selector(toResourcePicturesVC)];
    */
    
	self.navigationItem.leftBarButtonItems = @[listItem];
    
    // undo & redo
    undoItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"undo_n"] style:UIBarButtonItemStylePlain target:self action:@selector(undo:)];
    
    redoItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"redo_n"] style:UIBarButtonItemStylePlain target:self action:@selector(redo:)];

    undoItem.enabled = NO;
    redoItem.enabled = NO;
    
    /**
     * Mioto迁移不需要的item
    // 视频
    videoItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"video"] style:UIBarButtonItemStylePlain target:self action:@selector(tapVideo:)];
	*/
	// 操作
    settingItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"setting"] style:UIBarButtonItemStylePlain target:self action:@selector(showSetting:)];
    /**
     * Mioto迁移不需要的item
    // 图片
    pictureItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"picture"] style:UIBarButtonItemStylePlain target:self action:@selector(showPhotoBrowser:)];
    
    // 分享
    shareItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"share"] style:UIBarButtonItemStylePlain target:self action: nil];
    */
    
    self.navigationItem.rightBarButtonItems = @[redoItem,undoItem,settingItem];
    
    self.view.opaque = YES;
    self.view.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    
    /// 初始画板
    
    CanvasView *canvasView = [[HYBrushCore sharedInstance] initializeWithWidth:kScreenW
                                                                        Height:kScreenH
                                                                   ScreenScale:[UIScreen mainScreen].scale
                                              GLSLDirectory:[[[NSBundle mainBundle]bundlePath] stringByAppendingString:@"/BrushesCoreResources.bundle/glsl/"]];
    
    canvasView.delegate = self;
    [self.view insertSubview:canvasView atIndex:0];
    
    NSString *URLString = [[NSUserDefaults standardUserDefaults] objectForKey:@"lauchPaintingUrl"];
    // if app launched from another app
    if (URLString) {
        URLString = [URLString substringFromIndex:7];       // strip the "file://"
        NSString *defaultFilePath = [PaintingNameManager sharedInstance].newDefaultFilePath;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lauchPaintingUrl"];
        [[HYBrushCore sharedInstance] createPaintingFromUrl:URLString At:defaultFilePath];
    }
    else {
        NSArray *paintingNames = [[PaintingNameManager sharedInstance] allNames];
        if(paintingNames.count > 0)
        {
            NSString *dPath = [[PaintingNameManager sharedInstance] pathOfDefaultName:[paintingNames objectAtIndex:0]];
            [[HYBrushCore sharedInstance] loadActivePaintingFrom:dPath];
        }
        else
        {
            NSString *defaultFilePath = [PaintingNameManager sharedInstance].newDefaultFilePath;
            [[HYBrushCore sharedInstance] createPaintingAt:defaultFilePath];
        }
    }
    
#pragma mark - bottom bar view
    UIColor *activeColor = [[HYBrushCore sharedInstance]getActiveStatePaintColor];
    CGFloat r,g,b,a;
    [activeColor getRed:&r green:&g blue:&b alpha:&a];
    bottomBarView = [[BottomBarView alloc]initWithWellColor:[WDColor colorWithRed:r green:g blue:b alpha:a]];
    bottomBarView.delegate = self;
    [self.view addSubview:bottomBarView];
	if (iOS(8.0)) {
		
		[self constrainSubview:bottomBarView toMatchWithSuperview:self.view];
	}else{
		
		CGRect frame = bottomBarView.frame;
		
		frame.origin.y = CGRectGetWidth([UIScreen mainScreen].bounds) - 103;
		frame.origin.x = (CGRectGetHeight(self.view.bounds) - frame.size.width) / 2;
		
		bottomBarView.frame = frame;
	}
	
    activeButton = (BottomBarButtonType) bottomBarView.currentButton.tag;
    
    // brush size pannel
    brushSizePannelView = [[BrushSizePannelView alloc] initWithFrame:CGRectMake(-132, [UIScreen mainScreen].bounds.size.height/2.0, 346, 58)];
    brushSizePannelView.delegate = self;
    [self.view addSubview:brushSizePannelView];
    [brushSizePannelView setBrushSize:[[HYBrushCore sharedInstance]getActiveBrushSize]];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(paintColorChanged:) name:CZActivePaintColorDidChange object:nil];
    [nc addObserver:self selector:@selector(handleCanvasDirtyNotificaton) name:CZCanvasDirtyNotification object:nil];
    [nc addObserver:self selector:@selector(handleLayersOperationNotification:) name:LayersOperation object:nil];
    
    // 2.1 存储Action
    undoActions = [NSMutableArray array];
    redoActions = [NSMutableArray array];
    
    NSLog(@"Home path is %@",NSHomeDirectory());
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    // 全透明背景
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.translucent = YES;
    // 去掉分割线
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    /**
     * replay
    [self read];
     */
}

#pragma mark 加载线稿资源
- (void)read {
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [path objectAtIndex:0];
    NSString *filepath = [documents stringByAppendingPathComponent:@"paths.txt"];
    NSString *str = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
    
    NSArray *paths = [NSArray stringToJSON:str];
    
    CanvasView *canvasView = [[self.view subviews]objectAtIndex:0];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [canvasView autoDraw:paths];
    });
}

#pragma mark 图片资源
-(void)toResourcePicturesVC{
	_resourcePicturesController = [ZXHResourcePicturesController new];
	_resourcePicturesController.delegate = self;
	[self.navigationController pushViewController:_resourcePicturesController animated:true];
}

// delegate method -- .png
-(void)didSelectImage:(UIImage *)image{
//	[[UIApplication sharedApplication].keyWindow addSubview:[[UIImageView alloc] initWithImage:image]];
	[self showImageTransform:image];
}

-(BOOL)shouldAutorotate {
    return NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
//    return  UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight;
//}

#pragma mark - Top Bar Actions

-(void)closeBrush:(UIBarButtonItem*)sender {
    if(isClosed) return;
    CanvasView *canvasView = [[self.view subviews]objectAtIndex:0];
    [canvasView removeFromSuperview];
    [[HYBrushCore sharedInstance]saveActivePainting];
    [[HYBrushCore sharedInstance]restoreCore];
    isClosed = YES;
}

-(void)loadBrush:(UIBarButtonItem*)sender {
    if (!isClosed) return;
    
    CanvasView *canvasView = [[HYBrushCore sharedInstance] initializeWithWidth:kScreenW
                                                                        Height:kScreenH
                                                                   ScreenScale:[UIScreen mainScreen].scale
                                                                 GLSLDirectory:[[[NSBundle mainBundle]bundlePath] stringByAppendingString:@"/"]];
    
    canvasView.delegate = self;
    [self.view insertSubview:canvasView atIndex:0];
    
    NSArray *paintingNames = [[PaintingNameManager sharedInstance] allNames];
    NSString *dPath = [[PaintingNameManager sharedInstance] pathOfDefaultName:[paintingNames objectAtIndex:0]];
    [[HYBrushCore sharedInstance] loadActivePaintingFrom:dPath];
    
    isClosed = NO;
}

-(void)showPaintingList:(UIBarButtonItem*)sender {
    UIImage *image = [UIImage imageNamed:@"list_popover_bg"];

    ZXHPaintingListController *listVC = [[ZXHPaintingListController alloc]init];
    listVC.delegate = self;
    listVC.modalPresentationStyle = UIModalPresentationPopover;
    listVC.preferredContentSize = CGSizeMake(image.size.width, image.size.height-50);
    
    UIPopoverPresentationController *popController = [listVC popoverPresentationController];
    popController.delegate = self;
    popoverController.backgroundColor = [UIColor yellowColor];
    popController.popoverBackgroundViewClass = [DDPopoverBackgroundView class];
    [DDPopoverBackgroundView setContentInset:0];
    [DDPopoverBackgroundView setBackgroundImage:image];
    [DDPopoverBackgroundView setBackgroundImageCornerRadius:4];
    
    popController.barButtonItem = sender;
    
    // 弹出
    [self presentViewController:listVC animated:YES completion:^{
        
    }];
    
    [(ZXHPaintingListController*)_listPopoverController.contentViewController refreshData];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

-(BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController{
    return YES;
}

//弹框消失时调用的方法
-(void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController{
    
    NSLog(@"弹框已经消失");
    
}

- (void)tapVideo:(id)sender{
    
}

-(void)showSetting:(UIBarButtonItem*)sender{
    /**
     * 废弃PopoverController
    [self.settingPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
     */
    SettingViewController *settingCtrl =  [[SettingViewController alloc]init];
    settingCtrl.delegate = self;
    settingCtrl.preferredContentSize = CGSizeMake(100, 100);
    settingCtrl.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController *pop = settingCtrl.popoverPresentationController;
    pop.barButtonItem = sender;
    pop.backgroundColor = kBorderColor;
    pop.delegate = self;
    
    [self presentViewController:settingCtrl animated:YES completion:nil];
}

- (void)showPhotoBrowser:(UIBarButtonItem*) sender {
    if ([self shouldDismissPopoverForClassController:[UIImagePickerController class] insideNavController:NO]) {
        [self hidePopovers];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    
    [self showController:picker fromBarButtonItem:sender animated:YES];
}

- (void)showShareController:(id)sender{
    HYMenuViewController *menuViewController = [[HYMenuViewController alloc]init];
    UINavigationController *menuNavigationController = [[UINavigationController alloc]initWithRootViewController:menuViewController];
    menuNavigationController.navigationBar.barTintColor = kBackgroundColor;
    menuNavigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    
    menuPopoverController = [[UIPopoverController alloc]initWithContentViewController:menuNavigationController];
    
    menuPopoverController.popoverBackgroundViewClass =[DDPopoverBackgroundView class];
    UIImage *image = [UIImage imageNamed:@"menu_popover_bg"];
    [DDPopoverBackgroundView setBackgroundImage:image];
    [DDPopoverBackgroundView setBackgroundImageCornerRadius:2.f];
    [DDPopoverBackgroundView setArrowBase:0];
    [DDPopoverBackgroundView setArrowHeight:2];
    [menuPopoverController setPopoverContentSize:CGSizeMake(image.size.width, image.size.height-20)];
    [menuPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

#pragma mark PaintingListControllerDelegate

- (void)paintingListController:(ZXHPaintingListController *)paintingListCtrl loadPaintingFrom:(NSString*)path
{
    if (!hud) {
        hud = [[MBProgressHUD alloc]initWithView:self.view];
        hud.labelText = @"正在切换绘画...";
        [self.view addSubview:hud];
    }
    
    [_listPopoverController dismissPopoverAnimated:YES];
    
    [self.view setUserInteractionEnabled:NO];
    [hud showAnimated:YES whileExecutingBlock:^{
        [[HYBrushCore sharedInstance] loadActivePaintingFrom:path];
    } completionBlock:^ {
        NSLog(@"finish loading");
        [self.view setUserInteractionEnabled:YES];
        [[HYBrushCore sharedInstance]draw];
        [[NSNotificationCenter defaultCenter]postNotificationName:LayersCountChange object:nil userInfo:nil];
    }];
    
}

#pragma mark SettingViewControllerDelegate

- (BOOL) settingViewControllerSavePainting:(SettingViewController *)settingController {
    [[HYBrushCore sharedInstance]saveActivePainting];
    [_settingPopoverController dismissPopoverAnimated:YES];
    
    return YES;
}

- (BOOL) settingViewControllerClearLayer:(SettingViewController *)settingController {
    NSInteger currentLayerIdx = [[HYBrushCore sharedInstance]getActiveLayerIndex];
    [[HYBrushCore sharedInstance]clearLayer:currentLayerIdx];
    Actions *action = [Actions createCanvasChangingAction:currentLayerIdx];
    NSDictionary *userInfo = @{@"Action":action};
    [[NSNotificationCenter defaultCenter]postNotificationName:CZCanvasDirtyNotification object:nil userInfo:userInfo];
    [_settingPopoverController dismissPopoverAnimated:YES];
    
    return YES;
}

- (BOOL) settingViewControllerTransformLayer:(SettingViewController *)settingController {
    
    [_settingPopoverController dismissPopoverAnimated:YES];
    
    float canvasScale = [[HYBrushCore sharedInstance] getCanvasScale];
    float screenScale = [[UIScreen mainScreen] scale];
    transformOverlayer = [[TransformOverlayer alloc] initWithFrame:self.view.bounds title:@"图层变换" scaleFactor:screenScale / canvasScale];
    
    __weak HYDrawingViewController *weakSelf = self;
    transformOverlayer.cancelBlock = ^{ [weakSelf cancelLayerTransformation];   };
    transformOverlayer.acceptBlock = ^{ [weakSelf transformActiveLayer];    };
    
    [self.view addSubview:transformOverlayer];
    
    [[HYBrushCore sharedInstance]setActiveLayerLinearInterprolation:YES];
    
    [self displayToolView:NO];
    
    [transformOverlayer addTarget:self action:@selector(layerTransformChanged:)
                 forControlEvents:UIControlEventValueChanged];
    
    return YES;
}

#pragma mark UIImagePickerControllerDelegate

- (void) dismissImagePicker:(UIImagePickerController *)picker {
    //    if (self.runningOnPhone) {
    //        [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    //    } else {
    [popoverController dismissPopoverAnimated:YES];
    popoverController = nil;
    //    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    [self dismissImagePicker:picker];
    [self showImageTransform:image];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissImagePicker:picker];
}

#pragma mark - BottomBarViewDelegate

- (void)bottomBarView:(BottomBarView*)bottomBarView forButtonAction:(UIButton*)button {
    switch (button.tag) {
        case COLORWHEEL_BTN:        ///< 调色板
            [self showColorPicker:button];
            break;
        case ERASER_BTN:            ///< 橡皮擦
            [[HYBrushCore sharedInstance]activeEraser];
            [brushSizePannelView setBrushSize:[[HYBrushCore sharedInstance]getActiveBrushSize]];
            break;
        case PENCIL_BTN:            ///< 铅笔
            [[HYBrushCore sharedInstance]activePencil];
            [brushSizePannelView setBrushSize:[[HYBrushCore sharedInstance]getActiveBrushSize]];
            break;
        case MARKERPEN_BTN:         ///< 马克笔
            [[HYBrushCore sharedInstance]activeMarker];
            [brushSizePannelView setBrushSize:[[HYBrushCore sharedInstance]getActiveBrushSize]];
            break;
        case COLORBRUSH_BTN:        ///< 水彩笔
            [[HYBrushCore sharedInstance]activeWaterColorPen];
            [brushSizePannelView setBrushSize:[[HYBrushCore sharedInstance]getActiveBrushSize]];
            break;
        case CRAYON_BTN:
            [[HYBrushCore sharedInstance]activeCrayon];
            [brushSizePannelView setBrushSize:[[HYBrushCore sharedInstance]getActiveBrushSize]];
            break;
        case BUCKET_BTN:            ///< 倒色桶
            [[HYBrushCore sharedInstance]activeBucket];
            break;
        case SHAPEBOX_BTN:          ///< 图形箱
            [self showShapeBoxPopoverController:button];
            break;
        case EYEDROPPER_BTN:        ///< 取色管
            [[HYBrushCore sharedInstance]activeColorPicker];
            break;
        case LAYERS_BTN:            ///< 图层
            [self showLayerPopoverController:button];
            break;
        case CLIP_BTN:              ///< 裁减
                        [self showCliperView];
            break;
        case CANVAS_BTN:            ///< 背景图
            [self showCanvasBackgroundPopoverController:button];
            break;
        default:
            break;
    }
    
    activeButton = (BottomBarButtonType)button.tag;
    [self displayBrushSizePannel:YES];
    
}

- (void) showColorPicker:(id)sender {
    if ([self shouldDismissPopoverForClassController:[WDColorPickerController class] insideNavController:NO]) {
        [self hidePopovers];
        return;
    }
    self.colorPickerController.preferredContentSize = CGSizeMake([UIScreen mainScreen].bounds.size.width-20, [UIScreen mainScreen].bounds.size.height*2/3.0);
    self.colorPickerController.modalPresentationStyle = UIModalPresentationPopover;
    [self showController:self.colorPickerController fromBarButtonItem:sender animated:NO];
}

-(void)showShapeBoxPopoverController:(UIButton*)sender{
    UIImage *image = [UIImage imageNamed:@"shapebox_img_bg"];
    if (!_shapeBoxController) {
        _shapeBoxController = [[ZXHShapeBoxController alloc]initWithPreferredContentSize:CGSizeMake([UIScreen mainScreen].bounds.size.width-20, image.size.height)];
        _shapeBoxController.delegate = self;
        _shapeBoxController.modalPresentationStyle = UIModalPresentationPopover;
    }
    
    UIPopoverPresentationController *pop =_shapeBoxController.popoverPresentationController;
    // 弹出位置
    CGRect popRect = sender.frame;
    popRect.origin.x += popRect.size.width;
    pop.delegate = self;
    pop.sourceView = sender;
    pop.sourceRect = sender.bounds;
//    pop.popoverBackgroundViewClass = [DDPopoverBackgroundView class];
//    [DDPopoverBackgroundView setContentInset:0];
//    [DDPopoverBackgroundView setBackgroundImage:[UIImage new]];
//    [DDPopoverBackgroundView setBackgroundImageCornerRadius:4];
    
    [self presentViewController:_shapeBoxController animated:YES completion:^{
        
    }];
}

- (void)showCanvasBackgroundPopoverController:(UIButton*)sender {
    UIImage *image = [UIImage imageNamed:@"canvasBg_bg"];
    if (!_canvasBackgroundController) {
        _canvasBackgroundController = [[ZXHCanvasBackgroundController alloc]initWithPreferredContentSize:CGSizeMake([UIScreen mainScreen].bounds.size.width, image.size.height)];
        _canvasBackgroundController.modalPresentationStyle = UIModalPresentationPopover;
    }
    
    
    UIPopoverPresentationController *pop = _canvasBackgroundController.popoverPresentationController;
    pop.delegate = self;
    
    // 弹出位置
    CGRect popRect = sender.frame;
    popRect.origin.x -= popRect.size.width;
    pop.sourceView = sender;
    pop.sourceRect = sender.bounds;
    
    [self presentViewController:_canvasBackgroundController animated:YES completion:^{
        
    }];
}

-(void)showCliperView {
    CliperView *cliper = [[CliperView alloc]initWithFrame:self.view.frame];
    [self.view addSubview:cliper];
}

-(void)showLayerPopoverController:(UIButton*)sender {
    UIImage *image = [UIImage imageNamed:@"layers_popover_bg"];
    if (!_layersViewController) {
        _layersViewController = [ZXHLayersViewController new];
        _layersViewController.preferredContentSize = CGSizeMake(image.size.width, image.size.height-30);
        _layersViewController.modalPresentationStyle = UIModalPresentationPopover;
    }
    
    
    
    UIPopoverPresentationController *pop = _layersViewController.popoverPresentationController;
    pop.delegate = self;
    pop.popoverBackgroundViewClass = [DDPopoverBackgroundView class];
    [DDPopoverBackgroundView setContentInset:2];
    [DDPopoverBackgroundView setBackgroundImage:image];
    [DDPopoverBackgroundView setBackgroundImageCornerRadius:1.f];
    [DDPopoverBackgroundView setArrowBase:0];
    [DDPopoverBackgroundView setArrowHeight:2];
    
    // 弹出位置
    CGRect popRect = sender.frame;
    popRect.origin.x -= (image.size.width+70);
    popRect.origin.y -= 30;
    pop.sourceView = sender;
    pop.sourceRect = popRect;
    
    [self presentViewController:_layersViewController animated:YES completion:^{
        
    }];
    
    [_layersViewController addObserver:self forKeyPath:@"layersCount" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
}

#pragma mark WDColorPickerControllerDelegate
- (void) dismissViewController:(UIViewController *)viewController
{
    if (popoverController) {
        [self hidePopovers];
    } else {
        [viewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void) setActiveStateColor:(WDColor*)color from:(WDColorPickerController*) colorPickerController
{
    [[HYBrushCore sharedInstance] setActiveStateColor:[color UIColor]];
    bottomBarView.colorWheelButton.color = color;
}

#pragma mark ShapeBoxControllerDelegate

-(void)didSelectedShape:(UIImage*)img {
    [_shapeBoxPopoverController dismissPopoverAnimated:YES];
    [self showImageTransform:img];
}

#pragma mark -
#pragma mark Layer Transform
- (void) layerTransformChanged:(TransformOverlayer *)sender
{
    CGAffineTransform trans = sender.alignedTransform;
    [[HYBrushCore sharedInstance] setActiveLayerTransform: trans];
    
}

- (void) cancelLayerTransformation
{
//    if (!self.controller.runningOnPhone) {
//        [UIView animateWithDuration:UINavigationControllerHideShowBarDuration
//                         animations:^{ transformOverlay_.alpha = 0.0f; }
//                         completion:^(BOOL finished) {
//                             [transformOverlay_ removeFromSuperview];
//                             transformOverlay_ = nil;
//                             
//                             [self.controller showInterface];
//                         }];
//    } else
    {
        [transformOverlayer removeFromSuperview];
        transformOverlayer = nil;
        [self updateLayersView];
        [self displayToolView:YES];
    }
    
    [[HYBrushCore sharedInstance] setActiveLayerTransform:CGAffineTransformIdentity];
    [[HYBrushCore sharedInstance] setActiveLayerLinearInterprolation:NO];
}

- (void) transformActiveLayer
{
//    if (transformOverlay_.horizontalFlip) {
//        changeDocument(self.painting, [WDModifyLayer modifyLayer:self.painting.activeLayer withOperation:WDFlipLayerHorizontal]);
//    }
//    
//    if (transformOverlay_.verticalFlip) {
//        changeDocument(self.painting, [WDModifyLayer modifyLayer:self.painting.activeLayer withOperation:WDFlipLayerVertical]);
//    }
    
//    // only change the doc if the transform actually changed
//    if (!CGAffineTransformIsIdentity(rawLayerTransform)) {
//        changeDocument(self.painting, [WDTransformLayer transformLayer:self.painting.activeLayer transform:rawLayerTransform]);
//    }
    
    [[HYBrushCore sharedInstance] renderActiveLayerWithTransform:transformOverlayer.alignedTransform];
    [self cancelLayerTransformation];
}

#pragma mark Photo Placement
- (void)photoTransformChanged:(TransformOverlayer *)sender
{
    CGAffineTransform trans = sender.alignedTransform;
    [[HYBrushCore sharedInstance] setPhotoTransform: trans];
}

- (void) cancelPhotoPlacement
{
//    if (!self.controller.runningOnPhone) {
//        [UIView animateWithDuration:UINavigationControllerHideShowBarDuration
//                         animations:^{ transformOverlay_.alpha = 0.0f; }
//                         completion:^(BOOL finished) {
//                             [transformOverlay_ removeFromSuperview];
//                             transformOverlay_ = nil;
//                             
//                             [self.controller showInterface];
//                         }];
//    } else
    {
        [transformOverlayer removeFromSuperview];
        transformOverlayer = nil;
        [self updateLayersView];
        [self displayToolView:YES];
    }
    
    [[HYBrushCore sharedInstance]endPhotoPlacement:NO];
}

- (void) placePhoto
{
    
    {
        [transformOverlayer removeFromSuperview];
        transformOverlayer = nil;
        [self updateLayersView];
        [self displayToolView:YES];
    }
    
    [[HYBrushCore sharedInstance]endPhotoPlacement:YES];
    [[NSNotificationCenter defaultCenter]postNotificationName:LayersCountChange object:nil userInfo:nil];

}

#pragma mark -

#pragma mark BrushSizePannelViewDelegate
- (void)brushSizePannelView:(BrushSizePannelView *)brushSizePannelView valueChanged:(float)value
{
    [[HYBrushCore sharedInstance] setActiveBrushSize:value];
}


#pragma mark CanvasViewDelegate Methods

- (void)showMessageView:(ShowingMessageType)msgType
{
    NSLog(@"showMessageView");
    NSInteger curLayerIndex = [[HYBrushCore sharedInstance]getActiveLayerIndex];
    BOOL visible = [[HYBrushCore sharedInstance]isVisibleOfLayer:curLayerIndex];
    BOOL locked = [[HYBrushCore sharedInstance]isLockedofLayer:curLayerIndex];
    
    ZXHEditableTipsView *tipsView = [ZXHEditableTipsView defaultTipsView];
    tipsView.visible = visible;
    tipsView.locked = locked;
    [self.view addSubview:tipsView];
    [tipsView showTips];
}

- (void)dismissMessageView {
    NSLog(@"dismissMessageView");
    [[ZXHEditableTipsView defaultTipsView] dismissTips];
}

- (void)displayToolView:(BOOL) flag
{
    if (!flag && !bottomBarView.hidden) {
        [UIView animateWithDuration:0.25 animations:^{
            bottomBarView.alpha = 0;
            self.navigationController.navigationBar.alpha = 0;
            [self displayBrushSizePannel:NO];
        }completion:^(BOOL finished) {
            bottomBarView.hidden = YES;
        }];
    }
    else if(flag && bottomBarView.hidden) {
        [UIView animateWithDuration:0.25 animations:^{
            bottomBarView.alpha = 1;
            self.navigationController.navigationBar.alpha = 1;
            [self displayBrushSizePannel:YES];
        } completion:^(BOOL finished) {
            bottomBarView.hidden = NO;
        }];
    }
}

#pragma mark - Actions

- (void)undo:(UIBarButtonItem *)sender {
    undoItem.enabled = YES; // 应该为NO
    redoItem.enabled = YES;
    undoItem.image = [UIImage imageNamed:@"undo_n"];
    redoItem.image = [UIImage imageNamed:@"redo"];
    
    Actions *pre = undoActions.lastObject;
    switch (pre.type) {
        case kCanvasChanging:
            undoItem.enabled = [[HYBrushCore sharedInstance] undoPaintingOfLayer:pre.activeLayerIdx];
            break;
        case kAddingLayer:
        case kDuplicatingLayer:
            [[HYBrushCore sharedInstance] setActiveLayer:pre.activeLayerIdx];
            [[HYBrushCore sharedInstance] deleteActiveLayer];
            break;
        case kDeletingLayer:
            [[HYBrushCore sharedInstance] restoreDeletedLayer];
            break;
        default:
            break;
    }
    [redoActions addObject:undoActions.lastObject];
    [undoActions removeLastObject];
    if (undoActions.count>0) {
        undoItem.enabled = YES;
    }
    else {
        undoItem.enabled = NO;
    }
}

- (void)redo:(UIBarButtonItem *)sender {
    undoItem.enabled = YES;
    redoItem.enabled = YES; // 应该为NO
    undoItem.image = [UIImage imageNamed:@"undo"];
    redoItem.image = [UIImage imageNamed:@"redo_n"];
    
    Actions *fut = redoActions.lastObject;
    switch (fut.type) {
        case kCanvasChanging:
            redoItem.enabled = [[HYBrushCore sharedInstance] redoPaintingOfLayer:fut.activeLayerIdx];
            break;
        case kAddingLayer:
            [[HYBrushCore sharedInstance] setActiveLayer:fut.activeLayerIdx];
            [[HYBrushCore sharedInstance] addNewLayer];
            if (redoActions.count>0) {
                [HYBrushCore sharedInstance].isAllowRedo = YES;
            }
            break;
        case kDuplicatingLayer:
            [[HYBrushCore sharedInstance] setActiveLayer:fut.activeLayerIdx];
            [[HYBrushCore sharedInstance] duplicateActiveLayer];
            break;
        case kDeletingLayer:
            [[HYBrushCore sharedInstance] setActiveLayer:fut.activeLayerIdx];
            [[HYBrushCore sharedInstance] deleteActiveLayer];
            break;
        default:
            break;
    }
    [undoActions addObject:redoActions.lastObject];
    [redoActions removeLastObject];
    if (redoActions.count>0) {
        redoItem.enabled = YES;
    }
    else {
        redoItem.enabled = NO;
    }
}

- (void) handleCanvasDirtyNotificaton {
    undoItem.enabled = YES;
    redoItem.enabled = NO;
    undoItem.image = [UIImage imageNamed:@"undo"];
    redoItem.image = [UIImage imageNamed:@"redo_n"];
    
    [[HYBrushCore sharedInstance] restoreUndoFragments];
    
    if (preAction == nil || preAction.type != kCanvasChanging) {
        preAction = [Actions createCanvasChangingAction:[[HYBrushCore sharedInstance]getActiveLayerIndex]];
        if (undoActions.count>9) {
            for (int i = 1; i<undoActions.count; i++) {
                undoActions[i-1] = undoActions[i];
            }
            [undoActions replaceObjectAtIndex:9 withObject:preAction];
        }
        else {
            [undoActions addObject:preAction];
        }
    }
    else {
        preAction.activeLayerIdx = [[HYBrushCore sharedInstance]getActiveLayerIndex];
        if (undoActions.count>9) {
            for (int i = 1; i<undoActions.count; i++) {
                undoActions[i-1] = undoActions[i];
            }
            [undoActions replaceObjectAtIndex:9 withObject:preAction];
        }
        else {
            [undoActions addObject:preAction];
        }
    }
}

- (void) handleLayersOperationNotification:(NSNotification*) notification {
    undoItem.enabled = YES;
    redoItem.enabled = NO;
    undoItem.image = [UIImage imageNamed:@"undo"];
    redoItem.image = [UIImage imageNamed:@"redo_n"];
    
    preAction = [notification userInfo][@"Action"];
    if (undoActions.count>9) {
        for (int i = 1; i<undoActions.count; i++) {
            undoActions[i-1] = undoActions[i];
        }
        [undoActions replaceObjectAtIndex:9 withObject:preAction];
    }
    else {
        [undoActions addObject:preAction];
    }
}

#pragma mark - Private Methods

- (NSArray *)constrainSubview:(UIView *)subview toMatchWithSuperview:(UIView *)superview {
    subview.translatesAutoresizingMaskIntoConstraints = NO;
    float padding = (superview.frame.size.width - subview.frame.size.width) /2.f;
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(subview);
    NSDictionary *metrics = @{@"vHeight":@(51),@"hPadding":@(padding)};
    
    NSArray *constraints = [NSLayoutConstraint
                            constraintsWithVisualFormat:@"H:|-hPadding-[subview]-hPadding-|"
                            options:0
                            metrics:metrics
                            views:viewsDictionary];

    constraints = [constraints arrayByAddingObjectsFromArray:
                   [NSLayoutConstraint
                    constraintsWithVisualFormat:@"V:[subview(vHeight)]|"
                    options:0
                    metrics:metrics
                    views:viewsDictionary]];
    
    
    [superview addConstraints:constraints];
    
    return constraints;
}

- (void)constrainFullScreenSubview:(UIView *)subview toMatchWithSuperview:(UIView *)superview
{
    
    subview.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(subview);
    
    NSArray *constraints = [NSLayoutConstraint
                            constraintsWithVisualFormat:@"H:|[subview]|"
                            options:0
                            metrics:nil
                            views:viewsDictionary];
    constraints = [constraints arrayByAddingObjectsFromArray:
                   [NSLayoutConstraint
                    constraintsWithVisualFormat:@"V:|[subview]|"
                    options:0
                    metrics:nil
                    views:viewsDictionary]];
    [superview addConstraints:constraints];
}

- (void)displayBrushSizePannel:(BOOL) flag {
    if (!flag)
    {
        [brushSizePannelView setAlpha:0.0f];
        return;
    }
    
    switch (activeButton) {
        case ERASER_BTN:            ///< 橡皮擦
            [brushSizePannelView setAlpha:1.0f];
            break;
        case PENCIL_BTN:            ///< 铅笔
            [brushSizePannelView setAlpha:1.0f];
            break;
        case MARKERPEN_BTN:         ///< 马克笔
            [brushSizePannelView setAlpha:1.0f];
            break;
        case COLORBRUSH_BTN:        ///< 水彩笔
            [brushSizePannelView setAlpha:1.0f];
            break;
        case CRAYON_BTN:
            [brushSizePannelView setAlpha:1.0f];
            break;
        case BUCKET_BTN:            ///< 倒色桶
            [brushSizePannelView setAlpha:0.0f];
            break;
        case SHAPEBOX_BTN:          ///< 图形箱
            [brushSizePannelView setAlpha:0.0f];
            break;
        case EYEDROPPER_BTN:        ///< 取色管
            [brushSizePannelView setAlpha:0.0f];
            break;
        case CLIP_BTN:              ///< 裁减
            //            [self showCliperView];
            break;
        case CANVAS_BTN:            ///< 背景图
            [brushSizePannelView setAlpha:0.0f];
            break;
        default:
            break;
    }
}

- (void)updateLayersView
{
    _layersViewController.layersCount = [[HYBrushCore sharedInstance]getLayersNumber];
    [_layersViewController.tbView reloadData];
    
    [self displayToolView:YES];
}

- (void) paintColorChanged:(NSNotification *)aNotification
{
    UIColor *pickedColor = [aNotification userInfo][@"pickedColor"];
    CGFloat r,g,b,a;
    [pickedColor getRed:&r green:&g blue:&b alpha:&a];
    [self.colorPickerController setColor:[WDColor colorWithRed:r green:g blue:b alpha:a]];
}

- (void) showImageTransform:(UIImage*)image
{
    CGSize imageSize = image.size;
    if (imageSize.width > imageSize.height) {
        if (imageSize.width > 2048) {
            imageSize.height = (imageSize.height / imageSize.width) * 2048;
            imageSize.width = 2048;
        }
    } else {
        if (imageSize.height > 2048) {
            imageSize.width = (imageSize.width / imageSize.height) * 2048;
            imageSize.height = 2048;
        }
    }
    // TO DO:
//    image = [image resizedImage:imageSize interpolationQuality:kCGInterpolationHigh];
	
    // create transform overlayer of image
    float canvasScale = [[HYBrushCore sharedInstance] getCanvasScale];
    float screenScale = [[UIScreen mainScreen] scale];
    transformOverlayer = [[TransformOverlayer alloc] initWithFrame:self.view.bounds title:@"图片插入" scaleFactor:screenScale / canvasScale];
    
    __weak HYDrawingViewController *weakSelf = self;
    transformOverlayer.cancelBlock = ^{ [weakSelf cancelPhotoPlacement];    };
    transformOverlayer.acceptBlock = ^{ [weakSelf placePhoto];  };
    
    [transformOverlayer addTarget:self action:@selector(photoTransformChanged:)
                 forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:transformOverlayer];
    
    [[HYBrushCore sharedInstance]setActiveLayerLinearInterprolation:YES];
    [[HYBrushCore sharedInstance]beginPhotoPlacement:image withTransform:[transformOverlayer configureInitialPhotoTransform:image]];
    
    [self displayToolView:NO];
}

#pragma mark - Copied directly

- (BOOL) shouldDismissPopoverForClassController:(Class)controllerClass insideNavController:(BOOL)insideNav
{
    if (!popoverController) {
        return NO;
    }
    
    if (insideNav && [popoverController.contentViewController isKindOfClass:[UINavigationController class]]) {
        NSArray *viewControllers = [(UINavigationController *)popoverController.contentViewController viewControllers];
        
        for (UIViewController *viewController in viewControllers) {
            if ([viewController isKindOfClass:controllerClass]) {
                return YES;
            }
        }
    } else if ([popoverController.contentViewController isKindOfClass:controllerClass]) {
        return YES;
    }
    
    return NO;
}

- (void) showController:(UIViewController *)controller fromBarButtonItem:(UIBarButtonItem *)barButton animated:(BOOL)animated
{
    [self runPopoverWithController:controller from:barButton];
}

- (UIPopoverPresentationController *)runPopoverWithController:(UIViewController *)controller from:(id)sender
{
    [self hidePopovers];
    
    UIPopoverPresentationController *popP = controller.popoverPresentationController;
    if ([sender isKindOfClass:[UIBarButtonItem class]]) {
        popP.delegate = self;
        popP.barButtonItem = sender;
        [self presentViewController:controller animated:YES completion:^{
            
        }];
    } else {
        UIView *source = (UIView *)sender;
        popP.delegate = self;
        popP.sourceView = source;
        popP.sourceRect = source.bounds;
        [self presentViewController:controller animated:YES completion:^{
            
        }];
    }
    
    return popoverPController;
}

- (BOOL) popoverVisible
{
    return popoverController ? YES : NO;
}

- (void) hidePopovers
{
    if (popoverController) {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController1
{
    if (popoverController1 == popoverController) {
        popoverController = nil;
    }
}

@end
