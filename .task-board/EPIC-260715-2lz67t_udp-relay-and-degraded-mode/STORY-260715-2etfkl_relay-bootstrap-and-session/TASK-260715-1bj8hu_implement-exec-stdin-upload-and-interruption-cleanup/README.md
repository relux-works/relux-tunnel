# Implement exec-stdin relay upload and interruption cleanup

## Description
Stream the locally verified selected asset over an authenticated exec channel into a random private temporary file with bounded backpressure, exact byte accounting, timeout, cancellation, and deterministic cleanup.

## Scope
In scope: local manifest size and hash precheck; random validated temporary basename; fixed umask and create command; binary stdin writes; bounded chunks and outstanding bytes; SSH writability; remote exit and stderr bounds; byte count; local streaming hash; timeout; user stop; channel loss; partial-file removal; generation safety; aggregate progress metrics. Out of scope: SFTP, base64 transport unless separately justified, resuming partial uploads, checksum acceptance, final chmod or rename, executing the file, progress UI, and caching upload bytes outside the bundle.

## Acceptance Criteria
1. Upload begins only after the selected local asset matches its bundled size and SHA-256 and the remote target path has passed the private path policy. 2. Binary bytes are written without shell or text transformation, outstanding data never exceeds the configured ceiling, and success requires exact local and remote byte counts plus zero remote exit status. 3. Timeout, cancellation, SSH backpressure, early EOF, remote write failure, disk-full, stderr overflow, and lane loss close the channel and schedule idempotent removal of the random partial file. 4. Late callbacks from a cancelled or replaced generation cannot mark upload success, rename, execute, or retain buffer ownership. 5. Fake-channel and controlled-host tests cover zero and boundary writes, partial acknowledgements, stalls, interruptions at every phase, exact hash and count accounting, and return tasks, buffers, channel, and temporary files to baseline.
