//
//  VideoEditorController.swift
//  AnyImageKit
//
//  Created by 蒋惠 on 2019/12/18.
//  Copyright © 2019 AnyImageProject.org. All rights reserved.
//

import UIKit
import Photos

protocol VideoEditorControllerDelegate: class {
    
    func videoEditorDidCancel(_ editor: VideoEditorController)
    func videoEditor(_ editor: VideoEditorController, didFinishEditing video: URL, isEdited: Bool)
}

final class VideoEditorController: UIViewController {
    
    private let resource: VideoResource
    private let placeholdImage: UIImage?
    private let config: ImageEditorController.VideoConfig
    private weak var delegate: VideoEditorControllerDelegate?
    
    private var url: URL?
    private var didAddPlayerObserver = false
    
    private lazy var videoPreview: VideoPreview = {
        let view = VideoPreview(frame: .zero, image: placeholdImage)
        return view
    }()
    private lazy var toolView: VideoEditorToolView = {
        let view = VideoEditorToolView(frame: .zero, config: config)
        view.cancelButton.addTarget(self, action: #selector(cancelButtonTapped(_:)), for: .touchUpInside)
        view.doneButton.addTarget(self, action: #selector(doneButtonTapped(_:)), for: .touchUpInside)
        view.cropButton.addTarget(self, action: #selector(cropButtonTapped(_:)), for: .touchUpInside)
        return view
    }()
    private lazy var cropToolView: VideoEditorCropToolView = {
        let view = VideoEditorCropToolView(frame: .zero, config: config)
        view.delegate = self
        view.layer.cornerRadius = 5
        view.backgroundColor = UIColor.color(hex: 0x1F1E1F)
        return view
    }()
    
    init(resource: VideoResource, placeholdImage: UIImage?, config: ImageEditorController.VideoConfig, delegate: VideoEditorControllerDelegate) {
        self.resource = resource
        self.placeholdImage = placeholdImage
        self.config = config
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadData()
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    private func setupView() {
        view.backgroundColor = .black
        view.addSubview(videoPreview)
        view.addSubview(toolView)
        view.addSubview(cropToolView)
        
        videoPreview.snp.makeConstraints { (maker) in
            if #available(iOS 11, *) {
                maker.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(44)
            } else {
                maker.top.equalToSuperview()
            }
            maker.left.right.equalToSuperview()
            maker.bottom.equalTo(cropToolView.snp.top).offset(-30)
        }
        toolView.snp.makeConstraints { (maker) in
            if #available(iOS 11, *) {
                maker.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            } else {
                maker.bottom.equalToSuperview()
            }
            maker.left.right.equalToSuperview().inset(15)
            maker.height.equalTo(45)
        }
        cropToolView.snp.makeConstraints { (maker) in
            maker.left.right.equalToSuperview().inset(15)
            maker.bottom.equalTo(toolView.snp.top).offset(-30)
            maker.height.equalTo(50)
        }
    }
    
    private func loadData() {
        resource.loadURL { (result) in
            switch result {
            case .success(let url):
                hideHUD()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.url = url
                    self.videoPreview.setupPlayer(url: url)
                    self.setupProgressImage(url)
                }
            case .failure(let error):
                if error == .cannotFindInLocal {
                    showWaitHUD()
                } else {
                    hideHUD()
                }
                // TODO:
                _print(error)
            }
        }
    }
}

// MARK: - Target
extension VideoEditorController {
    
    @objc private func cancelButtonTapped(_ sender: UIButton) {
        delegate?.videoEditorDidCancel(self)
    }
    
    @objc private func doneButtonTapped(_ sender: UIButton) {
        guard let url = url else { return }
        let start = cropToolView.progressView.left
        let end = cropToolView.progressView.right
        let isEdited = end - start != 1
        captureVideo(url: url, start: start, end: end) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let url):
                _print("Export video at \(url)")
                self.delegate?.videoEditor(self, didFinishEditing: url, isEdited: isEdited)
            case .failure(let error):
                _print(error.localizedDescription)
            }
        }
    }
    
    @objc private func cropButtonTapped(_ sender: UIButton) {
        
    }
}

// MARK: - VideoPreviewDelegate
extension VideoEditorController: VideoPreviewDelegate {
    
    func previewPlayerDidPlayToEndTime(_ view: VideoPreview) {
        cropToolView.playButton.isSelected = view.isPlaying
    }
}

// MARK: - VideoEditorCropToolViewDelegate
extension VideoEditorController: VideoEditorCropToolViewDelegate {
    
    func cropTool(_ view: VideoEditorCropToolView, playButtonTapped button: UIButton) {
        videoPreview.playOrPause()
        button.isSelected = videoPreview.isPlaying
        addPlayerObserver()
    }
    
    func cropTool(_ view: VideoEditorCropToolView, didUpdate progress: CGFloat) {
        if videoPreview.isPlaying {
            videoPreview.playOrPause()
            view.playButton.isSelected = videoPreview.isPlaying
        }
        videoPreview.setProgress(progress)
    }
    
    func cropToolDurationOfVideo(_ view: VideoEditorCropToolView) -> CGFloat {
        return CGFloat(videoPreview.player?.currentItem?.duration.seconds ?? 0)
    }
}

// MARK: - Private
extension VideoEditorController {
    
    /// 设置缩略图
    private func setupProgressImage(_ url: URL) {
        // TODO: 没有占位图取第一帧
        let margin: CGFloat = 15 * 2.0
        let playButtonWidth: CGFloat = 45 + 2
        let progressButtonWidth: CGFloat = 20 * 2.0
        let imageSize = placeholdImage!.size
        let itemSize = CGSize(width: imageSize.width * 40 / imageSize.height, height: 40)
        let progressWidth = view.bounds.width - margin - playButtonWidth - progressButtonWidth
        let count = Int(round(progressWidth / itemSize.width))
        
        cropToolView.progressView.setupProgressImages(count, image: placeholdImage)
        getVideoThumbnailImage(url: url, count: count) { (idx, image) in
            let scale = UIScreen.main.scale
            let resizedImage = UIImage.resize(from: image, limitSize: CGSize(width: itemSize.width * scale, height: itemSize.height * scale), isExact: true)
            DispatchQueue.main.async { [weak self] in
                self?.cropToolView.progressView.setProgressImage(resizedImage, idx: idx)
            }
        }
    }
    
    /// 获取缩略图
    private func getVideoThumbnailImage(url: URL, count: Int, completion: @escaping (Int, UIImage) -> Void) {
        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceAfter = .zero
            generator.requestedTimeToleranceBefore = .zero
            let seconds = asset.duration.seconds
            let array = (0..<count).map{ NSValue(time: CMTime(seconds: Double($0)*(seconds/Double(count)), preferredTimescale: 1000)) }
            var i = 0
            generator.generateCGImagesAsynchronously(forTimes: array) { (requestedTime, cgImage, actualTime, result, error) in
                i += 1
                if let image = cgImage, result == .succeeded {
                    completion(i, UIImage(cgImage: image))
                }
            }
        }
    }
    
    /// 监听播放过程，实时更新进度条
    private func addPlayerObserver() {
        if videoPreview.player != nil && !didAddPlayerObserver {
            didAddPlayerObserver = true
            videoPreview.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: nil, using: { [weak self] (time) in
                guard let self = self else { return }
                guard self.videoPreview.isPlaying else { return }
                guard let current = self.videoPreview.player?.currentItem?.currentTime() else { return }
                guard let totle = self.videoPreview.player?.currentItem?.duration else { return }
                let progress = CGFloat(current.seconds / totle.seconds)
                let progressView = self.cropToolView.progressView
                self.cropToolView.progressView.setProgress(progress)
                if progress >= progressView.right {
                    self.videoPreview.player?.pause()
                    self.cropToolView.playButton.isSelected = self.videoPreview.isPlaying
                    self.cropToolView.progressView.setProgress(self.cropToolView.progressView.left)
                    self.videoPreview.setProgress(self.cropToolView.progressView.left)
                }
            })
        }
    }

    private func captureVideo(url: URL, start: CGFloat, end: CGFloat, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let duration = videoPreview.player?.currentItem?.duration else { return }
        let asset = AVURLAsset(url: url)
        let startTime = CMTime(seconds: duration.seconds * Double(start), preferredTimescale: duration.timescale)
        let captureDuration = CMTime(seconds: duration.seconds * Double(end - start), preferredTimescale: duration.timescale)
        let timeRange = CMTimeRange(start: startTime, duration: captureDuration)
        
        let composition = AVMutableComposition()
        let videoComposition = addVideoComposition(composition, timeRange: timeRange, asset: asset)
        addAudioComposition(composition, timeRange: timeRange, asset: asset)
        exportVideo(composition, videoComposition: videoComposition, metadata: asset.metadata, completion: completion)
    }
    
    private func addVideoComposition(_ composition: AVMutableComposition, timeRange: CMTimeRange, asset: AVURLAsset) -> AVVideoComposition? {
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        do {
            try compositionTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
        } catch {
            _print(error)
            return nil
        }
        compositionTrack.preferredTransform = assetVideoTrack.preferredTransform
        
        let videolayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        videolayerInstruction.setOpacity(0.0, at: asset.duration)
        
        let videoCompositionInstrution = AVMutableVideoCompositionInstruction()
        videoCompositionInstrution.timeRange = CMTimeRange(start: .zero, duration: compositionTrack.asset!.duration)
        videoCompositionInstrution.layerInstructions = [videolayerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = compositionTrack.naturalSize
        videoComposition.frameDuration = CMTime(seconds: 1, preferredTimescale: 30)
        videoComposition.instructions = [videoCompositionInstrution]
        return videoComposition
    }
    
    private func addAudioComposition(_ composition: AVMutableComposition, timeRange: CMTimeRange, asset: AVURLAsset) {
        let audioAssetTracks = asset.tracks(withMediaType: .audio)
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        for track in audioAssetTracks {
            do {
                try audioTrack.insertTimeRange(timeRange, of: track, at: .zero)
            } catch {
                _print(error)
            }
        }
    }
    
    private func exportVideo(_ composition: AVMutableComposition, videoComposition: AVVideoComposition?, metadata: [AVMetadataItem], completion: @escaping (Result<URL, Error>) -> Void) {
        let outputRoot = CacheModule.editor(.videoOutput).path
        let uuid = UUID().uuidString
        let outputURL = URL(fileURLWithPath: outputRoot + "\(uuid).mp4")
        FileHelper.createDirectory(at: outputRoot)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else { return }
        exportSession.metadata = metadata
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        if videoComposition != nil {
            exportSession.videoComposition = videoComposition
        }
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                if let error = exportSession.error {
                    completion(.failure(error))
                } else {
                    completion(.success(outputURL))
                }
            }
        }
    }
}
