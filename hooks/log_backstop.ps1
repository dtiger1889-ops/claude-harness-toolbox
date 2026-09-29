#requires -Version 5.1
# log_backstop.ps1 -- PostToolUse hook (matcher "Skill").
#
# After a /prove, /prevent, /fanout, /outside, or /dumb invocation, it reminds the session
# (exit 2, so the message reaches the model) to run /log before ending the turn, so a
# durable finding those skills produced gets written into the doc that owns it instead of
# staying in scrollback. It fires once per matching invocation, never on /log itself (that
# would loop) or /checkpoint (resume-state is that skill's job). It cannot block anything,
# because the skill already ran. Fails open.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    if ("$($j.tool_name)" -ne 'Skill') { exit 0 }

    $skill = "$($j.tool_input.skill)".Trim().TrimStart('/').ToLower()
    # Plugin installs namespace skills as <plugin>:<skill>; match on the skill part.
    if ($skill -match ':') { $skill = $skill.Split(':')[-1] }
    if ($skill -notin @('prove', 'prevent', 'fanout', 'outside', 'dumb')) { exit 0 }

    $msg = "[log-backstop] This turn invoked /$skill, which tends to produce durable findings. " +
    "Before ending this turn, run the /log skill to route any REUSABLE finding it produced " +
    "(a proof and its source, a corrected claim, a decision and its reason, a /fanout Synthesis) " +
    "into the doc that already owns it. /log stops at 'nothing to log' if nothing durable came out, " +
    "so this is a consideration pass, not a forced write. Do NOT route resume-state here (that is " +
    "/checkpoint). The $skill skill already ran -- do NOT retry it."
    [Console]::Error.WriteLine($msg)
    exit 2
} catch {
    exit 0
}
