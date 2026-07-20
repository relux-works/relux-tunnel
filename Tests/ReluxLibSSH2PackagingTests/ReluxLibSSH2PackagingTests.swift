import ReluxLibSSH2
import Testing

@Test("Public client-rekey symbol is exported by the XCFramework module")
func publicClientRekeySymbolIsExported() {
  #expect(libssh2_session_rekey(nil) == LIBSSH2_ERROR_BAD_USE)
}
