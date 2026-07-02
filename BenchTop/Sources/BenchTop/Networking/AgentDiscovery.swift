import Foundation
import Network

struct DiscoveredAgent: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var host: String
    var port: Int
}

/// Browses for BenchTop agents advertising themselves via Bonjour/mDNS on
/// the local network (see agent/benchtop_agent/discovery.py), so Settings
/// can offer a pick list instead of requiring a typed-in IP.
///
/// NWBrowser only hands back an opaque `.service` endpoint, not a usable
/// host:port — resolving one down to an address that can go in a URL
/// requires briefly opening an NWConnection to it and reading the resolved
/// path back. This is the standard (if slightly heavyweight) pattern for
/// Bonjour resolution on the Network framework; unlike the rest of the
/// networking layer this hasn't been exercised against a real Bonjour
/// browse in this environment (no Mac/iPhone available), so treat it as the
/// most likely spot to need a fix on first real-device run.
@MainActor
final class AgentDiscovery: ObservableObject {
    @Published private(set) var discovered: [DiscoveredAgent] = []

    private var browser: NWBrowser?
    private var resolvingConnections: [String: NWConnection] = [:]

    func start() {
        stop()

        let browser = NWBrowser(for: .bonjour(type: "_benchtop._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handle(results: results)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        for connection in resolvingConnections.values {
            connection.cancel()
        }
        resolvingConnections.removeAll()
        discovered.removeAll()
    }

    private func handle(results: Set<NWBrowser.Result>) {
        let currentNames = Set(results.compactMap(Self.serviceName))

        // Drop anything that's no longer being advertised.
        discovered.removeAll { !currentNames.contains($0.name) }
        for (name, connection) in resolvingConnections where !currentNames.contains(name) {
            connection.cancel()
            resolvingConnections[name] = nil
        }

        for result in results {
            guard let name = Self.serviceName(for: result.endpoint) else { continue }
            guard resolvingConnections[name] == nil else { continue }
            guard !discovered.contains(where: { $0.name == name }) else { continue }
            resolve(name: name, endpoint: result.endpoint)
        }
    }

    private static func serviceName(for endpoint: NWEndpoint) -> String? {
        guard case let .service(name, _, _, _) = endpoint else { return nil }
        return name
    }

    private func resolve(name: String, endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolvingConnections[name] = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let remoteEndpoint = connection.currentPath?.remoteEndpoint
                Task { @MainActor in
                    self?.finishResolving(name: name, remoteEndpoint: remoteEndpoint, connection: connection)
                }
            case .failed, .cancelled:
                Task { @MainActor in
                    self?.resolvingConnections[name] = nil
                }
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func finishResolving(name: String, remoteEndpoint: NWEndpoint?, connection: NWConnection) {
        defer {
            connection.cancel()
            resolvingConnections[name] = nil
        }
        guard case let .hostPort(host, port) = remoteEndpoint else { return }

        let agent = DiscoveredAgent(name: name, host: Self.hostString(host), port: Int(port.rawValue))
        // Replace rather than append, in case this name was already
        // resolved to a now-stale address (e.g. the rig's DHCP lease changed).
        discovered.removeAll { $0.name == name }
        discovered.append(agent)
    }

    private static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address): return address.debugDescription
        case .ipv6(let address): return address.debugDescription
        case .name(let name, _): return name
        @unknown default: return "\(host)"
        }
    }
}
