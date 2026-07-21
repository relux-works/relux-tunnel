package buildinfo

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"os"
	"regexp"
	"runtime"
	"strings"
)

const (
	IdentitySchemaVersion = 1
	RelayProtocolVersion  = 1
	MaximumIdentityBytes  = 512
	MaximumVersionBytes   = 64
)

var (
	semanticVersionPattern = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$`)
	lowerHexCommitPattern  = regexp.MustCompile(`^[0-9a-f]{40}$`)
)

// Identity is the fixed bootstrap record emitted before a protocol session.
// Field order is wire-significant because the record must be canonical.
type Identity struct {
	SchemaVersion        int    `json:"schemaVersion"`
	RelayProtocolVersion int    `json:"relayProtocolVersion"`
	RelayVersion         string `json:"relayVersion"`
	SourceCommit         string `json:"sourceCommit"`
	OS                   string `json:"os"`
	Arch                 string `json:"arch"`
	SelfSHA256           string `json:"selfSha256"`
}

type IdentityErrorCode string

const (
	IdentityInvalidBuild IdentityErrorCode = "invalidBuildIdentity"
	IdentityUnsupported  IdentityErrorCode = "unsupportedPlatform"
	IdentityExecutable   IdentityErrorCode = "executableUnavailable"
	IdentityRead         IdentityErrorCode = "executableUnreadable"
	IdentityEncode       IdentityErrorCode = "identityEncodingFailed"
	IdentityWrite        IdentityErrorCode = "identityWriteFailed"
)

// IdentityError is deliberately finite and contains no path or host error.
type IdentityError struct {
	Code IdentityErrorCode
}

func (e *IdentityError) Error() string {
	if e == nil {
		return ""
	}
	return "relayIdentity code=" + string(e.Code)
}

type identitySource struct {
	version    string
	commit     string
	os         string
	arch       string
	executable func() (string, error)
	open       func(string) (io.ReadCloser, error)
}

func runtimeIdentitySource() identitySource {
	return identitySource{
		version:    Version,
		commit:     Commit,
		os:         runtime.GOOS,
		arch:       runtime.GOARCH,
		executable: runningExecutable,
		open: func(path string) (io.ReadCloser, error) {
			return os.Open(path)
		},
	}
}

func runningExecutable() (string, error) {
	// Linux exposes the loaded executable inode even if its original pathname
	// is replaced after exec. Darwin has no equivalent cgo-free descriptor, so
	// use the standard library's process executable path there.
	if runtime.GOOS == "linux" {
		return "/proc/self/exe", nil
	}
	return os.Executable()
}

// CurrentIdentity hashes the bytes of the running executable and returns the
// canonical build tuple used by the bundle manifest.
func CurrentIdentity() (Identity, *IdentityError) {
	return identityFrom(runtimeIdentitySource())
}

func identityFrom(source identitySource) (Identity, *IdentityError) {
	if len(source.version) == 0 || len(source.version) > MaximumVersionBytes ||
		!semanticVersionPattern.MatchString(source.version) ||
		!lowerHexCommitPattern.MatchString(source.commit) {
		return Identity{}, &IdentityError{Code: IdentityInvalidBuild}
	}
	if (source.os != "linux" && source.os != "darwin") ||
		(source.arch != "amd64" && source.arch != "arm64") {
		return Identity{}, &IdentityError{Code: IdentityUnsupported}
	}
	path, err := source.executable()
	if err != nil || path == "" {
		return Identity{}, &IdentityError{Code: IdentityExecutable}
	}
	stream, err := source.open(path)
	if err != nil {
		return Identity{}, &IdentityError{Code: IdentityRead}
	}
	digest := sha256.New()
	buffer := make([]byte, 32*1024)
	_, copyErr := io.CopyBuffer(digest, stream, buffer)
	closeErr := stream.Close()
	if copyErr != nil || closeErr != nil {
		return Identity{}, &IdentityError{Code: IdentityRead}
	}
	return Identity{
		SchemaVersion:        IdentitySchemaVersion,
		RelayProtocolVersion: RelayProtocolVersion,
		RelayVersion:         source.version,
		SourceCommit:         source.commit,
		OS:                   source.os,
		Arch:                 source.arch,
		SelfSHA256:           hex.EncodeToString(digest.Sum(nil)),
	}, nil
}

// WriteIdentity writes exactly one bounded canonical JSON line.
func WriteIdentity(output io.Writer) *IdentityError {
	identity, failure := CurrentIdentity()
	if failure != nil {
		return failure
	}
	return writeIdentity(output, identity)
}

func writeIdentity(output io.Writer, identity Identity) *IdentityError {
	encoded, err := json.Marshal(identity)
	if err != nil || len(encoded)+1 > MaximumIdentityBytes {
		return &IdentityError{Code: IdentityEncode}
	}
	encoded = append(encoded, '\n')
	for len(encoded) > 0 {
		written, writeErr := output.Write(encoded)
		if writeErr != nil || written <= 0 || written > len(encoded) {
			return &IdentityError{Code: IdentityWrite}
		}
		encoded = encoded[written:]
	}
	return nil
}

// IsCanonicalSHA256 reports whether a value is the lowercase representation
// used by identity and manifest records.
func IsCanonicalSHA256(value string) bool {
	return len(value) == sha256.Size*2 && strings.ToLower(value) == value &&
		func() bool {
			_, err := hex.DecodeString(value)
			return err == nil
		}()
}
