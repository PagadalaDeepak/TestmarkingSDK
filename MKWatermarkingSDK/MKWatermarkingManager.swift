//
//  MKWatermarkingManager.swift
//  MKWatermarkingSDK
//
//  Created by Deepak Pagadala on 26/04/23.
//

import Foundation
import BitmovinPlayer
import AVFoundation
import AVKit
import MKPlayer
import asid_ott_sdk
import SwiftUI


public class MKWatermarkingManager: NSObject {
    private var mkPlayer: MKPlayer
    private let asidController = ASiDController()
    private let config = ASiDConfig()
    internal var playerView = UIView()
    private var playerBounds = CGRect()
    private var activeOverlays: [Int32: UIImageView] = [:]
    private var asidStarted = false
    private var isViewChanged: Bool = false
    private var isLiveEvent: Bool = false
    private var isTerminatePlaybackOnSecurityTampering: Bool = false
    
    /**
     * Initializer for this instance of MKWatermarkingManager.
     */
    public init(mkPlayer: MKPlayer) {
        print("MKWatermarkingManager: init completed")
        self.mkPlayer = mkPlayer
        super.init()
        self.mkPlayer.addEvent(listener: self) // subscribe to Player events
#if os(iOS)
        // Register notification to observe device orientation changes
        NotificationCenter.default.addObserver(self, selector: #selector(didDeviceOrientationChanged), name:  UIDevice.orientationDidChangeNotification, object: nil)
#endif
    }
    
    /**
     * This function is used to set the configuration for FMTS SDK.
     */
    internal func setConfig(initToken: String , assetTitle: String, isLivent:Bool, playerView: UIView, isTerminatePlaybackOnSecurityTampering: Bool) {
        print("MKWatermarkingManager: setConfig called with initToken- \(initToken), isLive -\(isLivent), assetTitle -\(assetTitle)")

        self.isLiveEvent = isLivent
        self.playerView = playerView
        self.isTerminatePlaybackOnSecurityTampering = isTerminatePlaybackOnSecurityTampering
        config.initialisationToken = initToken
        config.assetTitle = assetTitle
        setUpASiD()
    }
    
    /**
     *  Register all callbacks from FMTS sdk.
     */
    private func setUpASiD() {
        print("MKWatermarkingManager: setUpASiD invoked")
        asidController.setVideoSizeCallback() {
            // Video size provided as CGSize
            if self.isViewChanged {
                return self.playerBounds.size
            } else {
                return self.playerView.bounds.size
            }
        }

        asidController.setTamperCallback() { (lastIssueType) in

            if lastIssueType == ASiDSecurityIssue.imageHashInvalid.rawValue {
                self.sendError(code: MKPWaterMarkingError.ErrorModule.imageHashInvalid.rawValue, message:lastIssueType.description)
            } else if lastIssueType == ASiDSecurityIssue.signatureInvalid.rawValue {
                self.sendError(code: MKPWaterMarkingError.ErrorModule.signatureInvalid.rawValue, message:lastIssueType.description)
            } else if lastIssueType == ASiDSecurityIssue.terminateRequested.rawValue {
                self.sendError(code: MKPWaterMarkingError.ErrorModule.terminateRequested.rawValue, message:lastIssueType.description)
            } else {
                MKPLog.e("Something was wrong in FMTS SDK\(lastIssueType.description)")
            }
        }

        asidController.setTerminateCallback() { () in
            MKPLog.e("Termination for user requested")
            if self.asidStarted  {
                self.asidController.terminateExistingSession()
                self.asidStarted = false
            }
        }

        asidController.setDecryptionHandler { (initToken) in
            var decodedInitToken = String()
            if let decodedData = Data(base64Encoded: initToken ?? String()) {
                decodedInitToken = String(data: decodedData, encoding: .utf8) ?? String()
            }
            return decodedInitToken
        }

        asidController.setOverlayCallback() { (show, scheduleId, imageData, imageDataLength, visibilityRatio) in
            if !show {
                MKPLog.d("Hiding overlay\(scheduleId)")
                DispatchQueue.main.async {
                    self.activeOverlays[scheduleId]?.removeFromSuperview()
                }
            } else {
                MKPLog.d("Showing overlay \(scheduleId) of size \(imageDataLength) bytes")
                if let bytes = imageData {
                    DispatchQueue.main.async {
                        let data = Data.init(bytes:bytes, count:imageDataLength)
                        let overlayImage = UIImage(data: data)
                        let imageView = UIImageView(image: overlayImage)
                        self.displayOverlay(scheduleId: scheduleId, imageView: imageView)
                    }
                }
            }
        }

        asidController.setConfig(config)
    }
    
    /**
     * This function is responsible for adding the waterMarking
     * overlay once the playback starts
     */
    private func displayOverlay(scheduleId: Int32, imageView: UIImageView) {
        print("MKWatermarkingManager: displayOverlay")
        // If we were already showing the existing schedule, remove the current overlay
        self.activeOverlays[scheduleId]?.removeFromSuperview()

        // Ensure overlay resizes correctly
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false

        imageView.frame = self.playerView.bounds
        self.playerView.addSubview(imageView)

        self.activeOverlays[scheduleId] = imageView
    }
    
    /**
     * Remove the all overlay once playback finished.
     */
    private func removeAlloverlays() {
        print("MKWatermarkingManager: removeAlloverlays")
        for (_, imageView) in self.activeOverlays {
            imageView.removeFromSuperview()
        }
        self.activeOverlays = [:]
    }
    
    /**
     * This function is used to update the waterMarking overlay once
     * change in view
     */
    internal func updateWaterMarkingImage(videoReact: CGRect) {
        print("MKWatermarkingManager: updateWaterMarkingImage")
        if asidStarted {
            // terminate the existing session and remove any active overlays
            asidController.terminateExistingSession()
            removeAlloverlays()
            asidStarted = false
        }
        self.isViewChanged = true
        self.playerBounds = videoReact
        setUpASiD()
        self.asidController.start()
        self.asidStarted = true
    }
    
    /**
     * This function used to print/send the error to App/Console.
     * if isTerminatePlaybackOnSecurityTampering is true , stoping the playback
     * and sending the error to app
     *
     * if isTerminatePlaybackOnSecurityTampering is false, printing the logs on console
     */
    private func sendError(code: String, message: String) {
        MKPLog.e("Received setTamperCallback error from FMTS SDK, error code:\(code) and messgae:\(message)")
    }
    
#if os(iOS)
    // When the device orientation changes, the FMTS SDK is notified to update the waterMarking image size.
    @objc func didDeviceOrientationChanged(notification: Notification) {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            updateWaterMarkingImage() //??
        case .portrait, .portraitUpsideDown:
            updateWaterMarkingImage() //??
        default:
            // Other orientation (such as face up & down)
            break
        }
    }
#endif
    
    private func updateWaterMarkingImage() {
        print("MKWatermarkingManager: updateWaterMarkingImage invoked")
        guard let layer = self.mkPlayer.layer as? AVPlayerLayer else  { //??

            MKPLog.e("Either watermarking is not enabled or bitmovin view is not ready.")
            return
        }
        self.updateWaterMarkingImage(videoReact: layer.videoRect)
    }
}

extension MKWatermarkingManager: MKPPlayerEventListener {
    
    public func onStartWatermarking(event: MKPStartWatermarkingEvent) {
        print("MKWatermarkingManager: onStartWatermarking invoked -\(event.asidInitToken)")
        self.setConfig(initToken: event.asidInitToken, assetTitle: event.mediaId, isLivent: event.isLiveEvent, playerView: event.playerView, isTerminatePlaybackOnSecurityTampering: self.isTerminatePlaybackOnSecurityTampering)
    }
    
    public func onReady(event: MKPReadyEvent) {
        print("MKWatermarkingManager: onReady")
        //Program manager does this.
        if let layer = self.mkPlayer.layer as? AVPlayerLayer { //??
            self.playerView.frame = layer.videoRect
        }
        if (!self.asidStarted) {
            self.asidController.start()
            self.asidStarted = true;
        }
    }
    
    /// :nodoc:
    public func onSourceUnloaded(event: MKPSourceUnloadedEvent) {
        print("MKWatermarkingManager: onSourceUnloaded")
        if ( self.asidStarted ) {
            self.asidController.terminateExistingSession();
            self.asidStarted = false;
        }
    }
    /// :nodoc:
    public func onTimeChanged(event: MKPTimeChangedEvent) {
        print("MKWatermarkingManager: onTimeChanged")
        var offset: Int = 0
        if self.mkPlayer.isLive == true {
            //Setting absolute value for both live and live event
            offset = Int(self.mkPlayer.currentTime * 1000)
            MKPLog.d("Setting waterMarking offset for Live:\(offset)")
        }
        asidController.setPlaybackPosition(offset)
    }
    
    /// :nodoc:
    public func onPaused(event: MKPPausedEvent) {
        print("MKWatermarkingManager: onPaused")
        if self.mkPlayer.isLive == true {
            asidController.setPlaybackPosition(Int(self.mkPlayer.currentTime * 1000))
        } else {
            asidController.setPlaybackPosition(0)
        }
    }

}


