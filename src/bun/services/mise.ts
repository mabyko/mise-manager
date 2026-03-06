import { pickLatest } from "../../shared/version";
import type { PluginDefinitionInfo } from "../../shared/contracts";

export interface MiseResult {
	stdout: string;
	stderr: string;
	exitCode: number;
}

export async function runMise(args: string[]): Promise<MiseResult> {
	const proc = Bun.spawn(["mise", ...args], {
		stdout: "pipe",
		stderr: "pipe",
	});

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
