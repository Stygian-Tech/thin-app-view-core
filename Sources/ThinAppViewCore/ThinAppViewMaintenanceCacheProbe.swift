import Foundation

/// A unique, expiring key distinguishes cache failure from contention on a publisher's RSS lease.
struct ThinAppViewMaintenanceCacheProbe: Sendable {
  let acquire: @Sendable (String) async -> AppViewProjectionRefreshLease?
  let release: @Sendable (AppViewProjectionRefreshLease) async -> Void

  init(cache: any AppViewProjectionCacheStore) {
    acquire = { resource in
      await cache.acquireRefreshLease(domain: "maintenance_health", resource: resource, ttl: 10)
    }
    release = { await cache.releaseRefreshLease($0) }
  }

  init(acquire: @escaping @Sendable (String) async -> AppViewProjectionRefreshLease?,
    release: @escaping @Sendable (AppViewProjectionRefreshLease) async -> Void) {
    self.acquire = acquire
    self.release = release
  }

  func run() async throws {
    guard let lease = await acquire(UUID().uuidString.lowercased()) else { throw Failure.unavailable }
    // Release is joined even if the caller was cancelled after acquisition; TTL bounds a failed release.
    await release(lease)
  }

  enum Failure: Error, Sendable, Equatable { case unavailable }
}
