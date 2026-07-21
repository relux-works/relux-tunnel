package smoke

import (
	"bytes"
	"runtime"
	"strconv"
	"testing"

	"github.com/relux-works/relux-tunnel/relay/internal/buildinfo"
	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

func TestWriteIsDeterministicAndFeatureNeutral(t *testing.T) {
	previousVersion, previousCommit := buildinfo.Version, buildinfo.Commit
	t.Cleanup(func() {
		buildinfo.Version = previousVersion
		buildinfo.Commit = previousCommit
	})
	buildinfo.Version = "0.1.0"
	buildinfo.Commit = "0123456789abcdef0123456789abcdef01234567"

	var first bytes.Buffer
	if err := Write(&first, "relux-relay"); err != nil {
		t.Fatal(err)
	}
	var second bytes.Buffer
	if err := Write(&second, "relux-relay"); err != nil {
		t.Fatal(err)
	}
	if first.String() != second.String() {
		t.Fatal("smoke output changed between identical calls")
	}

	want := "{\"schemaVersion\":1,\"executable\":\"relux-relay\",\"executableVersion\":\"0.1.0\",\"protocolVersion\":" +
		strconv.Itoa(int(protocol.WireVersion)) +
		",\"sourceRevision\":\"0123456789abcdef0123456789abcdef01234567\",\"buildTarget\":\"" +
		runtime.GOOS + "/" + runtime.GOARCH +
		"\",\"contract\":\"metadata-and-empty-health\",\"relayBehaviorImplemented\":false,\"status\":\"ok\"}\n"
	if first.String() != want {
		t.Fatalf("unexpected smoke output: %q", first.String())
	}
}
