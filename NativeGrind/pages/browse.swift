//
//  browse.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 15/06/2026.
//

import SwiftUI
import NativeGrindCore

struct browseView: View {
    @State private var profiles: [CascadeResponseProfile]? = nil
    @State private var isLoading = false
    
    @State private var showFilters = false
    @State private var showLocation = false
    @State private var selectedProfile: CascadeResponseProfile? = nil
    @State private var filters = GridFilters()
    
    @State private var showProfileIdPrompt = false
    @State private var inputProfileId = ""
    @State private var directProfileId: identifiableId? = nil
    
    #if os(macOS)
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 8)
    ]
    #endif
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && profiles == nil {
                    ProgressView("Loading Grid...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profiles = profiles {
                    if profiles.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.sequence")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No profiles found nearby.")
                                .font(.headline)
                            Text("Try changing your filter settings.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Button("Reset Filters") {
                                filters = GridFilters()
                                applyFilters()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(profiles, id: \.profileId) { profile in
                                    gridCell(profile: profile)
                                        .aspectRatio(1, contentMode: .fit)
                                        .onTapGesture {
                                            selectedProfile = profile
                                        }
                                }
                            }
                            .padding(8)
                        }
                        .refreshable {
                            await loadGrid(contentLoaded: true)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Failed to load profiles")
                            .font(.headline)
                        Button("Retry") {
                            Task {
                                await loadGrid()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Browse")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button {
                            showFilters.toggle()
                        } label: {
                            Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        
                        Button {
                            showLocation.toggle()
                        } label: {
                            Image(systemName: showLocation ? "location.fill" : "location")
                        }
                        
                        Button {
                            showProfileIdPrompt = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Button {
                            Task {
                                await loadGrid()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                filterView(
                    filters: filters,
                    onApply: { newFilters in
                        filters = newFilters
                        showFilters = false
                        applyFilters()
                    },
                    onCancel: {
                        showFilters = false
                    }
                )
                #if os(macOS)
                .frame(width: 300, height: 250)
                #endif
            }
            .sheet(isPresented: $showLocation) {
                LocationView(
                    onApply: {
                        showLocation = false
                        applyFilters()
                    },
                    onCancel: {
                        showLocation = false
                    }
                )
                #if os(macOS)
                .frame(width: 450, height: 350)
                #endif
            }
            .sheet(item: $selectedProfile) { item in
                profileDetailView(profileId: String(item.profileId))
            }
            .sheet(item: $directProfileId) { item in
                profileDetailView(profileId: item.id)
            }
            .alert("Enter Profile ID", isPresented: $showProfileIdPrompt) {
                TextField("Profile ID", text: $inputProfileId)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                Button("Open") {
                    let trimmed = inputProfileId.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        directProfileId = identifiableId(id: trimmed)
                    }
                    inputProfileId = ""
                }
                Button("Cancel", role: .cancel) {
                    inputProfileId = ""
                }
            } message: {
                Text("Please enter the profile ID you want to view.")
            }
            .task {
                if profiles == nil {
                    await loadGrid()
                }
            }
        }
    }
    
    private func applyFilters() {
        Task {
            await loadGrid()
        }
    }
    
    private func loadGrid(contentLoaded: Bool = false) async {
        if (isLoading) {
            return
        }
        
        isLoading = true
        let geohash = await locationController.shared.currentGeohash
        
        if let geohash = geohash {
            profiles = await profileController.shared.fetchGrid(geohash: geohash, filters: filters)
        }
        isLoading = false
    }
}
