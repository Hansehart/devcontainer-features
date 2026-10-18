# Contributing

## Style

- **Comments** state a step's intent, in abstract terms, so they stay accurate as the concrete details change.
- **Commits** start with the kind of change and the feature's name, followed by a short summary. A feature's version raises its first number for breaking changes, its second for new options, and its third for fixes.
- **Workflow:** a change ideally starts as an issue, is made on its own branch, and lands on main as one squashed commit. Pull request and issue descriptions stay slim and minimal, about 2–3 sentences on average.

## Options

Every option belongs to one of these kinds, and every option is tested at least once with a non-default value.

- **Version:** `latest` or a version, resolved to an exact release before installing, and that release is logged. Tested by one `pinned_version` scenario with the newest release.
- **State:** `stateDir` is opt-in, must be inside the remote user's home, and is meant to sit on a volume. `state-dir.sh` checks the path at build time, and `init.sh` creates it at create and warns when it sits on the container filesystem. Tested by a `state_dir` scenario that sets it to `/home/ubuntu/<feature-id>`, with `remoteUser: ubuntu`.
- **User config:** written exactly as given, and only when set. Tested with a real hardening setting that differs from the default, checking that it's written and that the tool reads it.
- **Hardening:** a boolean, default `true`, that sets one documented env var in `/etc/profile.d/<feature>.sh`. `false` is the single opt-out, and the hardening stays independent of user config. Tested by a scenario that sets the opt-out value, named `<option>_<value>`.
- **Feature-specific:** whatever is unique to the tool.
