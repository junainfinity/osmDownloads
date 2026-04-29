import Foundation
import Network

actor ReachabilityService {
    static let shared = ReachabilityService()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.osm.downloads.reachability")
    private(set) var isReachable: Bool = true
    private var continuation: AsyncStream<Bool>.Continuation?

    func start() -> AsyncStream<Bool> {
        let stream = AsyncStream<Bool> { cont in
            self.continuation = cont
            monitor.pathUpdateHandler = { [weak self] path in
                let reachable = path.status == .satisfied
                Task { await self?.setReachable(reachable) }
            }
            monitor.start(queue: queue)
            cont.onTermination = { [weak self] _ in
                Task { await self?.stop() }
            }
        }
        return stream
    }

    private func setReachable(_ value: Bool) {
        isReachable = value
        continuation?.yield(value)
    }

    func stop() {
        monitor.cancel()
        continuation?.finish()
        continuation = nil
    }
}
