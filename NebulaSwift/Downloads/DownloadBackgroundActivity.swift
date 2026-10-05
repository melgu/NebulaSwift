//
//  DownloadBackgroundActivity.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
import BackgroundTasks
#endif

/// Keeps downloads running while the app is in the background, for as long as iOS allows.
///
/// From iOS 26, the system shows the downloads' progress while the app is in the background, and lets them be stopped there.
/// Before, downloads get the few seconds any app gets to finish its work.
/// On macOS, apps keep running in the background anyway.
@MainActor
final class DownloadBackgroundActivity {
	/// Called when the background time ends, after which the downloads have to pause.
	var onExpiration: (() -> Void)?
	
	private let logger = Logger(category: "DownloadBackgroundActivity")
	private(set) var isActive = false
	
	#if canImport(UIKit)
	private var assertion = UIBackgroundTaskIdentifier.invalid
	/// A `BGContinuedProcessingTask`, once the system started it.
	private var continuedTask: BGTask?
	private var continuedTaskIdentifier: String?
	private var title = ""
	private var subtitle = ""
	private var fraction = 0.0
	#endif
	
	/// Must be called while the app is in the foreground.
	func begin(title: String, subtitle: String) {
		guard !isActive else { return }
		isActive = true
		#if canImport(UIKit)
		self.title = title
		self.subtitle = subtitle
		fraction = 0
		if #available(iOS 26, *), submitContinuedTask() {
			return
		}
		beginAssertion()
		#endif
	}
	
	func update(subtitle: String, fraction: Double) {
		#if canImport(UIKit)
		self.subtitle = subtitle
		self.fraction = fraction
		if #available(iOS 26, *), let task = continuedTask as? BGContinuedProcessingTask {
			report(to: task)
		}
		#endif
	}
	
	/// - Parameter failure: Why downloads failed, which the system shows instead of a generic error.
	func end(failure: String? = nil) {
		guard isActive else { return }
		isActive = false
		#if canImport(UIKit)
		if #available(iOS 26, *) {
			if let task = continuedTask {
				if let failure, let task = task as? BGContinuedProcessingTask {
					task.updateTitle(title, subtitle: failure)
				}
				task.setTaskCompleted(success: failure == nil)
			} else if let continuedTaskIdentifier {
				// The system hasn't started it yet
				BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: continuedTaskIdentifier)
			}
		}
		continuedTask = nil
		continuedTaskIdentifier = nil
		endAssertion()
		#endif
	}
	
	private func expire() {
		guard isActive else { return }
		logger.log("Background time expired")
		end()
		onExpiration?()
	}
	
	#if canImport(UIKit)
	private func beginAssertion() {
		assertion = UIApplication.shared.beginBackgroundTask(withName: "Downloads") { [weak self] in
			MainActor.assumeIsolated {
				self?.expire()
			}
		}
	}
	
	private func endAssertion() {
		guard assertion != .invalid else { return }
		UIApplication.shared.endBackgroundTask(assertion)
		assertion = .invalid
	}
	
	/// - Returns: Whether the system accepted the task.
	@available(iOS 26, *)
	private func submitContinuedTask() -> Bool {
		let bundleIdentifier = Bundle.main.bundleIdentifier ?? "de.melgu.NebulaSwift"
		// Every task needs its own identifier, since registering one twice ends the app
		let identifier = "\(bundleIdentifier).download.\(UUID().uuidString)"
		let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { [weak self] task in
			MainActor.assumeIsolated {
				guard let self, self.isActive, self.continuedTaskIdentifier == identifier,
					  let task = task as? BGContinuedProcessingTask else {
					task.setTaskCompleted(success: true)
					return
				}
				self.logger.debug("Continued processing task started: \(identifier, privacy: .public)")
				self.continuedTask = task
				task.progress.totalUnitCount = 1000
				self.report(to: task)
				task.expirationHandler = { [weak self] in
					// The app is ended soon after, so this can't wait for the main actor
					task.updateTitle(task.title, subtitle: String(localized: "Paused. Open the app to continue."))
					task.setTaskCompleted(success: false)
					Task { @MainActor in
						guard let self, self.continuedTaskIdentifier == identifier else { return }
						// Already completed
						self.continuedTask = nil
						self.continuedTaskIdentifier = nil
						self.expire()
					}
				}
			}
		}
		guard registered else {
			logger.error("Registering the continued processing task failed")
			return false
		}
		let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: title, subtitle: subtitle)
		// Without room for it right away, the app gets the usual background time instead
		request.strategy = .fail
		do {
			try BGTaskScheduler.shared.submit(request)
			continuedTaskIdentifier = identifier
			return true
		} catch {
			logger.error("Submitting the continued processing task failed: \(error)")
			return false
		}
	}
	
	@available(iOS 26, *)
	private func report(to task: BGContinuedProcessingTask) {
		task.updateTitle(title, subtitle: subtitle)
		task.progress.completedUnitCount = Int64(fraction * 1000)
	}
	#endif
}
