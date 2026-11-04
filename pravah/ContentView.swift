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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    tabPicker
                    tabContent
                }
                AddEntryButton { isPresentingCapture = true }
                    .padding(20)
            }
            .navigationTitle("Pravah")
            .searchable(text: $searchText, prompt: "Search entries, places, tags...")
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

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            TimelineListView(entries: entries)
        } else {
            MapPlaceholderView()
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
