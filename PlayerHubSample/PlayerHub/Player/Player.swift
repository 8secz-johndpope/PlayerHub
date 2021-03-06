//
//  Player.swift
//  PlayerHubSample
//
//  Created by 廖雷 on 2019/10/10.
//  Copyright © 2019 Danis. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class Player: NSObject {
    enum Status {
        case initial        // 初始状态
        case prepared       // 装载了Item，但并未开始播放
        case buffering      // 加载中
        case playing        // 播放中
        case paused         // 暂停
        case end            // 播放到末尾
        case failed         // 播放出错
    }
    
    enum Gravity {
        case scaleToFill
        case scaleAspectFit
        case scaleAspectFill
        
        var videoGravity: AVLayerVideoGravity {
            switch self {
            case .scaleAspectFill:
                return .resizeAspectFill
            case .scaleAspectFit:
                return .resizeAspect
            case .scaleToFill:
                return .resize
            }
        }
        
        var imageContentMode: UIView.ContentMode {
            switch self {
            case .scaleToFill:
                return .scaleToFill
            case .scaleAspectFit:
                return .scaleAspectFit
            case .scaleAspectFill:
                return .scaleAspectFill
            }
        }
    }
    
    // MARK: Callback
    var statusDidChangeHandler: ((Status) -> Void)?
    var playedDurationDidChangeHandler: ((TimeInterval, TimeInterval) -> Void)?
    var bufferedDurationDidChangeHandler: ((Range<TimeInterval>) -> Void)?
    
    private let player: AVPlayer = {
        let temp = AVPlayer()
        temp.automaticallyWaitsToMinimizeStalling = false
        
        return temp
    }()
    
    private(set) var currentItem: AVPlayerItem?
    private(set) var currentAsset: AVAsset?
    private(set) var status = Status.initial {
        didSet {
            if status != oldValue {
                statusDidChangeHandler?(status)
                
                print("status changed -> \(status)")
                if status == .failed {
                    print("error -> \(error)")
                }
            }
        }
    }
    private(set) var error: Error?
    
    var gravity = Gravity.scaleAspectFit {
        didSet {
            playerLayer?.videoGravity = gravity.videoGravity
        }
    }
    var duration: TimeInterval {
        return currentItem?.duration.seconds ?? 0
    }
    var playedDuration: TimeInterval {
        return currentItem?.currentTime().seconds ?? 0
    }
    
    // Private
    private weak var playerLayer: AVPlayerLayer?
    private var toPlay = false
    private let startPlayingAfterPreBufferingDuration: TimeInterval = 2 // 缓存2秒内容进行播放
    
    private var playerObservations = [NSKeyValueObservation]()
    private var itemObservations = [NSKeyValueObservation]()
    private var timeObserver: Any?
    
    private var isPlayingWhenEnterBackground = false
    private var isPlayingWhenResignActive = false
    
    private let resourceLoaderDelegateQueue = DispatchQueue(label: "com.danis.Player.resourceLoaderDelegateQueue", attributes: .concurrent)

    // Cache
    var isCacheEnable = true
    private var resourceLoaderProxy: ResourceLoaderProxy?
    private var resourcePreloader: MediasPreloaderDataLoader?
    
    var isPlaying: Bool {
        return player.rate != 0
    }
    
    override init() {
        super.init()
        
        addPlayerObservers()
        addNotifications()
    }
    
    deinit {
        removeItemObservers()
        removePlayerObservers()
        removeNotifications()
    }
}

extension Player {
    func bind(to playerLayer: AVPlayerLayer) {
        playerLayer.player = player
        self.playerLayer = playerLayer
    }
    
    func replace(with url: URL) {
        replace(with: url, preload: nil)
    }
    
    func replace(with url: URL, preload nextURL: URL?) {
        if currentItem != nil {
            stop()
        }
        
        resourceLoaderProxy?.cancel()
        resourceLoaderProxy = nil
        
        resourcePreloader?.cancel()
        resourcePreloader = nil
        
        let asset: AVURLAsset
        if isCacheEnable {
            asset = AVURLAsset(url: CacheURL.addCacheScheme(from: url))
            resourceLoaderProxy = ResourceLoaderProxy()
            asset.resourceLoader.setDelegate(resourceLoaderProxy!, queue: resourceLoaderDelegateQueue)
            
            if let nextURL = nextURL, nextURL != url {
                resourcePreloader = MediasPreloaderDataLoader(sourceURL: nextURL)
                resourcePreloader?.resume()
            }
        } else {
            asset = AVURLAsset(url: url)
        }
        currentAsset = asset
        currentItem = AVPlayerItem(asset: asset)
        
        addItemObservers()
        
        player.replaceCurrentItem(with: currentItem)
        
        
    }
    
    func stop() {
        toPlay = false
        removeItemObservers()
        currentItem = nil
        player.replaceCurrentItem(with: nil)
        
        status = .initial
    }
    
    func play() {
        toPlay = true
        
        player.play()
    }
    
    func pause() {
        toPlay = false
        
        player.pause()
    }
    
    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func generateThumbnailAtCurrentTime() -> UIImage? {
        guard let currentAsset = currentAsset else {
            return nil
        }
        guard let currentItem = currentItem else {
            return nil
        }
        
        let generator = AVAssetImageGenerator(asset: currentAsset)
        let time = currentItem.currentTime()
        
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        } else {
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .negativeInfinity
            
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        
        return nil
    }
}

extension Player {
    private func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onNotificationEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onNotificationEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onNotificationBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onNotificationResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func addPlayerObservers() {
        let ob1 = player.observe(\.status, options: .new) { [unowned self] (player, change) in
            self.updateStatus()
        }
        
        let ob2 = player.observe(\.timeControlStatus, options: .new) { [unowned self] (player, change) in
            self.updateStatus()
        }
                
        playerObservations = [ob1, ob2]
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.03, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main, using: { [unowned self] (time) in
            guard let total = self.currentItem?.duration.seconds else {
                return
            }
            if total.isNaN || total.isZero {
                return
            }
            
            self.playedDurationDidChangeHandler?(self.playedDuration, self.duration)
        })
    }
    
    private func removePlayerObservers() {
        playerObservations.forEach {
            $0.invalidate()
        }
        playerObservations.removeAll()
        
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }
    
    private func addItemObservers() {
        guard let currentItem = currentItem else {
            return
        }
        
        let ob1 = currentItem.observe(\.status, options: .new) { [unowned self] (item, change) in
            self.updateStatus()
        }
        let ob2 = currentItem.observe(\.loadedTimeRanges, options: .new) { [unowned self] (item, change) in
            if let range = item.loadedTimeRanges.first as? CMTimeRange {
                self.bufferedDurationDidChangeHandler?(Range<Double>.init(uncheckedBounds: (range.start.seconds, range.start.seconds + range.duration.seconds)))
                
                if self.status == .buffering {
                    if range.start.seconds + range.duration.seconds == currentItem.duration.seconds { // 到末尾
                        self.play()
                    } else if range.start.seconds + range.duration.seconds > currentItem.currentTime().seconds + self.startPlayingAfterPreBufferingDuration {    // 多加载了1秒
                        self.play()
                    }
                }
            }
        }
        let ob3 = currentItem.observe(\.isPlaybackLikelyToKeepUp, options: .new) { [unowned self] (item, change) in
            self.updateStatus()
        }
        let ob4 = currentItem.observe(\.isPlaybackBufferEmpty, options: .new) { [unowned self] (item, change) in
            self.updateStatus()
        }
        let ob5 = currentItem.observe(\.isPlaybackBufferFull, options: .new) { [unowned self] (item, change) in
            self.updateStatus()
        }
        
        itemObservations = [ob1, ob2, ob3, ob4, ob5]
    }
    
    private func removeItemObservers() {
        itemObservations.forEach {
            $0.invalidate()
        }
        itemObservations.removeAll()
    }
    
    private func updateStatus() {
        guard let currentItem = currentItem else {
            return
        }
        
        if let error = player.error {
            self.error = error
            self.status = .failed
            
            return
        }
        
        if let error = currentItem.error {
            self.error = error
            self.status = .failed
            
            return
        }
        
        self.error = nil
        
        if currentItem.currentTime() == currentItem.duration {
            status = .end
        } else {
            if toPlay { // 期望播放
                if currentItem.isPlaybackLikelyToKeepUp && player.rate != 0 {
                    self.status = .playing
                } else {
                    self.status = .buffering
                }
            } else {
                if status == .initial || status == .prepared && currentItem.currentTime().seconds == 0 {
                    status = .prepared
                }  else {
                    status = .paused
                }
            }
        }
        
        
    }
}

extension Player {
    @objc private func onNotificationEnterBackground(_ noti: Notification) {
        isPlayingWhenEnterBackground = isPlaying
        
        if isPlaying {
            pause()
        }
    }
    
    @objc private func onNotificationEnterForeground(_ noti: Notification) {
        if isPlayingWhenEnterBackground {
            play()
        }
    }
    
    @objc private func onNotificationResignActive(_ noti: Notification) {
        isPlayingWhenResignActive = isPlaying
        
        if isPlaying {
            pause()
        }
    }
    
    @objc private func onNotificationBecomeActive(_ noti: Notification) {
        if isPlayingWhenResignActive {
            play()
        }
    }
}
    
