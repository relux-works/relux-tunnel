package main

import (
	"fmt"
	"io"
	"os"

	"github.com/relux-works/relux-tunnel/relay/internal/smoke"
)

const executableName = "relux-relay"

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(arguments []string, output io.Writer, errors io.Writer) int {
	if len(arguments) == 1 && arguments[0] == "smoke" {
		if err := smoke.Write(output, executableName); err != nil {
			fmt.Fprintln(errors, "relux-relay: smoke report failed")
			return 1
		}
		return 0
	}
	fmt.Fprintln(errors, "relux-relay: supported command: smoke")
	return 2
}
