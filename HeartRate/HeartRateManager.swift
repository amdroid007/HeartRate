//
//  HeartRateManager.swift
//  HeartRate Data storage class - gets the data from HealthStore and stores it in preferences
//
//  Created by Jonny on 11/7/16.
//  Copyright © 2016 Jonny. All rights reserved.
//

import Foundation
import HealthKit
import UIKit

func synchronized(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

class HeartRateManager {
    
    private let healthStore = HKHealthStore() // This is where health data is stored
    
    // Main data structure is an array of HeartRateRecords
    var records = [HeartRateRecord]() {
        didSet {
            recordsUpdateHandler?(records)
        }
    }
    
    var recordsUpdateHandler: (([HeartRateRecord]) -> Void)?
    
    var recordDictionary = [UUID : HeartRateRecord]()
    
    private struct Key {
        static let recordDictionary = "HeartRateManager.recordDictionary"
    }
    
    init() {
     
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            // As I expected - data is stored (temporarily?) in UserDefaults
            let termRecordsRaw = UserDefaults.standard.value(forKey: Key.recordDictionary) as? [[String : Any]] ?? []
            
            // Changed from flatMap to compactMap - hopefully will not break anything. flatMap was deprecated
            let records = termRecordsRaw.compactMap { HeartRateRecord(propertyList: $0) }
            
            DispatchQueue.main.async {
                self.records = records
            }
            
            // Create a recordDictionary from the records retrieved from userdefaults
            var recordDictionary = [UUID : HeartRateRecord]()
            records.forEach {
                recordDictionary[$0.uuid] = $0
            }
            self.recordDictionary = recordDictionary
        }
    }
    
    func save(_ heartRates: [HeartRateRecord]) {
        
        records.insert(contentsOf: heartRates, at: 0)
        heartRates.forEach { recordDictionary[$0.uuid] = $0 }
        
        asyncSaveRecordsLocally()
    }
    
    func delete(_ heartRates: [HeartRateRecord]) {
        
        heartRates.forEach { recordDictionary[$0.uuid] = nil }
        records = recordDictionary.values.sorted { $0.recordDate > $1.recordDate }
        
        asyncSaveRecordsLocally()
    }
    
    func deleteAllRecords() {
                
        recordDictionary.removeAll()
        records.removeAll()
        
        asyncSaveRecordsLocally()
    }
    
    @objc func applicationWillResignActive() {
        asyncSaveRecordsLocally()
    }
    
    private func asyncSaveRecordsLocally() {
        print(#function)
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.set(self.records.map { $0.propertyList }, forKey: Key.recordDictionary)
        }
    }
    
    func startWatchApp(handler: @escaping (Error?) -> Void) {
        
        WatchConnectivityManager.shared?.fetchActivatedSession { _ in
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        self.healthStore.startWatchApp(with: configuration) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("healthStore.startWatchApp error:", error)
                } else {
                    print("healthStore.startWatchApp success.")
                }
                handler(error)
            }
        }
        }
    }
    
    
    
}
