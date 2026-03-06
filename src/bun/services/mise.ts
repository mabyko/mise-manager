import { pickLatest } from "../../shared/version";
import type { PluginDefinitionInfo } from "../../shared/contracts";
import { existsSync } from "node:fs";
import { delimiter, join } from "node:path";

export interface MiseResult {
	stdout: string;
	stderr: string;
	exitCode: number;
}

const FALLBACK_BIN_DIRS = [
	".local/bin",
	".mise/bin",
	"bin",
	"/opt/homebrew/bin",
	"/usr/local/bin",
	"/usr/bin",
	"/bin",
];

function expandHomeDir(pathValue: string): string {
	const home = process.env.HOME;
	if (!home || !pathValue.startsWith("~/")) {
		return pathValue;
	}
	return join(home, pathValue.slice(2));
}

function getAugmentedPath(): string {
	const current = process.env.PATH ?? "";
	const dirs = new Set(
		current
			.split(delimiter)
			.map((entry) => entry.trim())
			.filter((entry) => entry.length > 0),
	);

	const home = process.env.HOME;
	for (const dir of FALLBACK_BIN_DIRS) {
		const resolved = dir.startsWith("/") ? dir : home ? join(home, dir) : dir;
		dirs.add(resolved);
	}

	return [...dirs].join(delimiter);
}

function resolveMiseExecutable(pathValue: string): string {
	const envBin = process.env.MISE_BIN?.trim();
	if (envBin) {
		return expandHomeDir(envBin);
	}

	for (const dir of pathValue.split(delimiter)) {
		const trimmed = dir.trim();
		if (!trimmed) {
			continue;
		}
		const candidate = join(trimmed, "mise");
		if (existsSync(candidate)) {
			return candidate;
		}
	}

	return "mise";
}

export async function runMise(args: string[]): Promise<MiseResult> {
	const pathValue = getAugmentedPath();
	const miseExecutable = resolveMiseExecutable(pathValue);
	const proc = (() => {
		try {
			return Bun.spawn([miseExecutable, ...args], {
				stdout: "pipe",
				stderr: "pipe",
				env: {
					...process.env,
					PATH: pathValue,
				},
			});
		} catch (error) {
			const reason = error instanceof Error ? error.message : String(error);
			throw new Error(
				`failed to spawn mise executable '${miseExecutable}' (PATH='${pathValue}'): ${reason}`,
			);
		}
	})();

	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited,
	]);

	return { stdout, stderr, exitCode };
}

export function sanitizeVersion(input: unknown): string | null {
	if (typeof input === "string" && input.trim().length > 0) {
		return input.trim();
	}
	return null;
}

export function parseRemoteVersions(stdout: string): string[] {
	const trimmed = stdout.trim();
	if (!trimmed) {
		return [];
	}

	try {
		const parsed = JSON.parse(trimmed);
		if (Array.isArray(parsed)) {
			const versions = parsed
				.map((entry) => {
					if (typeof entry === "string") {
						return sanitizeVersion(entry);
					}
					if (entry && typeof entry === "object" && "version" in entry) {
						return sanitizeVersion((entry as { version?: unknown }).version);
					}
					return null;
				})
				.filter((value): value is string => Boolean(value));

			return versions;
		}
	} catch {
		// Fallback to plain-text parsing below.
	}

	return trimmed
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0);
}

export function pickPreferredVersion(versions: string[]): string | null {
	if (versions.length === 0) {
		return null;
	}
	const semverCandidates = versions.filter((version) => /^\d/.test(version));
	return pickLatest(semverCandidates.length > 0 ? semverCandidates : versions);
}

export function parsePluginInfoLines(stdout: string): PluginDefinitionInfo[] {
	return stdout
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0)
		.map((line) => {
			const cols = line.split(/\s+/);
			return {
				name: cols[0] ?? "",
				url: cols[1] && !cols[1].startsWith("*") ? cols[1] : null,
			};
		})
		.filter((row) => row.name.length > 0);
}
