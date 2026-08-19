# Local build-integrity review

This is a defensive review of the deterministic build asset publisher in this repository. Inspect the current delta and verify the existing 20 local unit tests.

Confirm that when generation initially observes no destination, a directory created by another local process before publication is preserved unchanged and generation reports an error. Verify both existing timing hooks, exact inode and marker preservation, and cleanup limited to the staging directory created by this process.

Confirm existing-directory replacement remains atomic; archive bytes are hashed and parsed through one no-follow file descriptor with fixed bounds; conversion failures close their file descriptors.

Run the 20 focused tests, formatter, deterministic bundle and identity checks, unsigned Apple product and resource validation, core and protocol checks, and the broad Swift suite. No signing, installation, app or provider launch, VPN preference, tunnel start, route, or DNS operation.

Record an independent accepted or changes-requested verdict and route the task accordingly.