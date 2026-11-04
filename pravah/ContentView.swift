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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    tabPicker
                    tabContent
                }
                AddEntryButton { }
                    .padding(20)
            }
            .navigationTitle("Pravah")
            .searchable(text: $searchText, prompt: "Search entries, places, tags...")
        }
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
            TimelineListView(entries: MockEntry.samples)
        } else {
            MapPlaceholderView()
        }
    }
}

struct MockEntry: Identifiable, Sendable {
    enum MediaType: String, Sendable {
        case photo = "photo"
        case audio = "waveform"
        case video = "video"
        case text = "text.alignleft"
    }

    let id = UUID()
    let title: String
    let date: Date
    let locationName: String
    let mediaType: MediaType

    static let samples: [MockEntry] = [
        MockEntry(
            title: "Sunrise at the ghats",
            date: .now.addingTimeInterval(-3_600),
            locationName: "Assi Ghat, Varanasi",
            mediaType: .photo
        ),
        MockEntry(
            title: "Street musician's melody",
            date: .now.addingTimeInterval(-86_400),
            locationName: "Chandni Chowk, Delhi",
            mediaType: .audio
        ),
        MockEntry(
            title: "Monsoon over the bay",
            date: .now.addingTimeInterval(-259_200),
            locationName: "Marine Drive, Mumbai",
            mediaType: .video
        )
    ]
}

struct TimelineListView: View {
    let entries: [MockEntry]

    var body: some View {
        List(entries) { entry in
            MockEntryCard(entry: entry)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct MockEntryCard: View {
    let entry: MockEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.mediaType.rawValue)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.date, format: .relative(presentation: .named))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(entry.locationName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 18))
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
