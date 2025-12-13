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
    let blockNumber: Int
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
}

// MARK: - Timeline Entry

struct BGClientEntry: TimelineEntry {
    let date: Date
    let nodeId: String
    let blockNumber: String
    let isFollowingHead: Bool
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

        // Check if setup is needed
        guard !ownerAddress.isEmpty else {
            return BGClientEntry(
                date: currentDate,
                nodeId: "",
                blockNumber: "",
                isFollowingHead: false,
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

            // Find the selected node, or use the first one
            let node = response.nodes.first { $0.nodeId == selectedNodeId } ?? response.nodes.first

            guard let node = node else {
                return BGClientEntry(
                    date: currentDate,
                    nodeId: "",
                    blockNumber: "",
                    isFollowingHead: false,
                    executionPeers: "",
                    consensusPeers: "",
                    cpuUsage: "",
                    memoryUsage: "",
                    storageUsage: "",
                    hasError: true,
                    needsSetup: false
                )
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let blockFormatted = formatter.string(from: NSNumber(value: node.blockNumber)) ?? "\(node.blockNumber)"

            return BGClientEntry(
                date: currentDate,
                nodeId: node.nodeId,
                blockNumber: blockFormatted,
                isFollowingHead: node.isFollowingHead,
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
                        .fill(entry.isFollowingHead ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: entry.isFollowingHead ? .green : .orange, radius: 3)

                    Text(entry.isFollowingHead ? "Synced" : "Syncing")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.isFollowingHead ? .green : .orange)
                }

                // Node ID
                Text(shortenNodeId(entry.nodeId))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()
                    .frame(height: 4)

                // Block number
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
                            .fill(entry.isFollowingHead ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: entry.isFollowingHead ? .green : .orange, radius: 3)

                        Text(entry.isFollowingHead ? "Synced" : "Syncing")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(entry.isFollowingHead ? .green : .orange)
                    }

                    // Node ID
                    Text(shortenNodeId(entry.nodeId))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

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

                // Right side - Resource usage
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
                    blockNumber: "24,003,850",
                    isFollowingHead: true,
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
            .previewDisplayName("Medium")

            BGClientWidgetEntryView(
                entry: BGClientEntry(
                    date: Date(),
                    nodeId: "",
                    blockNumber: "",
                    isFollowingHead: false,
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
