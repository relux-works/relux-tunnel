//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

struct ChildChannelWindowManager {
    private(set) var configuration: NIOSSHChannelWindowConfiguration

    private var bufferedBytes: UInt32

    private var currentWindowSize: UInt32

    private var deliveredButUnadjustedBytes: UInt32

    private var adjustmentCount: UInt64

    private var adjustmentBytes: UInt64

    var targetWindowSize: UInt32 {
        self.configuration.initialWindowSize
    }

    init(targetWindowSize: UInt32) {
        self.init(
            configuration: .init(
                initialWindowSize: targetWindowSize,
                maximumWindowSize: targetWindowSize,
                windowAdjustmentThreshold: max(1, targetWindowSize / 2)
            )
        )
    }

    init(configuration: NIOSSHChannelWindowConfiguration) {
        self.configuration = configuration
        self.bufferedBytes = 0
        self.currentWindowSize = configuration.initialWindowSize
        self.deliveredButUnadjustedBytes = 0
        self.adjustmentCount = 0
        self.adjustmentBytes = 0
    }

    mutating func updateConfiguration(_ configuration: NIOSSHChannelWindowConfiguration) {
        precondition(self.bufferedBytes == 0)
        precondition(self.currentWindowSize == self.targetWindowSize)
        precondition(self.deliveredButUnadjustedBytes == 0)
        precondition(self.adjustmentCount == 0)

        self = .init(configuration: configuration)
    }

    var snapshot: NIOSSHChannelWindowSnapshot {
        .init(
            initialWindowSize: self.configuration.initialWindowSize,
            maximumWindowSize: self.configuration.maximumWindowSize,
            remainingWindowSize: self.currentWindowSize,
            bufferedBytes: self.bufferedBytes,
            deliveredButUnadjustedBytes: self.deliveredButUnadjustedBytes,
            adjustmentCount: self.adjustmentCount,
            adjustmentBytes: self.adjustmentBytes
        )
    }
}

extension ChildChannelWindowManager {
    mutating func bufferFlowControlledBytes(_ bufferedBytes: Int) throws {
        let increment = UInt32(bufferedBytes)

        let (newBufferedBytes, bufferedOverflow) = self.bufferedBytes.addingReportingOverflow(increment)
        let (newWindowSize, windowSizeOverflow) = self.currentWindowSize.subtractingReportingOverflow(increment)

        // Whoops, the window size went out of band! This is an error caused by the remote peer.
        if windowSizeOverflow || bufferedOverflow {
            throw NIOSSHError.flowControlViolation(currentWindow: self.currentWindowSize, increment: increment)
        }

        self.bufferedBytes = newBufferedBytes
        self.currentWindowSize = newWindowSize
    }

    mutating func unbufferBytes(_ bytes: Int) -> Increment? {
        let bytes = UInt32(bytes)

        self.bufferedBytes -= bytes

        let (newDeliveredBytes, deliveredOverflow) = self.deliveredButUnadjustedBytes.addingReportingOverflow(bytes)
        precondition(!deliveredOverflow)
        self.deliveredButUnadjustedBytes = newDeliveredBytes

        guard let threshold = self.configuration.windowAdjustmentThreshold,
            self.deliveredButUnadjustedBytes >= threshold
        else {
            return nil
        }

        let remainingBefore = self.currentWindowSize
        let capacity = self.configuration.maximumWindowSize - remainingBefore
        let increment = min(self.deliveredButUnadjustedBytes, capacity)
        guard increment > 0 else {
            return nil
        }

        self.currentWindowSize += increment
        self.deliveredButUnadjustedBytes -= increment
        self.adjustmentCount += 1
        self.adjustmentBytes += UInt64(increment)

        return Increment(
            rawValue: increment,
            remainingWindowBefore: remainingBefore,
            remainingWindowAfter: self.currentWindowSize,
            maximumWindowSize: self.configuration.maximumWindowSize
        )
    }
}

extension ChildChannelWindowManager {
    struct Increment {
        var rawValue: UInt32

        var remainingWindowBefore: UInt32

        var remainingWindowAfter: UInt32

        var maximumWindowSize: UInt32

        init(rawValue: UInt32) {
            self.rawValue = rawValue
            self.remainingWindowBefore = 0
            self.remainingWindowAfter = rawValue
            self.maximumWindowSize = rawValue
        }

        init(
            rawValue: UInt32,
            remainingWindowBefore: UInt32,
            remainingWindowAfter: UInt32,
            maximumWindowSize: UInt32
        ) {
            self.rawValue = rawValue
            self.remainingWindowBefore = remainingWindowBefore
            self.remainingWindowAfter = remainingWindowAfter
            self.maximumWindowSize = maximumWindowSize
        }
    }
}

extension ChildChannelWindowManager.Increment: Hashable {}

extension ChildChannelWindowManager.Increment: RawRepresentable {}

extension UInt32 {
    init(_ increment: ChildChannelWindowManager.Increment) {
        self = increment.rawValue
    }
}
