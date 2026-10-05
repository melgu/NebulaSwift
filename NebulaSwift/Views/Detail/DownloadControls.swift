//
//  DownloadControls.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import SwiftUI

/// The actions for a video's download that fit its state, for menus.
struct DownloadMenuItems: View {
	let video: Video
	
	@Environment(DownloadManager.self) private var downloads
	@Environment(\.handleError) private var handleError
	
	var body: some View {
		switch downloads.status(of: video) {
		case nil:
			Button {
				downloads.download(video)
			} label: {
				Label("Download", systemImage: "arrow.down.circle")
			}
		case .waiting, .downloading, .processing:
			Button {
				downloads.cancel(video)
			} label: {
				Label("Cancel Download", systemImage: "xmark.circle")
			}
		case .failed:
			Button {
				downloads.download(video)
			} label: {
				Label("Retry Download", systemImage: "arrow.clockwise")
			}
			Button(role: .destructive) {
				downloads.cancel(video)
			} label: {
				Label("Remove Download", systemImage: "trash")
			}
		case .finished:
			#if os(macOS)
			Button {
				downloads.showInFinder(video)
			} label: {
				Label("Show in Finder", systemImage: "folder")
			}
			#endif
			Button(role: .destructive) {
				do {
					try downloads.delete(video)
				} catch {
					handleError(error)
				}
			} label: {
				Label("Delete Download", systemImage: "trash")
			}
		}
	}
}

/// Downloads the video, or offers what can be done with its download.
struct DownloadButton: View {
	let video: Video
	
	@Environment(DownloadManager.self) private var downloads
	
	var body: some View {
		if let status = downloads.status(of: video) {
			Menu {
				DownloadMenuItems(video: video)
			} label: {
				DownloadStatusIcon(status: status)
			}
			.menuIndicator(.hidden)
		} else {
			Button {
				downloads.download(video)
			} label: {
				Label("Download", systemImage: "arrow.down.circle")
			}
		}
	}
}

/// Shows on a video's thumbnail whether it's downloaded or downloading.
struct DownloadBadge: View {
	let video: Video
	
	@Environment(DownloadManager.self) private var downloads
	
	var body: some View {
		if let status = downloads.status(of: video) {
			DownloadStatusIcon(status: status)
				.padding(2)
				.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
		}
	}
}

/// The icon for a download's status, with its title for VoiceOver.
///
/// It's no label, since a toolbar would show a label's title instead of an icon that isn't a symbol, like the progress pie.
struct DownloadStatusIcon: View {
	let status: DownloadManager.Status
	
	var body: some View {
		icon
			.accessibilityLabel(title)
			.accessibilityValue(progress?.formatted(.percent.precision(.fractionLength(0))) ?? "")
	}
	
	@ViewBuilder
	private var icon: some View {
		switch status {
		case .waiting:
			Image(systemName: "clock")
		case .downloading(let fraction), .processing(let fraction):
			DownloadProgressPie(fraction: fraction)
		case .failed:
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.yellow)
		case .finished:
			Image(systemName: "arrow.down.circle.fill")
		}
	}
	
	private var title: Text {
		switch status {
		case .waiting: Text("Waiting to Download")
		case .downloading: Text("Downloading")
		case .processing: Text("Processing Download")
		case .failed: Text("Download Failed")
		case .finished: Text("Downloaded")
		}
	}
	
	private var progress: Double? {
		switch status {
		case .downloading(let fraction), .processing(let fraction): fraction
		default: nil
		}
	}
}

/// A pie filling up with the progress inside a circle, the size of a symbol and in the color of the text around it.
private struct DownloadProgressPie: View {
	let fraction: Double
	
	var body: some View {
		// The symbol's circle matches the size and weight of the other download symbols
		Image(systemName: "circle")
			.overlay {
				PieSlice(fraction: fraction)
					// Leaves a gap to the circle about as wide as its line
					.scaleEffect(0.56)
					// Rendered on its own, since a shape turns translucent on a material, unlike a symbol
					.drawingGroup()
			}
			.animation(.default, value: fraction)
	}
}

/// A slice starting at the top and going clockwise.
private struct PieSlice: Shape {
	var fraction: Double
	
	var animatableData: Double {
		get { fraction }
		set { fraction = newValue }
	}
	
	func path(in rect: CGRect) -> Path {
		let center = CGPoint(x: rect.midX, y: rect.midY)
		var path = Path()
		path.move(to: center)
		path.addArc(
			center: center,
			radius: min(rect.width, rect.height) / 2,
			startAngle: .degrees(-90),
			endAngle: .degrees(-90 + 360 * fraction),
			clockwise: false
		)
		path.closeSubpath()
		return path
	}
}
