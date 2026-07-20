# TASK-260715-1q4qhw — validation and artifact hashes

## Validation

```text
task-board validate
Board is valid. No issues found.

git diff --check
(no output)

java -jar .temp/tools/plantuml.jar -checkonly \
  .temp/TASK-260715-1q4qhw_manager-provider-sequence.puml \
  .temp/TASK-260715-1q4qhw_authority-state.puml
(exit 0)
```

Both diagrams were rendered to PNG and visually inspected. The sequence view
shows install/update, explicit enable, system start, read-only messaging, and
joined stop cleanup. The authority view uses PlantUML's bundled ELK layout and
shows disabled/disconnected/connecting/connected/reasserting/disconnecting/
invalid states plus provider capability substates without cropping.

No implementation code was changed and no product test/build was required.
The architecture review inspected the Xcode 26.5 NetworkExtension public headers
for manager load/save/remove, status/error enums, session start/stop/message,
provider start/stop, completion ownership, sleep/wake, and app-message behavior.

## SHA-256

```text
b0f9ff61995b87a12d6e3ffe35befdadf0b96693ed94d9371ca376452c545eb7  TASK-260715-1q4qhw_runtime-lifecycle-contract.md
8930bfcc0167f67bdf1b4cb007a38d376bf16beefc235cc16d469247a0254a39  TASK-260715-1q4qhw_manager-provider-sequence.puml
16b2b2086751b249520ed914c3187414752249cae5198f98391c29ea5393f4b7  TASK-260715-1q4qhw_authority-state.puml
a992c1e4d1c7d72e36bf7dbbca771209cb0a29465f97034bef78899f4e6f289a  TASK-260715-1q4qhw_residual-risks.md
fa8fb88d9432b67dd0e3c7e3996759943124093d0b13faca1ab8ed4c9221edc6  TASK-260715-1q4qhw_manager-provider-sequence.png
062f93ce793ec5c6b3e0c48769f8c611327c41ce07fecc20b0e2d9f511bc2247  TASK-260715-1q4qhw_authority-state.png
```

The independent reviewer acceptance is recorded separately in
`TASK-260715-1q4qhw_agent-review.md`.
