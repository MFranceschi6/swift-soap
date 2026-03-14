# Skill: commit-checkpoint

## Purpose

Prepare and validate a safe checkpoint commit using repository hooks and commit-gate rules.

## Trigger Conditions

Use this skill when a meaningful technical checkpoint is ready to commit.

## Required Inputs

- checkpoint scope,
- files intended for commit,
- proposed commit message.

## Workflow Steps

1. Ensure hooks are installed in the current clone/worktree:
   - `scripts/install-git-hooks.sh`
2. Stage only intended files.
3. Run pre-commit gate (automatically via hook or manually):
   - `bash scripts/commit-gate.sh --pre-commit`
4. Validate commit message format:
   - gitmoji prefix + descriptive summary.
5. Confirm `CHANGELOG.md` contains the relevant entry.

## Validation/Gates

- Commit must fail if lint/structure checks fail.
- Commit message must satisfy gitmoji policy.
- Unrelated modified files should remain unstaged.

## Output Contract

Provide:
- staged file list,
- commit message proposal,
- gate results.

## Fallback/Failure Handling

- If gate fails, stop and provide concrete remediation steps before retrying commit.
