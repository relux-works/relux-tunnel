import ReluxLibSSH2
import Testing

@Test("Public client-rekey symbol is exported by the XCFramework module")
func publicClientRekeySymbolIsExported() {
  #expect(libssh2_session_rekey(nil) == LIBSSH2_ERROR_BAD_USE)
}

@Test("Public server-KEX observation symbols and typed states are exported")
func publicServerKEXObservationIsExported() {
  var status = LIBSSH2_SERVER_KEX_STATUS(
    state: LIBSSH2_SERVER_KEX_NONE,
    generation: 0
  )

  libssh2_session_server_kex_observer_set(nil, nil, nil)
  #expect(libssh2_session_server_kex_status(nil, &status) == LIBSSH2_ERROR_BAD_USE)
  #expect(LIBSSH2_SERVER_KEX_STARTED.rawValue != LIBSSH2_SERVER_KEX_SUCCEEDED.rawValue)
  #expect(LIBSSH2_SERVER_KEX_FAILED.rawValue != LIBSSH2_SERVER_KEX_SUCCEEDED.rawValue)
}

@Test("Public reply-correlated global-request symbol and bounds are exported")
func publicGlobalRequestIsExported() {
  var reply = LIBSSH2_GLOBAL_REQUEST_REPLY_NONE

  #expect(
    libssh2_session_global_request(nil, nil, 0, nil, 0, &reply)
      == LIBSSH2_ERROR_BAD_USE
  )
  #expect(LIBSSH2_GLOBAL_REQUEST_MAX_NAME_LENGTH == 255)
  #expect(LIBSSH2_GLOBAL_REQUEST_MAX_PAYLOAD_LENGTH == 1_024)
}
