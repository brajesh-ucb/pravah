//
//  ContentView.swift
//  pravah
//
//  Created by Brajesh Kumar on 11/3/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isPresentingCapture = false
    @State private var entries: [JournalEntry] = []
    @State private var vault = VaultActor()
    @State private var navigationPath: [JournalEntry] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    SearchField(text: $searchText)
                    tabPicker
                    tabContent
                }
                AddEntryButton { isPresentingCapture = true }
                    .padding(20)
            }
            .navigationTitle("Pravah")
            .navigationDestination(for: JournalEntry.self) { EntryDetailView(entry: $0) }
            .sheet(isPresented: $isPresentingCapture) {
                QuickCaptureSheet(onSave: { Task { await loadVaultEntries() } })
            }
            .task { await loadVaultEntries() }
        }
    }

    private func loadVaultEntries() async {
        entries = (try? await vault.fetchAllEntries()) ?? []
    }

    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            Text("Timeline").tag(0)
            Text("Map").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredEntries: [JournalEntry] {
        let query = trimmedSearchText
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            let searchableFields = [entry.title, entry.body, entry.locationName ?? ""] + entry.tags
            return searchableFields.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if filteredEntries.isEmpty && !trimmedSearchText.isEmpty {
            ContentUnavailableView(
                "No entries matching '\(searchText)'",
                systemImage: "magnifyingglass"
            )
        } else if selectedTab == 0 {
            TimelineListView(entries: filteredEntries)
        } else {
            MapView(entries: filteredEntries) { navigationPath.append($0) }
        }
    }
}

struct MapPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Interactive Map View",
            systemImage: "map",
            description: Text("Geotagged notes will cluster here.")
        )
    }
}

struct AddEntryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .padding(8)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Add entry")
    }
}

#Preview {
    ContentView()
}
