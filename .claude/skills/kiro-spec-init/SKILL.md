---
name: kiro-spec-init
description: Initialize a new specification with detailed project description
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
argument-hint: <project-description>
---

# Spec Initialization

<instructions>
## Core Task
Generate a unique feature name from the project description ($ARGUMENTS) and initialize the specification structure.

## Execution Steps
1. **Check for Brief**: If `.kiro/specs/{feature-name}/brief.md` exists (created by `/kiro-discovery`), read it. The brief contains problem, approach, scope, and constraints from the discovery session. Use this to pre-fill the project description and skip clarification questions that the brief already answers.
2. **Clarify Intent**: The Project Description in requirements.md must contain three elements: (a) who has the problem, (b) current situation, (c) what should change. If a brief.md exists and covers these, skip to step 3. Otherwise, ask the user to clarify before proceeding. Ask as many questions as needed; do not fill in gaps with your own assumptions.
3. **Check Uniqueness**: Verify `.kiro/specs/` for naming conflicts. If the directory already exists with only `brief.md` (no `spec.json`), use that directory (discovery created it).
4. **Create Directory**: `.kiro/specs/[feature-name]/` (skip if already exists from discovery)
5. **Initialize Files Using Templates**:
   - Read `.kiro/settings/templates/specs/init.json`
   - Read `.kiro/settings/templates/specs/requirements-init.md`
   - Replace placeholders:
     - `{{FEATURE_NAME}}` → generated feature name
     - `{{TIMESTAMP}}` → current ISO 8601 timestamp
     - `{{PROJECT_DESCRIPTION}}` → from brief.md if available, otherwise $ARGUMENTS
     - `ja` → language code (detect from user's input language, default to `en`)
   - Write `spec.json` and `requirements.md` to spec directory

## Important Constraints
- Do NOT generate requirements, design, or tasks. This skill only creates spec.json and requirements.md.
</instructions>

## Output Description
Provide output in the language specified in `spec.json` with the following structure:

1. **Generated Feature Name**: `feature-name` format with 1-2 sentence rationale
2. **Project Summary**: Brief summary (1 sentence)
3. **Created Files**: Bullet list with full paths
4. **Next Step**: Command block showing `/kiro-spec-requirements <feature-name>`

**Format Requirements**:
- Use Markdown headings (##, ###)
- Wrap commands in code blocks
- Keep total output concise (under 250 words)
- Use clear, professional language per `spec.json.language`

## Safety & Fallback
- **Ambiguous Feature Name**: If feature name generation is unclear, propose 2-3 options and ask user to select
- **Template Missing**: If template files don't exist in `.kiro/settings/templates/specs/`, report error with specific missing file path and suggest checking repository setup
- **Directory Conflict**: If feature name already exists, append numeric suffix (e.g., `feature-name-2`) and notify user of automatic conflict resolution
- **Write Failure**: Report error with specific path and suggest checking permissions or disk space

<!-- SDD-OVERLAY:ENSURE-AGREEMENT-LOG:START (sdd_base_template が付加。手動編集は再 init で再付与される) -->
## Ensure agreement-log.md exists (SDD overlay)

**This repository requires every spec to have a real `agreement-log.md` file.** cc-sdd's
spec-init does not create one, so as part of initializing a spec you MUST also create it if
missing:

1. After `spec.json` / `requirements.md` are generated, check for
   `.kiro/specs/<id>/agreement-log.md`.
2. If it does not exist, create it from the template
   `docs/sdd/templates/agreement-log.md`, filling in タスクID / 作成日 / 関係者 and the
   壁打ち概要 from the spec description. Do NOT leave the agreement as conversation-only.
3. Keep it updated at each approval gate (decisions, rationale, dates). The authoritative
   approval booleans still live in `spec.json`; agreement-log records the "why".

See `docs/sdd/workflow.md` (「非コーディング作業のドキュメント化」/「承認ゲートの原則」) for the rule.
<!-- SDD-OVERLAY:ENSURE-AGREEMENT-LOG:END -->
