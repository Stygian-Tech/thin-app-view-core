import Foundation
import Logging
import Testing
@testable import ThinAppViewCore

@Suite struct MicrocosmContentDiscoveryTests {
  @Test func hydratesValidatedPublicRecordsWithoutEnumeratingOrDeletingOnOmission() async throws {
    try await fixture { provider, transport, store in
      let scope = try PublicContentDiscoveryScope(authorDid: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", publicationKeys: ["at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.publication/main"])
      #expect(try await provider.discover(scope: scope) == 1)
      let item = try await store.fetchContentItem(uri: "at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.document/0")
      #expect(item?.title == "Article 0")
      let backlinks = await transport.backlinkCalls
      let hydrations = await transport.hydrationCalls
      #expect(backlinks == 2 && hydrations == 1)
      // A different scope may have no provider rows; that is not deletion proof.
      let empty = try PublicContentDiscoveryScope(authorDid: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", publicationKeys: [])
      #expect(try await provider.discover(scope: empty) == 0)
      #expect(try await store.fetchContentItem(uri: "at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.document/0") != nil)
    }
  }

  @Test(arguments: [MicrocosmTestTransport.Mode.wrongDID, .wrongURI, .wrongSite, .tamperedCID, .repeatedCursor])
  func rejectsForgedIdentityCIDScopeAndRepeatedPagination(mode: MicrocosmTestTransport.Mode) async throws {
    try await fixture(mode) { provider, _, _ in
      let scope = try PublicContentDiscoveryScope(authorDid: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", publicationKeys: ["at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.publication/main"])
      await #expect(throws: PublicContentDiscoveryError.invalidResponse) { try await provider.discover(scope: scope) }
    }
  }

  @Test func capsPaginationAndRecordHydrationDespiteLargerAdvertisedTotal() async throws {
    try await fixture(.many) { provider, transport, _ in
      let scope = try PublicContentDiscoveryScope(authorDid: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", publicationKeys: ["at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.publication/main"])
      #expect(try await provider.discover(scope: scope) == 50)
      let backlinks = await transport.backlinkCalls
      let hydrations = await transport.hydrationCalls
      #expect(backlinks == 2 && hydrations == 50)
    }
  }

  @Test func propagatesCancellationAndBoundsAStalledProvider() async throws {
    try await fixture(.stalled, timeout: .milliseconds(30)) { provider, _, store in
      let scope = try PublicContentDiscoveryScope(authorDid: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", publicationKeys: ["at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.publication/main"])
      await #expect(throws: PublicContentDiscoveryError.unavailable) { try await provider.discover(scope: scope) }
      let task = Task { try await provider.discover(scope: scope) }
      task.cancel()
      do { _ = try await task.value; Issue.record("Cancelled public discovery succeeded") }
      catch { #expect(error is CancellationError) }
      #expect(try await store.fetchContentItem(uri: "at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/site.standard.document/0") == nil)
    }
  }

  @Test func rejectsNonPublicOrForeignPublicationScopes() {
    for keys in [["http://private.example"], ["https://user:secret@example.test"], ["at://did:plc:bbbbbbbbbbbbbbbbbbbbbbbb/site.standard.publication/main"], ["at://did:plc:aaaaaaaaaaaaaaaaaaaaaaaa/app.thesocialwire.readState/self"]] {
      #expect(throws: PublicContentDiscoveryError.invalidScope) { try PublicContentDiscoveryScope(authorDid: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", publicationKeys: keys) }
    }
  }

  private func fixture(_ mode: MicrocosmTestTransport.Mode = .good, timeout: Duration = .seconds(12),
    body: (MicrocosmContentDiscovery, MicrocosmTestTransport, SQLiteThinAppViewStore) async throws -> Void) async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let logger = Logger(label: "microcosm.test")
    let store = try SQLiteThinAppViewStore(path: path, logger: logger)
    let indexer = ThinAppViewIndexer(store: store, config: .fromEnvironment(["ENABLE_THIN_APPVIEW": "true"]), logger: logger,
      publicationSiteResolver: nil)
    let transport = MicrocosmTestTransport(mode)
    try await body(.init(indexer: indexer, transport: transport, timeout: timeout), transport, store)
  }
}
