//
//  legalAcceptanceView.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 26/09/2026.
//

import SwiftUI
import NativeGrindCore

struct legalAcceptanceView: View {
    @ObservedObject var legal: legalController
    let onAccept: () -> Void

    @State private var isAdult = false
    @State private var agrees = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(legal.isUpdate ? "We've Updated Our Terms" : "Before You Start")
                    .font(.largeTitle.bold())

                Text(legal.isUpdate
                     ? "The Terms of Service or Privacy Policy for NativeServer have changed. Please read and accept them to keep using the app."
                     : "This version of NativeGrind uses NativeServer for sync and backups. Please read and accept the Terms of Service and Privacy Policy to continue.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    documentLink("Terms of Service", url: legal.termsURL)
                    documentLink("Privacy Policy", url: legal.privacyURL)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("I'm 18 or over", isOn: $isAdult)
                    Toggle("I've read and agree to the Terms of Service and Privacy Policy", isOn: $agrees)
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif

                Button {
                    legal.accept(confirmedAdult: isAdult)
                    onAccept()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!(isAdult && agrees))

                Text("If you don't want to use NativeServer, the standard build of NativeGrind doesn't need an account with us.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    @ViewBuilder
    private func documentLink(_ title: String, url: URL?) -> some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(url?.absoluteString ?? "").font(.caption).foregroundStyle(.secondary)
        }
        #else
        if let url {
            Link(destination: url) {
                Label("Read the \(title)", systemImage: "arrow.up.right.square")
            }
        }
        #endif
    }
}
