import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

const TOOL_ALIAS_SECTION = "tool_alias";

function getMiseConfigPath(): string {
	const xdgConfigHome = process.env.XDG_CONFIG_HOME?.trim();
	if (xdgConfigHome) {
		return join(xdgConfigHome, "mise", "config.toml");
	}

	const home = process.env.HOME;
	if (!home) {
		throw new Error("HOME is not set; cannot resolve mise config path");
	}
	return join(home, ".config", "mise", "config.toml");
}

function quoteTomlKey(value: string): string {
	return JSON.stringify(value);
}

function quoteTomlString(value: string): string {
	return JSON.stringify(value);
}

function parseTomlKey(rawKey: string): string | null {
	const trimmed = rawKey.trim();
	if (trimmed.length === 0) {
		return null;
	}
	if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
		try {
			const parsed = JSON.parse(trimmed) as unknown;
			return typeof parsed === "string" ? parsed : null;
		} catch {
			return null;
		}
	}
	return trimmed;
}

function getSectionName(line: string): string | null {
	const match = line.match(/^\s*\[([^[\]]+)]\s*(?:#.*)?$/);
	if (!match) {
		return null;
	}
	return match[1]?.trim() ?? null;
}

function findToolAliasSection(lines: string[]): {
	start: number;
	end: number;
} | null {
	let start = -1;
	for (let index = 0; index < lines.length; index += 1) {
		const sectionName = getSectionName(lines[index] ?? "");
		if (sectionName === TOOL_ALIAS_SECTION) {
			start = index;
			break;
		}
	}
	if (start === -1) {
		return null;
	}

	let end = lines.length;
	for (let index = start + 1; index < lines.length; index += 1) {
		if (getSectionName(lines[index] ?? "") !== null) {
			end = index;
			break;
		}
	}

	return { start, end };
}

function updateToolAliasToml(
	currentToml: string,
	plugin: string,
	gitUrl: string,
): string {
	const lines = currentToml.length > 0 ? currentToml.split(/\r?\n/) : [];
	const nextAliasLine = `${quoteTomlKey(plugin)} = ${quoteTomlString(gitUrl)}`;
	const section = findToolAliasSection(lines);

	if (!section) {
		const prefix = lines.length > 0 && lines[lines.length - 1] !== "" ? [""] : [];
		const nextLines = [...lines, ...prefix, `[${TOOL_ALIAS_SECTION}]`, nextAliasLine];
		return `${nextLines.join("\n")}\n`;
	}

	for (let index = section.start + 1; index < section.end; index += 1) {
		const line = lines[index] ?? "";
		const equalIndex = line.indexOf("=");
		if (equalIndex === -1) {
			continue;
		}
		const key = parseTomlKey(line.slice(0, equalIndex));
		if (key === plugin) {
			lines[index] = nextAliasLine;
			return lines.join("\n");
		}
	}

	lines.splice(section.end, 0, nextAliasLine);
	return lines.join("\n");
}

export async function updateUserToolAlias({
	plugin,
	gitUrl,
}: {
	plugin: string;
	gitUrl: string;
}): Promise<string> {
	const configPath = getMiseConfigPath();
	let currentToml = "";
	try {
		currentToml = await readFile(configPath, "utf8");
	} catch (error) {
		if (
			!error ||
			typeof error !== "object" ||
			!("code" in error) ||
			error.code !== "ENOENT"
		) {
			throw error;
		}
	}

	const nextToml = updateToolAliasToml(currentToml, plugin, gitUrl);
	await mkdir(dirname(configPath), { recursive: true });
	await writeFile(configPath, nextToml, "utf8");
	return configPath;
}
