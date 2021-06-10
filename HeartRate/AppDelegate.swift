//
//  AppDelegate.swift
//  HeartRate
//
//  Created by Jonny on 10/9/16.
//  Copyright © 2016 Jonny. All rights reserved.
//

import UIKit
import HealthKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        application.registerForRemoteNotifications()
        
        // activate WCSession at app startup.
        WatchConnectivityManager.shared?.activate()
        // These are things that we are reading - probably want to ask for stepcount as well?
        if HKHealthStore.isHealthDataAvailable() {
            let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
            let stepCountType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
            let typesToRead = Set([heartRateType, stepCountType])
            
            HKHealthStore().requestAuthorization(toShare: nil, read: typesToRead) { success, error in }
        }
                
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print(#function)
        self.application(application, performFetchWithCompletionHandler: completionHandler)
    }
    
    // background fetch, the app will be waked periodcally by the system
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print(#function)
        
        var didCompleted = false
        
        // maximum fetch duration is 30 seconds, we set the deadline to 25 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            if !didCompleted {
                didCompleted = true
                completionHandler(.noData)
            }
        }        
    }
    
    func applicationShouldRequestHealthAuthorization(_ application: UIApplication) {
        
        HKHealthStore().handleAuthorizationForExtension { _, error in
            if let error = error {
                print(error)
            }
        }
    }
    
}

