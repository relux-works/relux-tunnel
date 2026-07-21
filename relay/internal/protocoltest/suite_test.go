package protocoltest

import (
	"bytes"
	"testing"
)

func TestRunCoversOnlyHealthAndVersionMismatch(t *testing.T) {
	report, err := Run()
	if err != nil {
		t.Fatal(err)
	}
	if report.EmptyHealth != "pass" || report.VersionMismatch != "pass" || report.CasesRun != 2 || report.Status != "pass" {
		t.Fatalf("unexpected protocol-test report: %#v", report)
	}
}

func TestWriteIsDeterministic(t *testing.T) {
	var first, second bytes.Buffer
	if err := Write(&first); err != nil {
		t.Fatal(err)
	}
	if err := Write(&second); err != nil {
		t.Fatal(err)
	}
	if first.String() != second.String() {
		t.Fatal("protocol-test output changed between identical runs")
	}
}
