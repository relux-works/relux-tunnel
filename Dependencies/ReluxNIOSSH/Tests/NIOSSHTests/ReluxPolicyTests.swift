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

import Crypto
import NIOCore
import NIOEmbedded
import Testing

@testable import NIOSSH

private final class ReluxWindowEventRecorder: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = SSHChannelData

    var sequence: [String] = []
    var adjustments: [NIOSSHChannelWindowAdjustedEvent] = []

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.sequence.append("read")
        context.fireChannelRead(data)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let adjustment = event as? NIOSSHChannelWindowAdjustedEvent {
            self.sequence.append("adjust")
            self.adjustments.append(adjustment)
        }
        context.fireUserInboundEventTriggered(event)
    }
}

@Suite("Relux receive-window policy")
struct ReluxWindowPolicyTests {
    @Test(
        "Configured initial windows are emitted on channel open",
        arguments: [
            NIOSSHChannelWindowConfiguration(
                initialWindowSize: 32 * 1024,
                maximumWindowSize: 32 * 1024,
                windowAdjustmentThreshold: 16 * 1024
            ),
            NIOSSHChannelWindowConfiguration(
                initialWindowSize: 64 * 1024,
                maximumWindowSize: 64 * 1024,
                windowAdjustmentThreshold: 32 * 1024
            ),
            NIOSSHChannelWindowConfiguration(
                initialWindowSize: 512 * 1024,
                maximumWindowSize: 1024 * 1024,
                windowAdjustmentThreshold: 256 * 1024
            ),
        ]
    )
    func configuredInitialWindowIsOnWire(configuration: NIOSSHChannelWindowConfiguration) throws {
        let delegate = DummyDelegate()
        let multiplexer = SSHChannelMultiplexer(
            delegate: delegate,
            allocator: delegate.allocator,
            childChannelInitializer: nil
        )
        defer {
            multiplexer.parentChannelInactive()
            multiplexer.parentHandlerRemoved()
            delegate._channel.embeddedEventLoop.run()
            _ = try? delegate._channel.finish(acceptAlreadyClosed: true)
        }

        var childChannel: Channel?
        multiplexer.createChildChannel(nil, channelType: .session) { channel, _ in
            childChannel = channel
            return channel.setOption(SSHChildChannelOptions.receiveWindowConfiguration, value: configuration)
        }
        delegate._channel.embeddedEventLoop.run()

        guard case .channelOpen(let open)? = delegate.writes.first?.0 else {
            Issue.record("Expected a channel-open message")
            return
        }
        #expect(open.initialWindowSize == configuration.initialWindowSize)

        let snapshot = try #require(
            try childChannel?.getOption(SSHChildChannelOptions.receiveWindowSnapshot).wait()
        )
        #expect(snapshot.initialWindowSize == configuration.initialWindowSize)
        #expect(snapshot.maximumWindowSize == configuration.maximumWindowSize)
        #expect(snapshot.remainingWindowSize == configuration.initialWindowSize)
    }

    @Test("Unread bytes suppress credit return and explicit policy can suppress adjustment")
    func adjustmentSuppression() throws {
        var manager = ChildChannelWindowManager(
            configuration: .init(
                initialWindowSize: 64 * 1024,
                maximumWindowSize: 64 * 1024,
                windowAdjustmentThreshold: nil
            )
        )

        try manager.bufferFlowControlledBytes(32 * 1024)
        var snapshot = manager.snapshot
        #expect(snapshot.remainingWindowSize == 32 * 1024)
        #expect(snapshot.bufferedBytes == 32 * 1024)
        #expect(snapshot.adjustmentCount == 0)

        #expect(manager.unbufferBytes(32 * 1024) == nil)
        snapshot = manager.snapshot
        #expect(snapshot.remainingWindowSize == 32 * 1024)
        #expect(snapshot.bufferedBytes == 0)
        #expect(snapshot.deliveredButUnadjustedBytes == 32 * 1024)
        #expect(snapshot.adjustmentCount == 0)
    }

    @Test("Adjustments follow delivered bytes and never exceed the immutable cap")
    func adjustmentAccountingAndCap() throws {
        var manager = ChildChannelWindowManager(
            configuration: .init(
                initialWindowSize: 64 * 1024,
                maximumWindowSize: 96 * 1024,
                windowAdjustmentThreshold: 32 * 1024
            )
        )

        try manager.bufferFlowControlledBytes(48 * 1024)
        #expect(manager.unbufferBytes(31 * 1024) == nil)

        let possibleIncrement = manager.unbufferBytes(1024)
        let increment = try #require(possibleIncrement)
        #expect(increment.rawValue == 32 * 1024)
        #expect(increment.remainingWindowBefore == 16 * 1024)
        #expect(increment.remainingWindowAfter == 48 * 1024)
        #expect(increment.remainingWindowAfter <= increment.maximumWindowSize)

        let snapshot = manager.snapshot
        #expect(snapshot.bufferedBytes == 16 * 1024)
        #expect(snapshot.deliveredButUnadjustedBytes == 0)
        #expect(snapshot.adjustmentCount == 1)
        #expect(snapshot.adjustmentBytes == 32 * 1024)
    }

    @Test("Window adjustment event follows delivery and snapshot accounting")
    func windowAdjustmentEvent() throws {
        let delegate = DummyDelegate()
        let recorder = ReluxWindowEventRecorder()
        let multiplexer = SSHChannelMultiplexer(
            delegate: delegate,
            allocator: delegate.allocator,
            childChannelInitializer: nil
        )
        defer {
            multiplexer.parentChannelInactive()
            multiplexer.parentHandlerRemoved()
            delegate._channel.embeddedEventLoop.run()
            _ = try? delegate._channel.finish(acceptAlreadyClosed: true)
        }

        var childChannel: Channel?
        multiplexer.createChildChannel(nil, channelType: .session) { channel, _ in
            childChannel = channel
            return channel.setOption(
                SSHChildChannelOptions.receiveWindowConfiguration,
                value: .init(
                    initialWindowSize: 32 * 1024,
                    maximumWindowSize: 32 * 1024,
                    windowAdjustmentThreshold: 16 * 1024
                )
            ).flatMap {
                channel.pipeline.addHandler(recorder)
            }
        }
        delegate._channel.embeddedEventLoop.run()

        try multiplexer.receiveMessage(
            .channelOpenConfirmation(
                .init(
                    recipientChannel: 0,
                    senderChannel: 7,
                    initialWindowSize: 32 * 1024,
                    maximumPacketSize: 32 * 1024
                )
            )
        )

        var payload = delegate.allocator.buffer(capacity: 16 * 1024)
        payload.writeRepeatingByte(0x7e, count: 16 * 1024)
        try multiplexer.receiveMessage(.channelData(.init(recipientChannel: 0, data: payload)))
        multiplexer.parentChannelReadComplete()
        delegate._channel.embeddedEventLoop.run()

        #expect(recorder.sequence == ["read", "adjust"])
        let adjustment = try #require(recorder.adjustments.first)
        #expect(adjustment.remainingWindowBefore == 16 * 1024)
        #expect(adjustment.adjustment == 16 * 1024)
        #expect(adjustment.remainingWindowAfter == 32 * 1024)
        #expect(adjustment.remainingWindowAfter <= adjustment.maximumWindowSize)

        let snapshot = try #require(
            try childChannel?.getOption(SSHChildChannelOptions.receiveWindowSnapshot).wait()
        )
        #expect(snapshot.remainingWindowSize == 32 * 1024)
        #expect(snapshot.bufferedBytes == 0)
        #expect(snapshot.adjustmentCount == 1)
    }
}

private final class ReluxExternalSignerClientAuth: NIOSSHClientUserAuthenticationDelegate, @unchecked Sendable {
    let signingKey: Curve25519.Signing.PrivateKey
    private(set) var signatureInvocationCount = 0
    private var hasOfferedKey = false

    init(signingKey: Curve25519.Signing.PrivateKey) {
        self.signingKey = signingKey
    }

    var publicKey: NIOSSHPublicKey {
        NIOSSHPublicKey(backingKey: .ed25519(self.signingKey.publicKey))
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard availableMethods.contains(.publicKey), !self.hasOfferedKey else {
            nextChallengePromise.succeed(nil)
            return
        }
        self.hasOfferedKey = true

        var publicKeyBytes = ByteBufferAllocator().buffer(capacity: 64)
        publicKeyBytes.writeSSHHostKey(self.publicKey)
        let signingKey = self.signingKey
        let invocationRecorder = self

        do {
            let externalKey = try NIOSSHUserAuthenticationOffer.Offer.ExternalPublicKey(
                publicKeyBytes: publicKeyBytes,
                algorithm: "ssh-ed25519"
            ) { payload, eventLoop in
                let promise = eventLoop.makePromise(of: ByteBuffer.self)
                eventLoop.execute {
                    do {
                        let signature = try signingKey.signature(for: payload.readableBytesView)
                        var signatureBytes = ByteBufferAllocator().buffer(capacity: signature.count)
                        signatureBytes.writeBytes(signature)
                        invocationRecorder.signatureInvocationCount += 1
                        promise.succeed(signatureBytes)
                    } catch {
                        promise.fail(error)
                    }
                }
                return promise.futureResult
            }
            nextChallengePromise.succeed(
                .init(username: "foo", serviceName: "ssh-connection", offer: .externalPublicKey(externalKey))
            )
        } catch {
            nextChallengePromise.fail(error)
        }
    }
}

@Suite("Relux adapter-conformance APIs", .serialized)
struct ReluxAdapterConformanceTests {
    @Test("External asynchronous signer authenticates without a NIOSSH private key")
    func externalSignerAuthentication() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: [UInt8](repeating: 0x42, count: 32))
        let clientAuth = ReluxExternalSignerClientAuth(signingKey: signingKey)
        var harness = TestHarness()
        harness.clientAuthDelegate = clientAuth
        harness.serverAuthDelegate = ExpectPublicKeyAuth(clientAuth.publicKey)

        let events = UserEventExpecter()
        try channels.configureWithHarness(harness)
        try channels.client.pipeline.syncOperations.addHandler(events)
        try channels.activate()
        try channels.interactInMemory()

        #expect(clientAuth.signatureInvocationCount == 1)
        #expect(events.userEvents.contains { $0 is UserAuthSuccessEvent })

        _ = try channels.createNewChannel()
        try channels.interactInMemory()
        #expect(channels.activeServerChannels.count == 1)
    }

    @Test("Reply-observing keepalive follows the protected global-request round trip")
    func replyObservingKeepalive() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        try channels.configureWithHarness(TestHarness())
        try channels.activate()
        try channels.interactInMemory()

        var payload = channels.client.allocator.buffer(capacity: 8)
        payload.writeInteger(UInt64(0x0102_0304_0506_0708))
        let request = try NIOSSHGlobalRequest(name: "keepalive@openssh.com", payload: payload)
        let promise = channels.client.eventLoop.makePromise(of: NIOSSHGlobalRequestResponse.self)
        let completed = NIOLoopBoundBox(false, eventLoop: channels.client.eventLoop)
        promise.futureResult.whenComplete { _ in completed.value = true }

        channels.clientSSHHandler?.sendGlobalRequest(request, promise: promise)
        #expect(!completed.value)
        #expect(channels.activeServerChannels.isEmpty)

        try channels.interactInMemory()

        #expect(completed.value)
        #expect(try promise.futureResult.wait() == .failure)
        #expect(channels.activeServerChannels.isEmpty)
        #expect(request.payload.readableBytes <= NIOSSHGlobalRequest.maximumPayloadBytes)

        var oversized = channels.client.allocator.buffer(
            capacity: NIOSSHGlobalRequest.maximumPayloadBytes + 1
        )
        oversized.writeRepeatingByte(0, count: NIOSSHGlobalRequest.maximumPayloadBytes + 1)
        do {
            _ = try NIOSSHGlobalRequest(name: "keepalive@openssh.com", payload: oversized)
            Issue.record("Expected an oversized global request to be rejected")
        } catch let error as NIOSSHGlobalRequestError {
            #expect(
                error
                    == .payloadTooLarge(
                        maximumBytes: NIOSSHGlobalRequest.maximumPayloadBytes,
                        actualBytes: NIOSSHGlobalRequest.maximumPayloadBytes + 1
                    )
            )
        } catch {
            Issue.record("Unexpected global request validation error: \(error)")
        }
    }

    @Test("Client allowlists constrain and report exact negotiated algorithms")
    func algorithmAllowlistsAndSnapshot() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        var harness = TestHarness()
        harness.serverHostKeys = [
            .init(ed25519Key: .init()),
            .init(p256Key: .init()),
        ]
        let keyExchangeAllowlist = ["curve25519-sha256@libssh.org", "ecdh-sha2-nistp256"]
        let hostKeyAllowlist = ["ecdsa-sha2-nistp256", "ssh-ed25519"]
        try channels.configureWithHarness(
            harness,
            clientKeyExchangeAlgorithms: keyExchangeAllowlist,
            clientHostKeyAlgorithms: hostKeyAllowlist
        )
        try channels.activate()
        try channels.interactInMemory()

        let snapshot = try #require(channels.clientSSHHandler?.negotiatedAlgorithmsSnapshot)
        #expect(snapshot.keyExchangeAlgorithm == "curve25519-sha256@libssh.org")
        #expect(snapshot.keyExchangeAlgorithm != "ecdh-sha2-nistp384")
        #expect(snapshot.hostKeyAlgorithm == "ecdsa-sha2-nistp256")
        #expect(snapshot.cipherAlgorithm == "aes256-gcm@openssh.com")
        #expect(snapshot.macAlgorithm == "hmac-sha2-256")
        #expect(keyExchangeAllowlist.count == 2)
        #expect(hostKeyAllowlist.count == 2)

    }
}

private final class ReluxFakeRekeyClock: NIOSSHRekeyClock, @unchecked Sendable {
    var nowValue: NIODeadline = .uptimeNanoseconds(0)

    func now() -> NIODeadline {
        self.nowValue
    }

    func advance(by amount: TimeAmount) {
        self.nowValue = self.nowValue + amount
    }
}

@Suite("Relux automatic rekey policy", .serialized)
struct ReluxRekeyPolicyTests {
    @Test("Protected-byte threshold rekeys with active channels and preserves payload")
    func byteThresholdWithActiveChannel() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        try channels.configureWithHarness(
            TestHarness(),
            clientRekeyPolicy: .init(outboundByteThreshold: 4096)
        )
        try channels.activate()
        try channels.interactInMemory()

        let clientChild = try channels.createNewChannel()
        try channels.interactInMemory()
        let serverChild = try #require(channels.activeServerChannels.first)
        let recorder = ReadRecordingHandler()
        try serverChild.pipeline.syncOperations.addHandler(recorder)

        var payload = clientChild.allocator.buffer(capacity: 8192)
        payload.writeRepeatingByte(0x5a, count: 8192)
        try clientChild.writeAndFlush(SSHChannelData(type: .channel, data: .byteBuffer(payload))).wait()
        try channels.interactInMemory()

        let snapshot = try #require(channels.clientSSHHandler?.rekeySnapshot)
        #expect(snapshot.keyExchangeGeneration == 2)
        #expect(!snapshot.keyExchangeInProgress)
        #expect(clientChild.isActive)
        #expect(serverChild.isActive)
        #expect(recorder.reads.reduce(0) { $0 + $1.data.readableBytes } == 8192)
    }

    @Test("Inbound protected-byte threshold rekeys on the client")
    func inboundByteThreshold() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        try channels.configureWithHarness(
            TestHarness(),
            clientRekeyPolicy: .init(inboundByteThreshold: 4096)
        )
        try channels.activate()
        try channels.interactInMemory()

        _ = try channels.createNewChannel()
        try channels.interactInMemory()
        let serverChild = try #require(channels.activeServerChannels.first)

        var payload = serverChild.allocator.buffer(capacity: 8192)
        payload.writeRepeatingByte(0x3c, count: 8192)
        try serverChild.writeAndFlush(SSHChannelData(type: .channel, data: .byteBuffer(payload))).wait()
        try channels.interactInMemory()

        let snapshot = try #require(channels.clientSSHHandler?.rekeySnapshot)
        #expect(snapshot.keyExchangeGeneration == 2)
        #expect(!snapshot.keyExchangeInProgress)
    }

    @Test("Injected monotonic clock deterministically triggers elapsed-time rekey")
    func timeThreshold() throws {
        let channels = BackToBackEmbeddedChannel()
        let clock = ReluxFakeRekeyClock()
        defer { try? channels.finish() }

        try channels.configureWithHarness(
            TestHarness(),
            clientRekeyPolicy: .init(elapsedTimeThreshold: .seconds(10)),
            clientRekeyClock: clock
        )
        try channels.activate()
        try channels.interactInMemory()

        clock.advance(by: .seconds(10))
        channels.advanceTime(by: .seconds(10))
        try channels.interactInMemory()

        let snapshot = try #require(channels.clientSSHHandler?.rekeySnapshot)
        #expect(snapshot.keyExchangeGeneration == 2)
        #expect(!snapshot.keyExchangeInProgress)
    }

    @Test("Simultaneous byte and elapsed thresholds coalesce into one key exchange")
    func simultaneousThresholdsCoalesce() throws {
        let channels = BackToBackEmbeddedChannel()
        let clock = ReluxFakeRekeyClock()
        defer { try? channels.finish() }

        try channels.configureWithHarness(
            TestHarness(),
            clientRekeyPolicy: .init(
                outboundByteThreshold: 4096,
                elapsedTimeThreshold: .seconds(10)
            ),
            clientRekeyClock: clock
        )
        try channels.activate()
        try channels.interactInMemory()

        let events = UserEventExpecter()
        try channels.client.pipeline.syncOperations.addHandler(events)
        let clientChild = try channels.createNewChannel()
        try channels.interactInMemory()

        clock.advance(by: .seconds(10))
        var payload = clientChild.allocator.buffer(capacity: 8192)
        payload.writeRepeatingByte(0xa5, count: 8192)
        try clientChild.writeAndFlush(SSHChannelData(type: .channel, data: .byteBuffer(payload))).wait()
        try channels.interactInMemory()

        let started = events.userEvents.compactMap { $0 as? NIOSSHRekeyStartedEvent }
        #expect(started.count == 1)
        #expect(started.first?.reasons == [.outboundByteThreshold, .elapsedTimeThreshold])
        #expect(channels.clientSSHHandler?.rekeySnapshot.keyExchangeGeneration == 2)
    }

    @Test("Concurrent explicit requests share one production-path key exchange")
    func explicitRequestsCoalesce() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        try channels.configureWithHarness(TestHarness())
        try channels.activate()
        try channels.interactInMemory()

        let first = channels.client.eventLoop.makePromise(of: Void.self)
        let second = channels.client.eventLoop.makePromise(of: Void.self)
        channels.clientSSHHandler?.requestRekey(reason: .manual, promise: first)
        channels.clientSSHHandler?.requestRekey(reason: .manual, promise: second)
        #expect(channels.clientSSHHandler?.rekeySnapshot.keyExchangeInProgress == true)

        try channels.interactInMemory()
        try first.futureResult.wait()
        try second.futureResult.wait()
        #expect(channels.clientSSHHandler?.rekeySnapshot.keyExchangeGeneration == 2)
    }

    @Test("Server-initiated rekey remains supported and observable")
    func serverInitiatedRekey() throws {
        let channels = BackToBackEmbeddedChannel()
        defer { try? channels.finish() }

        try channels.configureWithHarness(TestHarness())
        try channels.activate()
        try channels.interactInMemory()

        let events = UserEventExpecter()
        try channels.client.pipeline.syncOperations.addHandler(events)
        channels.serverSSHHandler?.requestRekey(reason: .manual)
        try channels.interactInMemory()

        let started = events.userEvents.compactMap { $0 as? NIOSSHRekeyStartedEvent }
        let succeeded = events.userEvents.compactMap { $0 as? NIOSSHRekeySucceededEvent }
        #expect(started.contains { $0.reasons.contains(.serverInitiated) })
        #expect(succeeded.contains { $0.reasons.contains(.serverInitiated) })
        #expect(channels.clientSSHHandler?.rekeySnapshot.keyExchangeGeneration == 2)
    }
}
