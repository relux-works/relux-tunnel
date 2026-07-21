// Package buildinfo contains deterministic identity values injected into
// release binaries and the bounded runtime identity record.
package buildinfo

// Version and Commit are replaced by the deterministic release build.
var (
	Version = "development"
	Commit  = "unknown"
)
