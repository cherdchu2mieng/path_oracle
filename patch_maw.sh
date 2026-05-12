#!/bin/bash

# สคริปต์สำหรับอัปเดต maw-js: เวอร์ชันแก้ไขสมบูรณ์ (Final Fix)
# รองรับ: Full Slugs, Configurable Groups, Auto-resize Tmux และ Auto-Config
# วิธีใช้: chmod +x patch_maw.sh && ./patch_maw.sh <path_to_maw_js>

MAW_PATH="$1"

if [ -z "$MAW_PATH" ]; then
    echo -e "\x1b[31mError: Missing maw-js path.\x1b[0m"
    echo -e "Usage: ./patch_maw.sh <path_to_maw_js>"
    echo -e "Example: ./patch_maw.sh ~/ghq/github.com/Soul-Brews-Studio/maw-js"
    exit 1
fi

if [ ! -d "$MAW_PATH" ]; then
    echo -e "\x1b[31mError: Path $MAW_PATH not found.\x1b[0m"
    exit 1
fi

MAW_PATH=$(realpath "$MAW_PATH")

echo "🚀 Starting Final Patch for maw-js at $MAW_PATH..."

# --- 1. Patch src/config/types.ts ---
python3 - <<PY_EOF
import os
path = os.path.join('$MAW_PATH', 'src/config/types.ts')
content = open(path).read()
if 'groups?:' not in content:
    field = '  /** Grouping and ordering for fleet initialization */\n  groups?: Record<string, { session: string; order: number }>;'
    content = content.replace('export interface MawConfig {', 'export interface MawConfig {\n' + field)
    open(path, 'w').write(content)
    print('✓ Updated types.ts')
else:
    print('i types.ts already patched')
PY_EOF

# --- 2. Patch src/config/validate-ext.ts ---
python3 - <<PY_EOF
import os
path = os.path.join('$MAW_PATH', 'src/config/validate-ext.ts')
content = open(path).read()
insertion = """
  if (\\"groups\\" in raw) {
    if (raw.groups && typeof raw.groups === \\"object\\" && !Array.isArray(raw.groups)) {
      result.groups = raw.groups;
    } else {
      warn(\\"groups\\", \\"must be an object\\");
    }
  }
"""
if 'if ("groups" in raw)' not in content:
    target = 'function validateExtFields(raw: any, result: any, warn: any) {'
    if target in content:
        content = content.replace(target, target + insertion)
        open(path, 'w').write(content)
        print('✓ Updated validate-ext.ts')
    else:
        content = content.replace('  return result;', insertion + '\n  return result;')
        open(path, 'w').write(content)
        print('✓ Updated validate-ext.ts (via fallback)')
else:
    print('i validate-ext.ts already patched')
PY_EOF

# --- 3. Patch src/core/transport/tmux-class.ts ---
python3 - <<PY_EOF
import os
path = os.path.join('$MAW_PATH', 'src/core/transport/tmux-class.ts')
content = open(path).read()
if '"window-size", "largest"' not in content:
    old = 'await this.setOption(name, "renumber-windows", "on");'
    new = old + '\n    await this.setOption(name, "window-size", "largest");'
    content = content.replace(old, new)
    open(path, 'w').write(content)
    print('✓ Updated tmux-class.ts')
else:
    print('i tmux-class.ts already patched')
PY_EOF

# --- 4. เขียนไฟล์ fleet-init-scan.ts ---
cat << 'INNER_EOF' > "$MAW_PATH/src/commands/plugins/fleet/fleet-init-scan.ts"
import { join } from "path";
import { existsSync, mkdirSync, rmSync } from "fs";
import { hostExec, loadConfig } from "../../../sdk";
import { FLEET_DIR } from "../../../sdk";
import { ghqList } from "../../../core/ghq";

interface FleetWindow {
  name: string;
  repo: string;
}

interface FleetSession {
  name: string;
  windows: FleetWindow[];
  skip_command?: boolean;
}

export async function cmdFleetInit() {
  const config = loadConfig() as any;
  const GROUPS: Record<string, { session: string; order: number }> = config.groups || {
    pulse: { session: "pulse", order: 1 },
    hermes: { session: "hermes", order: 2 },
    neo: { session: "neo", order: 3 },
    homekeeper: { session: "homekeeper", order: 4 },
  };

  const fleetDir = FLEET_DIR;
  if (existsSync(fleetDir)) rmSync(fleetDir, { recursive: true });
  mkdirSync(fleetDir, { recursive: true });

  console.log(`\n  \x1b[36mScanning for oracle repos...\x1b[0m\n`);
  const allRepos = await ghqList();
  const oracleRepos: { name: string; path: string; repo: string; worktrees: { name: string; path: string; repo: string }[] }[] = [];

  for (const repoPath of allRepos) {
    const parts = repoPath.split("/");
    const repoName = parts.pop()!;
    const org = parts.pop()!;
    const domain = parts.pop()!; 
    const parentDir = parts.join("/") + "/" + domain + "/" + org;

    let oracleName: string | null = null;
    if (repoName.endsWith("-oracle")) {
      oracleName = repoName.replace(/-oracle$/, "").replace(/-/g, "");
    } else if (repoName === "homelab") {
      oracleName = "homekeeper";
    }

    if (!oracleName) continue;
    if (repoName.includes(".wt-")) continue;

    const worktrees: { name: string; path: string; repo: string }[] = [];
    try {
      const wtOut = await hostExec(`ls -d ${parentDir}/${repoName}.wt-* 2>/dev/null || true`);
      const usedNames = new Set<string>();
      for (const wtPath of wtOut.split("\n").filter(Boolean)) {
        const wtBase = wtPath.split("/").pop()!;
        const suffix = wtBase.replace(`${repoName}.wt-`, "");
        const taskPart = suffix.replace(/^\d+-/, "");
        let windowName = `${oracleName}-${taskPart}`;
        if (usedNames.has(windowName)) windowName = `${oracleName}-${suffix}`;
        usedNames.add(windowName);
        worktrees.push({
          name: windowName,
          path: wtPath,
          repo: `${domain}/${org}/${wtBase}`,
        });
      }
    } catch { }

    oracleRepos.push({
      name: oracleName,
      path: repoPath,
      repo: `${domain}/${org}/${repoName}`,
      worktrees,
    });

    console.log(`  found: ${oracleName.padEnd(15)} ${domain}/${org}/${repoName}`);
  }

  const sessionMap = new Map<string, { order: number; windows: FleetWindow[] }>();
  for (const oracle of oracleRepos) {
    const group = GROUPS[oracle.name] || { session: oracle.name, order: 50 };
    const key = group.session;
    if (!sessionMap.has(key)) sessionMap.set(key, { order: group.order, windows: [] });
    const sess = sessionMap.get(key)!;
    sess.windows.push({ name: `${oracle.name}-oracle`, repo: oracle.repo });
    for (const wt of oracle.worktrees) sess.windows.push({ name: wt.name, repo: wt.repo });
  }

  console.log(`\n  \x1b[36mWriting fleet configs...\x1b[0m\n`);
  const sorted = [...sessionMap.entries()].sort((a, b) => a[1].order - b[1].order);

  for (const [groupName, data] of sorted) {
    const paddedNum = String(data.order).padStart(2, "0");
    const sessionName = `${paddedNum}-${groupName}`;
    const config: FleetSession = { name: sessionName, windows: data.windows };
    await Bun.write(join(fleetDir, `${sessionName}.json`), JSON.stringify(config, null, 2) + "\n");
    console.log(`  \x1b[32m✓\x1b[0m ${sessionName}.json — ${data.windows.length} windows`);
  }

  if (oracleRepos.length > 0) {
    const overviewConfig = { name: "99-overview", windows: [{ name: "live", repo: oracleRepos[0].repo }], skip_command: true };
    await Bun.write(join(fleetDir, "99-overview.json"), JSON.stringify(overviewConfig, null, 2) + "\n");
  }

  console.log(`\n  \x1b[32m${sorted.length + 1} fleet configs written to fleet/\x1b[0m`);
}
INNER_EOF
echo "✓ Updated fleet-init-scan.ts (No escaped backticks)"

# --- 5. อัปเดต maw.config.json ---
python3 - <<PY_EOF
import json, os
path = os.path.expanduser('~/.config/maw/maw.config.json')
data = json.load(open(path)) if os.path.exists(path) else {}
if 'groups' not in data:
    data['groups'] = {
        'pulse': {'session': 'pulse', 'order': 1},
        'hermes': {'session': 'hermes', 'order': 2},
        'neo': {'session': 'neo', 'order': 3},
        'homekeeper': {'session': 'homekeeper', 'order': 4}
    }
    json.dump(data, open(path, 'w'), indent=2)
    print('✓ Added default groups to maw.config.json')
else:
    print('i groups already exists in maw.config.json')
PY_EOF

echo -e "\n📦 Running rebuild..."
cd "$MAW_PATH"

if [ ! -d "node_modules" ]; then
    echo "i node_modules not found, running bun install..."
    bun install
fi

if bun run build; then
    echo -e "\n✅ Patch & Build Complete!"
    echo -e "👉 Please run: \x1b[33mmaw kill --all && maw wake all\x1b[0m to restart with new logic."
else
    echo -e "\n❌ Error: 'bun run build' failed."
    echo -e "Please check the errors above. You might need to run 'bun install' manually."
    exit 1
fi
