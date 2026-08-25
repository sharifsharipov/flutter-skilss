# Flutter Master

> An enterprise-grade Flutter/Dart engineering standard, packaged as a [Claude Code](https://claude.com/claude-code) skill.

![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-8A63D2)
![Flutter](https://img.shields.io/badge/Flutter%20%2F%20Dart-02569B?logo=flutter&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

**Flutter Master** makes an AI assistant behave like a Staff/Principal Flutter Engineer performing a code review *before* writing any code. It is not a feature factory — it turns code generation into **code engineering**: decide the right shape first, then produce production-grade code suitable for large-scale enterprise apps.

Once installed, it applies automatically whenever you write, refactor, review, architect, test, secure, or optimize Flutter/Dart code — you never have to say "use clean architecture" again.

## Quick start

```bash
git clone https://github.com/sharifsharipov/flutter-skills.git
cd flutter-skills
./install.sh
```

Restart Claude Code. That's it — the skill triggers on any Flutter/Dart task.

`install.sh` symlinks `~/.claude/skills/flutter-master` to this repo, so editing a reference file here is live immediately. See [Install](#install) for the other modes.

## What actually changes

Ask for "a profile card widget" and a generic assistant gives you this:

```dart
Widget _buildProfileCard(User user) {           // widget-returning function
  return Container(                             // Container for a shape
    padding: EdgeInsets.all(16),                // magic number
    decoration: BoxDecoration(
      color: Color(0xFFF5F5F5),                 // raw hex, breaks dark mode
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Image.network(user.avatar),               // unsized, undecoded cache
      Text(user.fullName,                       // overflows on a real name
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ]),
  );
}
```

With this skill, the same request produces a public widget class in its own file, values from the project's token layer, an overflow policy on API-driven text, press feedback with a haptic, and a loading/empty/error state for the screen it lives on — or a question when a token is genuinely missing, instead of an invented hex.

The rules behind each of those decisions live in the reference files below.

## The Golden Rule

> **Never write code just because it works.**
> Always write production-grade code. Prioritize readability over cleverness. Every architectural decision must be justified by scalability, maintainability, and testability. Minimize coupling, maximize cohesion, follow SOLID, and align with official Flutter and Dart guidelines.

If a request violates this rule, the assistant says so plainly and proposes the correct shape. Being a good engineer sometimes means pushing back.

## How it works

1. A task touches a `.dart` file or a Flutter concept → the standard triggers (even if you never say "architecture" or "review").
2. The task is named as one of three **build modes** — *scaffold* (new feature), *UI* (draw a screen), or *composition/refactor* (clean up existing code).
3. The orchestrator loads only the 2–3 relevant reference files. A new feature is usually `scaffold` + `patterns` + `testing`; drawing a screen is `ui-from-design` + `ui-layout` + `refactor` §8; a review is `review` plus the domain the code lives in.
4. The design is decided first, then production-grade code is written.
5. A self-review checklist runs at the end of every code response, and anything with runtime behavior gets a manual self-test. Rule violations are flagged, never applied silently.

This is **progressive disclosure**: `SKILL.md` is a small orchestrator, and the deep rules stay out of context until the task needs them.

## What's inside

| File | Covers |
| --- | --- |
| [`SKILL.md`](SKILL.md) | Orchestrator — Golden Rule, pre-code checklist, default stack, three build modes, routing table, self-review protocol |
| [`ui-from-design.md`](references/ui-from-design.md) | Drawing UI from a screenshot/Figma — decompose → measure → ask → build → verify, the token contract, shape recipes, reusable-widget inventory, design-comparison loop |
| [`ui-layout.md`](references/ui-layout.md) | Constraints model, flex decision table, the eight overflow failures, canonical page shapes, safe area + keyboard, responsive & text scale, the four screen states, accessibility |
| [`scaffold.md`](references/scaffold.md) | Creating a feature end to end — repo calibration, dependency rules, domain-first build order, layer templates, directory layout |
| [`architect.md`](references/architect.md) | Clean Architecture, the dependency rule, feature-first folders, SOLID, DDD, use cases |
| [`patterns.md`](references/patterns.md) | `Either`/Result monad, Repository, Mapper (DTO⇄Entity), UseCase, Freezed unions, DI, Strategy/Factory/Adapter |
| [`performance.md`](references/performance.md) | Rebuild scoping (`const`, `BlocSelector`, `RepaintBoundary`), list/sliver builders, memory leaks & disposal, isolates, image cache |
| [`security.md`](references/security.md) | Secrets handling, secure token storage, Dio auth + 401 refresh, HTTPS + certificate pinning, authn/authz, log hygiene |
| [`testing.md`](references/testing.md) | Test pyramid, mocktail/`bloc_test`, widget/golden/integration tests, >90% business-logic coverage, TDD |
| [`refactor.md`](references/refactor.md) | KISS/DRY/YAGNI, widget extraction, god-class fixes, magic-value constants, smell→fix table, the widget-composition rulebook (§8) |
| [`review.md`](references/review.md) | PR review order, full checklist, smell detectors, AI self-review protocol |
| [`best-practices.md`](references/best-practices.md) | Effective Dart, strict lints, naming, null safety, immutability, modern Dart (records, patterns, enhanced enums), prefer/avoid lists |
| [`manual-test.md`](references/manual-test.md) | Proving a change at runtime — static gates, test plan, launch & drive, evidence capture, the Honesty Rule |
| [`enterprise.md`](references/enterprise.md) | CI/CD gates, flavors, melos monorepo, ADRs, semver + CHANGELOG, observability, dependency hygiene |

## Default tech stack

Unless your project dictates otherwise:

- **Architecture** — Clean Architecture, feature-first. `presentation → domain ← data`. The domain layer depends on nothing.
- **State** — BLoC/Cubit with immutable state. `BlocSelector` / `context.select` for granular rebuilds.
- **Models** — Freezed for data classes, unions, and `copyWith`. Value objects for domain invariants.
- **Errors** — Return `Either<Failure, T>` (or a sealed `Result`) from the domain boundary. No exceptions crossing layers.
- **DI** — `get_it` + `injectable`. Constructor injection everywhere.
- **Networking** — Dio with interceptors; a Mapper between DTOs and domain entities. DTOs never leak into the UI.
- **Immutability** — Prefer `StatelessWidget`, `const`, `final`, and immutable state.

**Prefer:** `StatelessWidget` · `const` constructors · composition over inheritance · extensions · value objects · Freezed · immutable state · `BlocSelector` · Repository pattern · UseCase pattern · feature-first structure.

**Avoid:** huge widgets · god classes · business logic in the UI · magic numbers/strings · deep widget trees · nested `FutureBuilder`/`BlocBuilder` · unnecessary `Container` · global mutable state.

## Adapting it to your project

**It works on a fresh clone.** Two reference files open by calibrating to whatever repo they're pointed at, before writing a line:

- [`scaffold.md`](references/scaffold.md) §0 — reads your reference feature to learn your `Either` implementation, folder plurality, failure factory, mapping style, and codegen command.
- [`ui-from-design.md`](references/ui-from-design.md) *Calibrate* — finds your theme extension, spacing/radius constants, generated asset references, l10n accessor, tap primitive, and shared-widget folder.

The concrete names throughout those files (`context.colors`, `AppDimens.kGap8`, `AppInkWell`, `core/widgets/`) are a **generic worked example**, clearly marked as such. The rules around them are universal.

One optional tune-up if you're forking for a team:

- [`ui-from-design.md`](references/ui-from-design.md) §1 + §4 — replace the example token table and shared-widget inventory with your project's real ones. Calibration discovers them each session; a written inventory means the assistant reuses your widgets without having to go looking.

Everything else — architecture, patterns, performance, security, testing, review, layout, Effective Dart, manual testing — applies to any Flutter codebase as written.

## Repository layout

The repo **is** the skill — same layout Claude Code expects, so there is no second copy to keep in sync.

```
SKILL.md            # orchestrator (skill entry point)
references/*.md     # the deep rules, loaded on demand
install.sh          # symlink this repo into ~/.claude/skills/
build.sh            # package flutter-master.skill (gitignored build artifact)
```

## Install

```bash
./install.sh              # symlink ~/.claude/skills/flutter-master -> this repo (recommended)
./install.sh --copy       # copy instead of symlink (re-run after every edit)
./install.sh --uninstall  # remove the link
./build.sh                # produce flutter-master.skill for distribution
```

The symlink install means editing a reference here is live immediately — no sync step, no drift between the repo and the installed copy. An existing real directory is moved to `~/.claude/skill-backups/` first, never inside `~/.claude/skills/` (a leftover copy there loads as a duplicate skill).

Restart Claude Code, or start a new session, to pick up the change.

## Using it without Claude Code

The reference files are plain markdown and work as a standalone Flutter engineering handbook, a team onboarding doc, or a PR-review checklist. Paste a single file into any assistant that accepts long context, or hand `references/review.md` to a human reviewer.

## Contributing

Issues and PRs welcome. Two rules for reference edits:

1. **Rules, not essays.** Every addition should be actionable — a rule, a table, a checklist item, or a copy-pasteable recipe. If a paragraph doesn't change what gets written, cut it.
2. **Keep the routing honest.** A new reference file needs a row in the `SKILL.md` routing table and in the table above, or it will never be loaded.

## License

[MIT](LICENSE) © Sharif Sharipov
