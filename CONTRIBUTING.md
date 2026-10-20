# Contributing

## Workflow

- **Changes** ideally start as an issue, are made on their own branch, and land on main through a pull request as one squashed commit.
- **Commits** start with the kind of change and the feature's name, followed by a short summary.
- **Descriptions** of pull requests and issues stay slim and minimal, about 2–3 sentences on average.

## Code

- **Comments** state a step's intent, in abstract terms, so they stay accurate as the concrete details change.

## Features

### Layout

Files go where the Filesystem Hierarchy Standard (FHS) puts them, so every feature lays out the same way.

- **Environment:** env vars for login shells go in `/etc/profile.d/<feature>.sh`, and env vars every process needs go in `containerEnv`.
- **Hook scripts:** the scripts the feature runs at build, create or start, and the code they share, go in `/usr/local/lib/<feature>`.
- **Packages:** apt packages keep the distribution's paths, and their signing keys go in `/etc/apt/keyrings`.
- **Programs:** a single binary goes in `/usr/local/bin`. A program made of many files goes in its own `/opt/<program>` tree, with its commands linked into `/usr/local/bin` and its own config in `/etc/opt/<program>`.
- **Runtime state:** data a service changes while running goes in `/var/lib/<service>`, and files that live only while it runs go in `/run`.
- **Settings:** what the feature records at build time for its hooks to apply goes in `/usr/local/etc/<feature>`.
- **Shipped data:** fixed files the feature ships for others to reference go in `/usr/local/share/<feature>`.
- **User data:** everything that belongs to the remote user stays in their home, including per-user installs in `~/.local/bin` and the feature's state dir.

### Options

Every option belongs to one of these kinds, and every option is tested at least once with a non-default value. Options are listed with `version` first, then `stateDir` if the feature has one, then the rest in alphabetical order.

- **Version:** `latest` or a version, resolved to an exact release before installing, and that release is logged. Tested by one `pinned_version` scenario with the newest release.
- **State:** `stateDir` is opt-in, must be inside the remote user's home, and is meant to sit on a volume. The feature checks the path at build time, and its create hook creates the dir and warns when it sits on the container filesystem. Tested by a `state_dir` scenario that sets it to `/home/ubuntu/<feature-id>`, with `remoteUser: ubuntu`.
- **Feature-specific:** whatever is unique to the tool.
- **Hardening:** a boolean, default `true`, that sets one documented env var in `/etc/profile.d/<feature>.sh`. `false` is the single opt-out, and the hardening stays independent of user config. Tested by a scenario that sets the opt-out value, named `<option>_<value>`.
- **User config:** written exactly as given, and only when set. Tested with a real hardening setting that differs from the default, checking that it's written and that the tool reads it.

### Versioning

A feature's version raises its first number for breaking changes, its second for new options, and its third for fixes.
