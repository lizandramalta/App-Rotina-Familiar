import Foundation
@testable import FamilyRoutine
import Testing

struct InviteLinkParserTests {
    private let parser = InviteLinkParser(baseURL: URL(string: "https://links.example.test")!)

    @Test("SPEC-005 CA-06 accepts only the configured Universal Link host and exact invite path")
    func acceptsConfiguredInvite() {
        #expect(parser.token(from: URL(string: "https://links.example.test/invite/AbC_123-xyz")!) == "AbC_123-xyz")
        #expect(parser.token(from: URL(string: "https://other.example.test/invite/AbC_123-xyz")!) == nil)
        #expect(parser.token(from: URL(string: "http://links.example.test/invite/AbC_123-xyz")!) == nil)
        #expect(parser.token(from: URL(string: "https://links.example.test/invite/AbC_123-xyz/extra")!) == nil)
        #expect(parser.token(from: URL(string: "https://links.example.test/invite/AbC_123-xyz?password=secret")!) == nil)
        #expect(parser.token(from: URL(string: "https://links.example.test/invite/%2e%2e")!) == nil)
    }
}
