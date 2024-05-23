//
//  ViewController.swift
//  WebDemo
//
//  Created by LiShuilong on 2024/5/9.
//

import UIKit
import WebKit
import CoreTelephony
import TZImagePickerController

//extension WKWebView {
//    override open var safeAreaInsets: UIEdgeInsets {
//        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }
//
//    open override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        return true
//    }
//}

public class WCViewController: UIViewController,WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, TZImagePickerControllerDelegate {
    
    var floatingView = UIView()
    
    private let canGoBackKeyPath = "canGoBack"
    
    var webView: WKWebView!;
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        NativeBridge.shared.setCurrentCtx(currentViewController: self);
        
        let contentController = WKUserContentController();
        //contentController.add(self, name: "nativeCallback")
        contentController.add(self, name: "NativeBridge")
        
        let scriptSource = "if (window.indexedDB) { console.log('IndexedDB is enabled'); } else { console.log('IndexedDB is not enabled'); }"
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        
        let config = WKWebViewConfiguration();
        config.userContentController = contentController;
        config.preferences = preferences
        config.websiteDataStore = WKWebsiteDataStore.default()
        //config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.audio
        
        //跨域问题
        //config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        //config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        webView = WKWebView(frame: .zero, configuration: config);
        
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.navigationDelegate = self
        webView.frame = UIScreen.main.bounds;
        view.addSubview(webView);
        
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        webView.addObserver(self, forKeyPath: canGoBackKeyPath, options: .new, context: nil)
        
        
        
        //开发工具悬浮窗
        self.floatingView.frame = CGRect(x: 16, y: 80, width: 40, height: 40)
        self.floatingView.backgroundColor = UIColor.red
        self.view.addSubview(self.floatingView)
        var panGesture = UIPanGestureRecognizer()
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(WCViewController.draggedView(_:)))
        floatingView.isUserInteractionEnabled = true
        floatingView.addGestureRecognizer(panGesture)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(WCViewController.floatingViewTap(gesture:)))
        tap.numberOfTapsRequired = 2
        floatingView.addGestureRecognizer(tap)
        
        //UIApplication.shared.statusBarStyle = .lightContent
        
        
        //国行 网络权限
        CTCellularData().cellularDataRestrictionDidUpdateNotifier = {state in
            if(state == .restricted) {
                //拒绝
            } else if(state == .notRestricted) {
                //已开启
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1, execute: {
                    self.loadHttp();
                })
                
            } else if(state == .restrictedStateUnknown) {
                //未知
            }
            print("网络变化 \(state)")
            
        }
    }
    
    
    var httpIsLoad = false
    func loadHttp() {
        if(httpIsLoad) {
            return
        }
        httpIsLoad = true
//        let myURL = URL(string: "http://10.43.2.59:8080/")
        let myURL = URL(string: "https://test-app.joyhappier.com/")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
        
        print("加载网页")
    }
    
    open override func observeValue(forKeyPath keyPath: String?,
                                    of object: Any?,
                                    change: [NSKeyValueChangeKey: Any]?,
                                    context: UnsafeMutableRawPointer?) {
        guard let theKeyPath = keyPath, object as? WKWebView == webView else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if theKeyPath == canGoBackKeyPath{
            
            //                         self.webView.allowsBackForwardNavigationGestures = self.webView.canGoBack;
            //                         self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.webView.canGoBack
            
            if let newValue = change?[NSKeyValueChangeKey.newKey],  let newV = newValue as? Bool{
                if let edgePan = self.navigationController?.interactivePopGestureRecognizer {
                    //edgePan.isEnabled = true;//!newV;
                }
            }
            
        }
    }
    
    
    deinit {
        webView.removeObserver(self, forKeyPath: canGoBackKeyPath, context: nil)
    }
    
    @objc func floatingViewTap(gesture:UIGestureRecognizer) {
       webView.reload()
    }
    
    @objc func draggedView(_ sender:UIPanGestureRecognizer){
        self.view.bringSubviewToFront(floatingView)
        let translation = sender.translation(in: self.view)
        floatingView.center = CGPoint(x: floatingView.center.x + translation.x, y: floatingView.center.y + translation.y)
        sender.setTranslation(CGPoint.zero, in: self.view)
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //print("message.name:\n\(message.name)")
        //print("message.body:\n\(message.body)")
        if message.name == "NativeBridge" {
            
            if(message.body is String) {
                NativeBridge.shared.postMessage(jsonStr: message.body as! String)
            }
        }
    }
    
    
    
    public func jsBridgeToNative(uuid:String, data:String) {
        
        NativeBridge.shared.filterLog(tag:"jsBridgeToNative", uuid: uuid, data: data)
        
        let params = [
            "uuid":uuid,
            "data":NativeBridge.encodeBase64(data: data),
        ]
        let tempJsonStr:String = NativeBridge.jsonToString(dictionary: params)
        let jsStr:String = String.init(format: "window.jsBridge.receiveMessage('%@')", tempJsonStr)
        webView.evaluateJavaScript(jsStr) { result, error in
            
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //                webView.evaluateJavaScript("displayDate()") { (any, error) in
        //                    if (error != nil) {
        //                        print(error ?? "err")
        //                    }
        //                }
        print("didFinish")
    }
    
    //加载不受信任的站点
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 判断服务器采用的验证方法
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if challenge.previousFailureCount == 0 {
                // 如果没有错误的情况下 创建一个凭证，并使用证书
                let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                DispatchQueue.global().async {
                    completionHandler(.useCredential, credential)
                }
            } else {
                // 验证失败，取消本次验证
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        print("webView error \(error)")
    }
    
    //进程终止(内存消耗过大导致白屏)
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("进程被终止")
        //webView.reload()
    }
    
}



