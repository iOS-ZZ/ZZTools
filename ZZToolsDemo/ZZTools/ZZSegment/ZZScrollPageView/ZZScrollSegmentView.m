//
//  ZZScrollSegmentView.m
//  ZZToolsDemo
//
//  Created by 刘猛 on 19/5/6.
//  Copyright © 2016年 刘猛. All rights reserved.
//

#import "ZZTitleView.h"
#import "ZZAutoLayout.h"
#import "ZZPrivateHeader.h"
#import "ZZScrollSegmentView.h"

@interface ZZScrollSegmentView ()<UIScrollViewDelegate> {
    CGFloat _currentWidth;
    NSUInteger _currentIndex;
    NSUInteger _oldIndex;
//    BOOL _isScroll;
}

// 滚动条
@property (nonatomic, strong) UIView *scrollLine;
// 遮盖
@property (nonatomic, strong) UIView *coverLayer;

//遮盖渐变层
@property (nonatomic, strong) CAGradientLayer *gradient;

// 滚动scrollView
@property (nonatomic, strong) UIScrollView *scrollView;
// 背景ImageView
@property (nonatomic, strong) UIImageView *backgroundImageView;
// 附加的按钮
@property (nonatomic, strong) UIButton *extraBtn;

// 用于懒加载计算文字的rgba差值, 用于颜色渐变的时候设置
@property (nonatomic, strong) NSArray *deltaRGBA;
@property (nonatomic, strong) NSArray *selectedColorRGBA;
@property (nonatomic, strong) NSArray *normalColorRGBA;

/** 缓存所有标题label */
@property (nonatomic, strong) NSMutableArray *titleViews;
// 缓存计算出来的每个标题的宽度
@property (nonatomic, strong) NSMutableArray *titleWidths;
// 响应标题点击
@property (copy, nonatomic) TitleBtnOnClickBlock titleBtnOnClick;
/**底部滚动的实例显示宽度*/
@property (nonatomic,assign)CGFloat scrollLineTrueShowWidth;
/**底部的阴影*/
@property (nonatomic,strong)UILabel *bottomShadowLabel;
/***/
@property (nonatomic,assign)CGFloat scrollLineUpOffset;

///
@property (nonatomic, strong) UIView *coverView;

@end

@implementation ZZScrollSegmentView

static CGFloat const xGap = 5.0;
static CGFloat const wGap = 2 * xGap;
static CGFloat const contentSizeXOff = 20.0;

#pragma mark - life cycle
- (instancetype)initWithFrame:(CGRect )frame segmentStyle:(ZZSegmentStyle *)segmentStyle delegate:(id<ZZScrollPageViewDelegate>)delegate titles:(NSArray *)titles titleDidClick:(TitleBtnOnClickBlock)titleDidClick {
    if (self = [super initWithFrame:frame]) {
        self.segmentStyle = segmentStyle;
        self.titles = titles;
        self.titleBtnOnClick = titleDidClick;
        self.delegate = delegate;
        _currentIndex = 0;
        _oldIndex = 0;
        _currentWidth = frame.size.width;
        
        if (!self.segmentStyle.isScrollTitle) { // 不能滚动的时候就不要把缩放和遮盖或者滚动条同时使用, 否则显示效果不好
            
            self.segmentStyle.scaleTitle = !(self.segmentStyle.isShowCover || self.segmentStyle.isShowLine);
        }
        
        if (self.segmentStyle.isShowImage) {//不要有以下的显示效果
            self.segmentStyle.scaleTitle = NO;
            self.segmentStyle.showCover = NO;
            self.segmentStyle.gradualChangeTitleColor = NO;
        }
        
        // 设置了frame之后可以直接设置其他的控件的frame了, 不需要在layoutsubView()里面设置
        [self setupSubviews];
        [self setupUI];

    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect )frame bottomLineWidth:(CGFloat)bottomLineWidth segmentStyle:(ZZSegmentStyle *)segmentStyle delegate:(id<ZZScrollPageViewDelegate>)delegate titles:(NSArray *)titles titleDidClick:(TitleBtnOnClickBlock)titleDidClick{
    if (self = [super initWithFrame:frame]) {
        self.segmentStyle = segmentStyle;
        self.titles = titles;
        self.titleBtnOnClick = titleDidClick;
        self.delegate = delegate;
        _currentIndex = 0;
        _oldIndex = 0;
        _currentWidth = frame.size.width;
        _scrollLineTrueShowWidth = bottomLineWidth;
        if (!self.segmentStyle.isScrollTitle) { // 不能滚动的时候就不要把缩放和遮盖或者滚动条同时使用, 否则显示效果不好
            
            self.segmentStyle.scaleTitle = !(self.segmentStyle.isShowCover || self.segmentStyle.isShowLine);
        }
        
        if (self.segmentStyle.isShowImage) {//不要有以下的显示效果
            self.segmentStyle.scaleTitle = NO;
            self.segmentStyle.showCover = NO;
            self.segmentStyle.gradualChangeTitleColor = NO;
        }
        
        // 设置了frame之后可以直接设置其他的控件的frame了, 不需要在layoutsubView()里面设置
        [self setupSubviews];
        [self setupUI];
        
    }
    
    return self;
}

- (void)setupSubviews {
    
    [self addSubview:self.scrollView];
    [self addScrollLineOrCoverOrExtraBtn];
    [self setupTitles];
}

- (void)addScrollLineOrCoverOrExtraBtn {
    if (self.segmentStyle.isShowLine) {
        [self.scrollView addSubview:self.scrollLine];
    }
    
    if (self.segmentStyle.isShowCover) {
        [self.scrollView insertSubview:self.coverLayer atIndex:0];
        
    }
    
    if (self.segmentStyle.isShowExtraButton) {
        [self addSubview:self.extraBtn];
    }
}

- (void)dealloc {
#if DEBUG
    //NSLog(@"ZZScrollSegmentView ---- 销毁");
    
#endif
}

#pragma mark - button action

- (void)titleLabelOnClick:(UITapGestureRecognizer *)tapGes {
    
    ZZTitleView *currentLabel = (ZZTitleView *)tapGes.view;
    
    if (!currentLabel) {
        return;
    }
    
    _currentIndex = currentLabel.tag;
    
    [self adjustUIWhenBtnOnClickWithAnimate:true taped:YES];
}

- (void)extraBtnOnClick:(UIButton *)extraBtn {
    
    if (self.extraBtnOnClick) {
        self.extraBtnOnClick(extraBtn);
    }
}

#pragma mark - private helper

- (void)setupTitles {
    
    if (self.titles.count == 0) return;
    
    NSInteger index = 0;
    for (NSString *title in self.titles) {
        
        ZZTitleView *titleView = [[ZZTitleView alloc] initWithFrame:CGRectZero];
        titleView.tag = index;
        
        titleView.font = self.segmentStyle.titleFont;
        titleView.text = title;
        titleView.textColor = self.segmentStyle.normalTitleColor;
        titleView.imagePosition = self.segmentStyle.imagePosition;

        
        if (self.delegate && [self.delegate respondsToSelector:@selector(setUpTitleView:forIndex:)]) {
            [self.delegate setUpTitleView:titleView forIndex:index];
        }
        
        UITapGestureRecognizer *tapGes = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleLabelOnClick:)];
        [titleView addGestureRecognizer:tapGes];
        
        CGFloat titleViewWidth = [titleView titleViewWidth];
        [self.titleWidths addObject:@(titleViewWidth)];
        
        [self.titleViews addObject:titleView];
        [self.scrollView addSubview:titleView];
        
        index++;
        
    }
    
}

- (void)setupUI {
    if (self.titles.count == 0) return;

    [self setupScrollViewAndExtraBtn];
    [self setUpTitleViewsPosition];
    [self setupScrollLineAndCover];
    
    if (self.segmentStyle.isScrollTitle) { // 设置滚动区域
        ZZTitleView *lastTitleView = (ZZTitleView *)self.titleViews.lastObject;
        
        if (lastTitleView) {
            self.scrollView.contentSize = CGSizeMake(CGRectGetMaxX(lastTitleView.frame) + contentSizeXOff, 0.0);
        }
    }
    
}

- (void)setupScrollViewAndExtraBtn {
    CGFloat extraBtnW = 44.0;
    CGFloat extraBtnY = 5.0;
    
    //    UILabel *lastLabel = _titleLabels.lastObject;
    //    CGFloat maxX = CGRectGetMaxX(lastLabel.frame) + 8;
    CGFloat scrollW = self.extraBtn ? _currentWidth - extraBtnW : _currentWidth;
    //    if (maxX < _currentWidth) {
    //        scrollW = maxX;
    //    }
    self.scrollView.frame = CGRectMake(0.0, 0.0, scrollW, self.zz_height);

    if (self.extraBtn) {
        self.extraBtn.frame = CGRectMake(scrollW , extraBtnY, extraBtnW, self.zz_height - 2*extraBtnY);
    }
}

- (void)setUpTitleViewsPosition {
    CGFloat titleX = 0.0;
    CGFloat titleY = 0.0;
    CGFloat titleW = 0.0;
    CGFloat titleH = self.zz_height - self.segmentStyle.scrollLineHeight;
    
    if (!self.segmentStyle.isScrollTitle) {// 标题不能滚动, 平分宽度
        titleW = self.scrollView.bounds.size.width / self.titles.count;
        
        NSInteger index = 0;
        for (ZZTitleView *titleView in self.titleViews) {
            
            titleX = index * titleW;
            
            titleView.frame = CGRectMake(titleX, titleY, titleW, titleH);
            if (self.segmentStyle.isShowImage) {
                [titleView adjustSubviewFrame];
            }
            index++;
        }
        
    } else {
        NSInteger index = 0;
        float lastLableMaxX = self.segmentStyle.titleMargin;
        float addedMargin = 0.0f;
        if (self.segmentStyle.isAutoAdjustTitlesWidth) {
            
            float allTitlesWidth = self.segmentStyle.titleMargin;
            for (int i = 0; i<self.titleWidths.count; i++) {
                allTitlesWidth = allTitlesWidth + [self.titleWidths[i] floatValue] + self.segmentStyle.titleMargin;
            }
            
            
            addedMargin = allTitlesWidth < self.scrollView.bounds.size.width ? (self.scrollView.bounds.size.width - allTitlesWidth)/self.titleWidths.count : 0 ;
        }

        for (ZZTitleView *titleView in self.titleViews) {
            titleW = [self.titleWidths[index] floatValue];
            titleX = lastLableMaxX + addedMargin/2;

            lastLableMaxX += (titleW + addedMargin + self.segmentStyle.titleMargin);

            titleView.frame = CGRectMake(titleX, titleY, titleW, titleH);
            if (self.segmentStyle.isShowImage) {
                [titleView adjustSubviewFrame];
            }
            index++;
            
        }
        
    }
    
    ZZTitleView *currentTitleView = (ZZTitleView *)self.titleViews[_currentIndex];
    currentTitleView.currentTransformSx = 1.0;
    if (currentTitleView) {
        
        // 缩放, 设置初始的label的transform
        if (self.segmentStyle.isScaleTitle) {
            currentTitleView.currentTransformSx = self.segmentStyle.titleBigScale;
        }
        // 设置初始状态文字的颜色
        currentTitleView.textColor = self.segmentStyle.selectedTitleColor;
        if (self.segmentStyle.isShowImage) {
            currentTitleView.selected = YES;
        }
    }
    
}

- (void)setupScrollLineAndCover {
    
    ZZTitleView *firstLabel = (ZZTitleView *)self.titleViews[0];
    CGFloat coverX = firstLabel.zz_x;
    CGFloat coverW = firstLabel.zz_width;
    CGFloat coverH = self.segmentStyle.coverHeight;
    CGFloat coverY = (self.bounds.size.height - coverH) * 0.5;
    
    if (self.scrollLine) {
        
        if (self.segmentStyle.isScrollTitle) {
            self.scrollLine.frame = CGRectMake(coverX , self.zz_height - self.segmentStyle.scrollLineHeight - self.scrollLineUpOffset - self.segmentStyle.scrollLineBottomMargin, coverW , self.segmentStyle.scrollLineHeight);

        } else {
            if (self.segmentStyle.isAdjustCoverOrLineWidth) {
                coverW = [self.titleWidths[_currentIndex] floatValue] + wGap;
                coverX = (firstLabel.zz_width - coverW) * 0.5;
            }

            self.scrollLine.frame = CGRectMake(coverX , self.zz_height - self.segmentStyle.scrollLineHeight - self.scrollLineUpOffset - self.segmentStyle.scrollLineBottomMargin, coverW , self.segmentStyle.scrollLineHeight);

        }
    }
    
    if (self.coverLayer) {
        
        if (self.segmentStyle.isScrollTitle) {
            self.coverLayer.frame = CGRectMake(coverX - xGap, coverY, coverW + wGap, coverH);
            if (self.segmentStyle.showCoverGrade) {
                [self.coverView zz_insertGradientLayerWithBounds:self.coverView.bounds colorArray:self.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
            }
        } else {
            if (self.segmentStyle.isAdjustCoverOrLineWidth) {
                coverW = [self.titleWidths[_currentIndex] floatValue] + wGap;
                coverX = (firstLabel.zz_width - coverW) * 0.5;
            }

            self.coverLayer.frame = CGRectMake(coverX, coverY, coverW, coverH);
            if (self.segmentStyle.showCoverGrade) {
                [self.coverView zz_insertGradientLayerWithBounds:self.coverView.bounds colorArray:self.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
            }
        }
        
        
    }
        
}

#pragma mark - public helper

- (void)adjustUIWhenBtnOnClickWithAnimate:(BOOL)animated taped:(BOOL)taped {
    if (_currentIndex == _oldIndex && taped) { return; }
    
    ZZTitleView *oldTitleView = (ZZTitleView *)self.titleViews[_oldIndex];
    ZZTitleView *currentTitleView = (ZZTitleView *)self.titleViews[_currentIndex];
    
    CGFloat animatedTime = animated ? 0.30 : 0.0;
    
    __weak typeof(self) weakSelf = self;
    
    [UIView animateWithDuration:animatedTime animations:^{
        oldTitleView.textColor = weakSelf.segmentStyle.normalTitleColor;
        currentTitleView.textColor = weakSelf.segmentStyle.selectedTitleColor;
        oldTitleView.selected = NO;
        currentTitleView.selected = YES;
        if (weakSelf.segmentStyle.isScaleTitle) {
            oldTitleView.currentTransformSx = 1.0;
            currentTitleView.currentTransformSx = weakSelf.segmentStyle.titleBigScale;
        }
        
        if (weakSelf.scrollLine) {
            if (weakSelf.segmentStyle.isScrollTitle) {
                weakSelf.scrollLine.zz_x = currentTitleView.zz_x;
                weakSelf.scrollLine.zz_width = currentTitleView.zz_width;
            } else {
                if (self.segmentStyle.isAdjustCoverOrLineWidth) {
                    CGFloat scrollLineW = [self.titleWidths[self->_currentIndex] floatValue] + wGap;
                    CGFloat scrollLineX = currentTitleView.zz_x + (currentTitleView.zz_width - scrollLineW) * 0.5;
                    weakSelf.scrollLine.zz_x = scrollLineX;
                    weakSelf.scrollLine.zz_width = scrollLineW;
                } else {
                    weakSelf.scrollLine.zz_x = currentTitleView.zz_x;
                    weakSelf.scrollLine.zz_width = currentTitleView.zz_width;
                }
                
            }
            
        }
        
        if (weakSelf.coverLayer) {
            if (weakSelf.segmentStyle.isScrollTitle) {
                weakSelf.coverLayer.zz_x = currentTitleView.zz_x - xGap;
                weakSelf.coverLayer.zz_width = currentTitleView.zz_width + wGap;
                if (weakSelf.segmentStyle.showCoverGrade) {
                    [weakSelf.coverView zz_insertGradientLayerWithBounds:weakSelf.coverView.bounds colorArray:weakSelf.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
                }
            } else {
                if (self.segmentStyle.isAdjustCoverOrLineWidth) {
                    CGFloat coverW = [self.titleWidths[self -> _currentIndex] floatValue] + wGap;
                    CGFloat coverX = currentTitleView.zz_x + (currentTitleView.zz_width - coverW) * 0.5;
                    weakSelf.coverLayer.zz_x = coverX;
                    weakSelf.coverLayer.zz_width = coverW;
                    if (weakSelf.segmentStyle.showCoverGrade) {
                        [weakSelf.coverView zz_insertGradientLayerWithBounds:weakSelf.coverView.bounds colorArray:weakSelf.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
                    }
                } else {
                    weakSelf.coverLayer.zz_x = currentTitleView.zz_x;
                    weakSelf.coverLayer.zz_width = currentTitleView.zz_width;
                    if (weakSelf.segmentStyle.showCoverGrade) {
                        [weakSelf.coverView zz_insertGradientLayerWithBounds:weakSelf.coverView.bounds colorArray:weakSelf.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
                    }
                }
            }
            
        }

    } completion:^(BOOL finished) {
        [weakSelf adjustTitleOffSetToCurrentIndex:self -> _currentIndex];

    }];
    
    _oldIndex = _currentIndex;
    if (self.titleBtnOnClick) {
        self.titleBtnOnClick(currentTitleView, _currentIndex);
    }
}

- (void)adjustUIWithProgress:(CGFloat)progress oldIndex:(NSInteger)oldIndex currentIndex:(NSInteger)currentIndex {
    if (oldIndex < 0 ||
        oldIndex >= self.titles.count ||
        currentIndex < 0 ||
        currentIndex >= self.titles.count
        ) {
        return;
    }
    _oldIndex = currentIndex;
    
    ZZTitleView *oldTitleView = (ZZTitleView *)self.titleViews[oldIndex];
    ZZTitleView *currentTitleView = (ZZTitleView *)self.titleViews[currentIndex];

    
    CGFloat xDistance = currentTitleView.zz_x - oldTitleView.zz_x;
    CGFloat wDistance = currentTitleView.zz_width - oldTitleView.zz_width;
    
    if (self.scrollLine) {
        
        if (self.segmentStyle.isScrollTitle) {
            self.scrollLine.zz_x = oldTitleView.zz_x + xDistance * progress;
            self.scrollLine.zz_width = oldTitleView.zz_width + wDistance * progress;
        } else {
            if (self.segmentStyle.isAdjustCoverOrLineWidth) {
                CGFloat oldScrollLineW = [self.titleWidths[oldIndex] floatValue] + wGap;
                CGFloat currentScrollLineW = [self.titleWidths[currentIndex] floatValue] + wGap;
                wDistance = currentScrollLineW - oldScrollLineW;
                
                CGFloat oldScrollLineX = oldTitleView.zz_x + (oldTitleView.zz_width - oldScrollLineW) * 0.5;
                CGFloat currentScrollLineX = currentTitleView.zz_x + (currentTitleView.zz_width - currentScrollLineW) * 0.5;
                xDistance = currentScrollLineX - oldScrollLineX;
                self.scrollLine.zz_x = oldScrollLineX + xDistance * progress;
                self.scrollLine.zz_width = oldScrollLineW + wDistance * progress;
            } else {
                self.scrollLine.zz_x = oldTitleView.zz_x + xDistance * progress;
                self.scrollLine.zz_width = oldTitleView.zz_width + wDistance * progress;
            }
        }

    }
    
    if (self.coverLayer) {
        if (self.segmentStyle.isScrollTitle) {
            self.coverLayer.zz_x = oldTitleView.zz_x + xDistance * progress - xGap;
            self.coverLayer.zz_width = oldTitleView.zz_width + wDistance * progress + wGap;
            if (self.segmentStyle.showCoverGrade) {
                [self.coverView zz_insertGradientLayerWithBounds:self.coverView.bounds colorArray:self.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
            }
        } else {
            if (self.segmentStyle.isAdjustCoverOrLineWidth) {
                CGFloat oldCoverW = [self.titleWidths[oldIndex] floatValue] + wGap;
                CGFloat currentCoverW = [self.titleWidths[currentIndex] floatValue] + wGap;
                wDistance = currentCoverW - oldCoverW;
                CGFloat oldCoverX = oldTitleView.zz_x + (oldTitleView.zz_width - oldCoverW) * 0.5;
                CGFloat currentCoverX = currentTitleView.zz_x + (currentTitleView.zz_width - currentCoverW) * 0.5;
                xDistance = currentCoverX - oldCoverX;
                self.coverLayer.zz_x = oldCoverX + xDistance * progress;
                self.coverLayer.zz_width = oldCoverW + wDistance * progress;
                if (self.segmentStyle.showCoverGrade) {
                    [self.coverView zz_insertGradientLayerWithBounds:self.coverView.bounds colorArray:self.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
                }
            } else {
                self.coverLayer.zz_x = oldTitleView.zz_x + xDistance * progress;
                self.coverLayer.zz_width = oldTitleView.zz_width + wDistance * progress;
                if (self.segmentStyle.showCoverGrade) {
                    [self.coverView zz_insertGradientLayerWithBounds:self.coverView.bounds colorArray:self.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
                }
            }
        }
    }
    
    // 渐变
    if (self.segmentStyle.isGradualChangeTitleColor) {

        oldTitleView.textColor = [UIColor
                                  colorWithRed:[self.selectedColorRGBA[0] floatValue] + [self.deltaRGBA[0] floatValue] * progress
                                  green:[self.selectedColorRGBA[1] floatValue] + [self.deltaRGBA[1] floatValue] * progress
                                  blue:[self.selectedColorRGBA[2] floatValue] + [self.deltaRGBA[2] floatValue] * progress
                                  alpha:[self.selectedColorRGBA[3] floatValue] + [self.deltaRGBA[3] floatValue] * progress];
        
        currentTitleView.textColor = [UIColor
                                      colorWithRed:[self.normalColorRGBA[0] floatValue] - [self.deltaRGBA[0] floatValue] * progress
                                      green:[self.normalColorRGBA[1] floatValue] - [self.deltaRGBA[1] floatValue] * progress
                                      blue:[self.normalColorRGBA[2] floatValue] - [self.deltaRGBA[2] floatValue] * progress
                                      alpha:[self.normalColorRGBA[3] floatValue] - [self.deltaRGBA[3] floatValue] * progress];
        
    }
    
    if (!self.segmentStyle.isScaleTitle) {
        return;
    }
    
    CGFloat deltaScale = self.segmentStyle.titleBigScale - 1.0;
    oldTitleView.currentTransformSx = self.segmentStyle.titleBigScale - deltaScale * progress;
    currentTitleView.currentTransformSx = 1.0 + deltaScale * progress;
    
    
}

- (void)adjustTitleOffSetToCurrentIndex:(NSInteger)currentIndex {
    _oldIndex = currentIndex;
    // 重置渐变/缩放效果附近其他item的缩放和颜色
    int index = 0;
    for (ZZTitleView *titleView in _titleViews) {
        if (index != currentIndex) {
            titleView.textColor = self.segmentStyle.normalTitleColor;
            titleView.currentTransformSx = 1.0;
            titleView.selected = NO;
            
        }
        else {
            titleView.textColor = self.segmentStyle.selectedTitleColor;
            if (self.segmentStyle.isScaleTitle) {
                titleView.currentTransformSx = self.segmentStyle.titleBigScale;
            }
            titleView.selected = YES;
        }
        index++;
    }
//

    if (self.scrollView.contentSize.width != self.scrollView.bounds.size.width + contentSizeXOff) {// 需要滚动
        ZZTitleView *currentTitleView = (ZZTitleView *)_titleViews[currentIndex];

        CGFloat offSetx = currentTitleView.center.x - _currentWidth * 0.5;
        if (offSetx < 0) {
            offSetx = 0;

        }
        CGFloat extraBtnW = self.extraBtn ? self.extraBtn.zz_width : 0.0;
        CGFloat maxOffSetX = self.scrollView.contentSize.width - (_currentWidth - extraBtnW);
        
        if (maxOffSetX < 0) {
            maxOffSetX = 0;
        }
        
        if (offSetx > maxOffSetX) {
            offSetx = maxOffSetX;
        }
        
//        if (!self.segmentStyle.isGradualChangeTitleColor) {
//            int index = 0;
//            for (ZZTitleView *titleView in _titleViews) {
//                if (index != currentIndex) {
//                    titleView.textColor = self.segmentStyle.normalTitleColor;
//                    titleView.currentTransformSx = 1.0;
//                    titleView.selected = NO;
//                }
//                else {
//                    titleView.textColor = self.segmentStyle.selectedTitleColor;
//                    if (self.segmentStyle.isScaleTitle) {
//                        titleView.currentTransformSx = self.segmentStyle.titleBigScale;
//                    }
//                    titleView.selected = YES;
// 
//                }
//                
//                index++;
//            }
//        }
        [self.scrollView setContentOffset:CGPointMake(offSetx, self.scrollView.contentOffset.y) animated:YES];
    }

 
}

- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated {
    
    @try {
        
        NSAssert(index >= 0 && index < self.titles.count, @"设置的下标不合法!!");
        
    }
    
    @catch (NSException *exception) {
        NSLog(@"%s\n%@", __FUNCTION__, exception);
    }

    

    if (index < 0 || index >= self.titles.count) {
        return;
    }
    
    _currentIndex = index;
    [self adjustUIWhenBtnOnClickWithAnimate:animated taped:NO];
}

- (void)reloadTitlesWithNewTitles:(NSArray *)titles {
    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    _currentIndex = 0;
    _oldIndex = 0;
    self.titleWidths = nil;
    self.titleViews = nil;
    self.titles = nil;
    self.titles = [titles copy];
    if (self.titles.count == 0) return;
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    [self setupSubviews];
    [self setupUI];
    [self setSelectedIndex:0 animated:YES];
    
}

- (void)reloadImageIsShow:(BOOL)imageIsShow alpha:(CGFloat)alpha lineColor:(UIColor *)lineColor lineWidth:(CGFloat)lineWidth{
    _scrollLineTrueShowWidth = lineWidth;
    _segmentStyle.showImage = imageIsShow;
    _segmentStyle.scrollLineColor = lineColor;
    self.bottomShadowLabel.hidden = imageIsShow;
    self.scrollLine.hidden = imageIsShow;
    if (self.titles.count == 0) return;
    for (int i = 0; i < self.titleViews.count; i ++) {
        ZZTitleView *titleView = self.titleViews[i];
        titleView.imageView.alpha = alpha;
    }
    
    if (imageIsShow) {
        self.scrollLine.hidden = YES;
        _segmentStyle.showLine = !imageIsShow;
        self.scrollView.contentOffset = CGPointMake(self.scrollView.contentOffset.x, 0);
    }else if (alpha != 1){//这里防止为偏移量为0时的移动!
        _segmentStyle.showLine = !imageIsShow;
        if (self.scrollLineUpOffset != -1) {
            self.scrollLineUpOffset = -1;
            [self.scrollView addSubview:self.scrollLine];
            [self setupScrollLineAndCover];
            self.scrollLine.hidden = NO;
        }
        self.scrollView.contentOffset = CGPointMake(self.scrollView.contentOffset.x, 5);
    }

    [self setSelectedIndex:_oldIndex animated:NO];
}

#pragma mark - getter --- setter
-(UILabel *)bottomShadowLabel{
    if (!_bottomShadowLabel) {
        _bottomShadowLabel = [[UILabel alloc] init];
        [self addSubview:_bottomShadowLabel];
        _bottomShadowLabel.backgroundColor = [UIColor zz_colorWithCSS:@"000000"];
        _bottomShadowLabel.alpha = 0.11;
        _bottomShadowLabel.sd_layout.leftEqualToView(self)
        .rightEqualToView(self)
        .bottomEqualToView(self)
        .heightIs(1);
    }
    return _bottomShadowLabel;
}

- (UIView *)scrollLine {
    
    if (!self.segmentStyle.isShowLine) {
        return nil;
    }
    
    if (!_scrollLine) {
        UIView *lineView = [[UIView alloc] init];
        UIView *ly_lineView = [[UIView alloc] init];
        [lineView addSubview:ly_lineView];//这里

        if (_scrollLineTrueShowWidth > 0) {
            ly_lineView.sd_layout.centerXEqualToView(lineView).widthIs(_scrollLineTrueShowWidth)
             .topEqualToView(lineView).bottomEqualToView(lineView);
            ly_lineView.sd_cornerRadius = @(0.5);
        }else{
            ly_lineView.sd_layout.leftEqualToView(lineView).rightEqualToView(lineView)
            .topEqualToView(lineView).bottomEqualToView(lineView);
            ly_lineView.sd_cornerRadius = @(0.5);
            
//            ly_lineView.frame = CGRectMake(lineView.frame.origin.x-15, lineView.frame.origin.y, lineView.frame.size.width + 60, 2);
//            ly_lineView.sd_cornerRadius = @(0.5);
            
            
        }
        
        ly_lineView.backgroundColor = self.segmentStyle.scrollLineColor;
        lineView.backgroundColor = [UIColor clearColor];
        
        _scrollLine = lineView;
        
    }
    
    return _scrollLine;
}

- (UIView *)coverLayer {
    if (!self.segmentStyle.isShowCover) {
        return nil;
    }
    
    if (!self.segmentStyle.gradientColors) {self.segmentStyle.showCoverGrade = NO;}
    
    if (_coverLayer == nil) {
        UIView *coverView = [[UIView alloc] init];self.coverView = coverView;
        
        if (self.segmentStyle.showCoverGrade) {
            
            coverView.layer.cornerRadius = self.segmentStyle.coverCornerRadius;
            [coverView zz_insertGradientLayerWithBounds:coverView.bounds colorArray:self.segmentStyle.gradientColors locations:@[@(0), @(1)] startPoint:CGPointMake(0, 0) endPoint:CGPointMake(1, 1)];
            
        }else{
            coverView.backgroundColor = self.segmentStyle.coverBackgroundColor;
            coverView.layer.cornerRadius = self.segmentStyle.coverCornerRadius;
            coverView.layer.masksToBounds = YES;
        }
        _coverLayer = coverView;
        
    }
    
    
    return _coverLayer;
}

- (UIButton *)extraBtn {
    
    if (!self.segmentStyle.showExtraButton) {
        return nil;
    }
    if (!_extraBtn) {
        UIButton *btn = [UIButton new];
        [btn addTarget:self action:@selector(extraBtnOnClick:) forControlEvents:UIControlEventTouchUpInside];
        NSString *imageName = self.segmentStyle.extraBtnBackgroundImageName ? self.segmentStyle.extraBtnBackgroundImageName : @"";
        [btn setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor whiteColor];
        // 设置边缘的阴影效果
        btn.layer.shadowColor = [UIColor whiteColor].CGColor;
        btn.layer.shadowOffset = CGSizeMake(-5, 0);
        btn.layer.shadowOpacity = 1;
        
        _extraBtn = btn;
    }
    return _extraBtn;
}

- (UIScrollView *)scrollView {
    
    if (!_scrollView) {
        UIScrollView *scrollView = [[UIScrollView alloc] init];
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.scrollsToTop = NO;
        scrollView.bounces = self.segmentStyle.isSegmentViewBounces;
        scrollView.pagingEnabled = NO;
        scrollView.delegate = self;
        _scrollView = scrollView;
    }
    return _scrollView;
}

- (UIImageView *)backgroundImageView {
    
    if (!_backgroundImageView) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        
        [self insertSubview:imageView atIndex:0];

        _backgroundImageView = imageView;
    }
    return _backgroundImageView;
}

- (void)setBackgroundImage:(UIImage *)backgroundImage {
    _backgroundImage = backgroundImage;
    if (backgroundImage) {
        self.backgroundImageView.image = backgroundImage;
    }
}

- (NSMutableArray *)titleViews {
    if (_titleViews == nil) {
        _titleViews = [NSMutableArray array];
    }
    return _titleViews;
}

- (NSMutableArray *)titleWidths {
    if (_titleWidths == nil) {
        _titleWidths = [NSMutableArray array];
    }
    return _titleWidths;
}

- (NSArray *)deltaRGBA {
    if (_deltaRGBA == nil) {
        NSArray *normalColorRgb = self.normalColorRGBA;
        NSArray *selectedColorRgb = self.selectedColorRGBA;
        
        NSArray *delta;
        if (normalColorRgb && selectedColorRgb) {
            CGFloat deltaR = [normalColorRgb[0] floatValue] - [selectedColorRgb[0] floatValue];
            CGFloat deltaG = [normalColorRgb[1] floatValue] - [selectedColorRgb[1] floatValue];
            CGFloat deltaB = [normalColorRgb[2] floatValue] - [selectedColorRgb[2] floatValue];
            CGFloat deltaA = [normalColorRgb[3] floatValue] - [selectedColorRgb[3] floatValue];
            delta = [NSArray arrayWithObjects:@(deltaR), @(deltaG), @(deltaB), @(deltaA), nil];
            _deltaRGBA = delta;

        }
    }
    return _deltaRGBA;
}

- (NSArray *)normalColorRGBA {
    if (!_normalColorRGBA) {
        NSArray *normalColorRGBA = [self getColorRGBA:self.segmentStyle.normalTitleColor];
        NSAssert(normalColorRGBA, @"设置普通状态的文字颜色时 请使用RGBA空间的颜色值");
        _normalColorRGBA = normalColorRGBA;
        
    }
    return  _normalColorRGBA;
}

- (NSArray *)selectedColorRGBA {
    if (!_selectedColorRGBA) {
        NSArray *selectedColorRGBA = [self getColorRGBA:self.segmentStyle.selectedTitleColor];
        NSAssert(selectedColorRGBA, @"设置选中状态的文字颜色时 请使用RGBA空间的颜色值");
        _selectedColorRGBA = selectedColorRGBA;
        
    }
    return  _selectedColorRGBA;
}

- (NSArray *)getColorRGBA:(UIColor *)color {
    CGFloat numOfcomponents = CGColorGetNumberOfComponents(color.CGColor);
    NSArray *rgbaComponents;
    if (numOfcomponents == 4) {
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        rgbaComponents = [NSArray arrayWithObjects:@(components[0]), @(components[1]), @(components[2]), @(components[3]), nil];
    }
    return rgbaComponents;
    
}

@end