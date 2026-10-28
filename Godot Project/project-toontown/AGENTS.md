\# AGENTS.md (Godot 4 project)



Instructions for AI coding agents (Cursor, Claude Code, Codex, Copilot, Windsurf...) working in this Godot 4.x project.



\## Before writing code

1\. Read `project.godot`: engine version (`config/features`), `\[autoload]` singletons, `\[input]` actions. Never use Godot 3 APIs.

2\. Read `docs/PROJECT.md` and `docs/ARCHITECTURE.md` if present.

3\. If you don't know the scene tree behind a `$Path` or `%Name`, ask, or state the nodes you assume.



\## Hard rules

\- GDScript 2.0 only: `@export`, `@onready`, `@tool`, `await`, `signal.emit()`, `signal.connect(callable)`, `instantiate()`, `CharacterBody2D/3D` + `velocity` + `move\_and\_slide()` with no arguments.

\- Static types on every var, parameter and return. Tabs for indentation.

\- Never invent APIs. If unsure, write \*\*unverified\*\* and link https://docs.godotengine.org/en/stable/classes/.

\- Never rename `@export` vars, signals, nodes or files without warning the user. Don't hand-edit `.tscn` unless asked.

\- Write complete files, not `# ...` stubs.



\## Before saying "done"

Run `godot --headless --check-only --script res://<file>.gd` on each changed script. Fix every parse error. Report what you ran.



Detailed rules: `.cursor/rules/\*.mdc`.

