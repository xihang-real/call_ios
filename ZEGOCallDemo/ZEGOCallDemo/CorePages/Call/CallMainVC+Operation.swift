//
//  CallMainVC+Operation.swift
//  ZEGOCallDemo
//
//  Created by zego on 2022/1/14.
//

import Foundation
import ZegoExpressEngine

extension CallMainVC: CallActionDelegate {
    func callhandUp(_ callView: CallBaseView) {
        if let userID = self.callUser?.userID {
            if self.statusType == .calling {
                RoomManager.shared.userService.endCall() { result in
                    switch result {
                    case .success():
                        CallBusiness.shared.audioPlayer?.stop()
                        CallBusiness.shared.currentCallStatus = .free
                        self.changeCallStatusText(.completed)
                        let deviceID: String = UIDevice.current.identifierForVendor!.uuidString
                        if let uuid = UUID(uuidString: deviceID) {
                            self.appDelegate.providerDelegate?.endCall(uuids: [uuid], completion: { uuid in
                                
                            })
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.dismiss(animated: true, completion: nil)
                        }
                    case .failure(let error):
                        let message = String(format: ZGLocalizedString("end_call_failed"), error.code)
                        TipView.showWarn(message)
                    }
                }
            } else {
                cancelCall(userID, callType: self.vcType)
            }
        }
    }
    
    func cancelCall(_ userID: String, callType: CallType, isTimeout: Bool = false) {
        var cancelType: CancelType = .intent
        if isTimeout { cancelType = .timeout}
        RoomManager.shared.userService.cancelCallToUser(userID: userID, responeType: cancelType) { result in
            switch result {
            case .success():
                CallBusiness.shared.audioPlayer?.stop()
                CallBusiness.shared.currentCallStatus = .free
                if isTimeout {
                    self.changeCallStatusText(.miss)
                } else {
                    self.changeCallStatusText(.canceled)
                }
                self.callDelayDismiss()
            case .failure(let error):
                let message = String(format: ZGLocalizedString("cancel_call_failed"), error.code)
                TipView.showWarn(message)
            }
        }
    }
    
    func callAccept(_ callView: CallBaseView) {
        updateCallType(self.vcType, userInfo: self.callUser ?? UserInfo(), status: .calling)
        if let userID = self.callUser?.userID {
            let rtcToken = AppToken.getRtcToken(withRoomID: userID)
            guard let rtcToken = rtcToken else { return }
            RoomManager.shared.userService.responseCall(userID, token:rtcToken, responseType: .accept) { result in
                if result.isSuccess {
                    CallBusiness.shared.audioPlayer?.stop()
                    CallBusiness.shared.currentCallStatus = .calling
                    ZegoExpressEngine.shared().useFrontCamera(true)
                    self.startPlayingStream(userID)
                }
            }
        }
    }
    
    func startPlayingStream(_ userID: String) {
        if let userRoomInfo = RoomManager.shared.userService.localUserRoomInfo {
            if vcType == .audio {
                RoomManager.shared.userService.micOperation(userRoomInfo.mic, callback: nil)
                guard let callUser = callUser else { return }
                startPlaying(callUser.userID, streamView: nil, type: .audio)
            } else {
                RoomManager.shared.userService.micOperation(userRoomInfo.mic, callback: nil)
                RoomManager.shared.userService.cameraOpen(userRoomInfo.camera, callback: nil)
                if let mainStreamID = mainStreamUserID {
                    startPlaying(mainStreamID, streamView: mainPreviewView, type: .video)
                } else {
                    startPlaying(RoomManager.shared.userService.localUserInfo?.userID, streamView: mainPreviewView, type: .video)
                }
                if let streamID = streamUserID {
                    startPlaying(streamID, streamView: previewView, type: .video)
                } else {
                    startPlaying(userID, streamView: previewView, type: .video)
                }
            }
            RoomManager.shared.userService.enableSpeaker(RoomManager.shared.userService.localUserRoomInfo?.voice ?? true)
        }
    }
    
    func callDecline(_ callView: CallBaseView) {
        if let userID = self.callUser?.userID {
            let rtcToken = AppToken.getRtcToken(withRoomID: userID)
            guard let rtcToken = rtcToken else { return }
            RoomManager.shared.userService.responseCall(userID, token: rtcToken ,responseType: .reject) { result in
                if result.isSuccess {
                    CallBusiness.shared.audioPlayer?.stop()
                    CallBusiness.shared.currentCallStatus = .free
                    self.changeCallStatusText(.decline)
                    self.callDelayDismiss()
                }
            }
        }
    }
    
    func callOpenMic(_ callView: CallBaseView, isOpen: Bool) {
        
        RoomManager.shared.userService.micOperation(isOpen, callback: nil)
    }
    
    func callOpenVoice(_ callView: CallBaseView, isOpen: Bool) {
        RoomManager.shared.userService.enableSpeaker(isOpen)
    }
    
    func callOpenVideo(_ callView: CallBaseView, isOpen: Bool) {
        RoomManager.shared.userService.cameraOpen(isOpen, callback: nil)
    }
    
    func callFlipCamera(_ callView: CallBaseView) {
        self.useFrontCamera = !self.useFrontCamera
        RoomManager.shared.userService.useFrontCamera(self.useFrontCamera)
    }
    
    func callDelayDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
