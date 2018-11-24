//
//  YouTubePlayer.swift
//  YouTubePlayer
//
//  Created by levantAJ on 24/11/18.
//  Copyright © 2018 levantAJ. All rights reserved.
//

import UIKit
import WebKit

open class YouTubePlayer: UIView {
    var activeArea: UIEdgeInsets = UIApplication.shared.safeAreaInsets
    var previewImageView: UIImageView!
    var backgroundVisualEffectView: UIVisualEffectView!
    var coverVisualEffectView: UIVisualEffectView!
    var webView: WKWebView!
    var loop: Bool = true
    var beganPoint: CGPoint = .zero
    var autoPlay: Bool = true
    var hideWhenDismissed: Bool = true
    var videoId: String?
    static var defaultFrame: CGRect {
        let safeArea = UIApplication.shared.safeAreaInsets
        let space: CGFloat = 20
        let width = UIScreen.main.bounds.width - safeArea.left - safeArea.right - space * 2
        let height = 9 * width / 16
        return CGRect(x: safeArea.left + space, y: safeArea.top, width: width, height: height)
    }
    
    public static let shared: YouTubePlayer = {
        let frame = YouTubePlayer.defaultFrame
        let view = YouTubePlayer(frame: frame)
        let safeArea = UIApplication.shared.safeAreaInsets
        view.activeArea = UIEdgeInsets(top: safeArea.top, left: frame.minX, bottom: safeArea.bottom, right: frame.minX)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    open override var frame: CGRect {
        didSet {
            backgroundVisualEffectView?.frame.size = frame.size
            coverVisualEffectView?.frame.size = frame.size
            previewImageView?.frame.size = frame.size
            webView?.frame.size = frame.size
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        webView.layer.cornerRadius = 12
        backgroundVisualEffectView.layer.cornerRadius = webView.layer.cornerRadius
        coverVisualEffectView.layer.cornerRadius = webView.layer.cornerRadius
        previewImageView.layer.cornerRadius = webView.layer.cornerRadius
        shadowed(cornerRadius: webView.layer.cornerRadius)
    }
    
    open func play(id: String, from view: UIView) {
        stop()
        self.videoId = id
        prepare(id: id)
        present(from: view)
    }
    
    open func stop() {
        let stoppedVideoId = videoId
        videoId = nil
        let url = URL(string: Constant.YouTubePlayer.blankURLString)!
        let request = URLRequest(url: url)
        webView.load(request)
        previewImageView.image = nil
        coverVisualEffectView.alpha = 0
        NotificationCenter.default.post(name: .playerDidStop, object: nil, userInfo: [Constant.YouTubePlayer.videoIdKey: stoppedVideoId as Any])
    }
}

// MARK: - WKNavigationDelegate

extension YouTubePlayer: WKNavigationDelegate {
    private func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.body { [weak self] body in
            guard let body = body,
                !body.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.previewImageView.image = nil
            }
        }
    }
}

// MARK: - User Interactions

extension YouTubePlayer {
    @objc func dragging(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            beganPoint = gesture.location(in: gesture.view)
        } else if gesture.state == .ended {
            if dismissIfNeeded(gesture: gesture) {
                return
            }
            didEndDragging()
            return
        }
        let point = gesture.location(in: gesture.view)
        let x = frame.minX + point.x - beganPoint.x
        let y = frame.minY + point.y - beganPoint.y
        frame.origin = CGPoint(x: x, y: y)
        updateAlpha()
    }
}

// MARK: - Privates

extension YouTubePlayer {
    private var safeArea: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return safeAreaInsets
        }
        return .zero
    }
    
    private func dismissIfNeeded(gesture: UIPanGestureRecognizer) -> Bool {
        let velocity = gesture.velocity(in: gesture.view)
        guard velocity.x < -Constant.YouTubePlayer.horizontalVelocityThreshold
            || velocity.x > Constant.YouTubePlayer.horizontalVelocityThreshold else { return false }
        let x = frame.origin.x < beganPoint.x ? -frame.width : UIScreen.main.bounds.width + frame.width
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
        if frame.minX + frame.width <= Constant.YouTubePlayer.collasedSpace * 4 {
            x = Constant.YouTubePlayer.collasedSpace - frame.width
            alpha = 1
        } else if UIScreen.main.bounds.width - frame.minX <= Constant.YouTubePlayer.collasedSpace * 4 {
            x = UIScreen.main.bounds.width - Constant.YouTubePlayer.collasedSpace
            alpha = 1
        } else if center.x < UIScreen.main.bounds.width/2 {
            x = activeArea.left
            alpha = 0
        } else {
            x = UIScreen.main.bounds.width - activeArea.right - frame.width
            alpha = 0
        }
        let y: CGFloat
        if frame.maxY <= Constant.YouTubePlayer.dimissedSpace + activeArea.top {
            y = -frame.height - activeArea.top
            dismissed = true
        } else if center.y < UIScreen.main.bounds.height/2 {
            y = activeArea.top
        } else {
            y = UIScreen.main.bounds.height - activeArea.bottom - frame.height
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
        if frame.minX >= activeArea.left && frame.maxX <= UIScreen.main.bounds.width - activeArea.right {
            coverVisualEffectView.alpha = 0
        } else if frame.minX < activeArea.left {
            coverVisualEffectView.alpha = max(min((abs(frame.minX) + activeArea.left) / frame.width, 1), 0)
        } else if frame.maxX > UIScreen.main.bounds.width - activeArea.right {
            coverVisualEffectView.alpha = max(min((frame.maxX - UIScreen.main.bounds.width + activeArea.right) / frame.width, 1), 0)
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
        configuration.requiresUserActionForMediaPlayback = false
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        
        let contentFrame = CGRect(origin: .zero, size: frame.size)
        
        backgroundVisualEffectView = UIVisualEffectView(frame: contentFrame)
        backgroundVisualEffectView.effect = UIBlurEffect(style: .dark)
        backgroundVisualEffectView.clipsToBounds = true
        addSubview(backgroundVisualEffectView)
        
        webView = WKWebView(frame: contentFrame, configuration: configuration)
        webView.isOpaque = false
        webView.clipsToBounds = true
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        addSubview(webView)
        
        previewImageView = UIImageView(frame: contentFrame)
        previewImageView.clipsToBounds = true
        previewImageView.backgroundColor = .clear
        previewImageView.contentMode = .scaleAspectFill
        addSubview(previewImageView)
        
        coverVisualEffectView = UIVisualEffectView(frame: contentFrame)
        coverVisualEffectView.effect = UIBlurEffect(style: .light)
        coverVisualEffectView.alpha = 0
        coverVisualEffectView.clipsToBounds = true
        addSubview(coverVisualEffectView)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragging))
        addGestureRecognizer(pan)
    }
    
    private func present(from view: UIView) {
        NotificationCenter.default.post(name: .playerWillPresent, object: nil, userInfo: [Constant.YouTubePlayer.videoIdKey: videoId as Any])
        frame = view.convert(view.bounds, to: UIApplication.shared.keyWindow)
        isHidden = false
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseIn], animations: { [weak self] in
            self?.frame = YouTubePlayer.defaultFrame
        })
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseIn], animations: { [weak self] in
            self?.frame = YouTubePlayer.defaultFrame
        }) { [weak self] _ in
            guard let presentedVideoId = self?.videoId else { return }
            NotificationCenter.default.post(name: .playerDidPresent, object: nil, userInfo: [Constant.YouTubePlayer.videoIdKey: presentedVideoId as Any])
        }
    }
    
    private func prepare(id: String) {
        let src = "https://www.youtube.com/embed/\(id)?playsinline=1&modestbranding=1&showinfo=0&rel=0&showsearch=0&loop=\(loop ? 1 : 0)&iv_load_policy=3&autoplay=\(autoPlay ? 1 : 0)&enablejsapi=1".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        if autoPlay {
            let body = "<html><head><style type=\"text/css\">\(Constant.YouTubePlayer.css)</style></head><body><div class=\"video-container\"><script type='text/javascript' src='http://www.youtube.com/iframe_api'></script><script type='text/javascript'>function onYouTubeIframeAPIReady(){ytplayer=new YT.Player('playerId',{events:{onReady:onPlayerReady}})}function onPlayerReady(a){a.target.playVideo();}</script><iframe id='playerId' type='text/html' width='\(bounds.width)' height='\(bounds.height)' src='\(src)' frameborder='0'></div></body></html>"
            webView.loadHTMLString(body, baseURL: nil)
        } else {
            let url = URL(string: src)!
            let request = URLRequest(url: url)
            webView.load(request)
        }
        previewImageView.setImage(with: URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg"))
        coverVisualEffectView.alpha = 0
    }
    
    private func dismiss() {
        stop()
        isHidden = hideWhenDismissed
    }
}

// MARK: - UIApplication

extension UIApplication {
    var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            guard let window = keyWindow else { return .zero }
            return window.safeAreaInsets
        }
        return .zero
    }
}

// MARK: - Notification.Name

extension Notification.Name {
    static let playerDidStop = Notification.Name(rawValue: "playerDidStop")
    static let playerWillPresent = Notification.Name(rawValue: "playerWillPresent")
    static let playerDidPresent = Notification.Name(rawValue: "playerDidPresent")
}

// MARK: - UIView

extension UIView {
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

// MARK: - UIView

extension WKWebView {
    func body(completion: @escaping (String?) -> Void) {
        evaluateJavaScript("document.getElementsByTagName('body')[0].innerHTML") { innerHTML, error in
            completion(innerHTML as? String)
        }
    }
}

// MARK: - UIImageView

extension UIImageView {
    func setImage(with url: URL?) {
        if let url = url {
            URLSession.shared.dataTask(with: url) { (data, _, _) in
                guard let data = data,
                    let image = UIImage(data: data) else { return }
                DispatchQueue.main.async() { [weak self] in
                    self?.image = image
                }
            }
        } else {
            image = nil
        }
    }
}

// MARK: - Constant

struct Constant {
    struct YouTubePlayer {
        static let collasedSpace: CGFloat = 30
        static let dimissedSpace: CGFloat = 30
        static let horizontalVelocityThreshold: CGFloat = 3500
        static let blankURLString = "about:blank"
        static let css = ".video-container{position:relative;padding-bottom:56.25%;height:0;overflow:hidden;background-color:transparent;}.video-container iframe,.video-container object,.video-container embed{position:absolute;top:0;left:0;width:100%;height:100%;}html,body{margin:0;height:100%;background-color:transparent;}"
        static let videoIdKey = "videoIdKey"
    }
}
