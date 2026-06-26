import Combine
import Foundation
import OSLog

@MainActor
final class HomeViewModel: ObservableObject {
    private enum Constants {
        static let defaultPageSize = 10
        static let defaultDebounceMilliseconds = 400
        static let initialOffset = 0
        static let initialSearchGeneration = 0
    }

    @Published var query = ""
    @Published private(set) var species: [PokemonSpeciesSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasSearched = false
    @Published private(set) var hasMoreResults = false

    let pageSize: Int

    private let service: PokemonServicing
    private let logger = Logger(subsystem: "Pokemon", category: "HomeViewModel")
    private var currentOffset = Constants.initialOffset
    private var lastSubmittedQuery = ""
    private var searchGeneration = Constants.initialSearchGeneration
    private var activeSearchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        service: PokemonServicing = PokemonGraphQLService(),
        pageSize: Int = Constants.defaultPageSize,
        debounceMilliseconds: Int = Constants.defaultDebounceMilliseconds
    ) {
        self.service = service
        self.pageSize = pageSize
        setupDebouncedSearch(debounceMilliseconds: debounceMilliseconds)
    }

    func clearSearch() {
        query = ""
        clearSearchResults()
    }

    /// Immediate search triggered by keyboard submit.
    func submitSearch() async {
        await executeSearch(term: normalizedQuery)
    }

    private func setupDebouncedSearch(debounceMilliseconds: Int) {
        $query
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(debounceMilliseconds), scheduler: DispatchQueue.main)
            .sink { [weak self] term in
                Task { @MainActor [weak self] in
                    await self?.executeSearch(term: term)
                }
            }
            .store(in: &cancellables)
    }

    private func executeSearch(term: String) async {
        activeSearchTask?.cancel()

        guard !term.isEmpty else {
            clearSearchResults()
            return
        }

        searchGeneration += 1
        let generation = searchGeneration

        activeSearchTask = Task {
            await performSearch(term: term, generation: generation)
        }

        await activeSearchTask?.value
    }

    private func performSearch(term: String, generation: Int) async {
        logger.info("Starting a new search for \(term, privacy: .public)")
        lastSubmittedQuery = term
        currentOffset = Constants.initialOffset
        hasSearched = true
        hasMoreResults = false
        errorMessage = nil
        isSearching = true

        defer {
            if generation == searchGeneration {
                isSearching = false
            }
        }

        do {
            let page = try await service.searchSpecies(name: term, limit: pageSize, offset: currentOffset)

            guard !Task.isCancelled, generation == searchGeneration else { return }

            species = page.results
            hasMoreResults = page.hasMore
            currentOffset = page.offset + page.results.count
            logger.info("Search completed with \(page.results.count) first-page species")
        } catch {
            guard !Task.isCancelled, generation == searchGeneration else { return }

            errorMessage = error.localizedDescription
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearSearchResults() {
        searchGeneration += 1
        activeSearchTask?.cancel()
        lastSubmittedQuery = ""
        currentOffset = Constants.initialOffset
        hasSearched = false
        hasMoreResults = false
        errorMessage = nil
        species = []
        isSearching = false
    }

    func loadNextPage() async {
        guard hasMoreResults, !isSearching, !isLoadingNextPage, !lastSubmittedQuery.isEmpty else { return }

        logger.info("Loading next page for \(self.lastSubmittedQuery, privacy: .public) at offset \(self.currentOffset)")
        errorMessage = nil
        isLoadingNextPage = true

        defer { isLoadingNextPage = false }

        do {
            let page = try await service.searchSpecies(name: lastSubmittedQuery, limit: pageSize, offset: currentOffset)
            species.append(contentsOf: page.results)
            hasMoreResults = page.hasMore
            currentOffset = page.offset + page.results.count
            logger.info("Next page loaded with \(page.results.count) species")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Next page failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
