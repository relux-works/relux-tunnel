package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestSmokeAndRunCommands(t *testing.T) {
	for _, test := range []struct {
		command string
		field   string
	}{
		{command: "smoke", field: `"executable":"relux-relay-protocol-test"`},
		{command: "run", field: `"versionMismatch":"pass"`},
	} {
		t.Run(test.command, func(t *testing.T) {
			var output, errors bytes.Buffer
			if status := run([]string{test.command}, &output, &errors); status != 0 {
				t.Fatalf("status = %d, stderr = %q", status, errors.String())
			}
			if !strings.Contains(output.String(), test.field) {
				t.Fatalf("output %q does not contain %q", output.String(), test.field)
			}
		})
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
