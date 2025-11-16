//
//  ContentView.swift
//  ArchiveQuickLook
//
//  Created by Michal Šára on 16.11.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("")
                .padding(.vertical)
            Image(systemName: "archivebox.fill")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(String(localized: "text.archive"))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "text.headline"))
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical)

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "text.formats"))
                    .font(.headline)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("ZIP (.zip)")
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("TAR (.tar, .tar.gz, .tgz, .tar.xz, .txz)")
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("GZIP (.gz)")
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("XZ (.xz)")
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)

            Divider()
                .padding(.vertical)

            VStack(spacing: 10) {
                Text(String(localized: "text.installed"))
                    .font(.headline)

                Text(String(localized: "text.instructions"))
                    .font(.subheadline)
                    .italic()
            }

            Spacer()

            Text(String(localized: "text.active"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
