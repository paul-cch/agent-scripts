import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  compactDescription,
  configuredModel,
  discoverRoots,
  parseLiveSkillsPrompt,
  plainLogSkillReads,
  referencedSkillPaths,
  usageEvidence,
} from "./skill-cleaner.ts";

test("reads basic and literal top-level Codex model strings and reports fallback", (context) => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "skill-cleaner-model-"));
  context.after(() => fs.rmSync(temp, { recursive: true, force: true }));
  const codex = path.join(temp, ".codex");
  fs.mkdirSync(codex);
  const config = path.join(codex, "config.toml");

  fs.writeFileSync(config, 'model = "gpt-basic" # current\\n[profiles.demo]\\nmodel = "ignored"\\n');
  assert.deepEqual(configuredModel(temp), { name: "gpt-basic", source: config });

  fs.writeFileSync(config, "model = 'gpt-literal#safe' # comment\\n");
  assert.deepEqual(configuredModel(temp), { name: "gpt-literal#safe", source: config });

  fs.writeFileSync(config, "[profiles.demo]\\nmodel = 'not-top-level'\\n");
  assert.deepEqual(configuredModel(temp), {
    name: "gpt-5.5",
    source: "fallback:no-readable-codex-model",
  });
});

test("limits root discovery to explicitly supplied roots", (context) => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "skill-cleaner-roots-"));
  context.after(() => fs.rmSync(temp, { recursive: true, force: true }));
  const defaultRoots = [
    path.join(temp, ".agents/skills"),
    path.join(temp, ".codex/skills"),
    path.join(temp, ".codex/plugins/cache"),
    path.join(temp, "Projects/agent-scripts/skills"),
    path.join(temp, "Projects/demo/.agents/skills"),
  ];
  const isolatedRoot = path.join(temp, "isolated/skills");
  for (const root of [...defaultRoots, isolatedRoot]) fs.mkdirSync(root, { recursive: true });

  assert.deepEqual(discoverRoots(temp, [isolatedRoot], true), [isolatedRoot]);
  assert.deepEqual(
    discoverRoots(temp, [isolatedRoot], false),
    [...defaultRoots, isolatedRoot].sort(),
  );
});

test("parses Codex skill roots and model-visible lines", () => {
  const raw = JSON.stringify([
    {
      role: "developer",
      content: [{
        type: "input_text",
        text: `<skills_instructions>
## Skills
### Skill roots
- \`r0\` = \`/tmp/skills\`
### Available skills
- demo: Demo work. (file: r0/demo/SKILL.md)
### How to use skills
</skills_instructions>`,
      }],
    },
  ]);

  const parsed = parseLiveSkillsPrompt(raw);
  assert.equal(parsed.roots.get("r0"), "/tmp/skills");
  assert.deepEqual(parsed.skillLines, [
    "- demo: Demo work. (file: r0/demo/SKILL.md)",
  ]);
});

test("compacts prose into a readable trigger phrase", () => {
  const compact = compactDescription(
    "Use this skill when the user wants to inspect calendars, compare availability, review conflicts, and schedule a meeting with timezone-aware details.",
    90,
  );
  assert.equal(
    compact,
    "inspect calendars, compare availability, review conflicts, and schedule a meeting with...",
  );
  assert.ok(compact.length <= 90);
  assert.doesNotMatch(compact, /audit, clean, verify/);
});

test("extracts user evidence without counting developer prompt listings", () => {
  assert.deepEqual(
    usageEvidence({ session_id: "abc", text: "use $skill-cleaner", ts: 123 }),
    { userText: "use $skill-cleaner" },
  );
  assert.deepEqual(
    usageEvidence({
      type: "response_item",
      payload: {
        type: "function_call",
        arguments: "{\"cmd\":\"cat /tmp/skills/demo/SKILL.md\"}",
      },
    }),
    { callArgs: "{\"cmd\":\"cat /tmp/skills/demo/SKILL.md\"}" },
  );
  assert.deepEqual(
    usageEvidence({
      type: "response_item",
      payload: { type: "message", role: "developer", content: ["$skill-cleaner"] },
    }),
    {},
  );
});

test("resolves relative skill reads from function-call workdirs", () => {
  assert.deepEqual(
    referencedSkillPaths(JSON.stringify({
      cmd: "cat skills/demo/SKILL.md",
      workdir: "/tmp/repo",
    })),
    ["/tmp/repo/skills/demo/SKILL.md"],
  );
});

test("counts command-like plain-log reads but ignores rendered listings", () => {
  assert.deepEqual(
    plainLogSkillReads([
      "cat skills/demo/SKILL.md",
      "- other: description (file: /tmp/skills/other/SKILL.md)",
    ].join("\n")),
    ["demo"],
  );
});
