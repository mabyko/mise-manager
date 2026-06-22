import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

const TOOL_ALIAS_SECTION = "tool_alias";

export function getMiseConfigPath(): string {
	const xdgConfigHome = process.env.XDG_CONFIG_HOME?.trim();
	if (xdgConfigHome) {
		return join(xdgConfigHome, "mise", "config.toml");
	}

	const home = process.env.HOME;
	if (!home) {
		throw new Error("HOME is not set; cannot find mise config path");
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
	if (trimmed.length === 0) return null;
	if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
		try {
			const parsed = JSON.parse(trimmed) as unknown;
			return typeof parsed === "string" ? parsed : null;
		} catch {
			return null;
		}
	}
	if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
		return trimmed.slice(1, -1);
	}
	return trimmed;
}

function parseTomlString(rawValue: string): string | null {
	const trimmed = rawValue.trim();
	if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
		try {
			const parsed = JSON.parse(trimmed) as unknown;
			return typeof parsed === "string" ? parsed : null;
		} catch {
			return null;
		}
	}
	if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
		return trimmed.slice(1, -1);
	}
	return null;
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

	if (start === -1) return null;

	let end = lines.length;
	for (let index = start + 1; index < lines.length; index += 1) {
		if (getSectionName(lines[index] ?? "") !== null) {
			end = index;
			break;
		}
	}

	return { start, end };
}

function splitTomlAssignment(line: string): [string, string] | null {
	let quote: '"' | "'" | null = null;
	let escaped = false;

	for (let index = 0; index < line.length; index += 1) {
		const char = line[index];
		if (escaped) {
			escaped = false;
			continue;
		}
		if (quote === '"' && char === "\\") {
			escaped = true;
			continue;
		}
		if ((char === '"' || char === "'") && quote === null) {
			quote = char;
			continue;
		}
		if (char === quote) {
			quote = null;
			continue;
		}
		if (char === "=" && quote === null) {
			return [line.slice(0, index), line.slice(index + 1)];
		}
	}

	return null;
}

export function parseToolAliasToml(toml: string): Map<string, string> {
	const lines = toml.split("\n");
	const section = findToolAliasSection(lines);
	if (!section) return new Map();

	const aliases = new Map<string, string>();
	for (let index = section.start + 1; index < section.end; index += 1) {
		const line = lines[index] ?? "";
		const assignment = splitTomlAssignment(line);
		if (!assignment) continue;
		const [rawKey, rawValue] = assignment;
		const key = parseTomlKey(rawKey);
		const value = parseTomlString(rawValue);
		if (key && value !== null) {
			aliases.set(key, value);
		}
	}

	return aliases;
}

export async function readUserToolAliases(): Promise<Map<string, string>> {
	const configPath = getMiseConfigPath();
	try {
		return parseToolAliasToml(await readFile(configPath, "utf8"));
	} catch (error) {
		if (
			error &&
			typeof error === "object" &&
			"code" in error &&
			error.code === "ENOENT"
		) {
			return new Map();
		}
		throw error;
	}
}

export function updateToolAliasToml(
	currentToml: string,
	plugin: string,
	gitUrl: string,
): string {
	const lines = currentToml.length > 0 ? currentToml.split("\n") : [];
	const nextAliasLine = `${quoteTomlKey(plugin)} = ${quoteTomlString(gitUrl)}`;
	const section = findToolAliasSection(lines);

	if (!section) {
		if (lines.length > 0 && lines.at(-1) !== "") {
			lines.push("");
		}
		lines.push(`[${TOOL_ALIAS_SECTION}]`, nextAliasLine);
		return lines.join("\n");
	}

	for (let index = section.start + 1; index < section.end; index += 1) {
		const line = lines[index] ?? "";
		const assignment = splitTomlAssignment(line);
		if (!assignment) continue;
		const key = parseTomlKey(assignment[0]);
		if (key === plugin) {
			lines[index] = nextAliasLine;
			return lines.join("\n");
		}
	}

	lines.splice(section.end, 0, nextAliasLine);
	return lines.join("\n");
}

export function removeToolAliasToml(currentToml: string, plugin: string): string {
	const lines = currentToml.split("\n");
	const section = findToolAliasSection(lines);
	if (!section) return currentToml;

	for (let index = section.end - 1; index > section.start; index -= 1) {
		const line = lines[index] ?? "";
		const assignment = splitTomlAssignment(line);
		if (!assignment) continue;
		const key = parseTomlKey(assignment[0]);
		if (key === plugin) {
			lines.splice(index, 1);
		}
	}

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

export async function removeUserToolAlias({
	plugin,
}: {
	plugin: string;
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

	const nextToml = removeToolAliasToml(currentToml, plugin);
	await mkdir(dirname(configPath), { recursive: true });
	await writeFile(configPath, nextToml, "utf8");
	return configPath;
}
