//
//  LSPhotoBrowser.swift
//  test20161130
//
//  Created by liu on 2017/5/23.
//  Copyright © 2017年 liu. All rights reserved.
//

import UIKit

@objc
protocol LSPhotoBrowserDelegate: NSObjectProtocol {
    /// 直接展示的图片，如果image接口返回非nil，则不再调用urlString接口
    @objc optional
    func photoBrowser(_ browser: LSPhotoBrowser, placeholderImageForIndex index: Int) -> UIImage?
    @objc optional
    func photoBrowser(_ browser: LSPhotoBrowser, placeholderUrlStringForIndex index: Int) -> String?
    /// 高清图片，如果image接口返回非nil，则不再调用urlString接口
    @objc optional
    func photoBrowser(_ browser: LSPhotoBrowser, highQualityImageForIndex index: Int) -> UIImage?
    @objc optional
    func photoBrowser(_ browser: LSPhotoBrowser, highQualityUrlStringForIndex index: Int) -> String?
    /// 更多操作
    @objc optional
    func photoBrowser(_ browser: LSPhotoBrowser, operationImage image: UIImage, atIndex index: Int)
    /// 返回图片动画需要的起始/终止rect(相对于屏幕)，如果rect与屏幕重合区域面积小于rect面积的80%，则不显示动画
    /// 最终是否显示动画，还要受到imageAnimationType限制
    /// LSPhotoBrowse隐藏statusBar，所以在dissmiss调用时会自动地向下调整20
    /// 如果前一个页面同样没有statusBar，那么需要手动向上调整20
    @objc optional
    func photoBrowser(_ browser: LSPhotoBrowser, targetRectForIndex index: Int) -> CGRect
}

private protocol GetImageDelegate: NSObjectProtocol {
    /// 同步获取缓存
    func LSPhotoBrowser_getCacheImage(_ url: String) -> UIImage?
    /// 异步加载图片
    func LSPhotoBrowser_asyncLoadImage(_ url: String, progress: ((Int, Int)->Void)?, completion: @escaping (UIImage?)->Void)
}

extension LSWebImage: GetImageDelegate {
    func LSPhotoBrowser_getCacheImage(_ url: String) -> UIImage? {
        return self.getFromMemoryAndDisk(forURL: url)
    }
    func LSPhotoBrowser_asyncLoadImage(_ url: String, progress: ((Int, Int) -> Void)?, completion: @escaping (UIImage?) -> Void) {
        self.asyncLoad(withURL: url, progress: progress, completed: { (image, error, _, _, _) in
            completion(image)
        })
    }
}

private class ScrollView: UIScrollView, UIScrollViewDelegate {
    
    private var imageView: UIImageView
    var image: UIImage? {
        set {
            imageView.image = newValue
            self.displayImage()
        }
        get {
            return imageView.image
        }
    }
    weak var cell: Cell!
    private var doubleScale: CGFloat = 2
    
    override init(frame: CGRect) {
        imageView = UIImageView.init(frame: .zero)
        super.init(frame: frame)
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.delegate = self
        imageView.contentMode = .center
        imageView.backgroundColor = .black
        imageView.isUserInteractionEnabled = true
        self.addSubview(imageView)
        
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(self.tap(_:)))
        let double = UITapGestureRecognizer.init(target: self, action: #selector(self.double(_:)))
        double.numberOfTapsRequired = 2
        let long = UILongPressGestureRecognizer.init(target: self, action: #selector(self.long(_:)))
        tap.require(toFail: double)
        tap.require(toFail: long)
        self.addGestureRecognizer(tap)
        self.addGestureRecognizer(long)
        self.addGestureRecognizer(double)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func tap(_ tap: UITapGestureRecognizer) {
        self.cell.photoBrowser.tap()
    }
    
    @objc private func double(_ tap: UITapGestureRecognizer) {
        if abs(self.zoomScale - self.doubleScale) < self.doubleScale * 0.1 {
            self.setZoomScale(self.minimumZoomScale, animated: true)
        } else {
            let touchPoint = tap.location(in: self.imageView)
            let xsize = self.bounds.width / self.doubleScale
            let ysize = self.bounds.height / self.doubleScale
            let rect = CGRect(x: touchPoint.x - xsize / 2, y: touchPoint.y - ysize / 2, width: xsize, height: ysize)
            self.zoom(to: rect, animated: true)
        }
    }
    
    @objc private func long(_ tap: UILongPressGestureRecognizer) {
        if tap.state == .began {
            self.cell.long()
        }
    }
    
    private func displayImage() {
        self.maximumZoomScale = 1
        self.minimumZoomScale = 1
        self.zoomScale = 1
        self.contentSize = .zero
        
        if (imageView.image != nil) {
            imageView.isHidden = false
            self.setMaxMinZoomScalesForCurrentBounds()
        } else {
            imageView.isHidden = true
        }
        self.setNeedsLayout()
    }
    
    private func setMaxMinZoomScalesForCurrentBounds() {
        
        let size = imageView.image!.sizeByPixel
        let frame = CGRect.init(origin: .zero, size: size)
        imageView.frame = frame
        self.contentSize = size
        
        let boundsSize = self.bounds.size
        let imageSize = imageView.image!.size
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        
        var minScale = min(xScale, yScale)
        if minScale > 1 {
            minScale = sqrt(minScale)
        }
        self.doubleScale = minScale * 2
        let maxScale = max(minScale * 3, 2)
        
        self.maximumZoomScale = maxScale
        self.minimumZoomScale = minScale
        self.zoomScale = minScale
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let boundsSize = self.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.width < boundsSize.width {
            frameToCenter.origin.x = CGFloat(floor(Double((boundsSize.width - frameToCenter.width) / 2.0)))
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.height < boundsSize.height {
            frameToCenter.origin.y = CGFloat(floor(Double((boundsSize.height - frameToCenter.height) / 2.0)))
        } else {
            frameToCenter.origin.y = 0
        }
        
        if frameToCenter != imageView.frame {
            imageView.frame = frameToCenter
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}

private class Cell: UICollectionViewCell {
    
    static let reuseIdentify: String = "LSPhotoBrowser.Cell"
    private var scrollView: ScrollView
    weak var photoBrowser: LSPhotoBrowser! {
        didSet {
            var frame = self.contentView.bounds
            frame.size.width = frame.width - photoBrowser.imageInterval
            scrollView.frame = frame
            scrollView.cell = self
        }
    }
    
    override init(frame: CGRect) {
        scrollView = ScrollView.init(frame: .zero)
        super.init(frame: frame)
        self.contentView.addSubview(scrollView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setPlaceholder(_ image: UIImage?) {
        DispatchQueue.async_on_main_queue {
            if image == nil {
                self.scrollView.image = nil
            } else if self.scrollView.image == nil {
                self.scrollView.image = image
            }
        }
    }
    
    func setHighQuality(_ image: UIImage?) {
        guard let image = image else {
            return
        }
        DispatchQueue.async_on_main_queue {
            self.scrollView.image = image
        }
    }
    
    func long() {
        self.photoBrowser.long(self, image: self.scrollView.image)
    }
}

private class Animation: NSObject, UIViewControllerAnimatedTransitioning {
    
    let isPresenting: Bool
    weak var photoBrowser: LSPhotoBrowser!
    private var duration: TimeInterval
    private var needImageAnimation: Bool = false
    private var targetRect: CGRect?
    private var targetImage: UIImage?
    
    init(isPresenting: Bool, photoBrowser: LSPhotoBrowser) {
        self.isPresenting = isPresenting
        self.photoBrowser = photoBrowser
        
        if self.isPresenting {
            if self.photoBrowser.imageAnimationType != .None,
                let rect = self.photoBrowser.delegate.photoBrowser?(self.photoBrowser, targetRectForIndex: self.photoBrowser.currentImageIndex),
                !rect.isEmpty {
                let intersection = rect.intersection(kScreenBounds())
                if !intersection.isEmpty, intersection.size.area / rect.size.area >= 0.8 {
                    var image = self.photoBrowser.getHighQualityImage(self.photoBrowser.currentImageIndex).0
                    if image == nil {
                        image = self.photoBrowser.getPlaceholderImage(self.photoBrowser.currentImageIndex).0
                    }
                    if image != nil {
                        targetRect = rect
                        targetImage = image
                        needImageAnimation = true
                        duration = self.photoBrowser.showAnimationDuration
                        return
                    }
                }
            }
            duration = self.photoBrowser.showAnimationDuration * self.photoBrowser.ratioOfAnimationDuration
        } else {
            if self.photoBrowser.imageAnimationType == .All,
                var rect = self.photoBrowser.delegate.photoBrowser?(self.photoBrowser, targetRectForIndex: self.photoBrowser.currentImageIndex),
                !rect.isEmpty {
                rect = rect.offsetBy(dx: 0, dy: 20)
                let intersection = rect.intersection(kScreenBounds())
                if !intersection.isEmpty, intersection.size.area / rect.size.area >= 0.8 {
                    var image = self.photoBrowser.getHighQualityImage(self.photoBrowser.currentImageIndex).0
                    if image == nil {
                        image = self.photoBrowser.getPlaceholderImage(self.photoBrowser.currentImageIndex).0
                    }
                    if image != nil {
                        targetRect = rect
                        targetImage = image
                        needImageAnimation = true
                        duration = self.photoBrowser.hideAnimationDuration
                        return
                    }
                }
            }
            duration = self.photoBrowser.hideAnimationDuration * self.photoBrowser.ratioOfAnimationDuration
        }
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if self.isPresenting {
            self.presentAnimateTransition(transitionContext)
        } else {
            self.dismissAnimateTransition(transitionContext)
        }
    }
    
    private func presentAnimateTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        var bgView: UIView? = nil
        var imageView: UIImageView? = nil
        if needImageAnimation {
            bgView = UIView.init(frame: kScreenBounds())
            var color = self.photoBrowser.view.backgroundColor ?? UIColor.black
            color = color.withAlphaComponent(0)
            bgView?.backgroundColor = color
            imageView = UIImageView.init(image: self.targetImage)
            imageView?.clipsToBounds = true
            imageView?.contentMode = .scaleAspectFill
            imageView?.frame = self.targetRect!
            bgView?.addSubview(imageView!)
            containerView.addSubview(bgView!)
        } else {
            containerView.addSubview(photoBrowser.view)
            photoBrowser.view.alpha = 0
        }
        
        UIView.animate(withDuration: self.duration, delay: 0, options: .curveLinear, animations: {
            if self.needImageAnimation {
                let screenSize = kScreenSize()
                let imageSize = self.targetImage!.size
                var scale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
                if scale > 1 {
                    scale = sqrt(scale)
                }
                let endSize = imageSize * scale
                let endX = (screenSize.width - endSize.width) * 0.5
                let endY = (screenSize.height - endSize.height) * 0.5
                imageView!.frame = CGRect(x: endX, y: endY, width: endSize.width, height: endSize.height)
                bgView?.backgroundColor = self.photoBrowser.view.backgroundColor
            } else {
                self.photoBrowser.view.alpha = 1
            }
        }) { (finished) in
            if self.needImageAnimation {
                containerView.addSubview(self.photoBrowser.view)
                bgView?.removeFromSuperview()
            } else {
                // do nothing
            }
            transitionContext.completeTransition(finished)
        }
        
    }
    
    private func dismissAnimateTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        var bgView: UIView? = nil
        var imageView: UIImageView? = nil
        if needImageAnimation {
            bgView = UIView.init(frame: kScreenBounds())
            bgView?.backgroundColor = self.photoBrowser.view.backgroundColor
            imageView = UIImageView.init(image: self.targetImage)
            imageView?.clipsToBounds = true
            imageView?.contentMode = .scaleAspectFill
            let screenSize = kScreenSize()
            let imageSize = self.targetImage!.size
            var scale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
            if scale > 1 {
                scale = sqrt(scale)
            }
            let endSize = imageSize * scale
            let endX = (screenSize.width - endSize.width) * 0.5
            let endY = (screenSize.height - endSize.height) * 0.5
            imageView!.frame = CGRect(x: endX, y: endY, width: endSize.width, height: endSize.height)
            bgView?.addSubview(imageView!)
            containerView.addSubview(bgView!)
            self.photoBrowser.view.removeFromSuperview()
        } else {
            // do nothing
        }
        
        UIView.animate(withDuration: self.duration, delay: 0, options: .curveLinear, animations: {
            if self.needImageAnimation {
                var color = self.photoBrowser.view.backgroundColor ?? UIColor.black
                color = color.withAlphaComponent(0)
                bgView?.backgroundColor = color
                imageView?.frame = self.targetRect!
            } else {
                self.photoBrowser.view.alpha = 0
            }
        }) { (finished) in
            if self.needImageAnimation {
                // do nothing
            } else {
                // do nothing
            }
            transitionContext.completeTransition(finished)
        }
        
    }
}

private enum PlaceholderRatio: Equatable {
    case NotBegin      // 没有开始下载
    case IsLoading     // 正在下载
    case HasDone       // 下载已完成
}

private enum HighQualityRatio: Equatable {
    case NotBegin      // 没有开始下载
    case Ratio(Int)    // 进度，[0,100]
    case HasDone       // 下载已完成
    
    static func ==(lhs: HighQualityRatio, rhs: HighQualityRatio) -> Bool {
        switch (lhs, rhs) {
        case (.NotBegin, .NotBegin):
            return true
        case (.HasDone, .HasDone):
            return true
        case (let .Ratio(llll), let .Ratio(rrrr)):
            return llll == rrrr
        default:
            return false
        }
    }
}

/// 仅支持竖屏，不支持屏幕方向切换
class LSPhotoBrowser: UIViewController {

    /// 高清图展示方式
    @objc(LSPhotoBrowserHighQualityLoadMode)
    enum HighQualityLoadMode: Int {
        case UserTrigger = 0 // 用户触发
        case Auto            // 直接加载
    }
    
    /// 图片动画显示类型
    @objc(LSPhotoBrowserImageAnimationType)
    enum ImageAnimationType: Int {
        case ShowOnly = 0 // 只显示入场
        case None         // 都不显示
        case All          // 入场/出场都显示
    }
    
    var currentImageIndex: Int = 0
    var imageCount: Int = 0
    weak var delegate: LSPhotoBrowserDelegate!
    fileprivate weak var getImageDelegate: GetImageDelegate!
    fileprivate var pageLabel: UILabel?
    fileprivate var highQualityButton: UIButton?
    fileprivate var bottomView: UIView?
    fileprivate var activityIndicator: UIActivityIndicatorView!
    fileprivate var hideStatusViews: Bool = false
    fileprivate var placeholderRecorder: [PlaceholderRatio]! // 占位图索引
    fileprivate var highQualityRecorder: [HighQualityRatio]! // 高清图索引
    
    /// 高清图展示方式，有点击“查看原图”加载和直接加载两种，默认点击按钮加载
    /// 如果没有实现高清图代理方法，则不加载/不显示“查看原图”按钮
    var highQualityMode: HighQualityLoadMode = .UserTrigger
    /// 高清图加载按钮文本内容，默认“查看原图”
    fileprivate var highQualityTitle: String = "查看原图"
    /// 图片间距，20
    fileprivate let imageInterval: CGFloat = 20
    /// 进场动画时长，默认0.25
    var showAnimationDuration: TimeInterval = 0.25
    /// 退场动画时长，默认0.25
    var hideAnimationDuration: TimeInterval = 0.25
    /// 图片动画隐藏与显示，默认ShowOnly
    /// 图片动画最终是否显示还要受到回调方法的返回值限制
    var imageAnimationType: ImageAnimationType = .ShowOnly
    /// 无图片动画时动画时长与有图片动画时动画时长的比例，默认0.8，范围[0,1]，超出范围后使用默认值
    var ratioOfAnimationDuration: Double = 0.8 {
        didSet {
            if ratioOfAnimationDuration < 0 || ratioOfAnimationDuration > 1 {
                ratioOfAnimationDuration = 0.8
            }
        }
    }
    
    fileprivate var collectionView: UICollectionView!
    private var layout: UICollectionViewFlowLayout!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        self.getImageDelegate = LSWebImage.sharedManager()
        
        self.providesPresentationContextTransitionStyle = true
        self.definesPresentationContext = true
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
        self.modalPresentationCapturesStatusBarAppearance = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        UIViewController.lsVisibleViewController().present(self, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.black
        
        self.placeholderRecorder = [PlaceholderRatio].init(repeating: .NotBegin, count: self.imageCount)
        self.highQualityRecorder = [HighQualityRatio].init(repeating: .NotBegin, count: self.imageCount)
        
        var frame = self.view.bounds
        frame.size.width = frame.width + self.imageInterval
        self.layout = UICollectionViewFlowLayout.init()
        self.layout.itemSize = frame.size
        self.layout.scrollDirection = .horizontal
        self.layout.minimumLineSpacing = 0
        self.collectionView = UICollectionView.init(frame: frame, collectionViewLayout: self.layout)
        self.collectionView.showsHorizontalScrollIndicator = false
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.allowsSelection = false
        if #available(iOS 10.0, *) { self.collectionView.isPrefetchingEnabled = false }
        self.collectionView.isPagingEnabled = true
        self.collectionView.register(Cell.self, forCellWithReuseIdentifier: Cell.reuseIdentify)
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.collectionView.backgroundColor = .clear
        self.view.addSubview(self.collectionView)
        self.collectionView.scrollToItem(at: IndexPath.init(item: self.currentImageIndex, section: 0), at: .centeredHorizontally, animated: false)
        
        self.bottomView = UIView.init()
        bottomView!.frame = CGRect(x: 0, y: self.view.bounds.height - 54, width: self.view.bounds.width, height: 54)
        // TODO: 设置颜色渐变，这个是作为其他功能按钮(暂时没有)背景用的
        self.view.addSubview(bottomView!)
        
        self.activityIndicator = UIActivityIndicatorView.init(activityIndicatorStyle: .white)
        self.view.addSubview(activityIndicator!)
        activityIndicator!.center = self.view.bounds.center
        
        self.pageLabel = UILabel.init()
        pageLabel!.frame = CGRect(x: 0, y: 16, width: self.view.bounds.width, height:15)
        pageLabel!.textColor = UIColor.white
        pageLabel!.font = UIFont.systemFont(ofSize: 15)
        pageLabel!.shadowColor = UIColor.gray
        pageLabel!.shadowOffset = CGSize(width: 0.3, height: 0.7)
        pageLabel!.textAlignment = .center
        self.view.addSubview(pageLabel!)
        pageLabel!.text = "\(self.currentImageIndex+1) / \(self.imageCount)"
        pageLabel!.isHidden = (self.imageCount == 1)
        
        if self.highQualityMode == .UserTrigger,
            (self.delegate.responds(to: #selector(LSPhotoBrowserDelegate.photoBrowser(_:highQualityImageForIndex:))) ||
            self.delegate.responds(to: #selector(LSPhotoBrowserDelegate.photoBrowser(_:highQualityUrlStringForIndex:)))) {
            self.highQualityButton = UIButton.init(type: .custom)
            highQualityButton!.frame = CGRect(x: self.view.bounds.width / 2 - 40, y: self.view.bounds.height - 39, width: 80, height:24)
            highQualityButton!.setTitleColor(UIColor.white, for: .normal)
            highQualityButton!.setTitle(highQualityTitle, for: .normal)
            highQualityButton!.titleLabel?.font = UIFont.systemFont(ofSize: 13)
            highQualityButton!.backgroundColor = UIColor.init(white: 0, alpha: 0.3)
            highQualityButton!.layer.cornerRadius = 3
            highQualityButton!.layer.borderColor = UIColor.white.cgColor
            highQualityButton!.layer.borderWidth = 1
            highQualityButton!.clipsToBounds = true
            highQualityButton!.addTarget(self, action: #selector(self.hightQualityButtonDidClicked), for: .touchDown)
            self.view.addSubview(highQualityButton!)
            highQualityButton!.isHidden = false
        }
    }
    
    fileprivate func asyncSetPlaceholderImage(forIndexPath indexPath: IndexPath, url: String) {
        let index = indexPath.item
        guard self.placeholderRecorder[index] == .NotBegin else {
            return
        }
        self.placeholderRecorder[index] = .IsLoading
        if index == self.currentImageIndex {
            self.setupActivityIndicatorView()
        }
        
        self.getImageDelegate.LSPhotoBrowser_asyncLoadImage(url, progress: nil, completion: { (image) in
            self.placeholderRecorder[index] = .HasDone
            if index == self.currentImageIndex {
                self.setupActivityIndicatorView()
            }
            guard image != nil else {
                return
            }
            DispatchQueue.after(0.03, block: {
                if let cell = self.collectionView.cellForItem(at: indexPath) as? Cell {
                    cell.setPlaceholder(image)
                }
            })
        })
    }
    
    fileprivate func asyncSetHighQualityImage(forIndexPath indexPath: IndexPath, url: String) {
        let index = indexPath.item
        guard self.highQualityRecorder[index] == .NotBegin else {
            return
        }
        self.highQualityRecorder[index] = .Ratio(0)
        if index == self.currentImageIndex {
            self.setupHighQualityButton()
        }
        
        self.getImageDelegate.LSPhotoBrowser_asyncLoadImage(url, progress: { (receivedSize, expectedSize) in
            var receivedSize = receivedSize
            var expectedSize = expectedSize
            if receivedSize < 0 {
                receivedSize = 0
            }
            if expectedSize <= 0 {
                expectedSize = 1
            }
            if expectedSize < receivedSize {
                expectedSize = receivedSize
            }
            let ratio = 100 * receivedSize / expectedSize
            self.highQualityRecorder[index] = .Ratio(ratio)
            if index == self.currentImageIndex {
                self.setupHighQualityButton()
            }
        }, completion: { (image) in
            self.highQualityRecorder[index] = .HasDone
            if index == self.currentImageIndex {
                self.setupHighQualityButton()
                self.setupActivityIndicatorView()
            }
            guard image != nil else {
                return
            }
            DispatchQueue.after(0.03, block: {
                if let cell = self.collectionView.cellForItem(at: indexPath) as? Cell {
                    cell.setHighQuality(image)
                }
            })
        })
    }
    
    fileprivate func tap() {
        self.dismiss(animated: true, completion: nil)
    }
    
    fileprivate func long(_ cell: Cell, image: UIImage?) {
        guard let image = image, let index = self.collectionView.indexPath(for: cell)?.item else {
            return
        }
        self.delegate.photoBrowser?(self, operationImage: image, atIndex: index)
    }
    
    @objc private func hightQualityButtonDidClicked() {
        if let url = self.delegate.photoBrowser?(self, highQualityUrlStringForIndex: self.currentImageIndex) {
            self.asyncSetHighQualityImage(forIndexPath: IndexPath(item: self.currentImageIndex, section: 0), url: url)
        }
    }
    
    fileprivate func getPlaceholderImage(_ index: Int) -> (UIImage?, String?) {
        if let image = self.delegate.photoBrowser?(self, placeholderImageForIndex: index) {
            return (image, nil)
        }
        if let url = self.delegate.photoBrowser?(self, placeholderUrlStringForIndex: index) {
            if let image = self.getImageDelegate.LSPhotoBrowser_getCacheImage(url) {
                return (image, nil)
            } else {
                return (nil, url)
            }
        }
        return (nil, nil)
    }
    
    fileprivate func getHighQualityImage(_ index: Int) -> (UIImage?, String?) {
        if let image = self.delegate.photoBrowser?(self, highQualityImageForIndex: index) {
            return (image, nil)
        }
        if let url = self.delegate.photoBrowser?(self, highQualityUrlStringForIndex: index) {
            if let image = self.getImageDelegate.LSPhotoBrowser_getCacheImage(url) {
                return (image, nil)
            } else {
                return (nil, url)
            }
        }
        return (nil, nil)
    }
    
    fileprivate func setupHighQualityButton() {
        guard let highQualityButton = self.highQualityButton else {
            return
        }
        if !self.hideStatusViews {
            switch self.highQualityRecorder[self.currentImageIndex] {
            case .NotBegin:
                highQualityButton.isHidden = false
                highQualityButton.setTitle(highQualityTitle, for: .normal)
            case .HasDone:
                highQualityButton.isHidden = true
            case .Ratio(let rrrr):
                highQualityButton.isHidden = false
                highQualityButton.setTitle("\(rrrr)%", for: .normal)
            }
        } else {
            highQualityButton.isHidden = true
        }
    }
    
    fileprivate func setupActivityIndicatorView() {
        guard let activityIndicator = self.activityIndicator else {
            return
        }
        if self.hideStatusViews ||
            self.placeholderRecorder[self.currentImageIndex] == .HasDone ||
            self.highQualityRecorder[self.currentImageIndex] == .HasDone {
            if activityIndicator.isAnimating {
                activityIndicator.stopAnimating()
            }
        } else {
            if !activityIndicator.isAnimating {
                activityIndicator.startAnimating()
            }
        }
    }
}

extension LSPhotoBrowser: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return Animation(isPresenting: true, photoBrowser: self)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return Animation(isPresenting: false, photoBrowser: self)
    }
}

extension LSPhotoBrowser: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return self.imageCount
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cell.reuseIdentify, for: indexPath) as! Cell
        cell.photoBrowser = self
        return cell
    }
}

extension LSPhotoBrowser: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let temp0 = Double(scrollView.contentOffset.x / scrollView.bounds.width)
        self.currentImageIndex = Int(temp0 + 0.5)
        self.pageLabel?.text = "\(self.currentImageIndex+1) / \(self.imageCount)"
        let temp1 = temp0 - floor(temp0)
        self.hideStatusViews = temp1 > 0.05 && temp1 < 0.95
        self.setupHighQualityButton()
        self.setupActivityIndicatorView()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath)
    {
        /*
         0.清空原有图片
         1.同步获取高清图，如果成功，设置高清图，标记已经获取高清图，返回
         2.如果自动获取高清图，异步获取高清图
         3.同步获取占位图，如果成功，设置占位图，返回
         4.异步获取占位图
         */
        
        let cell = cell as! Cell
        let index = indexPath.item
        
        // 0
        cell.setPlaceholder(nil)
        
        let (hi, hu) = self.getHighQualityImage(index)
        if let image = hi {
            // 1
            self.highQualityRecorder[index] = .HasDone
            self.setupHighQualityButton()
            self.setupActivityIndicatorView()
            cell.setHighQuality(image)
            return
        }
        if let url = hu, self.highQualityMode == .Auto {
            // 2
            self.asyncSetHighQualityImage(forIndexPath: indexPath, url: url)
        }
        let (pi, pu) = self.getPlaceholderImage(index)
        if let image = pi {
            // 3
            self.placeholderRecorder[index] = .HasDone
            self.setupActivityIndicatorView()
            cell.setPlaceholder(image)
            return
        }
        if let url = pu {
            // 4
            self.asyncSetPlaceholderImage(forIndexPath: indexPath, url: url)
        }
    }
}
