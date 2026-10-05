//
//  DownloadManager.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import SwiftUI
import OSLog
#if canImport(AppKit)
import AppKit
#endif

/// Downloads videos one after the other, and keeps track of the downloaded ones.
///
/// On macOS, videos go into a folder in the user's Movies folder. On iOS, they go into the app's
/// Documents folder, which the Files app shows. Either way, they're named after their channel
/// and title, followed by their identifier, which is how they're found again even if renamed.
@MainActor @Observable
final class DownloadManager {
	struct Download: Codable, Identifiable {
		/// The video as of the download, updated with newer engagement whenever possible.
		var video: Video
		var state: State
		/// The file's name in the downloads folder, once finished.
		var fileName: String?
		var height: Int?
		var fileSize: Int64?
		let addedAt: Date
		
		var id: String { video.episodeId }
	}
	
	enum State: Codable, Equatable {
		case waiting
		case failed(message: String)
		case finished
	}
	
	/// The fractions are of the whole download, processing included, so a progress indicator only fills up once.
	enum Status: Equatable {
		case waiting
		case downloading(Double)
		case processing(Double)
		case failed(message: String)
		case finished
	}
	
	/// In the order they were added.
	private(set) var downloads: [Download] = []
	private var activeID: String?
	private var activeProgress: DownloadProgress?
	/// How fast the running download downloads, in bytes per second, once that's known.
	private(set) var bytesPerSecond: Double?
	/// The running download's bytes over the last seconds, which the speed is averaged over.
	private var speedSamples: [(date: Date, bytes: Int64)] = []
	
	/// Where the finished videos go.
	let folder: URL
	/// Keeps the list of downloads, the images shown offline, and unfinished downloads.
	private let supportFolder: URL
	private var indexURL: URL { supportFolder.appending(path: "Downloads.json") }
	private var imagesFolder: URL { supportFolder.appending(path: "Images") }
	private var unfinishedFolder: URL { supportFolder.appending(path: "Unfinished", directoryHint: .isDirectory) }
	
	private let api: API
	private let storage: Storage
	private let downloader: any VideoDownloader = HLSDownloader()
	private let background = DownloadBackgroundActivity()
	private let logger = Logger(category: "DownloadManager")
	
	private var queueTask: Task<Void, Never>?
	private var activeTask: Task<Int, Error>?
	/// Whether the downloads wait for the app to come back to the foreground.
	private var isPaused = false
	/// Downloads cancelled while running, which shouldn't count as failed.
	private var cancelledIDs: Set<String> = []
	/// The download a pause stopped, which stays waiting even if the app is back before it noticed.
	private var pausedID: String?
	private var activationTask: Task<Void, Never>?
	
	init(api: API, storage: Storage) {
		self.api = api
		self.storage = storage
		#if os(macOS)
		folder = URL.moviesDirectory.appending(path: "NebulaSwift Offline", directoryHint: .isDirectory)
		#else
		folder = URL.documentsDirectory
		#endif
		supportFolder = URL.applicationSupportDirectory
			.appending(path: Bundle.main.bundleIdentifier ?? "de.melgu.NebulaSwift", directoryHint: .isDirectory)
			.appending(path: "Downloads", directoryHint: .isDirectory)
		
		load()
		refreshFiles()
		
		background.onExpiration = { [weak self] in
			self?.pause()
		}
		#if canImport(UIKit)
		activationTask = Task { [weak self] in
			for await _ in NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).values {
				guard let self else { return }
				refreshFiles()
				resume()
			}
		}
		#else
		// On iOS, the queue starts once the app becomes active, which it also does on launch
		startQueue()
		#endif
	}
	
	@MainActor
	deinit {
		activationTask?.cancel()
	}
	
	// MARK: Status
	
	func status(of video: Video) -> Status? {
		guard let download = download(for: video) else { return nil }
		switch download.state {
		case .finished:
			return .finished
		case .failed(let message):
			return .failed(message: message)
		case .waiting:
			guard activeID == download.id else { return .waiting }
			switch activeProgress {
			case .processing: return .processing(activeProgress?.overallFraction ?? 0)
			case .downloading: return .downloading(activeProgress?.overallFraction ?? 0)
			case nil: return .downloading(0)
			}
		}
	}
	
	/// The downloaded file, for playback without a connection.
	func fileURL(for video: Video) -> URL? {
		guard let download = download(for: video), download.state == .finished, let fileName = download.fileName else { return nil }
		return folder.appending(path: fileName)
	}
	
	/// The downloaded file's resolution and size, as far as they're known.
	func fileDetails(for video: Video) -> (height: Int?, size: Int64?)? {
		guard let download = download(for: video), download.state == .finished else { return nil }
		return (download.height, download.fileSize)
	}
	
	/// The video's thumbnail, saved when it was downloaded.
	func thumbnailURL(for video: Video) -> URL? {
		guard download(for: video) != nil else { return nil }
		return savedImage(named: "\(video.downloadKey)-thumbnail")
	}
	
	/// The video's channel avatar, saved when it was downloaded.
	func channelAvatarURL(for video: Video) -> URL? {
		guard download(for: video) != nil else { return nil }
		return savedImage(named: "\(video.downloadKey)-avatar")
	}
	
	/// The space the finished videos take up.
	var totalSize: Int64 {
		downloads.reduce(0) { $0 + ($1.state == .finished ? $1.fileSize ?? 0 : 0) }
	}
	
	private func download(for video: Video) -> Download? {
		downloads.first { $0.id == video.episodeId }
	}
	
	// MARK: Actions
	
	/// Adds the video to the queue, or tries a failed download again.
	func download(_ video: Video) {
		if let index = downloads.firstIndex(where: { $0.id == video.episodeId }) {
			guard case .failed = downloads[index].state else { return }
			downloads[index].state = .waiting
		} else {
			downloads.append(Download(video: video, state: .waiting, addedAt: .now))
		}
		save()
		// Adding a download asks to download now, also after the background time ran out
		resume()
	}
	
	/// Stops a download that hasn't finished yet, and throws away what it downloaded.
	func cancel(_ video: Video) {
		guard let download = download(for: video), download.state != .finished else { return }
		if activeID == download.id {
			cancelledIDs.insert(download.id)
			activeTask?.cancel()
		}
		remove(download)
	}
	
	/// Deletes a downloaded video. On macOS, it goes into the Trash.
	func delete(_ video: Video) throws {
		guard let download = download(for: video) else { return }
		if let fileURL = fileURL(for: video) {
			#if os(macOS)
			try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
			#else
			try FileManager.default.removeItem(at: fileURL)
			#endif
		}
		remove(download)
	}
	
	/// Cancels the downloads that haven't finished yet, and deletes all downloaded videos with everything saved for them.
	///
	/// On macOS, the videos go into the Trash.
	func deleteAll() throws {
		if let activeID {
			cancelledIDs.insert(activeID)
			activeTask?.cancel()
		}
		var failure: Error?
		for download in downloads {
			do {
				try delete(download.video)
			} catch {
				// The others still go
				logger.error("Deleting \(download.video.title) failed: \(error)")
				failure = error
			}
		}
		if let failure {
			throw failure
		}
		// Leftovers, like from a download cancelled just before it would have saved its progress
		try? FileManager.default.removeItem(at: imagesFolder)
		try? FileManager.default.removeItem(at: unfinishedFolder)
	}
	
	#if os(macOS)
	/// Shows the video in Finder, or the downloads folder if it's not given.
	func showInFinder(_ video: Video? = nil) {
		if let video, let fileURL = fileURL(for: video) {
			NSWorkspace.shared.activateFileViewerSelecting([fileURL])
		} else {
			try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			NSWorkspace.shared.open(folder)
		}
	}
	#endif
	
	/// Forgets downloads whose file was deleted, and follows files that were renamed.
	func refreshFiles() {
		let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
		var changed = false
		for download in downloads where download.state == .finished {
			let key = "[\(download.video.downloadKey)]"
			if let fileName = download.fileName, fileNames.contains(fileName) { continue }
			if let fileName = fileNames.first(where: { $0.contains(key) && $0.hasSuffix(".mp4") }) {
				logger.log("Found renamed download: \(fileName)")
				update(download.id) { $0.fileName = fileName }
			} else {
				logger.log("Download was deleted: \(download.video.title)")
				removeFiles(of: download)
				downloads.removeAll { $0.id == download.id }
			}
			changed = true
		}
		if changed {
			save()
		}
	}
	
	/// Updates the progress and Watch Later state of the downloaded videos, if there's a connection.
	func refreshEngagement() async {
		guard !downloads.isEmpty else { return }
		do {
			let videos = try await api.withEngagement(downloads.map(\.video))
			for video in videos {
				update(video.episodeId) { $0.video = video }
			}
			save()
		} catch {
			logger.debug("Refreshing engagement failed: \(error)")
		}
	}
	
	private func remove(_ download: Download) {
		removeFiles(of: download)
		downloads.removeAll { $0.id == download.id }
		save()
	}
	
	private func removeFiles(of download: Download) {
		try? FileManager.default.removeItem(at: workFolder(for: download.video))
		for name in ["thumbnail", "avatar"] {
			if let url = savedImage(named: "\(download.video.downloadKey)-\(name)") {
				try? FileManager.default.removeItem(at: url)
			}
		}
	}
	
	private func update(_ id: String, _ change: (inout Download) -> Void) {
		guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
		change(&downloads[index])
	}
	
	// MARK: Queue
	
	private func startQueue() {
		guard queueTask == nil, !isPaused, downloads.contains(where: { $0.state == .waiting }) else { return }
		queueTask = Task {
			await runQueue()
			queueTask = nil
			// Something may have been added while a pause was ending the queue
			startQueue()
		}
	}
	
	private func runQueue() async {
		background.begin(title: String(localized: "Downloading Videos"), subtitle: "")
		var failures: [String] = []
		while !isPaused, let download = downloads.first(where: { $0.state == .waiting }) {
			await run(download)
			if case .failed(let message) = self.download(for: download.video)?.state {
				failures.append(message)
			}
		}
		switch failures.count {
		case 0: background.end()
		case 1: background.end(failure: failures[0])
		default: background.end(failure: String(localized: "\(failures.count) downloads failed"))
		}
	}
	
	/// Stops the running download where it is, to continue later.
	private func pause() {
		logger.log("Pause downloads")
		isPaused = true
		pausedID = activeID
		activeTask?.cancel()
	}
	
	private func resume() {
		isPaused = false
		if queueTask != nil {
			// The app was suspended before the queue noticed the pause, so the queue goes on without the background time it ended
			let title = activeID.flatMap { id in downloads.first { $0.id == id }?.video.title } ?? ""
			background.begin(title: String(localized: "Downloading Videos"), subtitle: title)
		}
		startQueue()
	}
	
	private func run(_ download: Download) async {
		let id = download.id
		let video = download.video
		logger.log("Download \(video.title)")
		activeID = id
		activeProgress = .downloading(0, bytes: 0)
		background.update(subtitle: video.title, fraction: 0)
		defer {
			activeID = nil
			activeProgress = nil
			bytesPerSecond = nil
			speedSamples = []
			activeTask = nil
			if pausedID == id {
				pausedID = nil
			}
		}
		
		do {
			let artwork = await saveImages(of: video)
			let workFolder = workFolder(for: video)
			let request = { [api, storage] in
				VideoDownloadRequest(
					manifestURL: try api.manifestURL(for: video),
					maxHeight: storage.downloadQuality.maxHeight,
					workDirectory: workFolder,
					outputURL: workFolder.appending(path: "Output.mp4"),
					metadata: MP4Muxer.Metadata(
						title: video.title,
						channel: video.channelTitle,
						description: video.description,
						publishedAt: video.publishedAt,
						artwork: artwork
					)
				)
			}
			let height: Int
			do {
				height = try await runDownloader(try request(), id: id)
			} catch DownloadError.accessDenied {
				// The token in the manifest's URL may have expired
				try await api.refreshAuthorization()
				height = try await runDownloader(try request(), id: id)
			}
			// Cancelled just as it finished
			guard !cancelledIDs.contains(id) else { throw CancellationError() }
			try finish(video, from: workFolder.appending(path: "Output.mp4"), height: height)
			logger.log("Finished download of \(video.title)")
		} catch {
			if cancelledIDs.remove(id) != nil {
				logger.log("Cancelled download of \(video.title)")
				// The download may have written more since the cancellation removed its files
				try? FileManager.default.removeItem(at: workFolder(for: video))
				return
			}
			if pausedID == id {
				// It stays waiting and continues once the app is back
				logger.log("Paused download of \(video.title)")
				return
			}
			logger.error("Download of \(video.title) failed: \(error)")
			update(id) { $0.state = .failed(message: error.localizedDescription) }
			save()
		}
	}
	
	/// Downloads away from the main actor, and reports the progress back to it.
	private func runDownloader(_ request: VideoDownloadRequest, id: String) async throws -> Int {
		let downloader = downloader
		let progress: @Sendable (DownloadProgress) -> Void = { [weak self] progress in
			Task { @MainActor in
				self?.progressChanged(progress, id: id)
			}
		}
		let task = Task.detached {
			try await downloader.download(request, progress: progress)
		}
		activeTask = task
		return try await withTaskCancellationHandler {
			try await task.value
		} onCancel: {
			task.cancel()
		}
	}
	
	private func progressChanged(_ progress: DownloadProgress, id: String) {
		guard activeID == id else { return }
		activeProgress = progress
		background.update(subtitle: downloads.first { $0.id == id }?.video.title ?? "", fraction: progress.overallFraction)
		updateSpeed(with: progress)
	}
	
	/// Averages over a few seconds, since segments arrive in bursts.
	private func updateSpeed(with progress: DownloadProgress) {
		guard case .downloading(_, let bytes) = progress else {
			bytesPerSecond = nil
			speedSamples = []
			return
		}
		let now = Date.now
		speedSamples.append((now, bytes))
		// Keeps one sample from before the window, so the window is filled
		while speedSamples.count > 2, now.timeIntervalSince(speedSamples[1].date) > 5 {
			speedSamples.removeFirst()
		}
		guard let first = speedSamples.first, case let interval = now.timeIntervalSince(first.date), interval >= 1 else { return }
		bytesPerSecond = Double(bytes - first.bytes) / interval
	}
	
	private func finish(_ video: Video, from outputURL: URL, height: Int) throws {
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
		// A file from an earlier download of the same video would be found instead of the new one
		let key = "[\(video.downloadKey)]"
		for fileName in try fileManager.contentsOfDirectory(atPath: folder.path) where fileName.contains(key) && fileName.hasSuffix(".mp4") {
			try fileManager.removeItem(at: folder.appending(path: fileName))
		}
		let fileName = video.downloadFileName
		var destination = folder.appending(path: fileName)
		try fileManager.moveItem(at: outputURL, to: destination)
		#if os(iOS)
		// The videos can be downloaded again, so they don't need to take up space in backups
		var resourceValues = URLResourceValues()
		resourceValues.isExcludedFromBackup = true
		try? destination.setResourceValues(resourceValues)
		#endif
		let fileSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init)
		try? fileManager.removeItem(at: workFolder(for: video))
		
		update(video.episodeId) {
			$0.state = .finished
			$0.fileName = fileName
			$0.height = height
			$0.fileSize = fileSize
		}
		save()
	}
	
	// MARK: Files
	
	private func workFolder(for video: Video) -> URL {
		unfinishedFolder.appending(path: video.downloadKey, directoryHint: .isDirectory)
	}
	
	/// Saves the images the video is shown with, so they're there without a connection.
	///
	/// - Returns: The thumbnail, to show in the video file.
	private func saveImages(of video: Video) async -> Data? {
		try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
		var thumbnail: Data?
		for (name, url) in [("thumbnail", video.images.thumbnail[960]), ("avatar", video.images.channelAvatar[128])] {
			do {
				let (data, _) = try await URLSession.shared.data(from: url)
				// The image host picks the format on its own
				let fileExtension = data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "png" : "jpg"
				try data.write(to: imagesFolder.appending(path: "\(video.downloadKey)-\(name).\(fileExtension)"))
				if name == "thumbnail" {
					thumbnail = data
				}
			} catch {
				logger.error("Saving the \(name) of \(video.title) failed: \(error)")
			}
		}
		return thumbnail
	}
	
	private func savedImage(named name: String) -> URL? {
		["png", "jpg"]
			.map { imagesFolder.appending(path: "\(name).\($0)") }
			.first { FileManager.default.fileExists(atPath: $0.path) }
	}
	
	private func load() {
		do {
			let data = try Data(contentsOf: indexURL)
			downloads = try JSONDecoder().decode([Download].self, from: data)
		} catch CocoaError.fileReadNoSuchFile {
			// Nothing downloaded yet
		} catch {
			logger.error("Loading the downloads failed: \(error)")
		}
	}
	
	private func save() {
		do {
			let fileManager = FileManager.default
			if !fileManager.fileExists(atPath: supportFolder.path) {
				try fileManager.createDirectory(at: supportFolder, withIntermediateDirectories: true)
				#if os(iOS)
				var resourceValues = URLResourceValues()
				resourceValues.isExcludedFromBackup = true
				var supportFolder = supportFolder
				try? supportFolder.setResourceValues(resourceValues)
				#endif
			}
			try JSONEncoder().encode(downloads).write(to: indexURL, options: .atomic)
		} catch {
			logger.error("Saving the downloads failed: \(error)")
		}
	}
}

// MARK: - Progress

private extension DownloadProgress {
	/// How far the whole download got. Downloading takes most of the time, processing the rest.
	var overallFraction: Double {
		switch self {
		case .downloading(let fraction, _): fraction * 0.9
		case .processing(let fraction): 0.9 + fraction * 0.1
		}
	}
}

// MARK: - Video

extension Video {
	/// The episode's UUID, which identifies its download.
	var downloadKey: String {
		episodeId.split(separator: ":").last.map(String.init) ?? slug
	}
	
	/// Like “Channel – Title [UUID].mp4”.
	var downloadFileName: String {
		let forbidden = CharacterSet(charactersIn: "/\\:").union(.newlines).union(.controlCharacters)
		var name = "\(channelTitle) – \(title)"
			.components(separatedBy: forbidden)
			.joined(separator: "-")
		// File names are limited to 255 bytes, and “ [UUID].mp4” takes 43 of them
		while name.utf8.count > 200 {
			name.removeLast()
		}
		// Cutting the title short may leave a space at its end
		name = name.trimmingCharacters(in: .whitespaces)
		return "\(name) [\(downloadKey)].mp4"
	}
}
