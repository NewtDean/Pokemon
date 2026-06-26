import Foundation
import Testing
@testable import Pokemon

struct PokemonTests {
    private enum Constants {
        static let disabledDebounceMilliseconds = 0
        static let shortDebounceMilliseconds = 100
        static let debounceSettleDelayMilliseconds = 150
        static let clearResultsSettleDelayMilliseconds = 50
        static let suppressDebounceMilliseconds = 60_000
        static let defaultPageLimit = 10
        static let paginationPageSize = 1
        static let initialOffset = 0
        static let secondPageOffset = 1
        static let thirdPageOffset = 2
        static let searchOffset = 20
        static let httpSuccessStatus = 200
        static let httpServerErrorStatus = 500
        static let pikachuSpeciesID = 25
        static let pikachuCaptureRate = 190
        static let yellowColorID = 10
        static let staticAbilityID = 1
        static let lightningRodAbilityID = 2
        static let bulbasaurSpeciesID = 1
        static let bulbasaurCaptureRate = 45
        static let ivysaurSpeciesID = 2
        static let charizardSpeciesID = 6
        static let blazeAbilityID = 1
        static let solarPowerAbilityID = 2
    }

    @Test func graphQLServiceBuildsFuzzyRequestAndDecodesSpecies() async throws {
        let responseData = Data(
            """
            {
              "data": {
                "pokemon_v2_pokemonspecies": [
                  {
                    "id": \(Constants.pikachuSpeciesID),
                    "name": "pikachu",
                    "capture_rate": \(Constants.pikachuCaptureRate),
                    "pokemon_v2_pokemoncolor": { "id": \(Constants.yellowColorID), "name": "yellow" },
                    "pokemon_v2_pokemons": [
                      {
                        "id": \(Constants.pikachuSpeciesID),
                        "name": "pikachu",
                        "pokemon_v2_pokemonabilities": [
                          { "id": \(Constants.staticAbilityID), "pokemon_v2_ability": { "name": "static" } },
                          { "id": \(Constants.lightningRodAbilityID), "pokemon_v2_ability": { "name": "lightning-rod" } }
                        ]
                      }
                    ]
                  }
                ]
              }
            }
            """.utf8
        )
        let recorder = RequestRecorder()
        let service = PokemonGraphQLService(
            endpoint: URL(string: "https://example.com/graphql")!,
            transport: MockGraphQLTransport(statusCode: Constants.httpSuccessStatus, data: responseData, recorder: recorder)
        )

        let page = try await service.searchSpecies(
            name: " pika ",
            limit: Constants.defaultPageLimit,
            offset: Constants.searchOffset
        )
        let request = try #require(await recorder.request)
        let httpBody = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let variables = try #require(json["variables"] as? [String: Any])

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(variables["name"] as? String == "%pika%")
        #expect(variables["limit"] as? Int == Constants.defaultPageLimit)
        #expect(variables["offset"] as? Int == Constants.searchOffset)
        #expect(page.hasMore)
        #expect(page.results == [
            PokemonSpeciesSearchResult(
                id: Constants.pikachuSpeciesID,
                name: "pikachu",
                captureRate: Constants.pikachuCaptureRate,
                colorName: "yellow",
                pokemons: [
                    PokemonSummary(
                        id: Constants.pikachuSpeciesID,
                        name: "pikachu",
                        abilities: [
                            PokemonAbility(id: Constants.staticAbilityID, name: "static"),
                            PokemonAbility(id: Constants.lightningRodAbilityID, name: "lightning-rod")
                        ]
                    )
                ]
            )
        ])
    }

    @Test func graphQLServiceThrowsForHTTPFailure() async throws {
        let service = PokemonGraphQLService(
            endpoint: URL(string: "https://example.com/graphql")!,
            transport: MockGraphQLTransport(statusCode: Constants.httpServerErrorStatus, data: Data("{}".utf8), recorder: RequestRecorder())
        )

        await #expect(throws: PokemonServiceError.httpStatus(Constants.httpServerErrorStatus)) {
            try await service.searchSpecies(name: "mew", limit: Constants.defaultPageLimit, offset: Constants.initialOffset)
        }
    }

    @Test func graphQLServiceThrowsForGraphQLErrors() async throws {
        let service = PokemonGraphQLService(
            endpoint: URL(string: "https://example.com/graphql")!,
            transport: MockGraphQLTransport(
                statusCode: Constants.httpSuccessStatus,
                data: Data(#"{ "errors": [{ "message": "bad query" }] }"#.utf8),
                recorder: RequestRecorder()
            )
        )

        await #expect(throws: PokemonServiceError.graphQLErrors(["bad query"])) {
            try await service.searchSpecies(name: "mew", limit: Constants.defaultPageLimit, offset: Constants.initialOffset)
        }
    }

    @MainActor
    @Test func homeViewModelSearchesAndPaginates() async throws {
        let service = MockPokemonService(pages: [
            PokemonSearchPage(
                results: [
                    PokemonSpeciesSearchResult(
                        id: Constants.bulbasaurSpeciesID,
                        name: "bulbasaur",
                        captureRate: Constants.bulbasaurCaptureRate,
                        colorName: "green",
                        pokemons: [PokemonSummary(id: Constants.bulbasaurSpeciesID, name: "bulbasaur", abilities: [])]
                    )
                ],
                limit: Constants.paginationPageSize,
                offset: Constants.initialOffset
            ),
            PokemonSearchPage(
                results: [
                    PokemonSpeciesSearchResult(
                        id: Constants.ivysaurSpeciesID,
                        name: "ivysaur",
                        captureRate: Constants.bulbasaurCaptureRate,
                        colorName: "green",
                        pokemons: [PokemonSummary(id: Constants.ivysaurSpeciesID, name: "ivysaur", abilities: [])]
                    )
                ],
                limit: Constants.paginationPageSize,
                offset: Constants.secondPageOffset
            ),
            PokemonSearchPage(results: [], limit: Constants.paginationPageSize, offset: Constants.thirdPageOffset)
        ])
        let viewModel = HomeViewModel(
            service: service,
            pageSize: Constants.paginationPageSize,
            debounceMilliseconds: Constants.suppressDebounceMilliseconds
        )
        viewModel.query = "saur"

        await viewModel.submitSearch()
        #expect(viewModel.species.map(\.name) == ["bulbasaur"])
        #expect(viewModel.hasMoreResults)
        #expect(viewModel.hasSearched)

        await viewModel.loadNextPage()
        #expect(viewModel.species.map(\.name) == ["bulbasaur", "ivysaur"])

        await viewModel.loadNextPage()
        #expect(!viewModel.hasMoreResults)
        #expect(await service.calls == [
            PokemonSearchCall(name: "saur", limit: Constants.paginationPageSize, offset: Constants.initialOffset),
            PokemonSearchCall(name: "saur", limit: Constants.paginationPageSize, offset: Constants.secondPageOffset),
            PokemonSearchCall(name: "saur", limit: Constants.paginationPageSize, offset: Constants.thirdPageOffset)
        ])
    }

    @MainActor
    @Test func homeViewModelRejectsEmptySearch() async throws {
        let service = MockPokemonService(pages: [])
        let viewModel = HomeViewModel(service: service, debounceMilliseconds: Constants.disabledDebounceMilliseconds)
        viewModel.query = "   "

        await viewModel.submitSearch()
        #expect(await service.calls.isEmpty)
        #expect(viewModel.species.isEmpty)
        #expect(!viewModel.hasSearched)
    }

    @MainActor
    @Test func homeViewModelDebouncesSearchInput() async throws {
        let service = MockPokemonService(pages: [
            PokemonSearchPage(
                results: [
                    PokemonSpeciesSearchResult(
                        id: Constants.pikachuSpeciesID,
                        name: "pikachu",
                        captureRate: Constants.pikachuCaptureRate,
                        colorName: "yellow",
                        pokemons: [PokemonSummary(id: Constants.pikachuSpeciesID, name: "pikachu", abilities: [])]
                    )
                ],
                limit: Constants.defaultPageLimit,
                offset: Constants.initialOffset
            )
        ])
        let viewModel = HomeViewModel(service: service, debounceMilliseconds: Constants.shortDebounceMilliseconds)
        viewModel.query = "pi"
        viewModel.query = "pik"
        viewModel.query = "pika"

        try await Task.sleep(for: .milliseconds(Constants.debounceSettleDelayMilliseconds))

        #expect(viewModel.species.map(\.name) == ["pikachu"])
        #expect(await service.calls == [PokemonSearchCall(name: "pika", limit: Constants.defaultPageLimit, offset: Constants.initialOffset)])
    }

    @MainActor
    @Test func homeViewModelClearsResultsWhenQueryBecomesEmpty() async throws {
        let service = MockPokemonService(pages: [
            PokemonSearchPage(
                results: [
                    PokemonSpeciesSearchResult(
                        id: Constants.pikachuSpeciesID,
                        name: "pikachu",
                        captureRate: Constants.pikachuCaptureRate,
                        colorName: "yellow",
                        pokemons: [PokemonSummary(id: Constants.pikachuSpeciesID, name: "pikachu", abilities: [])]
                    )
                ],
                limit: Constants.defaultPageLimit,
                offset: Constants.initialOffset
            )
        ])
        let viewModel = HomeViewModel(service: service, debounceMilliseconds: Constants.disabledDebounceMilliseconds)
        viewModel.query = "pika"
        await viewModel.submitSearch()
        #expect(viewModel.hasSearched)

        viewModel.query = ""
        try await Task.sleep(for: .milliseconds(Constants.clearResultsSettleDelayMilliseconds))

        #expect(viewModel.species.isEmpty)
        #expect(!viewModel.hasSearched)
    }

    @MainActor
    @Test func homeViewModelReportsServiceError() async throws {
        let service = MockPokemonService(error: PokemonServiceError.graphQLErrors(["boom"]))
        let viewModel = HomeViewModel(service: service, debounceMilliseconds: Constants.suppressDebounceMilliseconds)
        viewModel.query = "mew"

        await viewModel.submitSearch()

        #expect(viewModel.species.isEmpty)
        #expect(viewModel.errorMessage == "boom")
        #expect(viewModel.hasSearched)
    }

    @Test func pokemonDetailModelKeepsAbilities() {
        let pokemon = PokemonSummary(
            id: Constants.charizardSpeciesID,
            name: "charizard",
            abilities: [
                PokemonAbility(id: Constants.blazeAbilityID, name: "blaze"),
                PokemonAbility(id: Constants.solarPowerAbilityID, name: "solar-power")
            ]
        )

        #expect(pokemon.name == "charizard")
        #expect(pokemon.abilities.map(\.name) == ["blaze", "solar-power"])
    }
}

private struct PokemonSearchCall: Equatable, Sendable {
    let name: String
    let limit: Int
    let offset: Int
}

private actor RequestRecorder {
    private(set) var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }
}

private struct MockGraphQLTransport: GraphQLTransport {
    let statusCode: Int
    let data: Data
    let recorder: RequestRecorder

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        await recorder.record(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com/graphql")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private actor MockPokemonService: PokemonServicing {
    private(set) var calls: [PokemonSearchCall] = []
    private var pages: [PokemonSearchPage]
    private let error: (any Error)?

    init(pages: [PokemonSearchPage] = [], error: (any Error)? = nil) {
        self.pages = pages
        self.error = error
    }

    func searchSpecies(name: String, limit: Int, offset: Int) async throws -> PokemonSearchPage {
        calls.append(PokemonSearchCall(name: name, limit: limit, offset: offset))

        if let error {
            throw error
        }

        guard !pages.isEmpty else {
            return PokemonSearchPage(results: [], limit: limit, offset: offset)
        }

        return pages.removeFirst()
    }
}
