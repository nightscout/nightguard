//
//  LogsView.swift
//  nightguard
//
//  SwiftUI view to display application logs
//

import SwiftUI
import UIKit

struct LogsView: View {
    @ObservedObject private var logger = AppLogger.singleton
    @State private var selectedLevel: AppLogger.LogEntry.LogLevel? = nil
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selectedLevel == nil) {
                        selectedLevel = nil
                    }
                    FilterChip(title: "Debug", isSelected: selectedLevel == .debug) {
                        selectedLevel = .debug
                    }
                    FilterChip(title: "Info", isSelected: selectedLevel == .info) {
                        selectedLevel = .info
                    }
                    FilterChip(title: "Warning", isSelected: selectedLevel == .warning) {
                        selectedLevel = .warning
                    }
                    FilterChip(title: "Error", isSelected: selectedLevel == .error) {
                        selectedLevel = .error
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            Divider()

            // Log list
            if filteredLogs.isEmpty {
                Spacer()
                Text("No logs to display")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { logger.clearLogs() }) {
                    Image(systemName: "trash")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search logs")
    }

    private var filteredLogs: [AppLogger.LogEntry] {
        logger.logs.filter { entry in
            let matchesLevel = selectedLevel == nil || entry.level == selectedLevel
            let matchesSearch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }.reversed()
    }
}

struct LogEntryRow: View {
    let entry: AppLogger.LogEntry
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formattedTime(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.level.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.2))
                    .foregroundColor(levelColor)
                    .cornerRadius(4)
                Button(action: copyToClipboard) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(showCopied ? .green : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.vertical, 4)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = "[\(formattedTime(entry.timestamp))] [\(entry.level.rawValue)] \(entry.message)"
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.nightguardAccent : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        LogsView()
    }
    .navigationViewStyle(StackNavigationViewStyle())
}