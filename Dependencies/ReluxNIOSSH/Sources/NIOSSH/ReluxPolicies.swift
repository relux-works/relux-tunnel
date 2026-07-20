//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Relux contributors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

/// Receive-window policy for one SSH child channel.
///
/// Set this policy with ``SSHChildChannelOptions/receiveWindowConfiguration``
/// from the child channel initializer. The initializer completes before NIOSSH
/// advertises the channel's local receive window.
public struct NIOSSHChannelWindowConfiguration: Hashable, Sendable {
    /// The receive window advertised when the channel is opened.
    public let initialWindowSize: UInt32

    /// The immutable upper bound for the channel's remaining protocol credit.
    public let maximumWindowSize: UInt32

    /// Delivered credit required before an automatic window adjustment.
    ///
    /// A `nil` value suppresses automatic `SSH_MSG_CHANNEL_WINDOW_ADJUST`
    /// messages. Bytes become eligible for return only after they are delivered
    /// through the child channel pipeline.
    public let windowAdjustmentThreshold: UInt32?

    public init(
        initialWindowSize: UInt32,
        maximumWindowSize: UInt32,
        windowAdjustmentThreshold: UInt32?
    ) {
        precondition(initialWindowSize > 0, "initialWindowSize must be positive")
        precondition(maximumWindowSize >= initialWindowSize, "maximumWindowSize must cover the initial window")
        if let windowAdjustmentThreshold {
            precondition(windowAdjustmentThreshold > 0, "windowAdjustmentThreshold must be positive")
            precondition(
                windowAdjustmentThreshold <= maximumWindowSize,
                "windowAdjustmentThreshold must not exceed maximumWindowSize"
            )
        }

        self.initialWindowSize = initialWindowSize
        self.maximumWindowSize = maximumWindowSize
        self.windowAdjustmentThreshold = windowAdjustmentThreshold
    }

    /// The behavior of unmodified SwiftNIO SSH 0.14.1.
    public static let upstreamDefault = Self(
        initialWindowSize: 1 << 24,
        maximumWindowSize: 1 << 24,
        windowAdjustmentThreshold: 1 << 23
    )
}

/// A consistent child-channel receive-window snapshot.
public struct NIOSSHChannelWindowSnapshot: Equatable, Sendable {
    public var initialWindowSize: UInt32
    public var maximumWindowSize: UInt32
    public var remainingWindowSize: UInt32
    public var bufferedBytes: UInt32
    public var deliveredButUnadjustedBytes: UInt32
    public var adjustmentCount: UInt64
    public var adjustmentBytes: UInt64

    public init(
        initialWindowSize: UInt32,
        maximumWindowSize: UInt32,
        remainingWindowSize: UInt32,
        bufferedBytes: UInt32,
        deliveredButUnadjustedBytes: UInt32,
        adjustmentCount: UInt64,
        adjustmentBytes: UInt64
    ) {
        self.initialWindowSize = initialWindowSize
        self.maximumWindowSize = maximumWindowSize
        self.remainingWindowSize = remainingWindowSize
        self.bufferedBytes = bufferedBytes
        self.deliveredButUnadjustedBytes = deliveredButUnadjustedBytes
        self.adjustmentCount = adjustmentCount
        self.adjustmentBytes = adjustmentBytes
    }
}

/// Fired on a child channel whenever NIOSSH emits a receive-window adjustment.
public struct NIOSSHChannelWindowAdjustedEvent: Equatable, Sendable {
    public var remainingWindowBefore: UInt32
    public var adjustment: UInt32
    public var remainingWindowAfter: UInt32
    public var maximumWindowSize: UInt32

    public init(
        remainingWindowBefore: UInt32,
        adjustment: UInt32,
        remainingWindowAfter: UInt32,
        maximumWindowSize: UInt32
    ) {
        self.remainingWindowBefore = remainingWindowBefore
        self.adjustment = adjustment
        self.remainingWindowAfter = remainingWindowAfter
        self.maximumWindowSize = maximumWindowSize
    }
}

/// Why a connection-wide key exchange was requested or observed.
public enum NIOSSHRekeyReason: Hashable, Sendable {
    case outboundByteThreshold
    case inboundByteThreshold
    case elapsedTimeThreshold
    case manual
    case serverInitiated
}

/// Optional automatic client-rekey thresholds.
///
/// The upstream-compatible default disables all automatic triggers. Thresholds
/// count protected SSH packet bytes independently in each direction.
public struct NIOSSHRekeyPolicy: Sendable {
    public let outboundByteThreshold: UInt64?
    public let inboundByteThreshold: UInt64?
    public let elapsedTimeThreshold: TimeAmount?

    public init(
        outboundByteThreshold: UInt64? = nil,
        inboundByteThreshold: UInt64? = nil,
        elapsedTimeThreshold: TimeAmount? = nil
    ) {
        if let outboundByteThreshold {
            precondition(outboundByteThreshold > 0, "outboundByteThreshold must be positive")
        }
        if let inboundByteThreshold {
            precondition(inboundByteThreshold > 0, "inboundByteThreshold must be positive")
        }
        if let elapsedTimeThreshold {
            precondition(elapsedTimeThreshold.nanoseconds > 0, "elapsedTimeThreshold must be positive")
        }

        self.outboundByteThreshold = outboundByteThreshold
        self.inboundByteThreshold = inboundByteThreshold
        self.elapsedTimeThreshold = elapsedTimeThreshold
    }

    public static let disabled = Self()
}

/// Monotonic time seam used by automatic elapsed-time rekeying.
public protocol NIOSSHRekeyClock: Sendable {
    func now() -> NIODeadline
}

/// The system monotonic clock used unless a caller injects another clock.
public struct NIOSSHSystemRekeyClock: NIOSSHRekeyClock, Sendable {
    public init() {}

    public func now() -> NIODeadline {
        .now()
    }
}

/// Current connection-wide rekey state.
public struct NIOSSHRekeySnapshot: Equatable, Sendable {
    public var keyExchangeGeneration: UInt64
    public var protectedBytesSent: UInt64
    public var protectedBytesReceived: UInt64
    public var keyExchangeInProgress: Bool
    public var observedReasons: Set<NIOSSHRekeyReason>

    public init(
        keyExchangeGeneration: UInt64,
        protectedBytesSent: UInt64,
        protectedBytesReceived: UInt64,
        keyExchangeInProgress: Bool,
        observedReasons: Set<NIOSSHRekeyReason>
    ) {
        self.keyExchangeGeneration = keyExchangeGeneration
        self.protectedBytesSent = protectedBytesSent
        self.protectedBytesReceived = protectedBytesReceived
        self.keyExchangeInProgress = keyExchangeInProgress
        self.observedReasons = observedReasons
    }
}

/// Fired on the parent channel when a post-authentication key exchange starts.
public struct NIOSSHRekeyStartedEvent: Equatable, Sendable {
    public var reasons: Set<NIOSSHRekeyReason>
    public var currentGeneration: UInt64

    public init(reasons: Set<NIOSSHRekeyReason>, currentGeneration: UInt64) {
        self.reasons = reasons
        self.currentGeneration = currentGeneration
    }
}

/// Fired on the parent channel after a post-authentication key exchange succeeds.
public struct NIOSSHRekeySucceededEvent: Equatable, Sendable {
    public var reasons: Set<NIOSSHRekeyReason>
    public var newGeneration: UInt64

    public init(reasons: Set<NIOSSHRekeyReason>, newGeneration: UInt64) {
        self.reasons = reasons
        self.newGeneration = newGeneration
    }
}
