# Contributing

Bug reports, fixes and new ideas are all welcome. This is a one-person project, so replies can take a few days.

## Reporting a problem

Open an issue with the **Bug report** form. The most useful reports say which agent and version you ran, your operating system, which skill or hook was involved, what you expected, and what happened instead. Paste the hook's output or error text if there was any.

Before you paste anything, take out personal details: names, file paths that include your username, project names you'd rather keep private, and any tokens or keys.

## Suggesting a change

Open an issue with the **Idea** form first if the change is bigger than a typo or a one-line fix. Saying the problem it solves up front helps, because the harness only takes rules that came from a real failure. A rule with no failure behind it tends to cost context on every session without ever paying that back.

## Pull requests

- Keep each pull request to one change.
- Some hooks ship in two forms, PowerShell for Windows and shell for macOS and Linux (`hooks/hooks.json` and `hooks/hooks-macos-linux.json` list which). If you change one of a pair, change the other, or say in the pull request that you couldn't.
- Skills are plain Markdown instructions. Keep them general: no names, paths or project details from your own setup, and no examples copied from real work.
- If a change fixes a failure, describe the failure in the pull request. That history is what `docs/design-history.md` is made of.

## License

By contributing you agree that your work is released under the [MIT License](LICENSE) that covers the rest of the project.
