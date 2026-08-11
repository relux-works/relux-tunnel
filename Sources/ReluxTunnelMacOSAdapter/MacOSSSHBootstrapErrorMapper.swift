import Foundation
import Network
import ReluxTunnelCore
import Security

/// macOS normalization layer for Network.framework and Security.framework failures.
/// Platform values are consumed for classification and are never copied into diagnostics.
public enum MacOSSSHBootstrapErrorMapper {
  public static func network(
    _ error: NWError,
    stage: SSHBootstrapStage,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    switch error {
    case .posix(let code):
      return SSHBootstrapErrorMapper.transport(
        posixCode: Int32(code.rawValue),
        stage: stage,
        configurationGeneration: configurationGeneration,
        context: context
      )
    case .dns:
      return SSHBootstrapErrorMapper.transport(
        .unavailable,
        stage: stage,
        configurationGeneration: configurationGeneration,
        context: context
      )
    case .tls:
      return SSHBootstrapErrorMapper.transport(
        .unexpected,
        stage: stage,
        configurationGeneration: configurationGeneration,
        context: context
      )
    case .wifiAware:
      return SSHBootstrapErrorMapper.transport(
        .unavailable,
        stage: stage,
        configurationGeneration: configurationGeneration,
        context: context
      )
    @unknown default:
      return SSHBootstrapErrorMapper.transport(
        .unexpected,
        stage: stage,
        configurationGeneration: configurationGeneration,
        context: context
      )
    }
  }

  public static func credential(
    _ error: MacOSCredentialResolverError,
    configurationGeneration: UInt64
  ) -> SSHBootstrapProviderError {
    switch error {
    case .credentialNotProvisioned:
      SSHBootstrapErrorMapper.credential(
        .notProvisioned,
        configurationGeneration: configurationGeneration
      )
    case .credentialAccessDenied:
      SSHBootstrapErrorMapper.credential(
        .accessDenied,
        configurationGeneration: configurationGeneration
      )
    case .credentialWrongClass, .credentialMalformed:
      SSHBootstrapErrorMapper.credential(
        .malformed,
        configurationGeneration: configurationGeneration
      )
    case .credentialGenerationMismatch:
      SSHBootstrapErrorMapper.credential(
        .generationMismatch,
        configurationGeneration: configurationGeneration
      )
    case .credentialPassphraseRequired:
      SSHBootstrapErrorMapper.credential(
        .passphraseRequired,
        configurationGeneration: configurationGeneration
      )
    case .credentialPassphraseInvalid:
      SSHBootstrapErrorMapper.credential(
        .passphraseInvalid,
        configurationGeneration: configurationGeneration
      )
    case .credentialKeyUnsupported:
      SSHBootstrapErrorMapper.credential(
        .keyUnsupported,
        configurationGeneration: configurationGeneration
      )
    case .operationCancelled:
      SSHBootstrapErrorMapper.cancellation(
        .taskCancelled,
        configurationGeneration: configurationGeneration
      )
    }
  }

  static func credential(
    status: OSStatus,
    itemLookup: Bool,
    configurationGeneration: UInt64
  ) -> SSHBootstrapProviderError {
    credential(
      MacOSCredentialResolverError(status: status, itemLookup: itemLookup),
      configurationGeneration: configurationGeneration
    )
  }
}
