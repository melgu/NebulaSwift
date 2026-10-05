//
//  MP4Muxer.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import AVFoundation

/// Puts the downloaded renditions into a single MP4 file, without re-encoding them.
enum MP4Muxer {
	struct AudioTrack {
		let url: URL
		/// A BCP 47 language tag.
		let language: String?
		let isDefault: Bool
	}
	
	struct SubtitleTrack {
		let subtitles: WebVTT
		/// A BCP 47 language tag.
		let language: String?
	}
	
	/// What Finder, QuickTime and media libraries show about the video.
	struct Metadata: Sendable {
		let title: String
		let channel: String
		let description: String
		let publishedAt: Date
		/// A JPEG or PNG image.
		let artwork: Data?
		
		var items: [AVMetadataItem] {
			var items = [
				item(.iTunesMetadataSongName, title as NSString),
				item(.iTunesMetadataArtist, channel as NSString),
				// The writer leaves out the description atom, but keeps comments
				item(.iTunesMetadataUserComment, description as NSString),
				item(.iTunesMetadataReleaseDate, publishedAt.formatted(.iso8601) as NSString),
			]
			if let artwork {
				let artworkItem = item(.iTunesMetadataCoverArt, artwork as NSData)
				// The image host picks the format on its own
				let isPNG = artwork.starts(with: [0x89, 0x50, 0x4E, 0x47])
				artworkItem.dataType = (isPNG ? kCMMetadataBaseDataType_PNG : kCMMetadataBaseDataType_JPEG) as String
				items.append(artworkItem)
			}
			return items
		}
		
		private func item(_ identifier: AVMetadataIdentifier, _ value: NSCopying & NSObjectProtocol) -> AVMutableMetadataItem {
			let item = AVMutableMetadataItem()
			item.identifier = identifier
			item.value = value
			return item
		}
	}
	
	static func mux(
		video videoURL: URL,
		audio: [AudioTrack],
		subtitles: [SubtitleTrack],
		metadata: Metadata,
		to outputURL: URL,
		progress: @escaping @Sendable (Double) -> Void
	) async throws {
		try? FileManager.default.removeItem(at: outputURL)
		let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
		// Puts the index first, so players can start right away
		writer.shouldOptimizeForNetworkUse = true
		writer.metadata = metadata.items
		
		let videoAsset = AVURLAsset(url: videoURL)
		let duration = try await videoAsset.load(.duration)
		let videoSource = try await passthroughSource(for: .video, of: videoAsset, writer: writer)
		var sources = [videoSource]
		
		var audioInputs: [AVAssetWriterInput] = []
		var defaultAudioInput: AVAssetWriterInput?
		for track in audio {
			let source = try await passthroughSource(for: .audio, of: AVURLAsset(url: track.url), writer: writer)
			setLanguage(track.language, of: source.input)
			// Only the default one plays, the others can be picked in the player
			source.input.marksOutputTrackAsEnabled = track.isDefault || audio.count == 1
			if source.input.marksOutputTrackAsEnabled, defaultAudioInput == nil {
				defaultAudioInput = source.input
			} else {
				source.input.marksOutputTrackAsEnabled = false
			}
			audioInputs.append(source.input)
			sources.append(source)
		}
		addGroup(of: audioInputs, defaultInput: defaultAudioInput, to: writer)
		
		var subtitleInputs: [AVAssetWriterInput] = []
		if !subtitles.isEmpty {
			let format = try WebVTT.textFormatDescription()
			for track in subtitles {
				let input = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil, sourceFormatHint: format)
				input.expectsMediaDataInRealTime = false
				setLanguage(track.language, of: input)
				// Subtitles stay off until picked in the player
				input.marksOutputTrackAsEnabled = false
				guard writer.canAdd(input) else { continue }
				writer.add(input)
				var samples = try track.subtitles.textSamples(duration: duration.seconds, format: format)[...]
				subtitleInputs.append(input)
				sources.append(Source(input: input, reader: nil) { samples.popFirst() })
			}
		}
		addGroup(of: subtitleInputs, defaultInput: nil, to: writer)
		
		for source in sources {
			guard source.reader?.startReading() != false else { throw source.reader?.error ?? DownloadError.processingFailed }
		}
		guard writer.startWriting() else { throw writer.error ?? DownloadError.processingFailed }
		writer.startSession(atSourceTime: .zero)
		
		let session = Session(writer: writer, sources: sources, duration: duration, progress: progress)
		try await withTaskCancellationHandler {
			try await session.run()
		} onCancel: {
			session.cancel()
		}
		await writer.finishWriting()
		guard writer.status == .completed else { throw writer.error ?? DownloadError.processingFailed }
	}
	
	private static func passthroughSource(for mediaType: AVMediaType, of asset: AVURLAsset, writer: AVAssetWriter) async throws -> Source {
		guard let track = try await asset.loadTracks(withMediaType: mediaType).first else { throw DownloadError.unsupportedStream }
		let (formatDescriptions, transform) = try await track.load(.formatDescriptions, .preferredTransform)
		let reader = try AVAssetReader(asset: asset)
		let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
		output.alwaysCopiesSampleData = false
		guard reader.canAdd(output) else { throw DownloadError.unsupportedStream }
		reader.add(output)
		
		let input = AVAssetWriterInput(mediaType: mediaType, outputSettings: nil, sourceFormatHint: formatDescriptions.first)
		input.expectsMediaDataInRealTime = false
		input.transform = transform
		guard writer.canAdd(input) else { throw DownloadError.unsupportedStream }
		writer.add(input)
		return Source(input: input, reader: reader) { output.copyNextSampleBuffer() }
	}
	
	/// Marks the tracks as alternatives to each other, so players offer them as choices.
	private static func addGroup(of inputs: [AVAssetWriterInput], defaultInput: AVAssetWriterInput?, to writer: AVAssetWriter) {
		guard !inputs.isEmpty else { return }
		let group = AVAssetWriterInputGroup(inputs: inputs, defaultInput: defaultInput)
		if writer.canAdd(group) {
			writer.add(group)
		}
	}
	
	private static func setLanguage(_ tag: String?, of input: AVAssetWriterInput) {
		guard let tag else { return }
		input.extendedLanguageTag = tag
		// The track header only takes ISO 639-2 codes
		input.languageCode = Locale.Language(identifier: tag).languageCode?.identifier(.alpha3)
	}
}

// MARK: - Session

private extension MP4Muxer {
	/// Only used on the session's queue, once set up.
	struct Source: @unchecked Sendable {
		let input: AVAssetWriterInput
		let reader: AVAssetReader?
		let nextSample: () -> CMSampleBuffer?
	}
	
	/// Feeds all inputs at once, since the writer interleaves them and waits for whichever falls behind.
	///
	/// Only touched on its queue, apart from the immutable setup.
	final class Session: @unchecked Sendable {
		private let writer: AVAssetWriter
		private let sources: [Source]
		private let duration: CMTime
		private let progress: @Sendable (Double) -> Void
		private let queue = DispatchQueue(label: "de.melgu.NebulaSwift.MP4Muxer")
		
		private var remaining: Int
		private var isFinished = false
		private var continuation: CheckedContinuation<Void, Error>?
		private var lastReportedProgress = 0.0
		
		init(writer: AVAssetWriter, sources: [Source], duration: CMTime, progress: @escaping @Sendable (Double) -> Void) {
			self.writer = writer
			self.sources = sources
			self.duration = duration
			self.progress = progress
			self.remaining = sources.count
		}
		
		func run() async throws {
			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				queue.async { [self] in
					guard !isFinished else {
						// Cancelled before it started
						continuation.resume(throwing: CancellationError())
						return
					}
					self.continuation = continuation
					for (index, source) in sources.enumerated() {
						source.input.requestMediaDataWhenReady(on: queue) { [self] in
							feed(source, reportsProgress: index == 0)
						}
					}
				}
			}
		}
		
		func cancel() {
			queue.async { [self] in
				finish(throwing: CancellationError())
			}
		}
		
		private func feed(_ source: Source, reportsProgress: Bool) {
			while !isFinished, source.input.isReadyForMoreMediaData {
				guard let sample = source.nextSample() else {
					if let reader = source.reader, reader.status == .failed {
						finish(throwing: reader.error ?? DownloadError.processingFailed)
						return
					}
					source.input.markAsFinished()
					remaining -= 1
					if remaining == 0 {
						finish(throwing: nil)
					}
					return
				}
				guard source.input.append(sample) else {
					finish(throwing: writer.error ?? DownloadError.processingFailed)
					return
				}
				if reportsProgress {
					report(CMSampleBufferGetPresentationTimeStamp(sample))
				}
			}
		}
		
		private func report(_ time: CMTime) {
			guard duration.seconds > 0 else { return }
			let fraction = min(max(time.seconds / duration.seconds, 0), 1)
			guard fraction - lastReportedProgress >= 0.01 else { return }
			lastReportedProgress = fraction
			progress(fraction)
		}
		
		private func finish(throwing error: Error?) {
			guard !isFinished else { return }
			isFinished = true
			if let error {
				for source in sources {
					source.reader?.cancelReading()
				}
				writer.cancelWriting()
				continuation?.resume(throwing: error)
			} else {
				continuation?.resume()
			}
			continuation = nil
		}
	}
}
