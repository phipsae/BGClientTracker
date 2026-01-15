//
//  BGClientTrackerApp.swift
//  BGClientTracker
//
//  Created by Philip on 04.12.25.
//

import SwiftUI
import UserNotifications

#if os(iOS)
import BackgroundTasks
#endif

// MARK: - App Delegate for Notification Handling

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate to show notifications in foreground
        UNUserNotificationCenter.current().delegate = self
        
        // Enable legacy background fetch (required for "Simulate Background Fetch")
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        return true
    }
    
    // Legacy background fetch
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task {
            await BGClientTrackerApp.performBackgroundNodeCheck()
            completionHandler(.newData)
        }
    }
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set notification delegate to show notifications in foreground
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
#endif

@main
struct BGClientTrackerApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @Environment(\.scenePhase) private var scenePhase
    
    #if os(iOS)
    static let backgroundTaskIdentifier = "com.buidlguidl.BGClientTracker.refresh"
    #endif
    
    // Timer for periodic refresh on macOS (since BGTaskScheduler isn't available)
    #if os(macOS)
    @State private var refreshTimer: Timer?
    #endif
    
    init() {
        #if os(iOS)
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            Self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleBackgroundRefresh()
            }
        }
        #elseif os(macOS)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                startMacOSBackgroundRefresh()
            }
        }
        #endif
    }
    
    #if os(iOS)
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
    
    static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
        
        // Create a task to fetch nodes
        let fetchTask = Task {
            await performBackgroundNodeCheck()
        }
        
        // Set expiration handler
        task.expirationHandler = {
            fetchTask.cancel()
        }
        
        // Complete the task when done
        Task {
            await fetchTask.value
            task.setTaskCompleted(success: true)
        }
    }
    #endif
    
    #if os(macOS)
    private func startMacOSBackgroundRefresh() {
        // Perform initial check
        Task {
            await Self.performBackgroundNodeCheck()
        }
    }
    #endif
    
    static func performBackgroundNodeCheck() async {
        let settings = SettingsManager.shared
        let notificationManager = NotificationManager.shared
        
        guard !settings.ownerAddress.isEmpty else { return }
        guard settings.notificationsEnabled else { return }
        
        do {
            let response = try await BGClientAPIService.fetchNodes(owner: settings.ownerAddress)
            
            await MainActor.run {
                notificationManager.checkNodesAndNotify(
                    nodes: response.nodes,
                    settings: settings
                )
            }
        } catch {
            // Silently fail - will retry on next background fetch
        }
    }
}
