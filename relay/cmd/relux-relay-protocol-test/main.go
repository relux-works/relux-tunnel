package main

import (
	"fmt"
	"io"
	"os"

	"github.com/relux-works/relux-tunnel/relay/internal/protocoltest"
	"github.com/relux-works/relux-tunnel/relay/internal/smoke"
)

const executableName = "relux-relay-protocol-test"

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(arguments []string, output io.Writer, errors io.Writer) int {
	if len(arguments) == 1 {
		switch arguments[0] {
		case "smoke":
			if err := smoke.Write(output, executableName); err == nil {
				return 0
			}
		case "run":
			if err := protocoltest.Write(output); err == nil {
				return 0
			}
		}
	}
	fmt.Fprintln(errors, "relux-relay-protocol-test: supported commands: smoke, run")
	return 2
}
