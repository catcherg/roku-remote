import Foundation
import RokuKit
import SwiftUI

/// Single source of truth (roadmap Phase 2 task 1). Owns the connection state
/// machine, discovery, command dispatch with optimistic-UI failure counting,
/// and persistence. Views never touch RokuKit networking directly.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published state

    @Published private(set) var connection: ConnectionState = .disconnected
    @Published private(set) var devices: [RokuDevice] = []
    @Published private(set) var isScanning = false
    /// Non-blocking banner after N consecutive command failures.
    @Published var isReconnecting = false
    /// ECP answered 403 → Roku is in "Limited" mode (roadmap §1.4). Routes to Help.
    @Published var limitedModeDetected = false

    // MARK: - Dependencies (RokuKit)

    let client = ECPClient()
    let store = SavedDeviceStore()
    let icons = IconCache()

    private var failures = ConsecutiveFailureTracker(threshold: 3)
    private var scanTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?

    var device: RokuDevice? { connection.device }

    init() {
        devices = store.devices
    }

    // MARK: - Launch / reconnect (roadmap Phase 2 task 4)

    /// On launch: ping the last device directly; skip discovery on success.
    func autoReconnect() async {
        guard case .disconnected = connection,
              let last = store.lastConnected else { return }
        connection = .discovering
        if let info = try? await client.deviceInfo(ip: last.ip),
           info.serialNumber == last.serialNumber {
            connect(to: info.device(ip: last.ip))
        } else {
            connection = .disconnected
            startScan()
        }
    }

    func connect(to device: RokuDevice) {
        store.setLastConnected(device)
        devices = store.devices
        failures.reset()
        isReconnecting = false
        connection = .connected(device)
    }

    func disconnect() {
        recoveryTask?.cancel()
        connection = .disconnected
    }

    // MARK: - Discovery (roadmap Phase 2 task 3)

    func startScan() {
        scanTask?.cancel()
        devices = store.devices // remembered devices shown instantly
        isScanning = true
        if connection == .disconnected { connection = .discovering }

        scanTask = Task { [weak self] in
            let coordinator = DiscoveryCoordinator()
            for await found in coordinator.discover() {
                guard let self, !Task.isCancelled else { return }
                self.upsert(found)
            }
            guard let self, !Task.isCancelled else { return }
            self.isScanning = false
            if self.connection == .discovering { self.connection = .disconnected }
        }
    }

    private func upsert(_ found: RokuDevice) {
        if let index = devices.firstIndex(where: { $0.serialNumber == found.serialNumber }) {
            devices[index] = found
            // Known device that moved IPs (DHCP): keep the store current.
            store.updateIP(serial: found.serialNumber, ip: found.ip)
        } else {
            devices.append(found)
        }
    }

    /// Manual IP entry (roadmap §1.2 last resort). Validates via device-info.
    /// Returns nil and connects on success; returns an error message otherwise.
    func connectManually(ip: String) async -> String? {
        let trimmed = ip.trimmingCharacters(in: .whitespaces)
        guard SubnetMath.toUInt32(trimmed) != nil else {
            return "That doesn't look like a valid IP address (e.g. 192.168.1.42)."
        }
        do {
            let info = try await client.deviceInfo(ip: trimmed)
            connect(to: info.device(ip: trimmed))
            return nil
        } catch ECPError.httpError(403) {
            limitedModeDetected = true
            return "The Roku answered but is blocking control (Limited mode). See Help."
        } catch {
            return "No Roku answered at \(trimmed). Check the IP under Settings → Network → About on your Roku."
        }
    }

    /// Marks a device as default (auto-reconnect target) without connecting.
    func setDefault(_ device: RokuDevice) {
        store.setLastConnected(device)
        devices = store.devices
        objectWillChange.send()
    }

    func rename(_ device: RokuDevice, to name: String) {
        store.rename(serial: device.serialNumber, to: name)
        devices = store.devices
        if case .connected(var current) = connection, current.serialNumber == device.serialNumber {
            current.name = name
            connection = .connected(current)
        }
    }

    func forget(_ device: RokuDevice) {
        store.forget(serial: device.serialNumber)
        devices.removeAll { $0.serialNumber == device.serialNumber }
    }

    // MARK: - Commands (optimistic UI, roadmap §2.2 + Phase 2 task 8)

    func send(_ key: ECPKey) {
        guard let device else { return }
        Task { await perform { try await self.client.keypress(key, ip: device.ip) } }
    }

    func launchChannel(_ app: RokuApp) {
        guard let device else { return }
        Task { await perform { try await self.client.launch(appID: app.id, ip: device.ip) } }
    }

    /// Press-and-hold support (volume ramping): Roku auto-repeats between
    /// keydown and keyup.
    func beginHold(_ key: ECPKey) {
        guard let device else { return }
        Task { await perform { try await self.client.keydown(key, ip: device.ip) } }
    }

    func endHold(_ key: ECPKey) {
        guard let device else { return }
        Task { await perform { try await self.client.keyup(key, ip: device.ip) } }
    }

    func typeText(_ text: String) {
        guard let device, !text.isEmpty else { return }
        Task { await perform { try await self.client.typeText(text, ip: device.ip) } }
    }

    func sendBackspace(count: Int = 1) {
        guard let device, count > 0 else { return }
        Task {
            await perform {
                for _ in 0..<count {
                    try await self.client.keypress(.backspace, ip: device.ip)
                }
            }
        }
    }

    func fetchApps() async -> [RokuApp] {
        guard let device else { return [] }
        do {
            let apps = try await client.apps(ip: device.ip)
            failures.recordSuccess()
            return apps
        } catch ECPError.httpError(403) {
            limitedModeDetected = true
            return []
        } catch {
            return []
        }
    }

    private func perform(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
            failures.recordSuccess()
            isReconnecting = false
        } catch ECPError.httpError(403) {
            // Limited mode: device reachable, control blocked. Not a connectivity
            // failure — route the user to the fix instead of counting it.
            limitedModeDetected = true
        } catch {
            if failures.recordFailure() {
                beginRecovery()
            }
        }
    }

    // MARK: - Recovery (banner → rescue or unreachable)

    private func beginRecovery() {
        guard recoveryTask == nil, let device else { return }
        isReconnecting = true
        recoveryTask = Task { [weak self] in
            defer { self?.recoveryTask = nil }
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if let info = try? await self.client.deviceInfo(ip: device.ip),
                   info.serialNumber == device.serialNumber {
                    self.failures.recordSuccess()
                    self.isReconnecting = false
                    return
                }
            }
            guard let self, !Task.isCancelled else { return }
            self.isReconnecting = false
            self.connection = .unreachable(device)
        }
    }
}
