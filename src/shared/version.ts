const PRE_RELEASE_PATTERN = /(?:a|alpha|b|beta|rc|pre|preview|dev|test)/i;

interface ParsedVersion {
	raw: string;
	parts: number[];
	isPreRelease: boolean;
}

function parseVersion(raw: string): ParsedVersion | null {
	const trimmed = raw.trim();
	if (!trimmed) {
		return null;
	}

	const match = trimmed.match(/^(\d+(?:\.\d+)*)(.*)$/);
	if (!match) {
		return null;
	}

	const parts = match[1].split(".").map((part) => Number.parseInt(part, 10));
	if (parts.some((part) => Number.isNaN(part))) {
		return null;
	}

	const suffix = match[2].trim();
	return {
		raw: trimmed,
		parts,
		isPreRelease: isPreReleaseSuffix(suffix),
	};
}

function isPreReleaseSuffix(suffix: string): boolean {
	if (!suffix) {
		return false;
	}
	if (suffix.startsWith("+")) {
		return false;
	}
	if (suffix.startsWith("-")) {
		return true;
	}
	return PRE_RELEASE_PATTERN.test(suffix.toLowerCase()) || /[a-z]/i.test(suffix);
}

export function isPreReleaseVersion(version: string): boolean {
	const parsed = parseVersion(version);
	return parsed ? parsed.isPreRelease : /(?:-|[a-z])/i.test(version);
}

export function isStableVersion(plugin: string, version: string): boolean {
	if (plugin !== "python" && plugin !== "ruby") {
		return true;
	}
	return !isPreReleaseVersion(version);
}

export function compareVersions(a: string, b: string): number {
	const parsedA = parseVersion(a);
	const parsedB = parseVersion(b);

	if (!parsedA || !parsedB) {
		return a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" });
	}

	const max = Math.max(parsedA.parts.length, parsedB.parts.length);
	for (let i = 0; i < max; i += 1) {
		const partA = parsedA.parts[i] ?? 0;
		const partB = parsedB.parts[i] ?? 0;
		if (partA !== partB) {
			return partA - partB;
		}
	}

	if (parsedA.isPreRelease !== parsedB.isPreRelease) {
		return parsedA.isPreRelease ? -1 : 1;
	}

	return parsedA.raw.localeCompare(parsedB.raw, undefined, {
		numeric: true,
		sensitivity: "base",
	});
}

export function getMajor(version: string): number | null {
	const parsed = parseVersion(version);
	return parsed ? parsed.parts[0] ?? null : null;
}

export function pickLatest(versions: string[]): string | null {
	if (versions.length === 0) {
		return null;
	}

	return [...versions].sort((a, b) => compareVersions(a, b)).at(-1) ?? null;
}
