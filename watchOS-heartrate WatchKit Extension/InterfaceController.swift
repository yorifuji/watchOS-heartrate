//
//  InterfaceController.swift
//  watchOS-heartrate WatchKit Extension
//
//  Created by yorifuji on 2020/05/08.
//  Copyright © 2020 yorifuji. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit


class InterfaceController: WKInterfaceController {

    @IBOutlet weak var label: WKInterfaceLabel!
    @IBOutlet weak var button: WKInterfaceButton!

    let fontSize = UIFont.systemFont(ofSize: 80)

    let healthStore = HKHealthStore()
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let heartRateUnit = HKUnit(from: "count/min")
    var heartRateQuery: HKQuery?

    var workoutSession: HKWorkoutSession?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        // Configure interface objects here.
        print(#function)

        guard HKHealthStore.isHealthDataAvailable() else {
            label.setText("HealthKit is not available on this device.")
            print("HealthKit is not available on this device.")
            return
        }

        let dataTypes = Set([heartRateType])
        self.healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) in
            guard success else {
                self.label.setText("Requests permission is not allowed.")
                print("Requests permission is not allowed.")
                return
            }
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print(#function)
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        print(#function)
    }

    @IBAction func btnTapped() {
        print(#function)
        if self.workoutSession == nil {
            let config = HKWorkoutConfiguration()
            config.activityType = .other
            do {
                self.workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                self.workoutSession?.delegate = self
                self.workoutSession?.startActivity(with: nil)
            }
            catch let e {
                print(e)
            }
        }
        else {
            self.workoutSession?.stopActivity(with: nil)
        }
    }
}

extension InterfaceController {

    private func createStreamingQuery() -> HKQuery {
        print(#function)
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: [])
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, samples, deletedObjects, anchor, error) in
            self.addSamples(samples: samples)
        }
        query.updateHandler = { (query, samples, deletedObjects, anchor, error) in
            self.addSamples(samples: samples)
        }
        return query
    }

    private func addSamples(samples: [HKSample]?) {
        print(#function)
        guard let samples = samples as? [HKQuantitySample] else { return }
        guard let quantity = samples.last?.quantity else { return }

        let text = String(quantity.doubleValue(for: self.heartRateUnit))
//        print(text)
        let attrStr = NSAttributedString(string: text, attributes:[NSAttributedString.Key.font:self.fontSize])
        DispatchQueue.main.async {
            self.label.setAttributedText(attrStr)
        }
    }
}

extension InterfaceController: HKWorkoutSessionDelegate {

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print(#function)
        switch toState {
        case .running:
            print("Session status to running")
            self.startQuery()
        case .stopped:
            print("Session status to stopped")
            self.stopQuery()
            self.workoutSession?.end()
        case .ended:
            print("Session status to ended")
            self.workoutSession = nil
        default:
            print("Other status \(toState.rawValue)")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("workoutSession delegate didFailWithError \(error.localizedDescription)")
    }

    func startQuery() {
        print(#function)
        heartRateQuery = self.createStreamingQuery()
        healthStore.execute(self.heartRateQuery!)
        DispatchQueue.main.async {
            self.button.setTitle("Stop")
        }
    }

    func stopQuery() {
        print(#function)
        healthStore.stop(self.heartRateQuery!)
        heartRateQuery = nil
        DispatchQueue.main.async {
            self.button.setTitle("Start")
            self.label.setText("")
        }
    }
}
