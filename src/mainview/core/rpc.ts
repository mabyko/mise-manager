import { invoke } from "@tauri-apps/api/core";

import type { AppRPC } from "../../shared/contracts";

type Requests = AppRPC["bun"]["requests"];

type RequestClient = {
	[K in keyof Requests]: Requests[K]["params"] extends undefined
		? () => Promise<Requests[K]["response"]>
		: (params: Requests[K]["params"]) => Promise<Requests[K]["response"]>;
};

const toSnakeCase = (name: string) =>
	name.replace(/[A-Z]/g, (char) => `_${char.toLowerCase()}`);

// Keeps the Electrobun-era `rpc.request.X(params)` shape so the call sites
// (and their tests) stay untouched. Tauri maps camelCase params itself.
export const rpc = {
	request: new Proxy({} as RequestClient, {
		get: (_target, name) => (params?: Record<string, unknown>) =>
			invoke(toSnakeCase(String(name)), params),
	}),
};
