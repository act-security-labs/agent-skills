# Act Security agent skills

One [Agent Skill](https://agentskills.io), `iam-tools`, that teaches your coding agent to answer AWS IAM questions by running the [Act Security Labs](https://github.com/act-security-labs) IAM tools on your machine, and to show you the tool output instead of a guess. Your policies never leave your computer.

| Ask your agent | Tool it runs |
|---|---|
| "What does `s3:Get*Tagging` actually include?" or "is `iam:PassRoel` real?" | [iam-expand](https://github.com/act-security-labs/iam-expand) |
| "This action list is too long, make it smaller without granting more" | [iam-shrink](https://github.com/act-security-labs/iam-shrink) |
| "Turn this policy into Terraform / CloudFormation / CDK" | [iam-convert](https://github.com/act-security-labs/iam-convert) |
| "When does this SCP block us? Show me a table" | [iam-truth](https://github.com/act-security-labs/iam-truth) |

Results come from the current AWS action catalog in [`@actsecurity/iam-data`](https://github.com/act-security-labs/iam-data), updated daily.

## Quick start

1. **Check the prerequisites.** Node.js 22 or newer, and a coding agent that supports Agent Skills ([Claude Code, Cursor, Codex, GitHub Copilot and others](https://agentskills.io/clients)).

   ```bash
   node -v
   ```

2. **Install the skill** in the project where you work with IAM policies. The installer asks which agents to install for; pick yours with the space bar, or pass it with `-a`.

   ```bash
   npx skills add act-security-labs/agent-skills -a claude-code
   ```

   Use `-a cursor`, `-a codex`, `-a '*'` for other agents, and add `-g` to install for your user instead of the current project.

3. **Check it landed.** For Claude Code:

   ```bash
   head -3 .claude/skills/iam-tools/SKILL.md
   ```

4. **Ask a question.** Start your agent in that folder and try:

   > What does `s3:Get*` actually grant?

   You will see the agent load `iam-tools`, fetch the iam-expand guide, tell you in one line that it will run the tool through `npx` and that nothing leaves your machine, then print the full action list exactly as the tool returned it, and only then add its own reading.

5. **Approve the two commands** it asks about, or pre-approve them. The skill only ever runs a fetch of a guide from GitHub and the tool through `npx`. In Claude Code you can allow exactly those in `.claude/settings.json`:

   ```json
   {"permissions":{"allow":["Bash(curl -fsSL --proto '=https' --max-redirs 0 *raw.githubusercontent.com/act-security-labs/*)","Bash(npx -y @actsecurity/*)"]}}
   ```

## Prompts to try

- Paste a policy and ask "what does this let someone do?" with no tool named. The skill picks iam-expand on its own.
- "Are all the actions in this policy real?" catches typos such as `s3:GetObjekt` that AWS would silently ignore.
- "Shrink this list" followed by 30 actions, then "prove nothing was added": shrink, then a round trip back through iam-expand.
- "Under which conditions does this SCP deny `s3:PutObject`?" then "what actually matters here?" for the simplified table.
- "Can role X read bucket Y in my account?" is out of scope on purpose. The skill points you to [iam-lens](https://github.com/act-security-labs/iam-lens) instead of guessing.

## How it works, and what leaves your machine

```
iam-tools (installed here, the only text your agent always carries)
   │  picks the tool
   ▼
fetches that tool's guide from its own repository, pinned to a commit and a SHA-256
   │  refuses the guide if the digest differs
   ▼
npx -y @actsecurity/<tool>@latest   (your policy in, tool output out, on your machine)
```

- **Two network calls, both outbound and both public.** `raw.githubusercontent.com` for the guide, `registry.npmjs.org` for the tool on first use. Your policy goes to neither. If a tool is already on your `PATH`, the agent uses it.
- **Nothing is installed.** `npx` keeps the tool in the npm cache; the guide is a Markdown file read once per session.
- **The guide is pinned.** The skill names, per tool, the commit of the guide and the SHA-256 of that file. The fetch is HTTPS only with no redirects, the digest is checked before the guide is read, and a guide that fails the check is not read; the agent falls back to the tool's `--help` and tells you. What your agent will follow is auditable from the installed `SKILL.md` alone.
- **The guide is data, not a command channel.** The only command a guide can authorize is `npx -y @actsecurity/<tool>@latest` with the flags it names.
- **Pins move by pull request.** A daily [workflow](.github/workflows/bump-guides.yml) compares each tool's `main` guide with the pin and opens a PR with the guide diff. Nothing reaches users until it is merged here and they update the skill.

### Verify a pin yourself

Take a row from the pin table in [`skills/iam-tools/SKILL.md`](skills/iam-tools/SKILL.md) and run:

```bash
curl -fsSL --proto '=https' --max-redirs 0 https://raw.githubusercontent.com/act-security-labs/iam-expand/<commit>/skills/iam-expand/SKILL.md | shasum -a 256
```

The output must equal the SHA-256 in that row.

### Prefer no fetch at all

Install the tool skills next to the router and the agent can read them locally. Each tool repository ships its own skill at `skills/<tool>/SKILL.md`:

```bash
npx skills add act-security-labs/iam-expand
```

Useful on locked-down machines, or when you want one tool without the router.

## Updating and removing

```bash
npx skills update            # picks up new pins and wording
```

To remove, delete the `iam-tools` folder from your agent's skills directory (`.claude/skills/iam-tools` for Claude Code).

## Not covered

Evaluating a request against your real account (identity, resource, SCP and boundary policies together) needs your collected IAM data. That is [iam-lens](https://github.com/act-security-labs/iam-lens) over [iam-collect](https://github.com/act-security-labs/iam-collect); the skill points you there.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Syntax errors or a crash on the first run | Node.js older than 22. Install Node 22+ or select it with your version manager. |
| First run is slow | `npx` is downloading the package once; later runs use the cache. |
| The agent says the guide was not verified and used `--help` | The fetch failed, a plugin or proxy blocked `curl`, or the digest did not match. The answer is still the tool's output; the agent just had less guidance. Run the verify command above to see which. |
| `Warning: The data package is over five days old` | The npx cache holds the catalog from the tool's last release. The skill re-runs once with `npx -y -p @actsecurity/iam-data@latest -p @actsecurity/<tool>@latest <tool>`. |
| Claude Code asks for permission on every run | Add the two allow rules from step 5 to `.claude/settings.json`. |

## Contributing

A guide lives with its tool: open the PR in that tool's repository under `skills/<tool>/SKILL.md`. Once merged, the daily workflow proposes the new pin here. Changes to routing or the shared rules go to [`skills/iam-tools/SKILL.md`](skills/iam-tools/SKILL.md) in this repository.

## License

MIT. The tools the skill runs are separate packages with their own licenses.
