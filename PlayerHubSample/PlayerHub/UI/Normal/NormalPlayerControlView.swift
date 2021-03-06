//
//  NormalPlayerBoxControlView.swift
//  PlayerHubSample
//
//  Created by 廖雷 on 2019/10/11.
//  Copyright © 2019 Danis. All rights reserved.
//

import UIKit
import SnapKit
import Kingfisher

private class NormalPlayerBottomBar: UIView {
    let playedDurationLabel: UILabel = {
        let temp = UILabel()
        temp.textColor = UIColor.white
        temp.font = UIFont.systemFont(ofSize: 12)
        
        return temp
    }()
    
    let totalDurationLabel: UILabel = {
        let temp = UILabel()
        temp.textColor = UIColor.white
        temp.font = UIFont.systemFont(ofSize: 12)
        
        return temp
    }()
    
    let slider = BufferedSlider()
    
    let fullScreenButton: UIButton = {
        let temp = UIButton(type: .custom)
        temp.setImage(UIImage(named: "normal_player_enter_fullscreen"), for: .normal)
        temp.setImage(UIImage(named: "normal_player_exit_fullscreen"), for: .selected)
        
        return temp
    }()
    
    private(set) var totalDuration: TimeInterval = 0 {
        didSet {
            totalDurationLabel.text = string(of: totalDuration)
        }
    }
    private(set) var playedDuration: TimeInterval = 0 {
        didSet {
            playedDurationLabel.text = string(of: playedDuration)
            
            if totalDuration != 0 {
                slider.playedProgress = playedDuration / totalDuration
            }

        }
    }
    private(set) var bufferedDuration: TimeInterval = 0 {
        didSet {
            if totalDuration != 0 {
                slider.bufferedProgress = bufferedDuration / totalDuration                
            }
        }
    }
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(playedDurationLabel)
        addSubview(totalDurationLabel)
        addSubview(slider)
        addSubview(fullScreenButton)
        
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        playedDurationLabel.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
        
        slider.snp.makeConstraints { (make) in
            make.top.bottom.equalToSuperview()
            make.left.equalTo(playedDurationLabel.snp.right).offset(8)
            make.right.equalTo(totalDurationLabel.snp.left).offset(-8)
        }
        
        fullScreenButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(36)
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        
        totalDurationLabel.snp.makeConstraints { (make) in
            make.right.equalTo(fullScreenButton.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func string(of time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func configure(totalDuration: TimeInterval) {
        self.totalDuration = totalDuration
    }
    
    func configure(playedDuration: TimeInterval) {
        self.playedDuration = playedDuration
    }
    
    func configure(bufferedDuration: TimeInterval) {
        self.bufferedDuration = bufferedDuration
    }
}
class NormalPlayerControlView: UIView {
    var didTouchToPlayHandler: (() -> Void)?
    var didTouchToPauseHandler: (() -> Void)?
    var didTouchWillSeekHandler: (() -> Void)?
    var didTouchToSeekHandler: ((TimeInterval) -> Void)?
    var didTouchToEnterFullScreenHandler: (() -> Void)?
    var didTouchToExitFullScreenHandler: (() -> Void)?
    
    private let bottomBar = NormalPlayerBottomBar()
    
    let coverImageView: UIImageView = {
        let temp = UIImageView()
        temp.contentMode = .scaleAspectFit
        
        return temp
    }()
    
    private let playButton: UIButton = {
        let temp = UIButton(type: .custom)
        temp.setImage(UIImage(named: "normal_player_play"), for: .normal)
        temp.setImage(UIImage(named: "normal_player_pause"), for: .selected)
        
        return temp
    }()
    
    private let indicatorView: UIActivityIndicatorView = {
        let temp = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.large)
        temp.color = UIColor.white
        temp.hidesWhenStopped = true
        
        return temp
    }()
    
    private var isStartedPlayingThrough = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(coverImageView)
        addSubview(bottomBar)
        addSubview(indicatorView)
        addSubview(playButton)
        
        coverImageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        bottomBar.snp.makeConstraints { (make) in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        
        indicatorView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        playButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(40)
            make.center.equalToSuperview()
        }
        
        configure(totalDuration: 0)
        configure(playedDuration: 0)
        
        playButton.addTarget(self, action: #selector(onTouch(playButton:)), for: .touchUpInside)
        
        bottomBar.slider.addTarget(self, action: #selector(onTouchDown(slider:)), for: .touchDown)
        bottomBar.slider.addTarget(self, action: #selector(onTouchUp(slider:)), for: .touchUpInside)
        bottomBar.slider.addTarget(self, action: #selector(onTouchUp(slider:)), for: .touchUpOutside)
        bottomBar.fullScreenButton.addTarget(self, action: #selector(onTouch(fullScreenButton:)), for: .touchUpInside)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTouchBackground(tap:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension NormalPlayerControlView {
    @objc private func onTouch(playButton: UIButton) {
        if playButton.isSelected {
            didTouchToPauseHandler?()
        } else {
            didTouchToPlayHandler?()
        }
    }
    
    @objc private func onTouchDown(slider: BufferedSlider) {
        didTouchWillSeekHandler?()
    }
    
    @objc private func onTouchUp(slider: BufferedSlider) {
        if bottomBar.totalDuration == 0 {
            return
        }
        didTouchToSeekHandler?(slider.playedProgress * bottomBar.totalDuration)
    }
    
    @objc private func onTouchBackground(tap: UITapGestureRecognizer) {
        bottomBar.isHidden = !bottomBar.isHidden
        if !indicatorView.isAnimating {
            playButton.isHidden = bottomBar.isHidden            
        }
    }
    
    @objc private func onTouch(fullScreenButton: UIButton) {
        fullScreenButton.isSelected = !fullScreenButton.isSelected
        
        if fullScreenButton.isSelected {
            didTouchToEnterFullScreenHandler?()
        } else {
            didTouchToExitFullScreenHandler?()
        }
    }
}

extension NormalPlayerControlView {
    func configure(cover url: URL?, placeholder: UIImage?) {
        coverImageView.kf.setImage(with: url, placeholder: placeholder)
    }
    func configure(totalDuration: TimeInterval) {
        bottomBar.configure(totalDuration: totalDuration)
    }
    func configure(playedDuration: TimeInterval) {
        bottomBar.configure(playedDuration: playedDuration)
    }
    func configure(bufferedDuration: TimeInterval) {
        bottomBar.configure(bufferedDuration: bufferedDuration)
    }
    
    func configure(with status: Player.Status) {
        var isPlayable = false      // 是否可播放
        var isBuffering = false     // 是否加载中，决定显示playButton还是indicator
        var isPlaying = false       // 是否正在播放
        
        switch status {
        case .initial:
            isPlayable = false
        case .prepared:
            isPlayable = true
            
            self.isStartedPlayingThrough = false
        case .buffering:
            isPlayable = true
            isBuffering = true
        case .paused:
            isPlayable = true
        case .playing:
            isPlayable = true
            isPlaying = true
            
            self.isStartedPlayingThrough = true
        case .end:
            isPlayable = true
        case .failed:
            isPlayable = false
        }
        
        if isStartedPlayingThrough {
            coverImageView.isHidden = true
        } else {
            coverImageView.isHidden = false
        }
        
        if isPlayable {
            if isBuffering {
                playButton.isHidden = true
                indicatorView.startAnimating()
            } else {
                playButton.isHidden = false
                indicatorView.stopAnimating()
                if isPlaying {
                    playButton.isSelected = true
                } else {
                    playButton.isSelected = false
                }
            }
        } else {
            playButton.isHidden = true
        }
    }
}
