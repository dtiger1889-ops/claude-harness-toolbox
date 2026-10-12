# Security

The hooks in this toolbox run as scripts on your own machine every time your agent uses a tool, so a flaw in one is worth reporting privately.

## Reporting a vulnerability

Use GitHub's private reporting: the **Security** tab of this repository, then **Report a vulnerability**. Please don't open a public issue for it.

Include which hook or script is affected, your operating system, and the steps that show the problem. You'll get a reply within a week, and a fix ships as a normal release once it's ready.

## What counts

- A hook or script that can be made to run commands, read files or send data it shouldn't.
- A guard or gate that can be bypassed in a way that lets a destructive command through.
- Anything that writes a token, key or other secret somewhere it could be shared.

Everything else, including a gate that blocks more than it should, is a regular bug report.
