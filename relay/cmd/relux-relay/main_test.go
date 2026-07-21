package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestSmokeCommand(t *testing.T) {
	var output, errors bytes.Buffer
	if status := run([]string{"smoke"}, &output, &errors); status != 0 {
		t.Fatalf("smoke status = %d, stderr = %q", status, errors.String())
	}
	if !strings.Contains(output.String(), `"executable":"relux-relay"`) ||
		!strings.Contains(output.String(), `"relayBehaviorImplemented":false`) {
		t.Fatalf("unexpected smoke output: %q", output.String())
	}
	if errors.Len() != 0 {
		t.Fatalf("unexpected stderr: %q", errors.String())
	}
}

func TestUnsupportedCommandDoesNotEchoInput(t *testing.T) {
	var output, errors bytes.Buffer
	untrusted := "untrusted-input"
	if status := run([]string{untrusted}, &output, &errors); status != 2 {
		t.Fatalf("unsupported command status = %d", status)
	}
	if strings.Contains(errors.String(), untrusted) {
		t.Fatal("unsupported command echoed untrusted input")
	}
}
