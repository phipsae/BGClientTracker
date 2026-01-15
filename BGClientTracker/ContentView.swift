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
    let blockNumber: Int?
    let isFollowingHead: Bool
    let nExecutionPeers: String
    let nConsensusPeers: String
    let cpuUsage: String
    let memoryUsage: String
    let storageUsage: String

    var id: String { nodeId }
}

struct BGBRDBalanceResponse: Codable {
    let address: String
    let balance: String
}

struct PendingBreadResponse: Codable {
    let owner: String
    let bread: String
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

    static func fetchBGBRDBalance(owner: String) async throws -> BGBRDBalanceResponse {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? owner
        guard let url = URL(string: "https://bg-client-tracker-backend.vercel.app/balance?address=\(encodedOwner)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(BGBRDBalanceResponse.self, from: data)
    }

    static func fetchPendingBread(owner: String) async throws -> PendingBreadResponse {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? owner
        guard let url = URL(string: "https://pool.mainnet.rpc.buidlguidl.com:48546/yourpendingbread?owner=\(encodedOwner)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(PendingBreadResponse.self, from: data)
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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var inputAddress: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

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
                        .frame(width: isIPad ? 240 : 180, height: isIPad ? 240 : 180)
                        .blur(radius: 40)
                        .opacity(0.5)

                    Image("BGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 240 : 180, height: isIPad ? 240 : 180)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer()
                    .frame(height: isIPad ? 50 : 30)

                // Title
                VStack(spacing: isIPad ? 10 : 6) {
                    Text("BG Client Tracker")
                        .font(.system(size: isIPad ? 40 : 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.6, green: 0.9, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Monitor your Ethereum node")
                        .font(.system(size: isIPad ? 20 : 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: isIPad ? 60 : 40)

                // Input card
                VStack(spacing: isIPad ? 28 : 20) {
                    VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                        Text("Enter your address")
                            .font(.system(size: isIPad ? 17 : 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: isIPad ? 16 : 12) {
                            Image(systemName: "wallet.pass")
                                .font(.system(size: isIPad ? 20 : 16))
                                .foregroundStyle(.cyan)

                            TextField("ENS name or ETH address", text: $inputAddress)
                                .font(.system(size: isIPad ? 18 : 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(isIPad ? 18 : 14)
                        .background(
                            RoundedRectangle(cornerRadius: isIPad ? 14 : 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isIPad ? 14 : 12)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )

                        Text("e.g., phipsae.eth or 0x123...")
                            .font(.system(size: isIPad ? 14 : 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    if let error = errorMessage {
                        HStack(spacing: isIPad ? 8 : 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: isIPad ? 14 : 12))
                            Text(error)
                                .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                        .padding(.vertical, isIPad ? 12 : 8)
                        .padding(.horizontal, isIPad ? 16 : 12)
                        .background(
                            RoundedRectangle(cornerRadius: isIPad ? 10 : 8)
                                .fill(.orange.opacity(0.15))
                        )
                    }

                    Button(action: validateAndContinue) {
                        HStack(spacing: isIPad ? 10 : 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Connect")
                                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isIPad ? 18 : 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.5, blue: 0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(isIPad ? 14 : 12)
                        .shadow(color: .cyan.opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(inputAddress.isEmpty || isLoading)
                    .opacity(inputAddress.isEmpty ? 0.6 : 1.0)
                }
                .padding(isIPad ? 32 : 24)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 24 : 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: isIPad ? 24 : 20)
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
                .frame(maxWidth: isIPad ? 500 : .infinity)
                .padding(.horizontal, isIPad ? 40 : 24)

                Spacer()

                // Footer
                Text("Track your BuidlGuidl node status")
                    .font(.system(size: isIPad ? 16 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .opacity(contentOpacity)
                    .padding(.bottom, isIPad ? 50 : 30)
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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var nodes: [BGNode] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date = Date()
    @State private var showingSettings: Bool = false
    @State private var bgbrdBalance: String?
    @State private var pendingBread: String?
    @State private var isBakingAnimating: Bool = false

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Adaptive grid columns based on device
    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            // iPad - 2 or 3 columns depending on node count
            return nodes.count > 2
                ? [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
                : [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        } else {
            // iPhone - single column
            return [GridItem(.flexible())]
        }
    }

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationStack {
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
                            .font(.system(size: isIPad ? 18 : 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else if let error = errorMessage, nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: isIPad ? 60 : 40))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: isIPad ? 18 : 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            fetchNodes()
                        }
                        .font(.system(size: isIPad ? 18 : 16))
                        .foregroundStyle(.cyan)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: isIPad ? 28 : 20) {
                            // Header info - adaptive layout for iPad
                            if isIPad {
                                iPadHeaderView
                            } else {
                                iPhoneHeaderView
                            }

                            // Node cards in adaptive grid
                            LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 16) {
                                ForEach(nodes) { node in
                                    NodeCardView(node: node, isSelected: node.nodeId == settings.selectedNodeId, isIPad: isIPad)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3)) {
                                                settings.selectedNodeId = node.nodeId
                                            }
                                        }
                                }
                            }

                            // Last updated
                            Text("Last updated: \(lastUpdated, style: .time)")
                                .font(.system(size: isIPad ? 14 : 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 8)
                        }
                        .padding(isIPad ? 32 : 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { fetchNodes() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: isIPad ? 18 : 16))
                            .foregroundStyle(.cyan)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("BGLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: isIPad ? 32 : 24, height: isIPad ? 32 : 24)
                        Text("BG Client Tracker")
                            .font(.system(size: isIPad ? 22 : 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: isIPad ? 18 : 16))
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(isIPad: isIPad)
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

    // MARK: - iPad Header View
    private var iPadHeaderView: some View {
        HStack(spacing: 24) {
            // Owner info card
            VStack(alignment: .leading, spacing: 8) {
                Text("Owner")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(settings.ownerAddress)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            // BGBRD Balance card
            if let balance = bgbrdBalance {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BGBRD Balance")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Text("🍞")
                                .font(.system(size: 18))
                            Text("\(balance)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                        }

                        if let pending = pendingBread, let pendingValue = Double(pending), pendingValue > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "oven.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                                    .opacity(isBakingAnimating ? 1.0 : 0.6)
                                    .scaleEffect(isBakingAnimating ? 1.05 : 0.95)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBakingAnimating)
                                Text("+\(pending)")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.red.opacity(0.9))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.red.opacity(0.15))
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }

            // Nodes Online card
            VStack(alignment: .center, spacing: 8) {
                Text("Nodes Online")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(nodes.filter { $0.isFollowingHead }.count)/\(nodes.count)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }
            .frame(minWidth: 150)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - iPhone Header View
    private var iPhoneHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Owner")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(settings.ownerAddress)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)

                // BGBRD Balance
                if let balance = bgbrdBalance {
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Text("🍞")
                                .font(.system(size: 12))
                            Text("\(balance)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.orange)
                        }

                        if let pending = pendingBread, let pendingValue = Double(pending), pendingValue > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "oven.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                                    .opacity(isBakingAnimating ? 1.0 : 0.6)
                                    .scaleEffect(isBakingAnimating ? 1.05 : 0.95)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBakingAnimating)
                                Text("+\(pending)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.red.opacity(0.9))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.red.opacity(0.15))
                            )
                        }

                        Text("BGBRD")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                    .padding(.top, 2)
                }
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
    }

    private func fetchNodes() {
        guard !settings.ownerAddress.isEmpty else { return }

        isLoading = true

        Task {
            do {
                // Fetch nodes and balance in parallel first
                async let nodesResponse = BGClientAPIService.fetchNodes(owner: settings.ownerAddress)
                async let balanceResponse = BGClientAPIService.fetchBGBRDBalance(owner: settings.ownerAddress)

                let (nodeData, balanceData) = try await (nodesResponse, balanceResponse)

                // Use the resolved ETH address from balance response for pending bread
                let pendingData = try await BGClientAPIService.fetchPendingBread(owner: balanceData.address)

                await MainActor.run {
                    nodes = nodeData.nodes
                    bgbrdBalance = balanceData.balance
                    pendingBread = pendingData.bread
                    lastUpdated = Date()
                    isLoading = false
                    errorMessage = nil

                    // Start baking animation if there's pending bread
                    if let pending = Double(pendingData.bread), pending > 0 {
                        isBakingAnimating = true
                    }
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
    var isIPad: Bool = false

    var statusColor: Color {
        node.isFollowingHead ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 14) {
            // Header row
            HStack {
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: isIPad ? 12 : 10, height: isIPad ? 12 : 10)
                        .shadow(color: statusColor, radius: 4)

                    Text(node.isFollowingHead ? "Synced" : "Syncing")
                        .font(.system(size: isIPad ? 14 : 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, isIPad ? 12 : 10)
                .padding(.vertical, isIPad ? 6 : 5)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.15))
                )

                Spacer()

                // Selection indicator
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: isIPad ? 14 : 12))
                        Text("Widget")
                            .font(.system(size: isIPad ? 13 : 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, isIPad ? 10 : 8)
                    .padding(.vertical, isIPad ? 5 : 4)
                    .background(
                        Capsule()
                            .fill(.cyan.opacity(0.15))
                    )
                }
            }

            // Node ID
            Text(node.nodeId)
                .font(.system(size: isIPad ? 18 : 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Block number
            HStack(spacing: 6) {
                Image(systemName: "cube.fill")
                    .font(.system(size: isIPad ? 13 : 11))
                    .foregroundStyle(.cyan.opacity(0.8))
                Text("Block #\(node.blockNumber.map { formatNumber($0) } ?? "---")")
                    .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Divider()
                .background(.white.opacity(0.1))

            // Clients info
            HStack(spacing: isIPad ? 24 : 16) {
                VStack(alignment: .leading, spacing: isIPad ? 4 : 2) {
                    Text("Execution")
                        .font(.system(size: isIPad ? 12 : 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(node.executionClient)
                        .font(.system(size: isIPad ? 13 : 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: isIPad ? 4 : 2) {
                    Text("Consensus")
                        .font(.system(size: isIPad ? 12 : 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(node.consensusClient)
                        .font(.system(size: isIPad ? 13 : 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Divider()
                .background(.white.opacity(0.1))

            // Peers
            HStack(spacing: isIPad ? 24 : 20) {
                StatPill(icon: "network", label: "EL Peers", value: node.nExecutionPeers, isIPad: isIPad)
                StatPill(icon: "antenna.radiowaves.left.and.right", label: "CL Peers", value: node.nConsensusPeers, isIPad: isIPad)
            }

            // Resource usage
            HStack(spacing: isIPad ? 16 : 12) {
                ResourceBar(label: "CPU", value: Double(node.cpuUsage) ?? 0, color: .cyan, isIPad: isIPad)
                ResourceBar(label: "MEM", value: Double(node.memoryUsage) ?? 0, color: .purple, isIPad: isIPad)
                ResourceBar(label: "DISK", value: Double(node.storageUsage) ?? 0, color: .orange, isIPad: isIPad)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
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
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: isIPad ? 8 : 6) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 12 : 10))
                .foregroundStyle(.cyan.opacity(0.8))
            Text("\(label): \(value)")
                .font(.system(size: isIPad ? 13 : 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Resource Bar

struct ResourceBar: View {
    let label: String
    let value: Double
    let color: Color
    var isIPad: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 6 : 4) {
            HStack {
                Text(label)
                    .font(.system(size: isIPad ? 11 : 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: isIPad ? 11 : 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: isIPad ? 3 : 2)
                        .fill(.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: isIPad ? 3 : 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(value / 100, 1.0))
                }
            }
            .frame(height: isIPad ? 6 : 4)
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
    var isIPad: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: isIPad ? 32 : 24) {
                        // Current owner section
                        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                            Text("Current Owner")
                                .font(.system(size: isIPad ? 16 : 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))

                            Text(settings.ownerAddress)
                                .font(.system(size: isIPad ? 18 : 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .padding(isIPad ? 16 : 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                        .fill(.white.opacity(0.05))
                                )
                        }

                        Divider()
                            .background(.white.opacity(0.1))

                        // Change owner section
                        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                            Text("Change Owner Address")
                                .font(.system(size: isIPad ? 16 : 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))

                            TextField("New ENS or ETH address", text: $newAddress)
                                .font(.system(size: isIPad ? 18 : 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(isIPad ? 16 : 12)
                                .background(
                                    RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                        .fill(.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: isIPad ? 14 : 12, weight: .medium))
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
                                            .font(.system(size: isIPad ? 17 : 14, weight: .semibold, design: .rounded))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isIPad ? 16 : 12)
                                .background(
                                    RoundedRectangle(cornerRadius: isIPad ? 12 : 10)
                                        .fill(Color.cyan.opacity(0.8))
                                )
                            }
                            .disabled(newAddress.isEmpty || isLoading)
                            .opacity(newAddress.isEmpty ? 0.5 : 1.0)
                        }

                        Spacer()
                            .frame(height: isIPad ? 40 : 20)

                        // Widget instructions
                        VStack(spacing: isIPad ? 16 : 12) {
                            Text("Widget Instructions")
                                .font(.system(size: isIPad ? 16 : 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))

                            VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                                InstructionRow(step: "1", icon: "hand.tap", text: "Long press on Home Screen", isIPad: isIPad)
                                InstructionRow(step: "2", icon: "plus.circle", text: "Tap + button", isIPad: isIPad)
                                InstructionRow(step: "3", icon: "magnifyingglass", text: "Search \"BG Client\"", isIPad: isIPad)
                                InstructionRow(step: "4", icon: "checkmark.circle.fill", text: "Add Widget", isIPad: isIPad)
                            }
                        }
                        .padding(isIPad ? 24 : 16)
                        .background(
                            RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                                .fill(.white.opacity(0.03))
                        )
                    }
                    .padding(isIPad ? 32 : 20)
                    .frame(maxWidth: isIPad ? 600 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: isIPad ? 17 : 16))
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
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isIPad ? 36 : 28, height: isIPad ? 36 : 28)

                Text(step)
                    .font(.system(size: isIPad ? 16 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Image(systemName: icon)
                .font(.system(size: isIPad ? 18 : 14))
                .foregroundStyle(.cyan.opacity(0.8))
                .frame(width: isIPad ? 24 : 20)

            Text(text)
                .font(.system(size: isIPad ? 16 : 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
