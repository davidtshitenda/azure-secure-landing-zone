## Phase 1: Remote state storage

- **Decision:** Terraform state lives in a separate storage account with versioning enabled.
- **Why:** State is the source of truth for the environment. A separate account means destroying the lab does not destroy the state, and versioning lets me recover from a bad apply or a corrupted file.
- **Alternative considered:** Local state on my laptop. Rejected because it cannot be shared with a pipeline and is lost if the machine fails.
- **Trade-off:** One extra resource to pay for and protect, which I locked against deletion.

![Blob versioning enabled](images/phase1-blob-versioning-enabled.png)