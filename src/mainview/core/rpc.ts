import { invoke } from "@tauri-apps/api/core";

import type { AppRequests } from "../../shared/contracts";

type RequestClient = {
	[K in keyof AppRequests]: AppRequests[K]["params"] extends undefined
		? () => Promise<AppRequests[K]["response"]>
		: (params: AppRequests[K]["params"]) => Promise<AppRequests[K]["response"]>;
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
