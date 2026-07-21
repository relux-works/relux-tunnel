package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/relux-works/relux-tunnel/relay/internal/buildinfo"
	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

const (
	testVersion = "1.2.3-test.1"
	testCommit  = "0123456789abcdef0123456789abcdef01234567"
)

type writeCloseBuffer struct {
	bytes.Buffer
}

func (*writeCloseBuffer) Close() error { return nil }

func TestParseInvocationIsExactAndBounded(t *testing.T) {
	for _, test := range []struct {
		name      string
		arguments []string
		want      invocationMode
	}{
		{"identity", []string{"--identity", "--protocol", "1"}, invocationIdentity},
		{"stdio", []string{"--stdio", "--protocol", "1"}, invocationStdio},
		{"empty", nil, invocationUnsupported},
		{"missing", []string{"--stdio", "--protocol"}, invocationUnsupported},
		{"duplicate", []string{"--stdio", "--stdio", "--protocol", "1"}, invocationUnsupported},
		{"wrong order", []string{"--protocol", "1", "--stdio"}, invocationUnsupported},
		{"wrong version", []string{"--stdio", "--protocol", "2"}, invocationUnsupported},
		{"unknown", []string{"--command", "--protocol", "1"}, invocationUnsupported},
		{"oversized", []string{"--stdio", "--protocol", strings.Repeat("1", maximumArgumentBytes+1)}, invocationUnsupported},
		{"oversized total", []string{strings.Repeat("a", 30), strings.Repeat("b", 30), strings.Repeat("c", 10)}, invocationUnsupported},
	} {
		t.Run(test.name, func(t *testing.T) {
			if got := parseInvocation(test.arguments); got != test.want {
				t.Fatalf("parseInvocation() = %d, want %d", got, test.want)
			}
		})
	}
}

func TestRunIdentityAndUnsupportedInvocationSeparateStreams(t *testing.T) {
	for _, test := range []struct {
		name       string
		arguments  []string
		writer     identityWriter
		wantStatus int
		wantStdout string
		wantStderr string
	}{
		{
			"identity",
			[]string{"--identity", "--protocol", "1"},
			func(output io.Writer) *buildinfo.IdentityError {
				_, _ = io.WriteString(output, "{\"fixed\":true}\n")
				return nil
			},
			exitSuccess,
			"{\"fixed\":true}\n",
			"",
		},
		{
			"identity failure",
			[]string{"--identity", "--protocol", "1"},
			func(io.Writer) *buildinfo.IdentityError {
				return &buildinfo.IdentityError{Code: buildinfo.IdentityRead}
			},
			exitInternal,
			"",
			"relux-relay: identity unavailable\n",
		},
		{
			"unsupported",
			[]string{"credential.example payload command stdin"},
			func(io.Writer) *buildinfo.IdentityError { return nil },
			exitUsage,
			"",
			"relux-relay: unsupported invocation\n",
		},
	} {
		t.Run(test.name, func(t *testing.T) {
			var output, diagnostics writeCloseBuffer
			status := run(
				context.Background(),
				test.arguments,
				io.NopCloser(bytes.NewReader(nil)),
				&output,
				&diagnostics,
				test.writer,
			)
			if status != test.wantStatus || output.String() != test.wantStdout || diagnostics.String() != test.wantStderr {
				t.Fatalf("status=%d stdout=%q stderr=%q", status, output.String(), diagnostics.String())
			}
		})
	}
}

func TestRunSupportedStdioWritesOnlyProtocolBytes(t *testing.T) {
	inputBytes := append(testClientHello(), testClientFrame(protocol.MessageTypeCloseSession, nil)...)
	var output, diagnostics writeCloseBuffer
	status := run(
		context.Background(),
		[]string{"--stdio", "--protocol", "1"},
		io.NopCloser(bytes.NewReader(inputBytes)),
		&output,
		&diagnostics,
		func(io.Writer) *buildinfo.IdentityError { return nil },
	)
	if status != exitSuccess || diagnostics.Len() != 0 {
		t.Fatalf("status=%d stderr=%q", status, diagnostics.String())
	}
	serverHello := protocol.EncodeServerHello(
		protocol.WireVersion,
		protocol.HelloStatusAccepted,
		0,
		protocol.MaxFrameDefault,
	)
	want := append(serverHello[:], testRelayFrame(protocol.MessageTypeCloseSession, nil)...)
	if !bytes.Equal(output.Bytes(), want) {
		t.Fatalf("stdout = %x, want %x", output.Bytes(), want)
	}
}

func TestExecutableEntrypointContract(t *testing.T) {
	binary := buildTestExecutable(t)
	t.Run("identity self hash and canonical output", func(t *testing.T) {
		command := exec.Command(binary, "--identity", "--protocol", "1")
		var diagnostics bytes.Buffer
		command.Stderr = &diagnostics
		output, err := command.Output()
		if err != nil {
			t.Fatalf("identity failed: %v stderr=%q", err, diagnostics.String())
		}
		if diagnostics.Len() != 0 || len(output) > buildinfo.MaximumIdentityBytes || bytes.Count(output, []byte{'\n'}) != 1 || output[len(output)-1] != '\n' {
			t.Fatalf("identity framing stdout=%q stderr=%q", output, diagnostics.String())
		}
		var identity buildinfo.Identity
		if err := json.Unmarshal(output, &identity); err != nil {
			t.Fatal(err)
		}
		contents, err := os.ReadFile(binary)
		if err != nil {
			t.Fatal(err)
		}
		digest := sha256.Sum256(contents)
		wantHash := hex.EncodeToString(digest[:])
		expectedIdentity := buildinfo.Identity{
			SchemaVersion:        1,
			RelayProtocolVersion: 1,
			RelayVersion:         testVersion,
			SourceCommit:         testCommit,
			OS:                   runtime.GOOS,
			Arch:                 runtime.GOARCH,
			SelfSHA256:           wantHash,
		}
		if identity != expectedIdentity {
			t.Fatalf("identity = %#v", identity)
		}
		wantLine := fmt.Sprintf(
			"{\"schemaVersion\":1,\"relayProtocolVersion\":1,\"relayVersion\":%q,\"sourceCommit\":%q,\"os\":%q,\"arch\":%q,\"selfSha256\":%q}\n",
			testVersion,
			testCommit,
			runtime.GOOS,
			runtime.GOARCH,
			wantHash,
		)
		if string(output) != wantLine {
			t.Fatalf("noncanonical identity stdout: %q", output)
		}
	})

	t.Run("unknown duplicate missing and oversized arguments", func(t *testing.T) {
		for name, arguments := range map[string][]string{
			"unknown":   {"payload.example", "--protocol", "1"},
			"duplicate": {"--stdio", "--stdio", "--protocol", "1"},
			"missing":   {"--stdio", "--protocol"},
			"oversized": {"--stdio", "--protocol", strings.Repeat("x", maximumArgumentBytes+1)},
			"legacy":    {"smoke"},
		} {
			t.Run(name, func(t *testing.T) {
				command := exec.Command(binary, arguments...)
				var stdout, stderr bytes.Buffer
				command.Stdout, command.Stderr = &stdout, &stderr
				err := command.Run()
				assertExitCode(t, err, exitUsage)
				if stdout.Len() != 0 || stderr.String() != "relux-relay: unsupported invocation\n" {
					t.Fatalf("stdout=%q stderr=%q", stdout.String(), stderr.String())
				}
				for _, argument := range arguments {
					if argument != "" && strings.Contains(stderr.String(), argument) {
						t.Fatal("stderr echoed an argument")
					}
				}
			})
		}
	})

	t.Run("handshake framing clean EOF and repeated exit", func(t *testing.T) {
		serverHello := protocol.EncodeServerHello(
			protocol.WireVersion,
			protocol.HelloStatusAccepted,
			0,
			protocol.MaxFrameDefault,
		)
		for iteration := 0; iteration < 12; iteration++ {
			command := exec.Command(binary, "--stdio", "--protocol", "1")
			command.Stdin = bytes.NewReader(testClientHello())
			var stdout, stderr bytes.Buffer
			command.Stdout, command.Stderr = &stdout, &stderr
			if err := command.Run(); err != nil {
				t.Fatalf("iteration %d: %v stderr=%q", iteration, err, stderr.String())
			}
			if !bytes.Equal(stdout.Bytes(), serverHello[:]) || stderr.Len() != 0 {
				t.Fatalf("iteration %d stdout=%x stderr=%q", iteration, stdout.Bytes(), stderr.String())
			}
		}
	})

	t.Run("malformed hello", func(t *testing.T) {
		hello := testClientHello()
		hello[0] = 'X'
		command := exec.Command(binary, "--stdio", "--protocol", "1")
		stdin, err := command.StdinPipe()
		if err != nil {
			t.Fatal(err)
		}
		stdout, err := command.StdoutPipe()
		if err != nil {
			t.Fatal(err)
		}
		var stderr bytes.Buffer
		command.Stderr = &stderr
		if err := command.Start(); err != nil {
			t.Fatal(err)
		}
		if _, err := stdin.Write(hello); err != nil {
			t.Fatal(err)
		}
		reply := make([]byte, protocol.ServerHelloWidth)
		if _, err := io.ReadFull(stdout, reply); err != nil {
			t.Fatal(err)
		}
		err = waitCommand(command, 2*time.Second)
		_ = stdin.Close()
		assertExitCode(t, err, exitProtocol)
		want := protocol.EncodeServerHello(protocol.WireVersion, protocol.HelloStatusInvalidClientHello, 0, 0)
		if !bytes.Equal(reply, want[:]) || stderr.String() != "relux-relay: protocol rejected\n" {
			t.Fatalf("stdout=%x stderr=%q", reply, stderr.String())
		}
	})

	t.Run("peer close exits while stdin remains open", func(t *testing.T) {
		command := exec.Command(binary, "--stdio", "--protocol", "1")
		stdin, err := command.StdinPipe()
		if err != nil {
			t.Fatal(err)
		}
		stdout, err := command.StdoutPipe()
		if err != nil {
			t.Fatal(err)
		}
		var stderr bytes.Buffer
		command.Stderr = &stderr
		if err := command.Start(); err != nil {
			t.Fatal(err)
		}
		input := append(testClientHello(), testClientFrame(protocol.MessageTypeCloseSession, nil)...)
		if _, err := stdin.Write(input); err != nil {
			t.Fatal(err)
		}
		reply := make([]byte, protocol.ServerHelloWidth+10)
		if _, err := io.ReadFull(stdout, reply); err != nil {
			t.Fatal(err)
		}
		if err := waitCommand(command, 2*time.Second); err != nil {
			t.Fatal(err)
		}
		_ = stdin.Close()
		if stderr.Len() != 0 {
			t.Fatalf("stderr=%q", stderr.String())
		}
	})

	t.Run("closed stdout", func(t *testing.T) {
		readEnd, writeEnd, err := os.Pipe()
		if err != nil {
			t.Fatal(err)
		}
		if err := readEnd.Close(); err != nil {
			t.Fatal(err)
		}
		command := exec.Command(binary, "--stdio", "--protocol", "1")
		command.Stdin = bytes.NewReader(testClientHello())
		command.Stdout = writeEnd
		var stderr bytes.Buffer
		command.Stderr = &stderr
		if err := command.Start(); err != nil {
			t.Fatal(err)
		}
		_ = writeEnd.Close()
		err = command.Wait()
		assertExitCode(t, err, exitIO)
		if stderr.String() != "relux-relay: stream failure\n" {
			t.Fatalf("stderr=%q", stderr.String())
		}
	})

	for signalName, terminationSignal := range map[string]os.Signal{
		"SIGINT":  os.Interrupt,
		"SIGTERM": syscall.SIGTERM,
	} {
		t.Run("termination signal "+signalName, func(t *testing.T) {
			command := exec.Command(binary, "--stdio", "--protocol", "1")
			stdin, err := command.StdinPipe()
			if err != nil {
				t.Fatal(err)
			}
			stdout, err := command.StdoutPipe()
			if err != nil {
				t.Fatal(err)
			}
			var stderr bytes.Buffer
			command.Stderr = &stderr
			if err := command.Start(); err != nil {
				t.Fatal(err)
			}
			if _, err := stdin.Write(testClientHello()); err != nil {
				t.Fatal(err)
			}
			reply := make([]byte, protocol.ServerHelloWidth)
			if _, err := io.ReadFull(stdout, reply); err != nil {
				t.Fatal(err)
			}
			if err := command.Process.Signal(terminationSignal); err != nil {
				t.Fatal(err)
			}
			err = command.Wait()
			_ = stdin.Close()
			assertExitCode(t, err, exitInterrupted)
			wantReply := protocol.EncodeServerHello(
				protocol.WireVersion,
				protocol.HelloStatusAccepted,
				0,
				protocol.MaxFrameDefault,
			)
			if !bytes.Equal(reply, wantReply[:]) || stderr.Len() != 0 {
				t.Fatalf("stdout=%x stderr=%q", reply, stderr.String())
			}
		})
	}

	t.Run("no runtime files", func(t *testing.T) {
		workingDirectory := t.TempDir()
		command := exec.Command(binary, "--identity", "--protocol", "1")
		command.Dir = workingDirectory
		if output, err := command.CombinedOutput(); err != nil {
			t.Fatalf("identity failed: %v output=%q", err, output)
		}
		entries, err := os.ReadDir(workingDirectory)
		if err != nil {
			t.Fatal(err)
		}
		if len(entries) != 0 {
			t.Fatalf("runtime files created: %v", entries)
		}
	})
}

func TestEntrypointDependencyBoundary(t *testing.T) {
	goCommand := filepath.Join(runtime.GOROOT(), "bin", "go")
	command := exec.Command(goCommand, "list", "-deps", ".")
	output, err := command.Output()
	if err != nil {
		t.Fatal(err)
	}
	dependencies := "\n" + string(output)
	for _, forbidden := range []string{"\nnet\n", "\nos/exec\n"} {
		if strings.Contains(dependencies, forbidden) {
			t.Fatalf("entrypoint includes forbidden runtime dependency %q", strings.TrimSpace(forbidden))
		}
	}
}

func buildTestExecutable(t *testing.T) string {
	t.Helper()
	output := filepath.Join(t.TempDir(), "relux-relay")
	goCommand := filepath.Join(runtime.GOROOT(), "bin", "go")
	ldflags := strings.Join([]string{
		"-buildid=",
		"-X", "github.com/relux-works/relux-tunnel/relay/internal/buildinfo.Version=" + testVersion,
		"-X", "github.com/relux-works/relux-tunnel/relay/internal/buildinfo.Commit=" + testCommit,
	}, " ")
	command := exec.Command(goCommand, "build", "-mod=readonly", "-trimpath", "-buildvcs=false", "-ldflags="+ldflags, "-o", output, ".")
	command.Env = append(os.Environ(), "CGO_ENABLED=0", "GOTOOLCHAIN=local", "GOWORK=off", "GOPROXY=off", "GOSUMDB=off")
	if combined, err := command.CombinedOutput(); err != nil {
		t.Fatalf("build entrypoint: %v output=%s", err, combined)
	}
	return output
}

func assertExitCode(t testing.TB, err error, want int) {
	t.Helper()
	var exitError *exec.ExitError
	if !errors.As(err, &exitError) || exitError.ExitCode() != want {
		t.Fatalf("exit error = %v, want code %d", err, want)
	}
}

func waitCommand(command *exec.Cmd, timeout time.Duration) error {
	result := make(chan error, 1)
	go func() { result <- command.Wait() }()
	select {
	case err := <-result:
		return err
	case <-time.After(timeout):
		_ = command.Process.Kill()
		<-result
		return errors.New("relux-relay process did not exit")
	}
}

func testClientHello() []byte {
	result := make([]byte, protocol.ClientHelloWidth)
	copy(result, protocol.Magic[:])
	binary.BigEndian.PutUint16(result[4:6], protocol.WireVersion)
	binary.BigEndian.PutUint32(result[8:12], protocol.MaxFrameDefault)
	return result
}

func testClientFrame(messageType protocol.MessageType, payload []byte) []byte {
	result := make([]byte, 10+len(payload))
	binary.BigEndian.PutUint32(result[:4], uint32(protocol.EnvelopeHeaderWidth+len(payload)))
	result[4] = byte(messageType)
	copy(result[10:], payload)
	return result
}

func testRelayFrame(messageType protocol.MessageType, payload []byte) []byte {
	return testClientFrame(messageType, payload)
}
