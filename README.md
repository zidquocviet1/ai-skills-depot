# AI Skills Depot 🏗️

A centralized collection of fine-tuned skills for AI agents. These skills provide specialized instructions and patterns for various coding roles, ensuring high-quality, consistent output from your AI collaborators.

## Supported Agents 🤖

This repository provides skills that work with multiple AI development tools:

- **Antigravity**: `.agent/skills/`
- **Cursor**: `.agent/skills/`
- **Claude Code**: `.claude/skills/`

## Quick Start 🚀

No need to clone this repository. You can install all skills directly from your project's root with a single command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/zidquocviet1/ai-skills-depot/main/install.sh)"
```

### Installation Steps (Remote):
1. **Run the command** in your terminal.
2. **Select Platform**: Choose the format expected by your AI tool (Antigravity, Cursor, or Claude Code). The script handles the root folder creation (`.agent/` or `.claude/`).
3. **Select Role(s)**: Opt for "All Roles" or specific domains (e.g., `backend`, `frontend`, `tester`).
4. **Optional Submodule Skills**: If the repo includes skill collections as git submodules, choose whether to install them and which collections to include.
5. **Profit!** The skills will be added to your current directory immediately.

---

## Local Development (For Contributors) 🛠️

If you want to contribute new skills, you can pull the repository and use the local setup script:

```bash
chmod +x setup.sh
./setup.sh
```

The local setup script can also scan initialized git submodules for `SKILL.md` files and copy the selected skill folders into your target AI agent skills directory.

Submodule skill aliases are configured in `skill-aliases.json`. The installer uses those aliases to prefix installed submodule skill folders and `name:` frontmatter, such as `gstack:ship` or `mott:tdd`.

### Manual Installation

If you prefer to install manually, you can simply copy the relevant files:

- **Antigravity**: Copy `roles/path/to/skill` to your project's `skills/` folder.
- **Cursor**: Copy `roles/path/to/skill/SKILL.md` to `.cursor/rules/skill-name.md`.
- **Claude Code**: Append the contents of `SKILL.md` to your project's `.clauderules` file.

## Repository Structure 📂

The skills are organized by role and technology:

```bash
roles/
├── backend/
│   ├── java/
│   │   ├── solid-principles/
│   │   │   ├── SKILL.md      # Core instructions
│   │   │   └── README.md     # Skill overview
```

## Contributing 🤝

1. Create a new directory under the appropriate role: `roles/<role>/<technology>/<skill-name>`.
2. Add a `SKILL.md` file with the required YAML frontmatter (name and description).
3. Use imperative language and provide clear examples (Good vs. Bad).
4. Run `./setup.sh` to verify your new skill is discoverable.

Happy Coding! 🚀
