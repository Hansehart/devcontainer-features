# Contributing

## Style

- **Comments** state a step's intent, in abstract terms, so they stay accurate as the concrete details change.
- **Commits** start with the kind of change and the feature's name, followed by a short summary. A feature's version raises its first number for breaking changes, its second for new options, and its third for fixes.
- **PR and issue descriptions** stay slim and minimal, about 2–3 sentences on average. A change ideally starts as an issue, is made on its own branch, and lands on main as one squashed commit.

## Tests

- Test every option at least once with a non-default value.
- **Versions:** one `pinned_version` scenario with the newest release, kept current by Renovate.
- **Paths:** `stateDir` is `/home/ubuntu/<feature-id>`, with `remoteUser: ubuntu`.
- **Booleans:** a scenario named `<option>_false`.
- **User config:** a real hardening setting that differs from the default. Check that it's written and that the tool reads it.

## Options

Every option belongs to one of these kinds:

- **Version:** `latest` or a version, resolved to an exact release before installing, and that release is logged.
- **State:** `stateDir` is opt-in, must be inside the remote user's home, and is meant to sit on a volume. `state-dir.sh` checks the path at build time, and `init.sh` creates it at create and warns when it sits on the container filesystem.
- **User config:** written exactly as given, and only when set.
- **Hardening:** a boolean, default `true`, that sets one documented env var in `/etc/profile.d/<feature>.sh`. `false` is the single opt-out, and the hardening stays independent of user config.
- **Feature-specific:** whatever is unique to the tool.
