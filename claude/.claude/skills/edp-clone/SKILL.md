# EDP Clone

User-invocable skill for cloning EDP repositories and setting up the project.

**Usage**: `/edp-clone [host] <repo-name>`

## Parameters

- `host` (optional): `ghe` (default) or `gitlab`
- `repo-name` (required): Repository name

## Workflow

### 1. Clone the repository

Based on host:

- **GHE** (default):
  ```bash
  gh repo clone einsatzleitsoftware/<repo> ~/Develop/EDP/<repo> -- --hostname einsatzleitsoftware.ghe.com
  ```
- **GitLab**:
  ```bash
  git clone git@gitlab.eifert-systems.de:edp4/<repo>.git ~/Develop/EDP/<repo>
  ```

### 2. Run `/init`

Execute `/init` in the cloned repository to generate an initial `CLAUDE.md`.

### 3. Enhance the generated CLAUDE.md

After `/init` generates the base CLAUDE.md, append/integrate the following sections:

```markdown
## Build & Git

See `~/Develop/EDP/CLAUDE.md` for git conventions and the **edp-build** skill for build system docs.

- Deploy mode: `<determine from compile.config or ask user>`
- Service: `<determine from compile.config or ask user>`
```

Add a quick reference section:

```markdown
### Quick Reference

```bash
edp <repo-name> compile          # Incremental build
edp <repo-name> compile -b       # Full build
edp <repo-name> start / stop / status
edp <repo-name> log
```
```

### 4. Check for compile.config

If `compile.config` does not exist in the repo root, inform the user:

> No `compile.config` found. Create one to enable `edp <repo-name> compile`. See the **edp-build** skill for the format.
