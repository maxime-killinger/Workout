//
//  StepSourceTableViewController.swift
//  Workout
//
//  Created by Marco Boschi on 06/03/2017.
//  Copyright © 2017 Marco Boschi. All rights reserved.
//

import UIKit
import HealthKit

enum StepSource: CustomStringConvertible {
	private static let phoneStr = "iphone"
	private static let watchStr = "watch"
	
	case iPhone, watch
	case custom(String)
	
	var description: String {
		switch self {
		case .iPhone:
			return StepSource.phoneStr
		case .watch:
			return StepSource.watchStr
		case let .custom(str):
			return str
		}
	}
	
	var displayName: String {
		switch self {
		case .iPhone:
			return "iPhone"
		case .watch:
			return "Apple Watch"
		case let .custom(str):
			return str
		}
	}
	
	static func getSource(for str: String) -> StepSource {
		switch str.lowercased() {
		case "":
			fallthrough
		case phoneStr:
			return .iPhone
		case watchStr:
			return .watch
		default:
			return .custom(str)
		}
	}
	
	private static var predicateCache = [String: NSPredicate]()
	private static var predicateRequestCache = [String: [(NSPredicate) -> Void]]()
	
	/// Fetch the predicate to load only those step data point for the relevant source(s).
	func getPredicate(_ callback: @escaping (NSPredicate) -> Void) {
		DispatchQueue.workout.async {
			if StepSource.predicateRequestCache.keys.contains(self.description) {
				// A request for the same predicate is ongoing, wait for it
				StepSource.predicateRequestCache[self.description]?.append(callback)
			} else if let cached = StepSource.predicateCache[self.description] {
				// The requested predicate has been already loaded
				callback(cached)
			} else {
				guard let type = HKQuantityTypeIdentifier.stepCount.getType() else {
					fatalError("Step count type doesn't seem to exists...")
				}
		
				let q = HKSourceQuery(sampleType: type, samplePredicate: nil) { _, res, _ in
					let sources = (res ?? Set()).filter { s in
						return s.name.lowercased().range(of: self.description.lowercased()) != nil
					}
					
					let predicate = HKQuery.predicateForObjects(from: sources)
					DispatchQueue.workout.async {
						StepSource.predicateCache[self.description] = predicate
						if let callbacks = StepSource.predicateRequestCache.removeValue(forKey: self.description) {
							for c in callbacks {
								c(predicate)
							}
						}
					}
				}
				
				StepSource.predicateRequestCache[self.description] = [callback]
				healthStore.execute(q)
			}
		}
	}
	
}

class StepSourceTableViewController: UITableViewController, UITextFieldDelegate {
	
	@IBOutlet weak var customSource: UITextField!
	weak var delegate: AboutViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		let row: Int
		switch Preferences.stepSourceFilter {
		case .iPhone:
			row = 0
		case .watch:
			row = 1
		case let .custom(str):
			customSource.text = str
			row = 2
		}
		
		tableView.cellForRow(at: IndexPath(row: row, section: 0))?.accessoryType = .checkmark
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		switch indexPath.row {
		case 0:
			Preferences.stepSourceFilter = .iPhone
		case 1:
			Preferences.stepSourceFilter = .watch
		default:
			customSource.becomeFirstResponder()
		}
		
		func setCheckmark() {
			for i in 0 ..< 3 {
				tableView.cellForRow(at: IndexPath(row: i, section: 0))?.accessoryType = .none
			}
			tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
		}
		
		if indexPath.row != 2 {
			customSource.text = ""
			customSource.resignFirstResponder()
			setCheckmark()
		} else if let txt = customSource.text, txt != "" {
			setCheckmark()
			Preferences.stepSourceFilter = .custom(txt)
		}
		
		delegate.updateStepSource()
	}
	
	@IBAction func customSourceDidChange(_ sender: AnyObject) {
		let str = customSource.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		
		if str != "" {
			for i in 0 ..< 3 {
				tableView.cellForRow(at: IndexPath(row: i, section: 0))?.accessoryType = .none
			}
			tableView.cellForRow(at: IndexPath(row: 2, section: 0))?.accessoryType = .checkmark
			
			Preferences.stepSourceFilter = .custom(str)
			delegate.updateStepSource()
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		
		return true
	}

}
