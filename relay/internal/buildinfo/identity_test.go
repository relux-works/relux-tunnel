package buildinfo

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"strings"
	"testing"
)

type readCloser struct {
	io.Reader
	closeError error
}

func (r *readCloser) Close() error { return r.closeError }

func validIdentitySource(contents []byte) identitySource {
	return identitySource{
		version: "1.2.3-beta.1",
		commit:  "0123456789abcdef0123456789abcdef01234567",
		os:      "linux",
		arch:    "arm64",
		executable: func() (string, error) {
			return "/private/redacted/relux-relay", nil
		},
		open: func(string) (io.ReadCloser, error) {
			return &readCloser{Reader: bytes.NewReader(contents)}, nil
		},
	}
}

func TestIdentityFromHashesSelectedExecutableBytes(t *testing.T) {
	contents := []byte("synthetic executable bytes")
	identity, failure := identityFrom(validIdentitySource(contents))
	if failure != nil {
		t.Fatal(failure)
	}
	want := sha256.Sum256(contents)
	if identity.SelfSHA256 != hex.EncodeToString(want[:]) {
		t.Fatalf("self hash = %q", identity.SelfSHA256)
	}
	if identity.SchemaVersion != 1 || identity.RelayProtocolVersion != 1 ||
		identity.RelayVersion != "1.2.3-beta.1" ||
		identity.SourceCommit != "0123456789abcdef0123456789abcdef01234567" ||
		identity.OS != "linux" || identity.Arch != "arm64" {
		t.Fatalf("unexpected identity: %#v", identity)
	}
}

func TestIdentityFromRejectsInvalidBuildAndPlatform(t *testing.T) {
	for name, mutate := range map[string]func(*identitySource){
		"development version": func(source *identitySource) { source.version = "development" },
		"oversized version":   func(source *identitySource) { source.version = strings.Repeat("1", MaximumVersionBytes+1) },
		"uppercase commit":    func(source *identitySource) { source.commit = strings.Repeat("A", 40) },
		"unknown os":          func(source *identitySource) { source.os = "plan9" },
		"unknown arch":        func(source *identitySource) { source.arch = "riscv64" },
	} {
		t.Run(name, func(t *testing.T) {
			source := validIdentitySource(nil)
			mutate(&source)
			_, failure := identityFrom(source)
			if failure == nil || (failure.Code != IdentityInvalidBuild && failure.Code != IdentityUnsupported) {
				t.Fatalf("failure = %#v", failure)
			}
		})
	}
}

func TestIdentityFromMapsExecutableFailuresWithoutSensitiveText(t *testing.T) {
	sensitive := "credential.example payload command stdin"
	for _, test := range []struct {
		name   string
		mutate func(*identitySource)
		want   IdentityErrorCode
	}{
		{"path", func(source *identitySource) {
			source.executable = func() (string, error) { return "", errors.New(sensitive) }
		}, IdentityExecutable},
		{"open", func(source *identitySource) {
			source.open = func(string) (io.ReadCloser, error) { return nil, errors.New(sensitive) }
		}, IdentityRead},
		{"read", func(source *identitySource) {
			source.open = func(string) (io.ReadCloser, error) { return &readCloser{Reader: errorReader{}}, nil }
		}, IdentityRead},
		{"close", func(source *identitySource) {
			source.open = func(string) (io.ReadCloser, error) {
				return &readCloser{Reader: bytes.NewReader(nil), closeError: errors.New(sensitive)}, nil
			}
		}, IdentityRead},
	} {
		t.Run(test.name, func(t *testing.T) {
			source := validIdentitySource(nil)
			test.mutate(&source)
			_, failure := identityFrom(source)
			if failure == nil || failure.Code != test.want {
				t.Fatalf("failure = %#v", failure)
			}
			if strings.Contains(failure.Error(), sensitive) {
				t.Fatal("identity failure exposed sensitive source text")
			}
		})
	}
}

type errorReader struct{}

func (errorReader) Read([]byte) (int, error) { return 0, errors.New("sensitive read failure") }

func TestCanonicalSHA256Validation(t *testing.T) {
	valid := strings.Repeat("a0", sha256.Size)
	if !IsCanonicalSHA256(valid) {
		t.Fatal("canonical hash rejected")
	}
	for _, invalid := range []string{valid[:63], strings.ToUpper(valid), strings.Repeat("z", 64)} {
		if IsCanonicalSHA256(invalid) {
			t.Fatalf("invalid hash accepted: %q", invalid)
		}
	}
}

type oneByteWriter struct {
	bytes.Buffer
}

func (w *oneByteWriter) Write(input []byte) (int, error) {
	if len(input) == 0 {
		return 0, nil
	}
	return w.Buffer.Write(input[:1])
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, errors.New("sensitive output failure") }

func TestWriteIdentityIsCanonicalBoundedAndHandlesPartialWrites(t *testing.T) {
	identity, failure := identityFrom(validIdentitySource([]byte("executable")))
	if failure != nil {
		t.Fatal(failure)
	}
	var first bytes.Buffer
	if failure := writeIdentity(&first, identity); failure != nil {
		t.Fatal(failure)
	}
	partial := &oneByteWriter{}
	if failure := writeIdentity(partial, identity); failure != nil {
		t.Fatal(failure)
	}
	if first.String() != partial.String() || len(first.Bytes()) > MaximumIdentityBytes ||
		bytes.Count(first.Bytes(), []byte{'\n'}) != 1 || first.Bytes()[first.Len()-1] != '\n' {
		t.Fatalf("noncanonical identity line: %q", first.String())
	}
	wantPrefix := "{\"schemaVersion\":1,\"relayProtocolVersion\":1,\"relayVersion\":\"1.2.3-beta.1\",\"sourceCommit\":\"0123456789abcdef0123456789abcdef01234567\",\"os\":\"linux\",\"arch\":\"arm64\",\"selfSha256\":\""
	if !strings.HasPrefix(first.String(), wantPrefix) || !strings.HasSuffix(first.String(), "\"}\n") {
		t.Fatalf("identity key order changed: %q", first.String())
	}
	if failure := writeIdentity(failingWriter{}, identity); failure == nil || failure.Code != IdentityWrite {
		t.Fatalf("write failure = %#v", failure)
	}
	identity.RelayVersion = strings.Repeat("x", MaximumIdentityBytes)
	if failure := writeIdentity(io.Discard, identity); failure == nil || failure.Code != IdentityEncode {
		t.Fatalf("oversized identity failure = %#v", failure)
	}
}
