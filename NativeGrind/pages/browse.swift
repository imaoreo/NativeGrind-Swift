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
    
    @State private var nextPageNumber: Int? = nil
    @State private var activeTaskID = UUID()
    @State private var isLocationRequired = false
    
    #if os(tvOS)
    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 24)
    ]
    #elseif os(macOS)
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 8)
    ]
    #endif
    
    var body: some View {
        NavigationStack {
            Group {
                if isLocationRequired {
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Location Required")
                            .font(.headline)
                        Text("Please select a location to browse nearby profiles.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Button("Select Location") {
                            showLocation = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading && profiles == nil {
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
                                    Button {
                                        selectedProfile = profile
                                    } label: {
                                        gridCell(profile: profile)
                                            .aspectRatio(1, contentMode: .fit)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear {
                                        if profile.profileId == profiles.last?.profileId {
                                            loadNextPage()
                                        }
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .refreshable {
                            await loadGrid()
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
            #if !os(tvOS)
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
            .sheetWithToast(isPresented: $showFilters) {
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
            #endif
            .sheetWithToast(isPresented: $showLocation) {
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
            .sheetWithToast(item: $selectedProfile) { item in
                profileDetailView(profileId: String(item.profileId), profiles: profiles)
            }
            .sheetWithToast(item: $directProfileId) { item in
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
    
    private func loadNextPage() {
        guard nextPageNumber != nil, !isLoading else { return }
        Task {
            await loadGrid(isPagination: true)
        }
    }
    
    private func loadGrid(isPagination: Bool = false) async {
        let taskID = UUID()
        activeTaskID = taskID
        
        isLoading = true
        await locationController.shared.syncWithServer()
        let geohash = await locationController.shared.currentGeohash
        
        guard let geohash = geohash else {
            if activeTaskID == taskID {
                isLocationRequired = true
                isLoading = false
            }
            return
        }
        
        isLocationRequired = false
        var queryFilters = filters
        if isPagination {
            queryFilters.pageNumber = nextPageNumber
        } else {
            queryFilters.pageNumber = nil
        }
        
        let response = await profileController.shared.fetchGrid(geohash: geohash, filters: queryFilters)
        
        guard activeTaskID == taskID else {
            return
        }
        
        if let response = response {
            if isPagination {
                if self.profiles == nil {
                    self.profiles = response.profiles
                } else {
                    let existingIds = Set(self.profiles?.map { $0.profileId } ?? [])
                    let newProfiles = response.profiles.filter { !existingIds.contains($0.profileId) }
                    self.profiles?.append(contentsOf: newProfiles)
                }
            } else {
                self.profiles = response.profiles
            }
            self.nextPageNumber = response.nextPage
        }
        isLoading = false
    }
}
