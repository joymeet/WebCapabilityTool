//
//  JMLocationManager.swift
//  WebDemo
//
//  Created by LiShuilong on 2024/5/10.
//

import CoreLocation
import UIKit

class JMLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = JMLocationManager()

    private let locationManager = CLLocationManager()
    
    var lastLocation: CLLocation?
    
    var callback:((CLLocation )->Void)?
    
    ///单次请求
    func requestLocation(callback:@escaping (CLLocation )->Void) {
        self.callback = callback
        if(self.locationManager.location != nil) {
            callback(self.locationManager.location!)
        } else {
            self.locationManager.requestLocation()
        }
    }
    
    func start() {
        self.locationManager.startUpdatingLocation()
    }
    
    func stop() {
        self.locationManager.stopUpdatingLocation()
    }
    
    private override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 100
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //self.locationManager.requestAlwaysAuthorization()
        //self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    var permissionCallback:Callback?;
    
    // 授权状态变化回调
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if(permissionCallback != nil) {
            if(status == .authorizedAlways || status == .authorizedWhenInUse) {
                permissionCallback!("1")
            } else {
                permissionCallback!("0")
            }
            permissionCallback = nil
        }
    }
    
    func checkPermission(callback:@escaping Callback) {
        if(CLLocationManager.locationServicesEnabled()) {
            let status = CLLocationManager.authorizationStatus()
            if(status == .authorizedAlways||status == .authorizedWhenInUse) {
                callback("1")
            } else {
                permissionCallback = callback
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    // 更新位置变化的回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastLocation = location
        NSLog("New location \(location)")
        DispatchQueue.main.async {[weak self] in
            self?.callback?(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("location error:\(error.localizedDescription)")
    }
}

