//
//  MYBannerCycleView.m
//  MYBannerCycleViewDemo
//
//  Created by QMMac on 2017/2/8.
//  Copyright © 2017 QMMac. All rights reserved.
//

#import "MYBannerCycleView.h"
#import "UIView+Addition.h"

static NSInteger const totalCollectionViewCellCount = 200;

#define BANNER_FOOTER_HEIGHT 49.0

@interface MYBannerCycleView () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout> {
    UICollectionView *_collectionView;
    UICollectionViewFlowLayout *_flowLayout;
}

@property (nonatomic, weak) NSTimer *timer;
@property (nonatomic, assign) NSInteger totalBannerItemsCount;
@property (nonatomic, strong) NSArray *showNewDatasource;
@property (nonatomic, assign) NSInteger itemCount;
/**
 cell 重用标识符
 */
@property (nonatomic, strong) NSString *reusableIdentifier;

/**
 footer 重用标识符
 */
@property (nonatomic, strong) NSString *reusableFooterIdentifier;

@end

@implementation MYBannerCycleView

@synthesize autoScroll = _autoScroll;
@synthesize cycleScrollEnable = _cycleScrollEnable;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _initSetting];
        [self addSubview:self.collectionView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self _initSetting];
        [self addSubview:self.collectionView];
    }
    return self;
}

- (void)reloadData {
    
    [self invalidateTimer];
    self.showNewDatasource = [self _getImageDataSources];
    
    // Hidden when data source is greater than zero
    self.backgroundImageView.hidden = ([self _imageDataSources].count > 0);
    
    if ([self _imageDataSources].count > 1) {
        self.collectionView.scrollEnabled = YES;
        [self setAutoScroll:self.autoScroll];
    } else {
        
        if ([self _imageDataSources].count == 0) { self.showFooter = NO; }
        
        BOOL isCan = ([self _imageDataSources].count == 0)?NO:(self.showFooter?YES:NO);
        
        self.collectionView.scrollEnabled = isCan;
        
        [self invalidateTimerWhenAutoScroll];
    }
    
    [self _setFooterViewCanShow:self.showFooter];
    
    [self.collectionView reloadData];
}


/** Initialize the default settings */
- (void)_initSetting{
    
    self.backgroundColor = [UIColor whiteColor];
    _autoDuration = 3.0;
    _autoScroll = YES;
    _cycleScrollEnable = YES;
    _showFooter = NO;
}

#pragma mark - Setter && Getter


#pragma mark - layoutSubviews
- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.dataSource = self.dataSource;
    [super layoutSubviews];
    
    self.flowLayout.itemSize = self.frame.size;
    
    self.collectionView.frame = self.bounds;
    
    if (self.collectionView.contentOffset.x == 0 &&  self.totalBannerItemsCount) {
        NSInteger targetIndex = self.cycleScrollEnable?(self.totalBannerItemsCount * 0.5):(0);
        [self _scrollBannerViewToSpecifiedPositionIndex:targetIndex animated:NO];
    }
    
    if (self.backgroundImageView) {
        self.backgroundImageView.frame = self.bounds;
    }
}

#pragma mark - Resolve compatibility optimization issues
- (void)willMoveToSuperview:(UIView *)newSuperview{
    if (!newSuperview) {
        [self invalidateTimer];
    }
}

- (void)scrollToIndex:(NSInteger)index animation:(BOOL)animation {
    if (self.showNewDatasource.count == 0) {
        return;
        
    }
    if (index >= 0 && index < self.showNewDatasource.count) {
        if (self.autoScroll) {
            [self invalidateTimer];
        }
        
        [self _scrollToIndex:((int)(self.totalBannerItemsCount * 0.5 + index)) animated:animation];
        
        if (self.autoScroll) {
            [self _setupTimer];
        }
    }
}

- (void)adjustBannerViewWhenCardScreen{
    
    long targetIndex = [self _currentPageIndex];
    if (targetIndex < self.totalBannerItemsCount) {
        [self _scrollBannerViewToSpecifiedPositionIndex:targetIndex animated:NO];
    }
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.totalBannerItemsCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:self.reusableIdentifier forIndexPath:indexPath];
    
    long itemIndex = [self _getRealIndexFromCurrentCellIndex:indexPath.item];
    
    if ([self.dataSource cycleView:self cellForItemAtRow:itemIndex]) {
        return cell;
    }
    
    return cell;
}

// Setting Footer Size
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section{
    return CGSizeMake((self.showFooter && [self _imageDataSources].count != 0)?[self _bannerViewFooterHeight]:0.0f, self.frame.size.height);
}

// Footer
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    
    if (kind == UICollectionElementKindSectionFooter) {
        
        UICollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:self.reusableFooterIdentifier forIndexPath:indexPath];
        
        if ([self.dataSource respondsToSelector:@selector(viewForSupplementaryElementOfFooter:)]) {
            footer = [self.dataSource viewForSupplementaryElementOfFooter:self];
        }
        return footer;
    }
    return nil;
}

#pragma mark - UIScrollViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if (self.delegate && [self.delegate respondsToSelector:@selector(cycleView:didSelectItemAtIndex:)]) {
        [self.delegate cycleView:self didSelectItemAtIndex:[self _getRealIndexFromCurrentCellIndex:indexPath.item]];
    }
    if (self.didSelectItemAtIndexBlock) {
        self.didSelectItemAtIndexBlock([self _getRealIndexFromCurrentCellIndex:indexPath.item]);
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if (![self _imageDataSources].count) return;
    int itemIndex = [self _currentPageIndex];
    int indexOnPageControl = [self _getRealIndexFromCurrentCellIndex:itemIndex];
    
    // 手动退拽时左右两端
    if (scrollView == self.collectionView && scrollView.isDragging && self.cycleScrollEnable) {
        NSInteger targetIndex = self.totalBannerItemsCount * 0.5;
        if (itemIndex == 0) { // top
            [self _scrollBannerViewToSpecifiedPositionIndex:targetIndex animated:NO];
        }else if (itemIndex == (self.totalBannerItemsCount - 1)){ // bottom
            targetIndex -= 1;
            [self _scrollBannerViewToSpecifiedPositionIndex:targetIndex animated:NO];
        }
    }
    
    // Footer
    if (self.showFooter) {
        static CGFloat lastOffset;
        CGFloat footerDisplayOffset = (self.collectionView.contentOffset.x - (self.flowLayout.itemSize.width * (self.totalBannerItemsCount - 1)));
        
        if (footerDisplayOffset > 0){
            if (footerDisplayOffset > [self _bannerViewFooterHeight]) {
                if (lastOffset > 0) return;
                if ([self.delegate respondsToSelector:@selector(footerViewTriggerStatus:)]) {
                    [self.delegate footerViewTriggerStatus:MYBannerViewStatusTrigger];
                }
            } else {
                if (lastOffset < 0) return;
                if ([self.delegate respondsToSelector:@selector(footerViewTriggerStatus:)]) {
                    [self.delegate footerViewTriggerStatus:MYBannerViewStatusIdle];
                }
            }
            lastOffset = footerDisplayOffset - [self _bannerViewFooterHeight];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    [self invalidateTimerWhenAutoScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    
    [self startTimerWhenAutoScroll];
    
    if (self.showFooter) {
        CGFloat footerDisplayOffset = (self.collectionView.contentOffset.x - (self.flowLayout.itemSize.width * (self.totalBannerItemsCount - 1)));
        
        if (footerDisplayOffset > [self _bannerViewFooterHeight]) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(cycleViewTriggerForFooter:)]) {
                [self.delegate cycleViewTriggerForFooter:self];
            }
            
            if (self.didEndTriggerFooterBlock) {
                self.didEndTriggerFooterBlock();
            }
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self scrollViewDidEndScrollingAnimation:self.collectionView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView{
    if (![self _imageDataSources].count) return;
    int itemIndex = [self _currentPageIndex];
    int indexOnPageControl = [self _getRealIndexFromCurrentCellIndex:itemIndex];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(cycleView:didScrollToItemAtIndex:)]) {
        [self.delegate cycleView:self didScrollToItemAtIndex:indexOnPageControl];
    }
    if (self.didScroll2IndexBlock) {
        self.didScroll2IndexBlock(indexOnPageControl);
    }
}

#pragma mark - Private function method

/** install Timer */
- (void)_setupTimer{
    
    [self invalidateTimer];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:self.autoDuration target:self selector:@selector(_automaticScrollAction) userInfo:nil repeats:YES];
    _timer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

/** stop timer */
- (void)invalidateTimer{
    
    [_timer invalidate];
    _timer = nil;
}

/** stop timer api */
- (void)invalidateTimerWhenAutoScroll{
    if (self.autoScroll) {
        [self invalidateTimer];
    }
}

/** restart timer api */
- (void)startTimerWhenAutoScroll{
    if (self.autoScroll) {
        [self _setupTimer];
    }
}

- (void)_automaticScrollAction{
    
    if (self.totalBannerItemsCount == 0) return;
    int currentIndex = [self _currentPageIndex];
    if (self.bannerViewScrollDirection == BannerViewDirectionLeft || self.bannerViewScrollDirection == BannerViewDirectionTop) {
        [self _scrollToIndex:(currentIndex + 1) animated:YES];
    }else if (self.bannerViewScrollDirection == BannerViewDirectionRight || self.bannerViewScrollDirection == BannerViewDirectionBottom){
        if ((currentIndex - 1) < 0) { // 小于零
            currentIndex = self.cycleScrollEnable?(self.totalBannerItemsCount * 0.5):(0);
            [self _scrollBannerViewToSpecifiedPositionIndex:(currentIndex - 1) animated:NO];
        }else{
            [self _scrollToIndex:(currentIndex - 1) animated:YES];
        }
    }
}

- (void)_scrollToIndex:(int)targetIndex animated:(BOOL)animated{
    
    if (targetIndex >= self.totalBannerItemsCount) {  // 超过最大
        targetIndex = self.cycleScrollEnable?(self.totalBannerItemsCount * 0.5):(0);
        [self _scrollBannerViewToSpecifiedPositionIndex:targetIndex animated:NO];
    }else{
        [self _scrollBannerViewToSpecifiedPositionIndex:targetIndex animated:animated];
    }
}

/** current page index */
- (int)_currentPageIndex{
    
    if (self.collectionView.width == 0 || self.collectionView.height == 0) {return 0;}
    int index = 0;
    if (self.flowLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
        index = (self.collectionView.contentOffset.x + self.flowLayout.itemSize.width * 0.5) / self.flowLayout.itemSize.width;
    } else {
        index = (self.collectionView.contentOffset.y + self.flowLayout.itemSize.height * 0.5) / self.flowLayout.itemSize.height;
    }
    return MAX(0, index);
}

/** current real index */
- (int)_getRealIndexFromCurrentCellIndex:(NSInteger)cellIndex{
    return (int)cellIndex % [self _imageDataSources].count;
}

- (NSArray *)_imageDataSources{
    return self.showNewDatasource;
}

/** Get new data from the proxy method */
- (NSArray *)_getImageDataSources{
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(bannerViewImages:)]) {
        return [self.dataSource bannerViewImages:self];
    }
    return @[];
}

/** Footer Height */
- (CGFloat)_bannerViewFooterHeight{
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(cycleViewFooterViewHeight:)]) {
        return [self.dataSource cycleViewFooterViewHeight:self];
    }
    return BANNER_FOOTER_HEIGHT;
}

/** reload 时控制尾巴的显示和消失 */
- (void)_setFooterViewCanShow:(BOOL)showFooter{
    
    if (showFooter) {
        self.bannerViewScrollDirection = BannerViewDirectionLeft;
        self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 0, -[self _bannerViewFooterHeight]);
    }else{
        self.collectionView.contentInset = UIEdgeInsetsZero;
    }
    
    if (self.bannerViewScrollDirection == BannerViewDirectionLeft) {
        self.collectionView.alwaysBounceHorizontal = showFooter;
    }else {
        self.collectionView.accessibilityViewIsModal = showFooter;
    }
}

/** Scroll the CollectionView to the specified location */
- (void)_scrollBannerViewToSpecifiedPositionIndex:(NSInteger)targetIndex animated:(BOOL)animated{
    NSInteger itemCount = [self.collectionView numberOfItemsInSection:0];
    if (targetIndex < itemCount) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:targetIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:animated];
    }
}

- (__kindof UICollectionViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forRow:(NSInteger)row
{
    return [self.collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
}

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier
{
    [self.collectionView registerClass:cellClass forCellWithReuseIdentifier:identifier];
    self.reusableIdentifier = identifier;
}

- (void)registerClass:(nullable Class)viewClass forFooterWithReuseIdentifier:(NSString *)identifier {
    [self.collectionView registerClass:viewClass forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:identifier];
    self.reusableFooterIdentifier = identifier;
}

- (__kindof UICollectionReusableView *)dequeueReusableEelementKindOfFooterwithReuseIdentifier:(NSString *)identifier forIndex:(NSInteger)index {
    return [self.collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:identifier forIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
}

#pragma mark - getter & setter
- (void)setEmptyImage:(UIImage *)emptyImage {
    _emptyImage = emptyImage;
    if (emptyImage) {
        self.backgroundImageView.image = emptyImage;
    }
}

- (void)setAutoScroll:(BOOL)autoScroll {
    
    _autoScroll = autoScroll;
    [self invalidateTimer];
    if (autoScroll) {
        [self _setupTimer];
    }
}

- (void)setBannerViewScrollDirection:(BannerViewDirection)bannerViewScrollDirection {
    
    if (self.showFooter && bannerViewScrollDirection != BannerViewDirectionLeft) {
        bannerViewScrollDirection = BannerViewDirectionLeft;
    }
    
    _bannerViewScrollDirection = bannerViewScrollDirection;
    
    if (bannerViewScrollDirection == BannerViewDirectionLeft || bannerViewScrollDirection == BannerViewDirectionRight) {
        self.flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    } else if (bannerViewScrollDirection == BannerViewDirectionTop || bannerViewScrollDirection == BannerViewDirectionBottom) {
        self.flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    }
}

- (void)setAutoDuration:(CGFloat)autoDuration {
    
    _autoDuration = autoDuration;
    [self setAutoScroll:self.autoScroll];
}

- (NSInteger)repeatCount {
    if (_repeatCount <= 0) {
        return totalCollectionViewCellCount;
    } else {
        if (_repeatCount % 2 != 0) {
            return _repeatCount + 1;
        } else {
            return _repeatCount;
        }
    }
}

- (NSInteger)totalBannerItemsCount {
    
    return self.cycleScrollEnable?(([self _imageDataSources].count > 1)?([self _imageDataSources].count * self.repeatCount):[self _imageDataSources].count):([self _imageDataSources].count);
}

- (BOOL)autoScroll {
    if (self.showFooter) {
        return NO;
    }
    return _autoScroll;
}

- (BOOL)cycleScrollEnable {
    if (self.showFooter) {
        return NO;
    }
    return _cycleScrollEnable;
}

- (UIImageView *)backgroundImageView {
    if (!_backgroundImageView) {
        _backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        _backgroundImageView.clipsToBounds = YES;
        [self insertSubview:_backgroundImageView belowSubview:self.collectionView];
    }
    return _backgroundImageView;
}

- (UICollectionViewFlowLayout *)flowLayout {
    if (!_flowLayout) {
        _flowLayout = [[UICollectionViewFlowLayout alloc] init];
        _flowLayout.minimumLineSpacing = 0.0f;
        _flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    }
    return _flowLayout;
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        _collectionView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:self.flowLayout];
        _collectionView.pagingEnabled = YES;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.scrollsToTop = NO;
    }
    return _collectionView;
}

- (void)dealloc {
    self.collectionView.delegate = nil;
    self.collectionView.dataSource = nil;
}


@end
