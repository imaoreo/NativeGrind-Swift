//
//  chatComposer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatComposerActions {
    var send: () -> Void
    var cancelReply: () -> Void
    var sendLocation: () -> Void
    var pickMedia: (() -> Void)?
    var chooseFile: (() -> Void)?
    var startRecording: (() -> Void)?
    var cancelRecording: () -> Void
    var finishRecording: () -> Void
}

struct chatComposer: View {
    @Binding var draft: String
    let isSending: Bool
    let replyingTo: chatMessage?
    let recordingStartedAt: Date?
    let actions: chatComposerActions

    private var hasText: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        !isSending && hasText
    }

    private let iconSize: CGFloat = 30

    var body: some View {
        VStack(spacing: 8) {
            if let replyingTo {
                replyBanner(for: replyingTo)
            }

            if let recordingStartedAt {
                recordingRow(startedAt: recordingStartedAt)
            } else {
                inputRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        #if !os(tvOS)
        .background(.bar)
        #endif
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func replyBanner(for message: chatMessage) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(message.summaryText)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: actions.cancelReply) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Menu {
                if let pickMedia = actions.pickMedia {
                    Button(action: pickMedia) {
                        Label("Photo or Video", systemImage: "photo.on.rectangle")
                    }
                }
                if let chooseFile = actions.chooseFile {
                    Button(action: chooseFile) {
                        Label("Choose File…", systemImage: "folder")
                    }
                }
                Button(action: actions.sendLocation) {
                    Label("Send Location", systemImage: "location.fill")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color.gray.opacity(0.18), in: Circle())
            }
            .menuIndicator(.hidden)
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(isSending)

            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                #if !os(tvOS)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 17))
                #endif
                #if os(macOS)
                .focusEffectDisabled()
                #endif
                .onSubmit {
                    if canSend { actions.send() }
                }

            trailingButton
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isSending {
            ProgressView()
                .controlSize(.small)
                .frame(width: iconSize, height: iconSize)
        } else if !hasText, let startRecording = actions.startRecording {
            Button(action: startRecording) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: iconSize))
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            .help("Record Voice Message")
        } else {
            Button(action: actions.send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: iconSize))
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            .disabled(!canSend)
        }
    }

    private func recordingRow(startedAt: Date) -> some View {
        HStack(spacing: 12) {
            Button(action: actions.cancelRecording) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                    .monospacedDigit()
            }

            Text("Recording")
                .foregroundColor(.secondary)

            Spacer()

            Button(action: actions.finishRecording) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: iconSize))
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
        .frame(minHeight: 32)
    }
}
