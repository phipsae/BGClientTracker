//
//  ContentView.swift
//  BGClientTracker
//
//  Created by Philip on 04.12.25.
//

import SwiftUI
import WidgetKit
import Combine

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

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // Use App Group for widget sharing
    private let defaults = UserDefaults(suiteName: "group.com.buidlguidl.BGClientTracker") ?? UserDefaults.standard

    @Published var ownerAddress: String {
        didSet {
            defaults.set(ownerAddress, forKey: "ownerAddress")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var selectedNodeId: String {
        didSet {
            defaults.set(selectedNodeId, forKey: "selectedNodeId")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var hasCompletedSetup: Bool {
        didSet {
            defaults.set(hasCompletedSetup, forKey: "hasCompletedSetup")
        }
    }

    init() {
        self.ownerAddress = defaults.string(forKey: "ownerAddress") ?? ""
        self.selectedNodeId = defaults.string(forKey: "selectedNodeId") ?? ""
        self.hasCompletedSetup = defaults.bool(forKey: "hasCompletedSetup")
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        if settings.hasCompletedSetup && !settings.ownerAddress.isEmpty {
            NodeDashboardView()
                .environmentObject(settings)
        } else {
            SetupView()
                .environmentObject(settings)
        }
    }
}

// MARK: - Setup View

struct SetupView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var inputAddress: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.10, green: 0.06, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated grid pattern
            GeometryReader { geo in
                Canvas { context, size in
                    for i in stride(from: 0, to: size.width, by: 50) {
                        for j in stride(from: 0, to: size.height, by: 50) {
                            let rect = CGRect(x: i, y: j, width: 1.5, height: 1.5)
                            context.fill(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.08)))
                        }
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo with glow
                ZStack {
                    Image("BGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .blur(radius: 40)
                        .opacity(0.5)

                    Image("BGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer()
                    .frame(height: 30)

                // Title
                VStack(spacing: 6) {
                    Text("BG Client Tracker")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.6, green: 0.9, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Monitor your Ethereum node")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 40)

                // Input card
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your address")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            Image(systemName: "wallet.pass")
                                .font(.system(size: 16))
                                .foregroundStyle(.cyan)

                            TextField("ENS name or ETH address", text: $inputAddress)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )

                        Text("e.g., phipsae.eth or 0x123...")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange.opacity(0.15))
                        )
                    }

                    Button(action: validateAndContinue) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Connect")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.5, blue: 0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .cyan.opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(inputAddress.isEmpty || isLoading)
                    .opacity(inputAddress.isEmpty ? 0.6 : 1.0)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .white.opacity(0.03)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .opacity(contentOpacity)
                .padding(.horizontal, 24)

                Spacer()

                // Footer
                Text("Track your BuidlGuidl node status")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .opacity(contentOpacity)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                contentOpacity = 1.0
            }
        }
    }

    private func validateAndContinue() {
        guard !inputAddress.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await BGClientAPIService.fetchNodes(owner: inputAddress)

                await MainActor.run {
                    isLoading = false

                    if response.nodes.isEmpty {
                        errorMessage = "No nodes found for this address"
                    } else {
                        settings.ownerAddress = inputAddress
                        settings.selectedNodeId = response.nodes.first?.nodeId ?? ""
                        settings.hasCompletedSetup = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to fetch nodes. Check your address."
                }
            }
        }
    }
}

// MARK: - Node Dashboard View

struct NodeDashboardView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var nodes: [BGNode] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date = Date()
    @State private var showingSettings: Bool = false

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.08),
                        Color(red: 0.06, green: 0.04, blue: 0.12),
                        Color(red: 0.10, green: 0.06, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Grid pattern
                GeometryReader { geo in
                    Canvas { context, size in
                        for i in stride(from: 0, to: size.width, by: 50) {
                            for j in stride(from: 0, to: size.height, by: 50) {
                                let rect = CGRect(x: i, y: j, width: 1.5, height: 1.5)
                                context.fill(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.05)))
                            }
                        }
                    }
                }
                .ignoresSafeArea()

                if isLoading && nodes.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(1.2)
                        Text("Loading nodes...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else if let error = errorMessage, nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            fetchNodes()
                        }
                        .foregroundStyle(.cyan)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header info
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Owner")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text(settings.ownerAddress)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                        .lineLimit(1)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Nodes Online")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("\(nodes.filter { $0.isFollowingHead }.count)/\(nodes.count)")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )

                            // Node cards
                            ForEach(nodes) { node in
                                NodeCardView(node: node, isSelected: node.nodeId == settings.selectedNodeId)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.selectedNodeId = node.nodeId
                                        }
                                    }
                            }

                            // Last updated
                            Text("Last updated: \(lastUpdated, style: .time)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 8)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { fetchNodes() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.cyan)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("BGLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("BG Client Tracker")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
                    .environmentObject(settings)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            fetchNodes()
        }
        .onReceive(refreshTimer) { _ in
            fetchNodes()
        }
    }

    private func fetchNodes() {
        guard !settings.ownerAddress.isEmpty else { return }

        isLoading = true

        Task {
            do {
                let response = try await BGClientAPIService.fetchNodes(owner: settings.ownerAddress)

                await MainActor.run {
                    nodes = response.nodes
                    lastUpdated = Date()
                    isLoading = false
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if nodes.isEmpty {
                        errorMessage = "Failed to fetch node data"
                    }
                }
            }
        }
    }
}

// MARK: - Node Card View

struct NodeCardView: View {
    let node: BGNode
    let isSelected: Bool

    var statusColor: Color {
        node.isFollowingHead ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack {
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: statusColor, radius: 4)

                    Text(node.isFollowingHead ? "Synced" : "Syncing")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.15))
                )

                Spacer()

                // Selection indicator
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Widget")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.cyan.opacity(0.15))
                    )
                }
            }

            // Node ID
            Text(node.nodeId)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            // Block number
            HStack(spacing: 6) {
                Image(systemName: "cube.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.cyan.opacity(0.8))
                Text("Block #\(formatNumber(node.blockNumber))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Divider()
                .background(.white.opacity(0.1))

            // Clients info
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Execution")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(node.executionClient)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Consensus")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(node.consensusClient)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Divider()
                .background(.white.opacity(0.1))

            // Peers
            HStack(spacing: 20) {
                StatPill(icon: "network", label: "EL Peers", value: node.nExecutionPeers)
                StatPill(icon: "antenna.radiowaves.left.and.right", label: "CL Peers", value: node.nConsensusPeers)
            }

            // Resource usage
            HStack(spacing: 12) {
                ResourceBar(label: "CPU", value: Double(node.cpuUsage) ?? 0, color: .cyan)
                ResourceBar(label: "MEM", value: Double(node.memoryUsage) ?? 0, color: .purple)
                ResourceBar(label: "DISK", value: Double(node.storageUsage) ?? 0, color: .orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
        )
        .shadow(color: isSelected ? .cyan.opacity(0.2) : .clear, radius: 10)
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.cyan.opacity(0.8))
            Text("\(label): \(value)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Resource Bar

struct ResourceBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(value / 100, 1.0))
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) var dismiss
    @State private var newAddress: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.10)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Current owner section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Owner")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))

                        Text(settings.ownerAddress)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.05))
                            )
                    }

                    Divider()
                        .background(.white.opacity(0.1))

                    // Change owner section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Change Owner Address")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))

                        TextField("New ENS or ETH address", text: $newAddress)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.orange)
                        }

                        Button(action: updateOwner) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Update")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.cyan.opacity(0.8))
                            )
                        }
                        .disabled(newAddress.isEmpty || isLoading)
                        .opacity(newAddress.isEmpty ? 0.5 : 1.0)
                    }

                    Spacer()

                    // Widget instructions
                    VStack(spacing: 12) {
                        Text("Widget Instructions")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))

                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(step: "1", icon: "hand.tap", text: "Long press on Home Screen")
                            InstructionRow(step: "2", icon: "plus.circle", text: "Tap + button")
                            InstructionRow(step: "3", icon: "magnifyingglass", text: "Search \"BG Client\"")
                            InstructionRow(step: "4", icon: "checkmark.circle.fill", text: "Add Widget")
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.03))
                    )
                }
                .padding(20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func updateOwner() {
        guard !newAddress.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await BGClientAPIService.fetchNodes(owner: newAddress)

                await MainActor.run {
                    isLoading = false

                    if response.nodes.isEmpty {
                        errorMessage = "No nodes found for this address"
                    } else {
                        settings.ownerAddress = newAddress
                        settings.selectedNodeId = response.nodes.first?.nodeId ?? ""
                        newAddress = ""
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to verify address"
                }
            }
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let step: String
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Text(step)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.cyan.opacity(0.8))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
