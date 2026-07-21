package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"github.com/relux-works/relux-tunnel/relay/internal/buildinfo"
	relaystdio "github.com/relux-works/relux-tunnel/relay/internal/stdio"
)

const (
	exitSuccess          = 0
	exitUsage            = 64
	exitProtocol         = 65
	exitInternal         = 70
	exitIO               = 74
	exitInterrupted      = 130
	maximumArguments     = 3
	maximumArgumentBytes = 64
)

type invocationMode uint8

const (
	invocationUnsupported invocationMode = iota
	invocationIdentity
	invocationStdio
)

type identityWriter func(io.Writer) *buildinfo.IdentityError

func main() {
	// A closed SSH stdout must become a deterministic write error, not an
	// asynchronous SIGPIPE termination.
	signal.Ignore(syscall.SIGPIPE)
	termination := make(chan os.Signal, 1)
	signal.Notify(termination, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-termination
		os.Exit(exitInterrupted)
	}()
	os.Exit(run(context.Background(), os.Args[1:], os.Stdin, os.Stdout, os.Stderr, buildinfo.WriteIdentity))
}

func run(
	ctx context.Context,
	arguments []string,
	input io.ReadCloser,
	output io.WriteCloser,
	diagnostics io.Writer,
	writeIdentity identityWriter,
) int {
	switch parseInvocation(arguments) {
	case invocationIdentity:
		if failure := writeIdentity(output); failure != nil {
			writeDiagnostic(diagnostics, "relux-relay: identity unavailable")
			return exitInternal
		}
		return exitSuccess
	case invocationStdio:
		failure := relaystdio.Run(ctx, input, output, relaystdio.DefaultConfig())
		if failure == nil {
			return exitSuccess
		}
		switch failure.Code {
		case relaystdio.ErrorCancelled:
			writeDiagnostic(diagnostics, "relux-relay: interrupted")
			return exitInterrupted
		case relaystdio.ErrorStreamFailure:
			writeDiagnostic(diagnostics, "relux-relay: stream failure")
			return exitIO
		case relaystdio.ErrorProtocolRejected:
			writeDiagnostic(diagnostics, "relux-relay: protocol rejected")
			return exitProtocol
		default:
			writeDiagnostic(diagnostics, "relux-relay: relay unavailable")
			return exitInternal
		}
	default:
		writeDiagnostic(diagnostics, "relux-relay: unsupported invocation")
		return exitUsage
	}
}

func parseInvocation(arguments []string) invocationMode {
	if len(arguments) != maximumArguments {
		return invocationUnsupported
	}
	totalBytes := 0
	for _, argument := range arguments {
		totalBytes += len(argument)
		if len(argument) > maximumArgumentBytes || totalBytes > maximumArgumentBytes {
			return invocationUnsupported
		}
	}
	if arguments[1] != "--protocol" || arguments[2] != "1" {
		return invocationUnsupported
	}
	switch arguments[0] {
	case "--identity":
		return invocationIdentity
	case "--stdio":
		return invocationStdio
	default:
		return invocationUnsupported
	}
}

func writeDiagnostic(output io.Writer, message string) {
	_, _ = fmt.Fprintln(output, message)
}
