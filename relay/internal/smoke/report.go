// Package smoke emits the credential-free metadata contract shared by relay
// and protocol-test binaries.
package smoke

import (
	"encoding/json"
	"fmt"
	"io"
	"runtime"

	"github.com/relux-works/relux-tunnel/relay/internal/buildinfo"
	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

const SchemaVersion = 1

type Report struct {
	SchemaVersion            int    `json:"schemaVersion"`
	Executable               string `json:"executable"`
	ExecutableVersion        string `json:"executableVersion"`
	ProtocolVersion          uint16 `json:"protocolVersion"`
	SourceRevision           string `json:"sourceRevision"`
	BuildTarget              string `json:"buildTarget"`
	Contract                 string `json:"contract"`
	RelayBehaviorImplemented bool   `json:"relayBehaviorImplemented"`
	Status                   string `json:"status"`
}

func Current(executable string) Report {
	return Report{
		SchemaVersion:            SchemaVersion,
		Executable:               executable,
		ExecutableVersion:        buildinfo.Version,
		ProtocolVersion:          protocol.WireVersion,
		SourceRevision:           buildinfo.Commit,
		BuildTarget:              runtime.GOOS + "/" + runtime.GOARCH,
		Contract:                 "metadata-and-empty-health",
		RelayBehaviorImplemented: false,
		Status:                   "ok",
	}
}

func Write(output io.Writer, executable string) error {
	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(Current(executable)); err != nil {
		return fmt.Errorf("encode smoke report: %w", err)
	}
	return nil
}
