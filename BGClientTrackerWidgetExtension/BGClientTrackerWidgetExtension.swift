import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Refresh Intent

struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"
    static var description = IntentDescription("Refreshes the BG Client widget data")

    func perform() async throws -> some IntentResult {
        try? await Task.sleep(for: .milliseconds(50))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

#if os(iOS)
@available(iOSApplicationExtension, unavailable)
extension RefreshWidgetIntent: ForegroundContinuableIntent {}
#endif

// MARK: - API Response Models

struct BGClientResponse: Codable {
    let nodesOnline: Int
    let nodes: [BGNode]
}

struct BGNode: Codable, Identifiable {
    let nodeId: String
    let executionClient: String
    let consensusClient: String
    let blockNumber: Int?
    let isFollowingHead: Bool
    let nExecutionPeers: String
    let nConsensusPeers: String
    let cpuUsage: String
    let memoryUsage: String
    let storageUsage: String

    var id: String { nodeId }
}

// MARK: - API Service

struct BGClientAPIService {
    static func fetchNodes(owner: String) async throws -> BGClientResponse {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? owner
        guard let url = URL(string: "https://pool.mainnet.rpc.buidlguidl.com:48547/yournodes?owner=\(encodedOwner)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(BGClientResponse.self, from: data)
    }
}

// MARK: - Settings Manager (Widget Side)

struct WidgetSettings {
    private static let defaults = UserDefaults(suiteName: "group.com.buidlguidl.BGClientTracker") ?? UserDefaults.standard

    static var ownerAddress: String {
        defaults.string(forKey: "ownerAddress") ?? ""
    }

    static var selectedNodeId: String {
        defaults.string(forKey: "selectedNodeId") ?? ""
    }

    // Store the last shown node ID so widget can show it even if app clears selection
    static var lastShownNodeId: String {
        get {
            defaults.string(forKey: "widgetLastShownNodeId") ?? ""
        }
        set {
            defaults.set(newValue, forKey: "widgetLastShownNodeId")
        }
    }
}

// MARK: - Timeline Entry

struct BGClientEntry: TimelineEntry {
    let date: Date
    let nodeId: String
    let blockNumber: String
    let isFollowingHead: Bool
    let isOffline: Bool  // Node completely disappeared from API
    let executionPeers: String
    let consensusPeers: String
    let cpuUsage: String
    let memoryUsage: String
    let storageUsage: String
    let hasError: Bool
    let needsSetup: Bool
}

// MARK: - Timeline Provider

struct BGClientProvider: TimelineProvider {
    func placeholder(in context: Context) -> BGClientEntry {
        BGClientEntry(
            date: Date(),
            nodeId: "my-node",
            blockNumber: "24,000,000",
            isFollowingHead: true,
            isOffline: false,
            executionPeers: "95",
            consensusPeers: "149",
            cpuUsage: "15.0",
            memoryUsage: "58.0",
            storageUsage: "79.0",
            hasError: false,
            needsSetup: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BGClientEntry) -> ()) {
        if context.isPreview {
            let entry = placeholder(in: context)
            completion(entry)
        } else {
            Task {
                let entry = await fetchData()
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BGClientEntry>) -> ()) {
        Task {
            let entry = await fetchData()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: entry.date)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchData() async -> BGClientEntry {
        let currentDate = Date()
        let ownerAddress = WidgetSettings.ownerAddress
        let selectedNodeId = WidgetSettings.selectedNodeId

        // Use selected node ID, or fall back to last shown node ID
        let nodeIdToShow = !selectedNodeId.isEmpty ? selectedNodeId : WidgetSettings.lastShownNodeId

        // Check if setup is needed
        guard !ownerAddress.isEmpty else {
            return BGClientEntry(
                date: currentDate,
                nodeId: "",
                blockNumber: "",
                isFollowingHead: false,
                isOffline: false,
                executionPeers: "",
                consensusPeers: "",
                cpuUsage: "",
                memoryUsage: "",
                storageUsage: "",
                hasError: false,
                needsSetup: true
            )
        }

        do {
            let response = try await BGClientAPIService.fetchNodes(owner: ownerAddress)

            // Check if the node we want to show is in the response
            let targetNode = response.nodes.first { $0.nodeId == nodeIdToShow }

            // If target node is not found but we have a node ID, the node is offline
            if targetNode == nil && !nodeIdToShow.isEmpty {
                // Node is offline - show offline state with the stored node ID
                return BGClientEntry(
                    date: currentDate,
                    nodeId: nodeIdToShow,
                    blockNumber: "—",
                    isFollowingHead: false,
                    isOffline: true,
                    executionPeers: "—",
                    consensusPeers: "—",
                    cpuUsage: "—",
                    memoryUsage: "—",
                    storageUsage: "—",
                    hasError: false,
                    needsSetup: false
                )
            }

            // If no target node and API returns empty (all nodes offline)
            if response.nodes.isEmpty {
                // Use last shown node ID if available
                let offlineNodeId = !WidgetSettings.lastShownNodeId.isEmpty ? WidgetSettings.lastShownNodeId : "Unknown node"
                return BGClientEntry(
                    date: currentDate,
                    nodeId: offlineNodeId,
                    blockNumber: "—",
                    isFollowingHead: false,
                    isOffline: true,
                    executionPeers: "—",
                    consensusPeers: "—",
                    cpuUsage: "—",
                    memoryUsage: "—",
                    storageUsage: "—",
                    hasError: false,
                    needsSetup: false
                )
            }

            // Use target node or fall back to first available node
            let node = targetNode ?? response.nodes.first

            guard let node = node else {
                // No nodes at all (shouldn't reach here due to check above)
                return BGClientEntry(
                    date: currentDate,
                    nodeId: "",
                    blockNumber: "",
                    isFollowingHead: false,
                    isOffline: true,
                    executionPeers: "",
                    consensusPeers: "",
                    cpuUsage: "",
                    memoryUsage: "",
                    storageUsage: "",
                    hasError: true,
                    needsSetup: false
                )
            }

            // Save the node ID we're showing so we can use it if node goes offline
            WidgetSettings.lastShownNodeId = node.nodeId

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let blockFormatted: String
            if let blockNum = node.blockNumber {
                blockFormatted = formatter.string(from: NSNumber(value: blockNum)) ?? "\(blockNum)"
            } else {
                blockFormatted = "---"
            }

            return BGClientEntry(
                date: currentDate,
                nodeId: node.nodeId,
                blockNumber: blockFormatted,
                isFollowingHead: node.isFollowingHead,
                isOffline: false,
                executionPeers: node.nExecutionPeers,
                consensusPeers: node.nConsensusPeers,
                cpuUsage: node.cpuUsage,
                memoryUsage: node.memoryUsage,
                storageUsage: node.storageUsage,
                hasError: false,
                needsSetup: false
            )
        } catch {
            print("Widget API Error: \(error)")
            return BGClientEntry(
                date: currentDate,
                nodeId: selectedNodeId,
                blockNumber: "—",
                isFollowingHead: false,
                isOffline: false,
                executionPeers: "—",
                consensusPeers: "—",
                cpuUsage: "—",
                memoryUsage: "—",
                storageUsage: "—",
                hasError: true,
                needsSetup: false
            )
        }
    }
}

// MARK: - Widget Entry View

struct BGClientWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: BGClientProvider.Entry

    var body: some View {
        Group {
            if entry.needsSetup {
                setupNeededView
            } else {
                switch family {
                case .systemMedium:
                    mediumWidget
                default:
                    smallWidget
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.10, green: 0.06, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Setup Needed View
    var setupNeededView: some View {
        VStack(spacing: 8) {
            Image("BGLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            Text("Setup Required")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Open app to configure")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
    }

    // Status color based on node state
    var statusColor: Color {
        if entry.isOffline {
            return .red
        } else if entry.isFollowingHead {
            return .green
        } else {
            return .orange
        }
    }

    // Status text based on node state
    var statusText: String {
        if entry.isOffline {
            return "Offline"
        } else if entry.isFollowingHead {
            return "Synced"
        } else {
            return "Syncing"
        }
    }

    // MARK: - Small Widget
    var smallWidget: some View {
        ZStack {
            // BG Logo - upper right corner
            VStack {
                HStack {
                    Spacer()
                    Image("BGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                Spacer()
            }
            .padding(.top, -10)
            .padding(.trailing, -10)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor, radius: 3)

                    Text(statusText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                // Node ID
                Text(shortenNodeId(entry.nodeId))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.isOffline ? .white.opacity(0.6) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()
                    .frame(height: 4)

                // Block number (or offline message)
                if entry.isOffline {
                    Text("Node is down")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.cyan.opacity(0.8))
                        Text(entry.blockNumber)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer()

                // Timestamp
                Text(entry.date, style: .time)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Refresh button - bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(intent: RefreshWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Medium Widget
    var mediumWidget: some View {
        ZStack {
            // BG Logo - upper right corner
            VStack {
                HStack {
                    Spacer()
                    Image("BGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                Spacer()
            }
            .padding(.top, -10)
            .padding(.trailing, -10)

            // Main content
            HStack(alignment: .center, spacing: 0) {
                // Left side - Node info
                VStack(alignment: .leading, spacing: 6) {
                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor, radius: 3)

                        Text(statusText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(statusColor)
                    }

                    // Node ID
                    Text(shortenNodeId(entry.nodeId))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.isOffline ? .white.opacity(0.6) : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if entry.isOffline {
                        // Offline message
                        Text("Node is down")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.red.opacity(0.8))

                        Text("Check your node")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        // Block number
                        HStack(spacing: 4) {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.cyan.opacity(0.8))
                            Text(entry.blockNumber)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        // Peers
                        HStack(spacing: 10) {
                            HStack(spacing: 3) {
                                Image(systemName: "network")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.cyan.opacity(0.8))
                                Text("\(entry.executionPeers)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            HStack(spacing: 3) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.purple.opacity(0.8))
                                Text("\(entry.consensusPeers)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }

                    // Timestamp
                    Text(entry.date, style: .time)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1)
                    .frame(maxHeight: 70)

                // Right side - Resource usage or offline indicator
                if entry.isOffline {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.red.opacity(0.8))

                        Text("Restart\nRequired")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 12)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resources")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        // CPU
                        ResourceBarWidget(label: "CPU", value: entry.cpuUsage, color: .cyan)

                        // Memory
                        ResourceBarWidget(label: "MEM", value: entry.memoryUsage, color: .purple)

                        // Storage
                        ResourceBarWidget(label: "DISK", value: entry.storageUsage, color: .orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                }
            }

            // Refresh button - bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(intent: RefreshWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // Helper to shorten node ID for display
    func shortenNodeId(_ nodeId: String) -> String {
        if nodeId.count > 20 {
            let prefix = String(nodeId.prefix(16))
            return "\(prefix)..."
        }
        return nodeId
    }
}

// MARK: - Resource Bar Widget

struct ResourceBarWidget: View {
    let label: String
    let value: String
    let color: Color

    var numericValue: Double {
        Double(value) ?? 0
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 28, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(numericValue / 100, 1.0))
                }
            }
            .frame(height: 4)

            Text("\(value)%")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Widget Declaration

struct BGClientTrackerWidget: Widget {
    let kind: String = "BGClientTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BGClientProvider()) { entry in
            BGClientWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BG Client")
        .description("Track your BuidlGuidl Ethereum node status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

struct BGClientTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "blubbo-NUC10i7FNH",
                    blockNumber: "24,003,850",
                    isFollowingHead: true,
                    isOffline: false,
                    executionPeers: "95",
                    consensusPeers: "149",
                    cpuUsage: "16.9",
                    memoryUsage: "58.1",
                    storageUsage: "79.6",
                    hasError: false,
                    needsSetup: false
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Synced")

            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "blubbo-NUC10i7FNH",
                    blockNumber: "24,003,850",
                    isFollowingHead: false,
                    isOffline: false,
                    executionPeers: "95",
                    consensusPeers: "149",
                    cpuUsage: "16.9",
                    memoryUsage: "58.1",
                    storageUsage: "79.6",
                    hasError: false,
                    needsSetup: false
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Syncing")

            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "blubbo-NUC10i7FNH",
                    blockNumber: "—",
                    isFollowingHead: false,
                    isOffline: true,
                    executionPeers: "—",
                    consensusPeers: "—",
                    cpuUsage: "—",
                    memoryUsage: "—",
                    storageUsage: "—",
                    hasError: false,
                    needsSetup: false
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Offline")

            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "blubbo-NUC10i7FNH",
                    blockNumber: "24,003,850",
                    isFollowingHead: true,
                    isOffline: false,
                    executionPeers: "95",
                    consensusPeers: "149",
                    cpuUsage: "16.9",
                    memoryUsage: "58.1",
                    storageUsage: "79.6",
                    hasError: false,
                    needsSetup: false
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Synced")

            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "blubbo-NUC10i7FNH",
                    blockNumber: "—",
                    isFollowingHead: false,
                    isOffline: true,
                    executionPeers: "—",
                    consensusPeers: "—",
                    cpuUsage: "—",
                    memoryUsage: "—",
                    storageUsage: "—",
                    hasError: false,
                    needsSetup: false
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Offline")

            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "",
                    blockNumber: "",
                    isFollowingHead: false,
                    isOffline: false,
                    executionPeers: "",
                    consensusPeers: "",
                    cpuUsage: "",
                    memoryUsage: "",
                    storageUsage: "",
                    hasError: false,
                    needsSetup: true
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Setup Needed")
        }
    }
}
