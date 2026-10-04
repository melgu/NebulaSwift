//
//  Task+finishingInBackground.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

#if canImport(UIKit)
import UIKit
#endif

extension Task where Success == Void, Failure == Never {
	/// Runs the operation like `Task.init`, but asks iOS for time to finish it if the app goes to the background meanwhile.
	///
	/// If that time runs out first, the task is cancelled.
	///
	/// Like `Task.init`, the operation may use `self` implicitly, since it is released once the task ends.
	@MainActor @discardableResult
	static func finishingInBackground(named name: String, @_implicitSelfCapture operation: @escaping @MainActor () async -> Void) -> Task {
		#if canImport(UIKit)
		// Has to begin synchronously, or the app may be suspended before the task runs
		let assertion = BackgroundAssertion(name: name)
		let task = Task {
			await operation()
			assertion.end()
		}
		assertion.onExpiration = { task.cancel() }
		return task
		#else
		return Task { await operation() }
		#endif
	}
}

#if canImport(UIKit)
@MainActor
private final class BackgroundAssertion {
	var onExpiration: (() -> Void)?
	private var identifier = UIBackgroundTaskIdentifier.invalid

	init(name: String) {
		identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [self] in
			onExpiration?()
			end()
		}
	}

	/// Safe to call more than once.
	func end() {
		guard identifier != .invalid else { return }
		UIApplication.shared.endBackgroundTask(identifier)
		identifier = .invalid
	}
}
#endif
