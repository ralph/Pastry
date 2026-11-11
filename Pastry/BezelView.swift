import AppKit
import SwiftUI

/// What the bezel shows: where the clip came from, when, its text, and how far
/// through the history it is.
struct BezelView: View {
    let clip: Clip?
    let position: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            text
            footer
        }
        .padding(20)
        .frame(width: 520, height: 280, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var header: some View {
        if let clip {
            HStack(spacing: 8) {
                if let icon = sourceIcon(for: clip) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                }
                Text(clip.appName ?? "Unknown app")
                    .font(.headline)
                Spacer()
                Text(clip.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var text: some View {
        ScrollView {
            Text(clip?.text ?? "Empty")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(clip == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.disabled)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        if count > 0 {
            Text("\(position + 1) of \(count)")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func sourceIcon(for clip: Clip) -> NSImage? {
        guard let url = clip.appBundleURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}
