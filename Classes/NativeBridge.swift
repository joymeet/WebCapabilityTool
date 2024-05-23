//
//  NativeBridge.swift
//  WebDemo
//
//  Created by LiShuilong on 2024/5/10.
//

import Foundation
import UIKit
import AdSupport
import AppTrackingTransparency
import FBSDKLoginKit
import AppsFlyerLib
import CoreLocation
import FBSDKLoginKit
import Alamofire
import Kingfisher
import AudioToolbox
import AVFoundation
import TZImagePickerController
import NIMSDK
import CommonCrypto
import MobileCoreServices
//import UniformTypeIdentifiers


typealias Callback = (Any)->Void
private let isDevice = TARGET_OS_SIMULATOR == 0

class NativeBridge:NSObject,TZImagePickerControllerDelegate, UIImagePickerControllerDelegate & UINavigationControllerDelegate ,NIMLoginManagerDelegate {
    
    ///需要禁用的log类型
    private var disableLogTypes = ["image","net","loadLocalFile"]//["image","net","localStorage","loadLocalFile"]
    
    private init(ctx: WCViewController? = nil) {
        self.ctx = ctx
    }
    
    
    public func md5(path:String) -> String {
        let data = NSData(contentsOfFile: path)! as Data
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    public func mimeType(path:String) -> String {
        let url = NSURL(fileURLWithPath: path)
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: url.pathExtension!)?.preferredMIMEType {
                return mimeType
            }
        } else {
            
            let pathExtension = url.pathExtension
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as! NSString, nil)?.takeRetainedValue() {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                    return mimetype as String
                }
            }
        }
        return "application/octet-stream"
    }
    
    private override init() {
        super.init()
        
    }
    
    static let shared = NativeBridge()
    
    private var ctx:WCViewController?;
    
    public func setCurrentCtx(currentViewController:WCViewController) {
        ctx = currentViewController;
        
        
        let option = NIMSDKOption(appKey: "424a76147467f73a24bd0e056d2b2214")
        NIMSDK.shared().register(with: option)
        NIMSDK.shared().loginManager.add(self)
        
    }
    
    func onLogin(_ step: NIMLoginStep) {
        print("onLogin \(step)")
    }
    
    func onAutoLoginFailed(_ error: any Error) {
        print("onAutoLoginFailed \(error.localizedDescription)")
    }
    
    ///UIImagePickerControllerDelegate
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        if let currentViewController = ctx {
            let dataMap = pickerCameraUuid!
            guard let uuid:String = dataMap["uuid"] as? String else { return }
            var data:String = (dataMap["data"] as? String) ?? ""
            data = NativeBridge.decodeBase64(data: data)
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,String>
            guard let type = params["type"] as? String else { return }
            let count = params["count"] ?? "1"
            let crop = params["crop"] ?? "0"
            pickerCameraUuid = nil
            
            picker.dismiss(animated: true) {
                if(!uuid.isEmpty) {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
                }
            }
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let currentViewController = ctx,let image = info[.originalImage] as? UIImage,let meta = info[.mediaMetadata] as? [AnyHashable : Any] {
            if(pickerCameraUuid != nil) {
                let dataMap = pickerCameraUuid!
                guard let uuid:String = dataMap["uuid"] as? String else { return }
                var data:String = (dataMap["data"] as? String) ?? ""
                data = NativeBridge.decodeBase64(data: data)
                let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,String>
                guard let type = params["type"] as? String else { return }
                let count = params["count"] ?? "1"
                let crop = params["crop"] ?? "0"
                pickerCameraUuid = nil
                
                if(crop == "1") {
                    TZImageManager.default().savePhoto(with: image, meta: meta , location: CLLocation()) { phAsset, error in
                        
                        let cropVc = TZImagePickerController(cropTypeWith: phAsset, photo: image) { img, asset in
                            DispatchQueue.main.async {
                                if let imageData = img!.jpegData(compressionQuality: 1.0) {
//                                    let base64Data = String(format: "data:image/jpg;base64,%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))
//                                    currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                                    
                                    if var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
                                        path = path + "/temp_camera.jpg"
                                        if(FileManager.default.fileExists(atPath: path)) {
                                            try? FileManager.default.removeItem(atPath: path)
                                        }
                                        let result = FileManager.default.createFile(atPath: path, contents: imageData as Data)
                                        currentViewController.jsBridgeToNative(uuid: uuid, data: path)
                                    }
                                }
                            }
                        }
                        if(crop == "1") {
                            let sw = UIScreen.main.bounds.width
                            let sh = UIScreen.main.bounds.width / 0.7
                            cropVc!.cropRect = CGRect(x: 0, y: (UIScreen.main.bounds.height - sh) / 2, width:sw , height:sh )
                        }
                        cropVc!.modalPresentationStyle = .fullScreen
                        picker.dismiss(animated: true) {
                            currentViewController.present(cropVc!, animated: true)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        if let imageData = image.jpegData(compressionQuality: 0.6) {
//                            let base64Data = String(format: "data:image/jpg;base64,%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))
//                            currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                            
                            if var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
                                path = path + "/temp_camera.jpg"
                                if(FileManager.default.fileExists(atPath: path)) {
                                    try? FileManager.default.removeItem(atPath: path)
                                }
                                let result = FileManager.default.createFile(atPath: path, contents: imageData as Data)
                                currentViewController.jsBridgeToNative(uuid: uuid, data: path)
                            }
                        }
                    }
                    picker.dismiss(animated: true) {
                        
                    }
                }
                
            }
        }
    }
    
    ///打印日志
    public func filterLog(tag:String,uuid:String,data:String) -> Void {
        let eventUuid = uuid.split(separator: "_").map{String($0)}.first
        if(!disableLogTypes.contains(eventUuid ?? "")) {
            print("\(tag)- uuid:\(uuid)\n data:\(data)")
        }
        
    }
    ///原请求参数 jsonStr
    var pickerCameraUuid:NSDictionary?;
    
    //设计原则 图片/视频/音频等在端上选择或者录制完成后，im上传至云信，app内则上传至后台。拿到url返回给web
    public func postMessage(jsonStr:String) {
        
        guard let currentViewController = ctx else { return }
        
        let dataMap = NativeBridge.stringToJson(jsonString: jsonStr)
        guard let uuid:String = dataMap["uuid"] as? String else { return }
        var data:String = (dataMap["data"] as? String) ?? ""
        
        if(!data.isEmpty) {
            data = NativeBridge.decodeBase64(data: data)
        }
        
        filterLog(tag:"postMessage",uuid: uuid, data: data)
        
        if(uuid.hasPrefix("log")) {
            print("log:\(data)")
        }
        else if(uuid.hasPrefix("FileUpload")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            //附带请求信息
            guard let type = params["type"] as? String,let path = params["path"] as? String,let request = params["request"] as? String else { return }
            print("上传图片 \(type) \(path)")
            print("\(request)")
            
            var tempRequest = NativeBridge.stringToJson(jsonString: request)
            net(params: tempRequest as! Dictionary<String, AnyObject>) { result in
                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: result as! Dictionary<String, Any>))
            }
            
        }
        else if(uuid.hasPrefix("NimUpload")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let type = params["type"] as? String,let path = params["path"] as? String else { return }
            guard let account = params["imAccount"] as? String,let token = params["imToken"] as? String else { return }
            
            //必须登录才能上传
            if(!NIMSDK.shared().loginManager.isLogined()) {
                NIMSDK.shared().loginManager.login(account, token: token) {[weak self] error in
                    print("login error:\(error?.localizedDescription)")
                    if(error == nil) {
                        //登录成功
                        //继续上传
                        DispatchQueue.main.async {
                            NativeBridge.shared.postMessage(jsonStr: jsonStr)
                        }
                    }
                }
            } else {
                
                //不需要设置info.scene
                let info = NIMResourceExtraInfo()
                info.mime = mimeType(path: path)
                info.md5 = md5(path: path)
                
                //获取文件信息
                var width:Int = 0
                var height:Int = 0
                if(type == "image" || type == "video") {
                    if let imageSource = CGImageSourceCreateWithURL(NSURL(fileURLWithPath: path) as CFURL, nil) {
                        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                            width = imageProperties[kCGImagePropertyPixelWidth] as! Int
                            height = imageProperties[kCGImagePropertyPixelHeight] as! Int
                            
                            print("the image width is: \(width)")
                            print("the image height is: \(height)")
                            
                        }
                    }
                }
                
                var attributes: [FileAttributeKey : Any]?
                var fileSize:UInt64 = 0
                do {
                    attributes = try FileManager.default.attributesOfItem(atPath: path)
                    fileSize = attributes?[.size] as? UInt64 ?? UInt64(0)
                    let fileSizeStr:String = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                    
                    print("the image size is: \(fileSizeStr) \(fileSize)")//351 KB 351067
                    
                } catch let error as NSError {
                    print("FileAttribute error: \(error)")
                }
                
                var resultMap:[String:String] = [
                    "mime":"\(info.mime!)",
                    "md5":"\(info.md5!)",
                    "size":"\(fileSize)",
                    "width":"\(width)",
                    "height":"\(height)",
                ]
                
                if(type == "video") {
                    let asset = AVAsset(url: NSURL(fileURLWithPath: path) as URL)
                    let duration = asset.duration//毫秒
                    let durationTime = CMTimeGetSeconds(duration)
                    resultMap["duration"] = "\(Int(durationTime*1000))"
                }
                
                if(type == "audio") {
                    let asset = AVAsset(url: NSURL(fileURLWithPath: path) as URL)
                    let duration = asset.duration//毫秒
                    let durationTime = CMTimeGetSeconds(duration)
                    resultMap["duration"] = "\(Int(durationTime*1000))"
                }
                
                //image/jpeg 69e65ecd426327db87b39525cabfd67f
                print("NIMSDK upload info:\(path) \(info.mime) \(info.md5)")
                
                NIMSDK.shared().resourceManager.upload(path, extraInfo: info, progress: {progress in
                    print("NIMSDK upload progress:\(progress)")
                }, completion: {url,error in
                    print("NIMSDK upload completion url:\(url) error:\(error)")
                    let error = error?.localizedDescription ?? ""
                    
                    resultMap["error"] = error
                    resultMap["url"] = "\(url!)"
                    DispatchQueue.main.async {
                        currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: resultMap))
                    }
                })
            }
        }
        else if(uuid.hasPrefix("getApplicationDirectory")) {
            //获取应用目录
            var resultPath:String = ""
            //默认获取
            //document
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                resultPath = path
            }
            if(data == "document") {
                
            }
            if(data == "cache") {
                //cache
                if let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
                    resultPath = path
                }
            }
            if(data == "tmp") {
                //tmp
                let path = NSTemporaryDirectory()
                resultPath = path
            }
            currentViewController.jsBridgeToNative(uuid: uuid, data: resultPath)
            
        }
        else if(uuid.hasPrefix("writeAsBytes")) {
            //写入文件
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let data = params["data"] as? String,let path = params["path"] as? String else { return }
            if let tempData = NSData(base64Encoded: data, options: .ignoreUnknownCharacters) {
                
                if(FileManager.default.fileExists(atPath: path)) {
                    try? FileManager.default.removeItem(atPath: path)
                }
                let result = FileManager.default.createFile(atPath: path, contents: tempData as Data)
                print("writeAsBytes result \(result) \(path)")
                currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
            } else {
                currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
            }
        }
        else if(uuid.hasPrefix("openAppSettings")) {
            UIApplication.shared.openURL(NSURL(string: UIApplication.openSettingsURLString) as! URL)
        }
        else if(uuid.hasPrefix("PermissionStatus")) {
            //获取权限状态0 未授权 1允许 2拒绝
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,String>
            guard let type = params["type"] as? String else { return }
            if(type == "camera") {
                let authStatus:AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                if(authStatus == .notDetermined) {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "notDetermined")
                } else if(authStatus == .authorized) {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "authorized")
                } else {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "denied")
                }
            } else if(type == "photo") {
                if (PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.notDetermined) {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "notDetermined")
                } else if (PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized) {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "authorized")
                } else {
                    if #available(iOS 14, *) {
                        if(PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.limited) {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: "limited")
                        } else {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: "denied")
                        }
                    } else {
                        currentViewController.jsBridgeToNative(uuid: uuid, data: "denied")
                    }
                }
            } else if (type == "location") {
                //"0" "1"
                JMLocationManager.shared.checkPermission { status in
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "\(status)" == "1" ? "authorized" : "denied")
                }
            }
        }
        else if(uuid.hasPrefix("PermissionRequest")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,String>
            guard let type = params["type"] as? String else { return }
            if(type == "camera") {
                let authStatus:AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                if(authStatus == .restricted || authStatus == .denied) {
                    //UIApplication.shared.openURL(NSURL(string: UIApplication.openSettingsURLString) as! URL)
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
                } else if (authStatus == .notDetermined) {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.main.async {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: granted ? "1" : "0")
                        }
                    }
                } else {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
                }
            } else if (type == "photo") {
                let authStatus = PHPhotoLibrary.authorizationStatus()
                if (authStatus == PHAuthorizationStatus.denied||authStatus == PHAuthorizationStatus.restricted) {
                    //已被拒绝，没有相册权限，将无法保存拍的照片
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
                } else if (PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.notDetermined) {
                    // 未请求过相册权限
                    TZImageManager.default().requestAuthorization {
                        let newAuthStatus = PHPhotoLibrary.authorizationStatus()
                        if #available(iOS 14, *) {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: (newAuthStatus == .authorized||newAuthStatus == .limited) ? "1" : "0")
                        } else {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: (newAuthStatus == .authorized) ? "1" : "0")
                        }
                    }
                } else {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
                }
            } else if (type == "location") {
                //"0" "1"
                JMLocationManager.shared.checkPermission { status in
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "\(status)")
                }
            }
        }
        else if(uuid.hasPrefix("pickerImage")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,String>
            guard let type = params["type"] as? String else { return }
            let count = params["count"] ?? "1"
            let crop = params["crop"] ?? "0"
            
            //选择图片 视频
            if(type == "photo") {
                let imagePickerVc = TZImagePickerController(maxImagesCount: Int(count) ?? 1, delegate: self)!
                imagePickerVc.showSelectBtn = false
                if(crop == "1") {
                    let sw = UIScreen.main.bounds.width
                    let sh = UIScreen.main.bounds.width / 0.7
                    imagePickerVc.cropRect = CGRect(x: 0, y: (UIScreen.main.bounds.height - sh) / 2, width:sw , height:sh )
                    imagePickerVc.allowCrop = true
                }
                imagePickerVc.allowPickingGif = false
                imagePickerVc.allowTakePicture = false
                imagePickerVc.didFinishPickingPhotosHandle = { photos,assets,isSelectOriginalPhoto in
                    if(photos?.count == 1) {
                        if let imageData = photos![0].jpegData(compressionQuality: 1.0) {
//                            let base64Data = String(format: "%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))//"data:image/jpg;base64,%@"
//                            currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                            
                            if var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
                                path = path + "/temp_photo.jpg"
                                if(FileManager.default.fileExists(atPath: path)) {
                                    try? FileManager.default.removeItem(atPath: path)
                                }
                                let result = FileManager.default.createFile(atPath: path, contents: imageData as Data)
                                currentViewController.jsBridgeToNative(uuid: uuid, data: path)
                            }
                            
                        }
                    }
                }
                imagePickerVc.modalPresentationStyle = .fullScreen
                currentViewController.present(imagePickerVc, animated: true)
            } else if(type == "imPhoto") {
                let imagePickerVc = TZImagePickerController(maxImagesCount: Int(count) ?? 1, delegate: self)!
                imagePickerVc.showSelectBtn = false
                imagePickerVc.allowPickingGif = false
                imagePickerVc.allowTakeVideo = false
                imagePickerVc.allowPickingVideo = true
                imagePickerVc.allowTakePicture = false
                //自定义UI
                var isDestruct = true
                imagePickerVc.photoPreviewPageUIConfigBlock = {collectionView, naviBar, backButton, selectButton, indexLabel, toolBar, originalPhotoButton, originalPhotoLabel, doneButton, numberImageView, numberLabel in
                    
                    originalPhotoLabel?.alpha = 0
                    originalPhotoButton?.alpha = 0
                    doneButton?.setTitle("Send", for: .normal)
                    doneButton?.setTitle("Send", for: .selected)
                    doneButton?.titleLabel?.font = UIFont.systemFont(ofSize: 12)
                    doneButton?.setTitleColor(UIColor.white, for: .normal)
                    doneButton?.setTitleColor(UIColor.white, for: .selected)
                    doneButton?.backgroundColor = UIColor(red: 0.959, green: 0.255, blue: 0.576, alpha: 1)
                    doneButton?.layer.cornerRadius = 18
                    doneButton?.contentEdgeInsets = UIEdgeInsets(top: 2, left: 24, bottom: 2, right: 24)
                    let sv = doneButton?.superview
                    if(sv != nil) {
                        let tipLabel = UILabel(frame: CGRect(x: 60, y: 8, width: 180, height: 30))
                        tipLabel.text = "SELF-DESTRUCT ON"//"SELF-DESTRUCT OFF"
                        tipLabel.font = UIFont.systemFont(ofSize: 15)
                        tipLabel.textColor = UIColor.white
                        tipLabel.tag = 1002
                        sv?.addSubview(tipLabel)
                        
                        let fireButton = UIBlockButton(type: .custom)
                        fireButton.frame = CGRect(x: 16, y: 5, width: 36, height: 36)
                        fireButton.setImage(UIImage(named: "ic_destructing_fire_open"), for: .selected)
                        fireButton.setImage(UIImage(named: "ic_destructing_fire_close"), for: .normal)
                        fireButton.isSelected = true
                        fireButton.tag = 1001
                        fireButton.handlecontrollEvent(event: .touchUpInside, action: {sender in
                            sender.isSelected = !sender.isSelected
                            isDestruct = sender.isSelected
                            tipLabel.text = sender.isSelected ? "SELF-DESTRUCT ON" : "SELF-DESTRUCT OFF"
                        })
                        sv?.addSubview(fireButton)
                    }
                    
                }
                imagePickerVc.photoPreviewPageDidLayoutSubviewsBlock = {collectionView, naviBar, backButton, selectButton, indexLabel, toolBar, originalPhotoButton, originalPhotoLabel, doneButton, numberImageView, numberLabel in
                    doneButton?.frame.origin.y = 5
                    doneButton?.frame.size.height = 36
                }
                imagePickerVc.videoPreviewPageUIConfigBlock = {playButton, toolBar, editBtn, doneButton in
                    
                    doneButton?.setTitle("Send", for: .normal)
                    doneButton?.setTitle("Send", for: .selected)
                    doneButton?.titleLabel?.font = UIFont.systemFont(ofSize: 12)
                    doneButton?.setTitleColor(UIColor.white, for: .normal)
                    doneButton?.setTitleColor(UIColor.white, for: .selected)
                    doneButton?.backgroundColor = UIColor(red: 0.959, green: 0.255, blue: 0.576, alpha: 1)
                    doneButton?.layer.cornerRadius = 18
                    doneButton?.contentEdgeInsets = UIEdgeInsets(top: 2, left: 24, bottom: 2, right: 24)
                    let sv = doneButton?.superview
                    if(sv != nil) {
                        let tipLabel = UILabel(frame: CGRect(x: 60, y: 8, width: 180, height: 30))
                        tipLabel.text = "SELF-DESTRUCT ON"//"SELF-DESTRUCT OFF"
                        tipLabel.font = UIFont.systemFont(ofSize: 15)
                        tipLabel.textColor = UIColor.white
                        tipLabel.tag = 1002
                        sv?.addSubview(tipLabel)
                        
                        let fireButton = UIBlockButton(type: .custom)
                        fireButton.frame = CGRect(x: 16, y: 5, width: 36, height: 36)
                        fireButton.setImage(UIImage(named: "ic_destructing_fire_open"), for: .selected)
                        fireButton.setImage(UIImage(named: "ic_destructing_fire_close"), for: .normal)
                        fireButton.isSelected = true
                        fireButton.tag = 1001
                        fireButton.handlecontrollEvent(event: .touchUpInside, action: {sender in
                            sender.isSelected = !sender.isSelected
                            isDestruct = sender.isSelected
                            tipLabel.text = sender.isSelected ? "SELF-DESTRUCT ON" : "SELF-DESTRUCT OFF"
                        })
                        sv?.addSubview(fireButton)
                    }
                    
                }
                imagePickerVc.videoPreviewPageDidLayoutSubviewsBlock = {playButton, toolBar, editButton, doneButton in
                    doneButton?.frame.origin.y = 5
                    doneButton?.frame.size.height = 36
                }
                imagePickerVc.didFinishPickingPhotosHandle = { photos,assets,isSelectOriginalPhoto in
                    //print("didFinishPickingPhotosHandle:\(photos?.count)")
                    if(photos?.count == 1) {
                        if let imageData = photos![0].jpegData(compressionQuality: 1.0) {
//                            let base64Data = String(format: "%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))//"data:image/jpg;base64,%@"
//                            currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                            
                            if var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
                                path = path + "/temp_photo.jpg"
                                if(FileManager.default.fileExists(atPath: path)) {
                                    try? FileManager.default.removeItem(atPath: path)
                                }
                                let result = FileManager.default.createFile(atPath: path, contents: imageData as Data)
                                
                                //获取基本信息 width height size duration
                                var width:Int = 0
                                var height:Int = 0
                                if let imageSource = CGImageSourceCreateWithURL(NSURL(fileURLWithPath: path) as CFURL, nil) {
                                    if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                                        width = imageProperties[kCGImagePropertyPixelWidth] as! Int
                                        height = imageProperties[kCGImagePropertyPixelHeight] as! Int
                                        
                                        print("the image width is: \(width)")
                                        print("the image height is: \(height)")
                                        
                                    }
                                }
                                
                                var attributes: [FileAttributeKey : Any]?
                                var fileSize:UInt64 = 0
                                do {
                                    attributes = try FileManager.default.attributesOfItem(atPath: path)
                                    fileSize = attributes?[.size] as? UInt64 ?? UInt64(0)
                                    let fileSizeStr:String = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                                    
                                    print("the image size is: \(fileSizeStr) \(fileSize)")//351 KB 351067
                                    
                                } catch let error as NSError {
                                    print("FileAttribute error: \(error)")
                                }
                                
                                //优化 返回压缩后的缩略图base64
                                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: ["path":"\(path)","isImage":"1","isDestruct":isDestruct ? "1" : "0","size":"\(fileSize)","width":"\(width)","height":"\(height)"]))
                            }
                            
                        }
                    }
                }
                imagePickerVc.didFinishPickingVideoHandle = { photos,assets in
                    TZImageManager.default().getVideoOutputPath(with: assets!, presetName: AVAssetExportPresetLowQuality) { outputPath in
                        print("视频导出到本地完成,沙盒路径为:%@",outputPath)
                        
                        //获取基本信息 width height size duration
                        var width:Int = 0
                        var height:Int = 0
                        
                        if let imageSource = CGImageSourceCreateWithURL(NSURL(fileURLWithPath: outputPath!) as CFURL, nil) {
                            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                                width = imageProperties[kCGImagePropertyPixelWidth] as! Int
                                height = imageProperties[kCGImagePropertyPixelHeight] as! Int
                                
                                print("the image width is: \(width)")
                                print("the image height is: \(height)")
                                
                            }
                        }
                        
                        var attributes: [FileAttributeKey : Any]?
                        var fileSize:UInt64 = 0
                        do {
                            attributes = try FileManager.default.attributesOfItem(atPath: outputPath!)
                            fileSize = attributes?[.size] as? UInt64 ?? UInt64(0)
                            let fileSizeStr:String = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                            
                            print("the image size is: \(fileSizeStr) \(fileSize)")//351 KB 351067
                            
                        } catch let error as NSError {
                            print("FileAttribute error: \(error)")
                        }
                        
                        let asset = AVAsset(url: NSURL(fileURLWithPath: outputPath!) as URL)
                        let duration = asset.duration//毫秒
                        let durationTime = CMTimeGetSeconds(duration)
                        
                        //优化 返回压缩后的缩略图base64
                        currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: ["path":"\(outputPath!)","isVideo":"1","isDestruct":isDestruct ? "1" : "0","size":"\(fileSize)","width":"\(width)","height":"\(height)","duration":"\(Int(durationTime*1000))"]))
                    } failure: { errorMessage, error in
                        print("视频导出失败:%@,error:%@",errorMessage,error)
                    }

                }
                imagePickerVc.modalPresentationStyle = .fullScreen
                currentViewController.present(imagePickerVc, animated: true)
            } else if (type == "camera") {
                
                let imagePickerVc = UIImagePickerController()
                imagePickerVc.delegate = self
                
                if(UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera)) {
                    imagePickerVc.sourceType = UIImagePickerController.SourceType.camera;
                }
                imagePickerVc.modalPresentationStyle = .fullScreen
                currentViewController.present(imagePickerVc, animated: true)
                
                pickerCameraUuid = dataMap
            }
        }
        else if(uuid.hasPrefix("loadLocalFile")) {
            //读取本地文件
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let type = params["type"] as? String,let path = params["path"] as? String else { return }
            
            if(type == "image") {
                DispatchQueue.main.async {
                    if let imageData = NSData(contentsOfFile: path) {
                        let base64Data = String(format: "%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))//"data:image/jpg;base64,%@"
                        
                        //print("loadLocalFile length:\(base64Data.count)")
                        currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                    }
                }
            }
            else if(type == "video") {
                DispatchQueue.main.async {
                    if let imageData = NSData(contentsOfFile: path) {
                        let base64Data = String(format: "%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))//"data:video/mp4;base64,%@"
                        
                        print("loadLocalFile length:\(base64Data.count)")
                        currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                    }
                }
            } else {
                if(!path.isEmpty) {
                    //file
                    DispatchQueue.main.async {
                        if let imageData = NSData(contentsOfFile: path) {
                            let base64Data = String(format: "%@", imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters))
                            
                            print("loadLocalFile length:\(base64Data.count)")
                            currentViewController.jsBridgeToNative(uuid: uuid, data: base64Data)
                        }
                    }
                } else {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
                }
            }
        }
        else if(uuid.hasPrefix("localStorage")) {
            //UserDefaults
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,String>
            guard let type = params["type"], let key = params["key"] else { return }
            let value = (params["value"]) ?? ""
            if(type == "save") {
                UserDefaults.standard.set("\(value)", forKey: key)
                currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
            }
            if(type == "remove") {
                UserDefaults.standard.removeObject(forKey: key)
                currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
            }
            if(type == "get") {
                
                let temp = UserDefaults.standard.string(forKey: key) ?? ""
                
                //print("localStorage get k:\(key) v:\(temp)")
                
                currentViewController.jsBridgeToNative(uuid: uuid, data: "\(temp)")
            }
            UserDefaults.standard.synchronize()
        }
        else if(uuid.hasPrefix("mediaMetadataRetriever")) {
            //获取视频第一帧
            let path = URL.init(fileURLWithPath: data)
            let asset = AVURLAsset(url:path)
            let generate = AVAssetImageGenerator(asset:asset)
            generate.appliesPreferredTrackTransform = true
            if let oneRef = try? generate.copyCGImage(at: CMTimeMake(value: 1, timescale: 2), actualTime: nil) {
                let image:UIImage = UIImage(cgImage: oneRef)
                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: ["width":"\(image.size.width)","height":"\(image.size.height)"]))
            }
        }
        else if(uuid.hasPrefix("getIdfa")) {
            let idfa = ASIdentifierManager.shared().advertisingIdentifier
            currentViewController.jsBridgeToNative(uuid: uuid, data: "\(idfa)")
        }
        else if(uuid.hasPrefix("idfaPermission")) {
            if #available(iOS 14, *) {
                ATTrackingManager .requestTrackingAuthorization(completionHandler: { state in
                    switch state {
                    case .notDetermined:
                        NSLog("--申请tracking权限，用户为做选择或未弹窗")
                        break
                    case .authorized:
                        let idfa = ASIdentifierManager.shared().advertisingIdentifier
                        NSLog("--用户允许广告追踪 idfa:\(idfa)")
                        break
                    case .denied:
                        NSLog("--用户拒绝广告id")
                        break
                    case .restricted:
                        NSLog("--restricted")
                        break
                    @unknown default:
                        NSLog("--unknown")
                    }
                    
                    if(state == .authorized) {
                        DispatchQueue.main.async {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
                        }
                    } else {
                        DispatchQueue.main.async {
                            currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
                        }
                    }
                    
                })
            } else {
                if ASIdentifierManager.shared().isAdvertisingTrackingEnabled == true {
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier
                    NSLog("允许广告追踪 idfa:\(idfa)")
                    DispatchQueue.main.async {
                        currentViewController.jsBridgeToNative(uuid: uuid, data: "1")
                    }
                }else{
                    NSLog("用户限制了广告追踪")
                    DispatchQueue.main.async {
                        currentViewController.jsBridgeToNative(uuid: uuid, data: "0")
                    }
                }
            }
        }
        else if(uuid.hasPrefix("setIosPasteboard")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            if let str = params["str"] as? String,let appToken = params["appToken"] as? String {
                if(!appToken.isEmpty){
                    UIPasteboard.general.string = str
                    UIPasteboard.general.addItems([["public.utf8-plain-text" : appToken]])
                } else {
                    if(!str.isEmpty) {
                        UIPasteboard.general.string = str
                    }
                }
            }
        }
        else if(uuid.hasPrefix("getIosPasteboard")) {
            var str = ""
            if let tmp = UIPasteboard.general.string {
                print("getIosPasteboard-str \(tmp)")
                str = tmp
            }
            var appToken = ""
            
            for obj in UIPasteboard.general.items.reversed() {
                if let tmp = obj["public.utf8-plain-text"] as? String {
                    appToken = tmp
                    break
                }
            }
            
            //回传
            currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: ["str":str,"appToken":appToken]))
        }
        else if(uuid.hasPrefix("reviewAccountLogin")) {
            //打开A面
        }
        else if(uuid.hasPrefix("loadBundleResource")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            if let fileName = params["fileName"] as? String,let type = params["type"] as? String,let path = Bundle.main.path(forResource: fileName, ofType: type) as? String {
                
                if let data = NSDictionary(contentsOfFile: path) as? [String: Any] {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: data))
                } else {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: ["code":"1","message":"loadBndleResource decode error"]))
                }
            } else {
                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: ["code":"1","message":"loadBndleResource open error"]))
            }
        }
        else if(uuid.hasPrefix("getAppInfo")) {
            if !data.isEmpty {
                let tmp = self.getAppInfo(key: data)
                currentViewController.jsBridgeToNative(uuid: uuid, data: tmp)
            } else {
                let tmp = self.getAppInfo(key: nil)
                currentViewController.jsBridgeToNative(uuid: uuid, data: tmp)
            }
        }
        else if(uuid.hasPrefix("subscribeToTopic")) {
            let topic = data
            if(!data.isEmpty) {
                //                Messaging.messaging().subscribe(toTopic: topic) { error in
                //                    if(error != nil) {
                //                        NSLog("subscribeToTopic failed:\(error!.localizedDescription)")
                //                    } else {
                //                        NSLog("subscribeToTopic success")
                //                    }
                //                }
            }
        }
        else if(uuid.hasPrefix("unsubscribeFromTopic")) {
            let topic = data
            //            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            //             if(error != nil) {
            //                 NSLog("unsubscribeFromTopic failed:\(error!.localizedDescription)")
            //                } else {
            //                    NSLog("unsubscribeFromTopic success")
            //                }
            //            }
        }
        else if(uuid.hasPrefix("facebookLogEvent")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            facebookLogEvent(args: params)
        }
        else if(uuid.hasPrefix("appsFlyerLogEvent")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            appsFlyerLogEvent(args: params)
        }
        else if (uuid.hasPrefix("event")) {
            let channelParams = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let eventName = channelParams["name"] as? String else { return }
            
            var params:Dictionary<String,Any>? = nil
            if let tmp = channelParams["params"] as? Dictionary<String,Any> {
                params = tmp
            }
            
            //            if(eventName.count > 0) {
            //                if(eventName == "setUserProperty" && params != nil) {
            //                    guard let dic = params, let uuid = dic["uuid"] as? String else { return }
            //                    Analytics.setUserID(uuid)
            //                    dic.forEach { (key: String, value: Any) in
            //                        Analytics.setUserProperty(key, forName: (value as? String) ?? "")
            //                    }
            //                    print("Analytics.setUserProperty:\(uuid){\(dic)}")
            //                } else {
            //                    Analytics.logEvent(eventName, parameters: params)
            //                    print("Analytics.logEvent:\(eventName){\(String(describing: params))}")
            //                }
            //            }
        }
        else if(uuid.hasPrefix("facebookLogin")) {
            facebookLongin(completion: { value in
                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: value))
            })
        }
        //        else if(uuid.hasPrefix("googlePlay")) {
        //            //Android
        //        }
        //        else if(uuid.hasPrefix("payClicked")) {
        //            //Android
        //        }
        else if(uuid.hasPrefix("snapshot")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            var enable = false
            if((params["enable"] as! String) == "1") {
                enable = true
            }
            //self?.secureView.isSecureTextEntry = !enable
            //self?.secureBgView.isHidden = enable
        }
        else if(uuid.hasPrefix("iosIAP")) {
            let channelParams = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let productId = channelParams["productId"] as? String else { return }
            //iap(params: channelParams, result: result)
        }
        else if(uuid.hasPrefix("location")) {
            //请求定位
            DispatchQueue.main.async {
                JMLocationManager.shared.requestLocation { location in
                    var temp = Dictionary<String,Double>()
                    temp["longitude"] = location.coordinate.longitude
                    temp["latitude"] = location.coordinate.latitude
                    currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: temp))
                }
            }
        }
        else if(uuid.hasPrefix("badge")) {
            //iOS端设置appIcon角标
            let num = "\(data)"
            UIApplication.shared.applicationIconBadgeNumber = Int(num) ?? 0
        }
        else if(uuid.hasPrefix("net")) {
            let channelParams = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,AnyObject>
            //print("网络请求 \(channelParams["method"])")
            net(params: channelParams) { result in
                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: result as! Dictionary<String, Any>))
            }
        }
        else if(uuid.hasPrefix("setSpeakerphoneOn")) {
            //iOS端设置扬声器
            let channelParams = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let isSpeakerphoneOn = channelParams["isSpeakerphoneOn"] as? Bool else { return }
            if isSpeakerphoneOn {
                try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            } else {
                try?  AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
            }
        }
        else if(uuid.hasPrefix("revenuecatReceipt")) {
            NSLog("iap revenuecatReceipt")
            //TODO:未实现
        }
        else if(uuid.hasPrefix("getPlatformVersion")) {
            let systemVersion = UIDevice.current.systemVersion
            currentViewController.jsBridgeToNative(uuid: uuid, data: "iOS "+systemVersion)
        }
        else if(uuid.hasPrefix("image")) {
            //图片加载用web原生
            let channelParams = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,Any>
            guard let url = channelParams["url"] as? String else { return }
            self.loadImage(params: url) { result in
                DispatchQueue.main.async {
                    currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: result as! Dictionary<String, Any>))
                }
            }
        }
        else if(uuid.hasPrefix("getLocalTimezone")) {
            let timeZoneFormatter = DateFormatter()
            timeZoneFormatter.dateFormat = "ZZZZZ"
            //timeZoneFormatter.locale = Locale(identifier: "en_US")
            var timezoneStr = timeZoneFormatter.string(from: Date())
            if(timezoneStr == "Z") {
                timezoneStr = "+00:00"
            }
            NSLog("timezone:GMT%@",timezoneStr)
            currentViewController.jsBridgeToNative(uuid: uuid, data: String(format: "GMT%@", timezoneStr))
        }
        else if(uuid.hasPrefix("geocoder")) {
            guard let params = NativeBridge.stringToJson(jsonString: data) as? Dictionary<String,String> else { return }
            guard let lat = Double(params["lat"] ?? "0.0") ,let lon = Double(params["lon"] ?? "0.0") else { return  }
            self.getAddress(from: CLLocationCoordinate2D(latitude: lat, longitude: lon)) { result in
                currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: result as! Dictionary<String, Any>))
            }
        }
        else if(uuid.hasPrefix("openAppSettings")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,AnyObject>
            guard let category = params["category"] as? String else { return }
            if(category == "notification") {
                if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        
                    } else {
                        // Fallback on earlier versions
                        
                    }
                }
            }
        }
        else if(uuid.hasPrefix("notification")) {
            let params = NativeBridge.stringToJson(jsonString: data) as! Dictionary<String,AnyObject>
            guard let imagePath:String = params["imagePath"] as? String,
                  let title:String = params["title"] as? String,
                  let text:String = params["text"] as? String,
                  let badge:String = params["badge"] as? String
            else { return }
            
            UIApplication.shared.cancelAllLocalNotifications()
            
            var notification = UILocalNotification()
            //notification.fireDate = NSDate().dateByAddingTimeInterval(1)
            //setting timeZone as localTimeZone
            notification.timeZone = NSTimeZone.local
            notification.repeatInterval = NSCalendar.Unit.day
            notification.alertTitle = title
            notification.alertBody = text
            notification.alertLaunchImage = imagePath
            //notification.alertAction = "OK"
            notification.soundName = UILocalNotificationDefaultSoundName
            //setting app's icon badge
            notification.applicationIconBadgeNumber = Int(badge) ?? 0
            //notification.userInfo = ["kLocalNotificationID":"LocalNotificationID"]
            
            //                UIApplication.shared.scheduleLocalNotification(notification)
            UIApplication.shared.presentLocalNotificationNow(notification)
            //                UNUserNotificationCenter.current().add()
            
        }
        else if(uuid.hasPrefix("getDevicesInfo")) {
            let isEmulator = false
            
            let language:NSString = NSLocale.preferredLanguages[0] as NSString
            
            var languageCode = ""
            var countryCode = ""
            let tmpArrray:[String] = language.components(separatedBy: "-")
            if(tmpArrray.count > 0) {
                languageCode = tmpArrray[0]
            }
            if(tmpArrray.count > 1) {
                countryCode = tmpArrray[tmpArrray.count-1]
            }
            
            let tempMap = [
                "isEmulator":isEmulator,
                "language":languageCode,
                "country":countryCode,
                "languageDisplayScript":language,
                "timeZoneId":NSTimeZone.local.identifier,
                "timeZoneDisplayName":NSTimeZone.local.localizedName(for: NSTimeZone.NameStyle.generic, locale: Locale(identifier: "cn"))!.description,
            ] as [String : Any]
            
            currentViewController.jsBridgeToNative(uuid: uuid, data: NativeBridge.jsonToString(dictionary: tempMap))
        }
        else if(uuid.hasPrefix("vibrate")) {
            let type = data
            switch (type) {
            case "canVibrate":
                if isDevice {
                    //result(true)
                } else {
                    //result(false)
                }
            case "vibrate":
                //震动
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                //UINotificationFeedbackGenerator().notificationOccurred(UINotificationFeedbackGenerator.FeedbackType.error)
                // Feedback
            case "impact":
                if #available(iOS 10.0, *) {
                    let impact = UIImpactFeedbackGenerator()
                    impact.prepare()
                    impact.impactOccurred()
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "selection":
                if #available(iOS 10.0, *) {
                    let selection = UISelectionFeedbackGenerator()
                    selection.prepare()
                    selection.selectionChanged()
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "success":
                if #available(iOS 10.0, *) {
                    let notification = UINotificationFeedbackGenerator()
                    notification.prepare()
                    notification.notificationOccurred(.success)
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "warning":
                if #available(iOS 10.0, *) {
                    let notification = UINotificationFeedbackGenerator()
                    notification.prepare()
                    notification.notificationOccurred(.warning)
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "error":
                if #available(iOS 10.0, *) {
                    let notification = UINotificationFeedbackGenerator()
                    notification.prepare()
                    notification.notificationOccurred(.error)
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "heavy":
                if #available(iOS 10.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.prepare()
                    generator.impactOccurred()
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "medium":
                if #available(iOS 10.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            case "light":
                if #available(iOS 10.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                } else {
                    // Fallback on earlier versions
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            default:
                print("\(uuid):method not implemented")
                //result(FlutterMethodNotImplemented)
            }
            
        }
        
    }
    
    static func jsonToString(dictionary:Dictionary<String, Any>) -> String {
        if !JSONSerialization.isValidJSONObject(dictionary) {
            print("无法解析出JSONString")
            return ""
        }
        
        let data:Data = try! JSONSerialization.data(withJSONObject: dictionary)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    static func stringToJson(jsonString:String) -> NSDictionary {
        if let jsonData = jsonString.data(using: .utf8) {
            let dict = try? JSONSerialization.jsonObject(with: jsonData,options: .mutableContainers)
            if (dict != nil) {
                return dict as! NSDictionary
            }
        }
        return NSDictionary()
    }
    
    static func encodeBase64(data:String) -> String {
        guard let utf8EncodeData = data.data(using: String.Encoding.utf8, allowLossyConversion: true)
        else {return ""}
        let base64String = utf8EncodeData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: UInt(0)))
        return base64String as String
    }
    
    static func decodeBase64(data:String) -> String {
        guard let base64Data = NSData(base64Encoded:data, options:NSData.Base64DecodingOptions(rawValue: 0)),let dataDecode = NSString(data:base64Data as Data, encoding:String.Encoding.utf8.rawValue) else { return "" }
        return dataDecode as String
    }
    
    func facebookLongin(completion: @escaping (Dictionary<String,String>) -> Void) {
        
        if let token = AccessToken.current,
           !token.isExpired {
            var temp = Dictionary<String,String>()
            temp["accessToken"] = token.tokenString
            completion(temp)
        } else {
            //public_profile, email, user_hometown, user_birthday, user_age_range, user_gender, user_link, user_friends, user_location, user_likes, user_photos, user_videos, user_posts
            LoginManager().logIn(permissions: ["public_profile", "email",], from: ctx!) { result, error in
                if let token = result?.token {
                    var temp = Dictionary<String,String>()
                    temp["accessToken"] = token.tokenString
                    completion(temp)
                }
            }
        }
    }
    
    func appsFlyerLogEvent(args:Dictionary<String,Any>) {
        guard let eventName = args["eventName"] as? String else { return }
        NSLog("%@:%@", eventName,args)
        
        if eventName.hasPrefix("af_subscribe") {
            //AFInAppEventType.PURCHASE
            AppsFlyerLib.shared().logEvent(name: eventName, values: nil, completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully:", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
        else if eventName.hasPrefix("af_packet") {
            //AFInAppEventType.PURCHASE
            AppsFlyerLib.shared().logEvent(name: eventName, values: nil, completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully:", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
        else if eventName == "af_coin" {
            //AFInAppEventType.PURCHASE
            AppsFlyerLib.shared().logEvent(name: eventName, values: nil, completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully:", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
        else if eventName == "af_ticket" {
            //AFInAppEventType.PURCHASE
            AppsFlyerLib.shared().logEvent(name: eventName, values: nil, completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully:", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
        else if eventName == "af_pay" {
            guard let sku = args["sku"] as? String,let type = args["type"] as? String,let revenue = args["revenue"] as? String else { return }
            var eventValues:Dictionary<String,Any> = [AFEventParamContentId:sku,AFEventParamContentType:type,AFEventParamRevenue:revenue,"af_subscribe":sku]
            //通用付费事件
            AppsFlyerLib.shared().logEvent(name: eventName, values: eventValues, completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
        else if eventName == "af_complete_registration" {
            guard let gender = args["gender"] as? String else { return }
            AppsFlyerLib.shared().logEvent(name: eventName, values: [AFEventParam1:(Int(gender) ?? 1)], completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
        else {
            AppsFlyerLib.shared().logEvent(name: eventName, values: nil, completionHandler: { (response: [String : Any]?, error: Error?) in
                if let response = response {
                    print("Event sent successfully:", response)
                }
                if let error = error {
                    print("Event failed to be sent ERROR:", error)
                }
            })
        }
    }
    
    ///仅iOS 1.支付/会员（按订阅处理） 2.注册EVENT_NAME_COMPLETED_REGISTRATION
    func facebookLogEvent(args:Dictionary<String,Any>) {
        //        guard let eventName = args["eventName"] as? String else { return }
        //        NSLog("%@:%@", eventName,args)
        //
        //        if(eventName == "subscribe") {
        //            guard let sku = args["sku"] as? String,let type = args["type"] as? String,let revenueStr = args["revenue"] as? String ,let revenue = Double(revenueStr)else { return }
        //
        //            //订阅 会员都按照订阅处理 同时记录一次购买
        //            AppEvents.shared.logEvent(AppEvents.Name.subscribe,valueToSum:0.0,parameters: [AppEvents.ParameterName.contentID:sku])
        //            //购买 金额x0.5
        //            AppEvents.shared.logPurchase(amount: revenue, currency: "USD", parameters: [AppEvents.ParameterName.contentID : sku])
        //
        //        }
        //        if(eventName == "purchase") {
        //            guard let sku = args["sku"] as? String,let type = args["type"] as? String,let revenueStr = args["revenue"] as? String,let revenue = Double(revenueStr)  else { return }
        //
        //             //购买 金额x0.5
        //            AppEvents.shared.logPurchase(amount: revenue, currency: "USD", parameters: [AppEvents.ParameterName.contentID : sku])
        //        }
        //        if(eventName == "completed_registration") {
        //            guard let method = args["method"] as? String else { return }
        //            //"Facebook", "email", "Twitter", etc
        //            //应用内 "apple", "google","facebook","mobile","email_password_only_login"
        //            AppEvents.shared.logEvent(AppEvents.Name.completedRegistration,parameters: [AppEvents.ParameterName.registrationMethod:method])
        //        }
    }
    
    func getAppInfo(key:String?) -> String {
        var result: String = ""
        if let info = Bundle.main.infoDictionary {
            if(key != nil) {
                if let v = info[key!] as? String {
                    result = v
                }
                if let v = info[key!] as? Dictionary<String, Any> {
                    result = NativeBridge.jsonToString(dictionary: v)
                }
            } else {
                result = NativeBridge.jsonToString(dictionary: info)
            }
        }
        return result
    }
    
    //三方实现
    ///加载图片
    func loadImage(params:String, callResult:@escaping Callback) {
        guard let url = URL(string: params) else { return }
        let start = Int(Date().timeIntervalSince1970 * 1000)
        let fileUrl = ImageCache.default.cachePath(forKey: params,processorIdentifier: "joymeet")
        if(FileManager.default.fileExists(atPath: fileUrl)) {
            //print("fileExists:\(params)")
            let end = Int(Date().timeIntervalSince1970 * 1000)
            var temp = [
                "start":"\(start)",
                "end":"\(end)",
                "path":fileUrl,
                "cache":"1"
            ] as [String:Any]
            callResult(temp)
            return
        }
        
        ImageDownloader.default.downloadImage(with: url, options: nil) { result in
            switch result {
            case .success(let value):
                //print("image url:\(value.url!.absoluteString)")
                ImageCache.default.storeToDisk(value.originalData, forKey: params,processorIdentifier: "joymeet") { t in
                    if(FileManager.default.fileExists(atPath: fileUrl)) {
                        let end = Int(Date().timeIntervalSince1970 * 1000)
                        var temp = [
                            "start":"\(start)",
                            "end":"\(end)",
                            "path":fileUrl,
                            "cache":"0"
                        ] as [String:Any]
                        callResult(temp)
                    }
                }
            case .failure(let error):
                print("Error: \(error)")
                let end = Int(Date().timeIntervalSince1970 * 1000)
                var temp = [
                    "start":"\(start)",
                    "end":"\(end)",
                    "error":"\(error)",
                    "cache":"0"
                ] as [String:Any]
                callResult(temp)
            }
        }
    }
    
    ///net 网络请求
    func net(params:Dictionary<String,AnyObject>, callResult:@escaping Callback) {
        
        //print("net 网络请求")
        //print(params)
        
        let method = Alamofire.HTTPMethod(rawValue:params["method"] as! String)
        let url:String = params["url"] as! String
        var headers:HTTPHeaders = HTTPHeaders()
        let headersTemp = params["header"] as! Dictionary<String,AnyObject>
        headersTemp.forEach { (key: String, value: AnyObject) in
            headers.add(name: key,value: value as! String)
        }
        let contentType:String = headers.value(for: "content-type") ?? ""
        
        var dataRequest: DataRequest?
        let data:Any? = params["data"]
        if (contentType == "multipart/form-data") {
            if (data is Array<Int>) {
                //rc4
                let rc4Body:Array<UInt8> = data as! Array<UInt8>
                let encoding = JMSignBodyEncoding(body: rc4Body)
                dataRequest = AF.request(url, method: method, encoding: encoding, headers: headers)
                
            }
            else if (data is Dictionary<String, String>) {
                //file
                let temp = params["data"] as! Dictionary<String,String>
                let name:String = temp["name"] ?? ""
                let mimeType:String = temp["mimeType"] ?? ""
                let path:String = temp["path"] ?? ""
                guard let image = UIImage(contentsOfFile: path),let imageData = image.jpegData(compressionQuality: 0.85) else {
                    return
                }
                dataRequest = AF.upload(multipartFormData: { multipartFormData in
                    multipartFormData.append(imageData, withName: "file",fileName: name,mimeType: mimeType)
                }, to: url).uploadProgress(closure: {[weak self] progress in
                    //  NSLog("uploadProgress:%ld,%lf",progress.totalUnitCount,progress.fractionCompleted)
                    //                    var temp = Dictionary<String,Any>()
                    //                    temp["path"] = path
                    //                    temp["total"] = Int(progress.totalUnitCount)
                    //                    temp["count"] = Int(progress.completedUnitCount)
                    //self?.eventSink?(temp)
                })
            }
        } else {
            //普通参数
            dataRequest = AF.request(url, method: method, parameters: data as? Parameters,encoding: JSONEncoding.default, headers: headers)
            
        }
        
        //处理请求结果
        dataRequest?.responseString { response in
            //print(response)
            let statusCode = response.response?.statusCode ?? 0
            switch response.result {
            case .success(let data):
                if(statusCode == 200) {
                    var temp = Dictionary<String,Any>()
                    let headers:HTTPHeaders = response.response?.headers ?? HTTPHeaders()
                    let contentType:String = headers.value(for: "content-type")!
                    temp["headers"] = headers.dictionary
                    //print("contentType:%@",contentType);
                    if (contentType == "application/json") {
                        temp["data"] = data
                    } else if (contentType == "application/encrypt") {
                        //rc4
                        //let bytes = Array(data)
                        let bytes = Array<UInt8>(response.data!)
                        temp["data"] = bytes
                    }
                    let message = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    temp["statusCode"] = statusCode
                    temp["statusMessage"] = message
                    callResult(temp)
                } else {
                    var temp = Dictionary<String,Any>()
                    let headers:HTTPHeaders = response.response?.headers ?? HTTPHeaders()
                    let contentType:String = headers.value(for: "content-type")!
                    temp["headers"] = headers.dictionary
                    if (contentType == "application/json") {
                        temp["data"] = data
                    } else if (contentType == "application/encrypt") {
                        //rc4
                        //let bytes = Array(data)
                        let bytes = Array<UInt8>(response.data!)
                        temp["data"] = bytes
                    }
                    let message = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    temp["statusCode"] = statusCode
                    temp["statusMessage"] = message
                    temp["error"] = ["code":statusCode,"message":message,"url":url]
                    //                callResult(FlutterError(code: statusCode, message: message, details: message))
                    callResult(temp)
                }
            case .failure(let error):
                print("failure:\(error.responseCode ?? -1)\(error.localizedDescription)")
                //接口请求失败
                var temp = Dictionary<String,Any>()
                let message = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                temp["statusCode"] = statusCode
                temp["statusMessage"] = message
                temp["error"] = ["code":-1,"message":error.localizedDescription]
                //                callResult(FlutterError(code: statusCode, message: message, details: message))
                callResult(temp)
            }
            
        }
        
    }
    
    ///逆地理编码
    func getAddress(from coordinate: CLLocationCoordinate2D, completion: @escaping (Dictionary<String,String>) -> Void) {
        let geoCoder = CLGeocoder()
        let location = CLLocation.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var temp = Dictionary<String,String>();
        geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
            
            // check for errors
            guard let placeMarkArr = placemarks else {
                completion(temp)
                debugPrint(error ?? "")
                return
            }
            // check placemark data existence
            
            guard let placemark = placeMarkArr.first, !placeMarkArr.isEmpty else {
                completion(temp)
                return
            }
            // create address string
            temp["country"] = placemark.country
            temp["address_lines"] = placemark.subLocality
            temp["admin"] = placemark.country
            temp["sub_admin"] = placemark.subAdministrativeArea
            temp["locality"] = placemark.locality
            temp["thoroughfare"] = placemark.thoroughfare
            //                let outputString = [placemark.locality,
            //                                    placemark.subLocality,
            //                                    placemark.thoroughfare,
            //                                    placemark.postalCode,
            //                                    placemark.subThoroughfare,
            //                                    placemark.country].compactMap { $0 }.joined(separator: ", ")
            
            completion(temp)
        })
    }
    
    
    
    
    
}



struct JMSignBodyEncoding: ParameterEncoding {
    
    private let body: [UInt8]
    
    init(body: [UInt8]) { self.body = body }
    
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        guard var urlRequest = urlRequest.urlRequest else { throw Errors.emptyURLRequest }
        let data = Data(body)
        guard data.count > 0 else { throw Errors.encodingProblem }
        urlRequest.httpBody = data
        
        //let rc4 = RC4()
        //let drc4body = rc4.decrypt(data.bytes, key: rc4.byteArr("Q92LIQTQ4KuTpMsC"))
        //JMLog.log(String(data: Data(drc4body), encoding: .utf8))
        
        return urlRequest
    }
}

extension JMSignBodyEncoding {
    enum Errors: Error {
        case emptyURLRequest
        case encodingProblem
    }
}

extension JMSignBodyEncoding.Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyURLRequest: return "Empty url request"
        case .encodingProblem: return "Encoding problem"
        }
    }
}


typealias ActionBlock = (UIButton)->Void
class UIBlockButton: UIButton {
    
    init(type: UIButton.ButtonType) {
        super.init(frame: CGRect.zero)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private var _actionBlock:ActionBlock? = nil
    func handlecontrollEvent(event:UIControl.Event,action:@escaping ActionBlock) -> Void {
        _actionBlock = action
        self.addTarget(self, action: #selector(UIBlockButton.callActionBlock(sender:)), for: event)
    }
    
    @objc func callActionBlock(sender:UIButton) -> Void {
        _actionBlock!(sender)
    }
}
