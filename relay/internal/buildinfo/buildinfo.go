// Package buildinfo contains the values injected into release binaries.
package buildinfo

// Version and Commit are replaced by the deterministic release build.
var (
	Version = "development"
	Commit  = "unknown"
)
