//
//  YouTubeVideoPlayer.swift
//  YouTubeVideoPlayer
//
//  Created by levantAJ on 24/11/18.
//  Copyright © 2018 levantAJ. All rights reserved.
//

import UIKit
import WebKit

public protocol YouTubeVideoPlayerDelegate: class {
    func youTubeVideoPlayer(_ player: YouTubeVideoPlayer, didStop videoId: String)
    func youTubeVideoPlayer(_ player: YouTubeVideoPlayer, willPresent videoId: String)
    func youTubeVideoPlayer(_ player: YouTubeVideoPlayer, didPresent videoId: String)
}

open class YouTubeVideoPlayer: UIView {
    public static let videoIdKey = "videoIdKey"
    public static let playerDidStop = Notification.Name(rawValue: "com.levantAJ.YouTubeVideoPlayer.playerDidStop")
    public static let playerWillPresent = Notification.Name(rawValue: "com.levantAJ.YouTubeVideoPlayer.playerWillPresent")
    public static let playerDidPresent = Notification.Name(rawValue: "com.levantAJ.YouTubeVideoPlayer.playerDidPresent")
    public private(set) var videoId: String?
    public var isAutoPlay: Bool = true
    public var isLooped: Bool = true
    public var pauseWhenIdle: Bool = false
    public var maxWidth: CGFloat = 500
    public weak var delegate: YouTubeVideoPlayerDelegate?
    
    @objc dynamic var webView: WKWebView!
    var activeAreaInsets: UIEdgeInsets = .zero
    var previewImageView: UIImageView!
    var backgroundVisualEffectView: UIVisualEffectView!
    var coverVisualEffectView: UIVisualEffectView!
    var draggingBeganPoint: CGPoint = .zero
    var initialRect: CGRect = .zero
    open override var frame: CGRect {
        didSet {
            backgroundVisualEffectView?.frame.size = frame.size
            coverVisualEffectView?.frame.size = frame.size
            previewImageView?.frame.size = frame.size
            webView?.frame.size = frame.size
        }
    }
    
    public static let shared: YouTubeVideoPlayer = {
        return YouTubeVideoPlayer(frame: .zero)
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    deinit {
        removeObserver(self, forKeyPath: Constant.YouTubeVideoPlayer.webViewLoadingKeyPath)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUpViews()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        webView.layer.cornerRadius = 12
        backgroundVisualEffectView.layer.cornerRadius = webView.layer.cornerRadius
        coverVisualEffectView.layer.cornerRadius = webView.layer.cornerRadius
        previewImageView.layer.cornerRadius = webView.layer.cornerRadius
        shadowed(cornerRadius: webView.layer.cornerRadius)
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath,
            keyPath == Constant.YouTubeVideoPlayer.webViewLoadingKeyPath,
            let loading = change?[.newKey] as? Bool,
            loading == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                if self?.isAutoPlay == true {
                    self?.resume()
                }
                self?.previewImageView.image = nil
                self?.previewImageView.isHidden = true
                debugPrint("YouTubeVideoPlayer is loaded.")
            }
        }
    }
    
    open func play(videoId: String, sourceView: UIView) {
        layout(sourceView: sourceView)
        stop()
        self.videoId = videoId
        prepare(videoId: videoId)
        present(sourceView: sourceView)
    }
    
    open func stop() {
        let stoppedVideoId = videoId
        videoId = nil
        let url = URL(string: Constant.YouTubeVideoPlayer.blankURLString)!
        let request = URLRequest(url: url)
        webView.load(request)
        previewImageView.image = nil
        coverVisualEffectView.alpha = 0
        NotificationCenter.default.post(name: YouTubeVideoPlayer.playerDidStop, object: nil, userInfo: [YouTubeVideoPlayer.videoIdKey: stoppedVideoId as Any])
        delegate?.youTubeVideoPlayer(self, didStop: stoppedVideoId!)
    }
    
    open func resume() {
        webView.evaluateJavaScript("ytplayer.playVideo()")
    }
    
    open func pause() {
        webView.evaluateJavaScript("ytplayer.pauseVideo()")
    }
}

// MARK: - User Interactions

extension YouTubeVideoPlayer {
    @objc func dragging(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            draggingBeganPoint = gesture.location(in: gesture.view)
        } else if gesture.state == .ended {
            if dismissIfNeeded(gesture: gesture) {
                return
            }
            didEndDragging()
            return
        }
        let point = gesture.location(in: gesture.view)
        let x = frame.minX + point.x - draggingBeganPoint.x
        let y = frame.minY + point.y - draggingBeganPoint.y
        frame.origin = CGPoint(x: x, y: y)
        updateAlpha()
    }
}

// MARK: - Privates

extension YouTubeVideoPlayer {
    private func layout(sourceView: UIView) {
        let safeArea = sourceView.safeArea
        let padding: CGFloat = 20
        let width = min(UIScreen.main.bounds.width, maxWidth) - safeArea.left - safeArea.right - padding * 2
        let height = 9 * width / 16
        let top = safeArea.top == 0 ? padding : safeArea.top
        frame = CGRect(x: safeArea.left + padding, y: top, width: width, height: height)
        initialRect = frame
        activeAreaInsets = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: safeArea.bottom + padding, right: frame.minX)
    }
    
    private func dismissIfNeeded(gesture: UIPanGestureRecognizer) -> Bool {
        let velocity = gesture.velocity(in: gesture.view)
        guard velocity.x < -Constant.YouTubeVideoPlayer.horizontalVelocityThreshold
            || velocity.x > Constant.YouTubeVideoPlayer.horizontalVelocityThreshold else { return false }
        let x = frame.origin.x < draggingBeganPoint.x ? -frame.width : UIScreen.main.bounds.width + frame.width
        let y = frame.origin.y
        UIView.animate(withDuration: 0.1, delay: 0.0, options: [.curveEaseIn], animations: { [weak self] in
            self?.frame.origin = CGPoint(x: x, y: y)
        }) { [weak self] _ in
            self?.dismiss()
        }
        return true
    }
    
    private func didEndDragging() {
        let x: CGFloat
        let alpha: CGFloat
        var dismissed = false
        if frame.minX + frame.width <= Constant.YouTubeVideoPlayer.collasedSpace * 4 {
            x = Constant.YouTubeVideoPlayer.collasedSpace - frame.width
            alpha = 1
            if pauseWhenIdle {
                pause()
            }
        } else if UIScreen.main.bounds.width - frame.minX <= Constant.YouTubeVideoPlayer.collasedSpace * 4 {
            x = UIScreen.main.bounds.width - Constant.YouTubeVideoPlayer.collasedSpace
            alpha = 1
            if pauseWhenIdle {
                pause()
            }
        } else if center.x < UIScreen.main.bounds.width/2 {
            x = activeAreaInsets.left
            alpha = 0
            if pauseWhenIdle {
                resume()
            }
        } else {
            x = UIScreen.main.bounds.width - activeAreaInsets.right - frame.width
            alpha = 0
            if pauseWhenIdle {
                resume()
            }
        }
        let y: CGFloat
        if frame.maxY <= Constant.YouTubeVideoPlayer.dimissedSpace + activeAreaInsets.top {
            y = -frame.height - activeAreaInsets.top
            dismissed = true
        } else if center.y < UIScreen.main.bounds.height/2 {
            y = activeAreaInsets.top
        } else {
            y = UIScreen.main.bounds.height - activeAreaInsets.bottom - frame.height
        }
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut], animations: { [weak self] in
            self?.coverVisualEffectView.alpha = alpha
            self?.frame.origin = CGPoint(x: x, y: y)
        }) { [weak self] _ in
            guard dismissed else { return }
            self?.dismiss()
        }
    }
    
    private func updateAlpha() {
        if frame.minX >= activeAreaInsets.left && frame.maxX <= UIScreen.main.bounds.width - activeAreaInsets.right {
            coverVisualEffectView.alpha = 0
        } else if frame.minX < activeAreaInsets.left {
            coverVisualEffectView.alpha = max(min((abs(frame.minX) + activeAreaInsets.left) / frame.width, 1), 0)
        } else if frame.maxX > UIScreen.main.bounds.width - activeAreaInsets.right {
            coverVisualEffectView.alpha = max(min((frame.maxX - UIScreen.main.bounds.width + activeAreaInsets.right) / frame.width, 1), 0)
        }
    }
    
    private func setUpViews() {
        backgroundColor = .clear
        layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        if #available(iOS 9.0, *) {
            configuration.requiresUserActionForMediaPlayback = false
            configuration.allowsAirPlayForMediaPlayback = true
            configuration.allowsPictureInPictureMediaPlayback = true
        }
        
        backgroundVisualEffectView = UIVisualEffectView(frame: bounds)
        backgroundVisualEffectView.effect = UIBlurEffect(style: .dark)
        backgroundVisualEffectView.clipsToBounds = true
        addSubview(backgroundVisualEffectView)
        
        webView = WKWebView(frame: bounds, configuration: configuration)
        webView.isOpaque = false
        webView.clipsToBounds = true
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.isScrollEnabled = false
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        addObserver(self, forKeyPath: Constant.YouTubeVideoPlayer.webViewLoadingKeyPath, options: .new, context: nil)
        addSubview(webView)
        
        previewImageView = UIImageView(frame: bounds)
        previewImageView.clipsToBounds = true
        previewImageView.backgroundColor = .clear
        previewImageView.contentMode = .scaleAspectFill
        addSubview(previewImageView)
        
        coverVisualEffectView = UIVisualEffectView(frame: bounds)
        coverVisualEffectView.effect = UIBlurEffect(style: .light)
        coverVisualEffectView.alpha = 0
        coverVisualEffectView.clipsToBounds = true
        addSubview(coverVisualEffectView)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(dragging))
        addGestureRecognizer(panGesture)
    }
    
    private func present(sourceView: UIView) {
        NotificationCenter.default.post(name: YouTubeVideoPlayer.playerWillPresent, object: nil, userInfo: [YouTubeVideoPlayer.videoIdKey: videoId as Any])
        delegate?.youTubeVideoPlayer(self, willPresent: videoId!)
        frame = sourceView.convert(sourceView.bounds, to: sourceView.window)
        isHidden = false
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseIn], animations: {
            self.frame = self.initialRect
        })
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseIn], animations: {
            self.frame = self.initialRect
        }) { _ in
            guard let presentedVideoId = self.videoId else { return }
            NotificationCenter.default.post(name: YouTubeVideoPlayer.playerDidPresent, object: nil, userInfo: [YouTubeVideoPlayer.videoIdKey: presentedVideoId as Any])
            self.delegate?.youTubeVideoPlayer(self, didStop: presentedVideoId)
        }
    }
    
    private func prepare(videoId: String) {
        coverVisualEffectView.alpha = 0
        previewImageView.isHidden = false
        previewImageView.setImage(with: URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"))
        let src = "https://www.youtube.com/embed/\(videoId)?playsinline=1&modestbranding=1&showinfo=0&rel=0&showsearch=0&loop=\(isLooped ? 1 : 0)&iv_load_policy=3&autoplay=\(isAutoPlay ? 1 : 0)&enablejsapi=1".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        if isAutoPlay {
            let body = "<html><head><style type=\"text/css\">\(Constant.YouTubeVideoPlayer.css)</style></head><body><div class=\"video-container\"><script type='text/javascript' src='http://www.youtube.com/iframe_api'></script><script type='text/javascript'>function onYouTubeIframeAPIReady(){ytplayer=new YT.Player('playerId',{events:{onReady:onPlayerReady}})}function onPlayerReady(a){a.target.playVideo();}</script><iframe id='playerId' type='text/html' width='\(bounds.width)' height='\(bounds.height)' src='\(src)' frameborder='0'></div></body></html>"
            webView.loadHTMLString(body, baseURL: nil)
        } else {
            let url = URL(string: src)!
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    private func dismiss() {
        stop()
        isHidden = true
    }
}

// MARK: - UIView

extension UIView {
    var safeArea: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return window?.safeAreaInsets ?? safeAreaInsets
        }
        return .zero
    }
    
    func shadowed(shadowRadius: CGFloat = 15.0,
                  shadowColor: UIColor = .black,
                  shadowOpacity: Float = 0.45,
                  shadowOffset: CGSize = CGSize(width: 0, height: 3),
                  cornerRadius: CGFloat = 10.0) {
        layer.masksToBounds = false
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOffset = shadowOffset
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
}

// MARK: - UIImageView

extension UIImageView {
    static let imagesCache = NSCache<NSString, UIImage>()
    
    func setImage(with url: URL?) {
        if let url = url {
            if let image = UIImageView.imagesCache.object(forKey: url.absoluteString as NSString) {
                self.image = image
            } else {
                URLSession.shared.dataTask(with: url) { (data, _, _) in
                    guard let data = data,
                        let image = UIImage(data: data) else { return }
                    DispatchQueue.main.async() { [weak self] in
                        self?.image = image
                        UIImageView.imagesCache.setObject(image, forKey: url.absoluteString as NSString)
                    }
                }.resume()
            }
        } else {
            image = nil
        }
    }
}

// MARK: - Constant

struct Constant {
    struct YouTubeVideoPlayer {
        static let collasedSpace: CGFloat = 30
        static let dimissedSpace: CGFloat = 30
        static let horizontalVelocityThreshold: CGFloat = 3500
        static let blankURLString = "about:blank"
        static let css = ".video-container{position:relative;padding-bottom:56.25%;height:0;overflow:hidden;background-color:transparent;}.video-container iframe,.video-container object,.video-container embed{position:absolute;top:0;left:0;width:100%;height:100%;}html,body{margin:0;height:100%;background-color:transparent;}"
        static let webViewLoadingKeyPath = "webView.loading"
    }
}
