// Package protocoltest provides the deliberately empty protocol-test shell.
// It validates metadata health and one version-mismatch contract without
// opening sockets or exercising relay feature behavior.
package protocoltest

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

const SchemaVersion = 1

type Report struct {
	SchemaVersion   int    `json:"schemaVersion"`
	Contract        string `json:"contract"`
	EmptyHealth     string `json:"emptyHealth"`
	VersionMismatch string `json:"versionMismatch"`
	CasesRun        int    `json:"casesRun"`
	Status          string `json:"status"`
}

func Run() (Report, error) {
	report := Report{
		SchemaVersion: SchemaVersion,
		Contract:      "empty-health-and-version-mismatch",
		EmptyHealth:   "pass",
		CasesRun:      2,
	}
	if failure := protocol.DefaultServerHandshakeConfig().Validate(); failure != nil {
		return Report{}, fmt.Errorf("empty health contract failed: %w", failure)
	}

	hello := make([]byte, protocol.ClientHelloWidth)
	copy(generatedField(hello, "magic"), protocol.Magic[:])
	binary.BigEndian.PutUint16(generatedField(hello, "version"), protocol.WireVersion+1)
	binary.BigEndian.PutUint32(generatedField(hello, "maxFrame"), protocol.MaxFrameDefault)
	_, failure := protocol.DecodeClientHelloExact(hello, protocol.DefaultServerHandshakeConfig())
	if failure == nil || failure.Code != protocol.HandshakeUnsupportedVersion {
		return Report{}, fmt.Errorf("version mismatch contract did not reject the candidate version")
	}
	report.VersionMismatch = "pass"
	report.Status = "pass"
	return report, nil
}

func generatedField(input []byte, name string) []byte {
	for _, field := range protocol.ClientHelloLayout {
		if field.Name == name {
			return input[field.ByteOffset : field.ByteOffset+field.ByteWidth]
		}
	}
	panic("generated client hello layout is missing a required field")
}

func Write(output io.Writer) error {
	report, err := Run()
	if err != nil {
		return err
	}
	encoder := json.NewEncoder(output)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(report); err != nil {
		return fmt.Errorf("encode protocol-test report: %w", err)
	}
	return nil
}
