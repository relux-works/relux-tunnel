# Required SSH handoff

Before production integration, consume accepted outcomes from:

- TASK-260715-1gjxer — selected SSH engine and conformance result
- TASK-260715-3t2v9w — authenticated profile-driven SSH session bootstrap

The probe must use the accepted bidirectional exec-channel contract and must not reimplement authentication or weaken host verification.