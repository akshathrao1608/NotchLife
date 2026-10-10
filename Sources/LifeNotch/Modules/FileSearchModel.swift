import Foundation

// FileSearchModel.swift
// Finds files and apps using Spotlight (Apple's built-in search index), the same engine as
// Finder's search box. Everything stays on your Mac. LifeNotch only reads file names and locations.

struct FileHit: Identifiable, Equatable {
    let path: String
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
    var folder: String { url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

final class FileSearchModel: ObservableObject {
    @Published var query = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var results: [FileHit] = []
    @Published private(set) var isSearching = false

    private let metadataQuery = NSMetadataQuery()
    private var debounce: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    init() {
        metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope, "/Applications"]
        metadataQuery.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        let center = NotificationCenter.default
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, Notification.Name.NSMetadataQueryDidUpdate] {
            observers.append(center.addObserver(forName: name, object: metadataQuery, queue: .main) { [weak self] _ in
                self?.collectResults()
            })
        }
    }

    deinit {
        for token in observers { NotificationCenter.default.removeObserver(token) }
        metadataQuery.stop()
    }

    private func scheduleSearch() {
        debounce?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            metadataQuery.stop()
            results = []
            isSearching = false
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.runSearch(text) }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func runSearch(_ text: String) {
        metadataQuery.stop()
        metadataQuery.predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, text)
        isSearching = true
        metadataQuery.start()
    }

    private func collectResults() {
        metadataQuery.disableUpdates()
        var hits: [FileHit] = []
        for case let item as NSMetadataItem in metadataQuery.results {
            if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                hits.append(FileHit(path: path))
            }
            if hits.count >= 40 { break }
        }
        metadataQuery.enableUpdates()
        results = hits
        isSearching = false
    }
}
