import SwiftUI
import WindowKit

struct HomeView: View {
    private enum Constants {
        static let stackSpacing: CGFloat = 16
        static let loadingStackSpacing: CGFloat = 12
        static let loadingIconSize: CGFloat = 48
        static let emptyStateIconSize: CGFloat = 56
        static let emptyStateSpacing: CGFloat = 16
        static let resultsStackSpacing: CGFloat = 12
        static let loadMoreVerticalPadding: CGFloat = 8
        static let scrollVerticalPadding: CGFloat = 4
        static let searchControlSpacing: CGFloat = 8
        static let searchFieldPadding: CGFloat = 10
        static let searchFieldCornerRadius: CGFloat = 10
        static let searchFieldStrokeOpacity: Double = 0.25
        static let emptyPlaceholderIconName = "sparkles"
        static let emptyPlaceholderMessage = "No searched Pokemons yet, discover your favorites now!"
    }

    @StateObject private var viewModel: HomeViewModel
    @FocusState private var isSearchFieldFocused: Bool

    private var showsWindowLoadingOverlay: Bool {
        viewModel.isSearching && !viewModel.species.isEmpty
    }

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.stackSpacing) {
                searchControls

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Pokémon Search")
            .navigationDestination(for: PokemonSummary.self) { pokemon in
                DetailView(pokemon: pokemon)
            }
        }
        .windowOverlay(nil, content: {
            if showsWindowLoadingOverlay {
                SearchLoadingWindowOverlay()
            }
        }, configure: { config in
            config.tintColor = .clear
        })
    }

    private var searchControls: some View {
        HStack(spacing: Constants.searchControlSpacing) {
            TextField("Search species name", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    isSearchFieldFocused = false
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearSearch()
                    isSearchFieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Constants.searchFieldPadding)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Constants.searchFieldCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.searchFieldCornerRadius)
                .stroke(Color.secondary.opacity(Constants.searchFieldStrokeOpacity))
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching && viewModel.species.isEmpty {
            fullScreenLoading
        } else if let errorMessage = viewModel.errorMessage, viewModel.species.isEmpty, !viewModel.isSearching {
            ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
        } else if viewModel.hasSearched && viewModel.species.isEmpty, !viewModel.isSearching {
            ContentUnavailableView("No Pokémon Found", systemImage: "magnifyingglass", description: Text("Try another species name."))
        } else if !viewModel.species.isEmpty {
            resultsList
        } else {
            emptyPlaceholder
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: Constants.emptyStateSpacing) {
            Spacer()

            Image(systemName: Constants.emptyPlaceholderIconName)
                .font(.system(size: Constants.emptyStateIconSize))
                .foregroundStyle(.secondary)

            Text(Constants.emptyPlaceholderMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fullScreenLoading: some View {
        VStack {
            Spacer()
            loadingIndicator
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingIndicator: some View {
        VStack(spacing: Constants.loadingStackSpacing) {
            Image(systemName: "hourglass.circle")
                .font(.system(size: Constants.loadingIconSize))
                .symbolEffect(.pulse)
            ProgressView("Loading Pokémon...")
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: Constants.resultsStackSpacing) {
                ForEach(viewModel.species) { species in
                    PokemonSpeciesCard(species: species)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewModel.hasMoreResults {
                    Button {
                        Task { await viewModel.loadNextPage() }
                    } label: {
                        if viewModel.isLoadingNextPage {
                            ProgressView()
                        } else {
                            Text("Load More")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoadingNextPage)
                    .padding(.vertical, Constants.loadMoreVerticalPadding)
                }
            }
            .padding(.vertical, Constants.scrollVerticalPadding)
        }
    }
}

private struct PokemonSpeciesCard: View {
    private enum Constants {
        static let stackSpacing: CGFloat = 12
        static let titleStackSpacing: CGFloat = 4
        static let colorBadgeHorizontalPadding: CGFloat = 8
        static let colorBadgeVerticalPadding: CGFloat = 4
        static let pokemonRowPadding: CGFloat = 10
        static let pokemonRowCornerRadius: CGFloat = 10
        static let cardCornerRadius: CGFloat = 16
        static let strokeOpacity: Double = 0.25
    }

    let species: PokemonSpeciesSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.stackSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: Constants.titleStackSpacing) {
                    Text(species.name)
                        .font(.headline)
                    Text("Capture rate: \(species.captureRate)")
                        .font(.subheadline)
                }

                Spacer()

                Text(species.colorName)
                    .font(.caption)
                    .padding(.horizontal, Constants.colorBadgeHorizontalPadding)
                    .padding(.vertical, Constants.colorBadgeVerticalPadding)
                    .background(.thinMaterial, in: Capsule())
            }

            if species.pokemons.isEmpty {
                Text("No Pokémon entries")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(species.pokemons) { pokemon in
                    NavigationLink(value: pokemon) {
                        HStack {
                            Text(pokemon.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(Constants.pokemonRowPadding)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Constants.pokemonRowCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .foregroundStyle(PokemonColorPalette.foregroundColor(for: species.colorName))
        .background(PokemonColorPalette.color(for: species.colorName), in: RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
                .stroke(Color.secondary.opacity(Constants.strokeOpacity))
        )
    }
}
