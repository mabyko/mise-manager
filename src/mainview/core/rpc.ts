import { invoke } from "@tauri-apps/api/core";

import type { AppRequests } from "../../shared/contracts";
import { mockRequest } from "./rpcMock";

export type RequestClient = {
	[K in keyof AppRequests]: AppRequests[K]["params"] extends undefined
		? () => Promise<AppRequests[K]["response"]>
		: (params: AppRequests[K]["params"]) => Promise<AppRequests[K]["response"]>;
};

const toSnakeCase = (name: string) =>
	name.replace(/[A-Z]/g, (char) => `_${char.toLowerCase()}`);

const asMessage = (error: unknown) =>
	typeof error === "string" ? error : JSON.stringify(error);

const hasTauri = typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

// Keeps the Electrobun-era `rpc.request.X(params)` shape so the call sites
// (and their tests) stay untouched. Tauri maps camelCase params itself.
// Without a Tauri runtime (plain browser on the Vite dev server) the mock
// backend answers instead, so the UI can be reviewed/designed in a browser.
export const rpc = {
	request: hasTauri
		? (new Proxy({} as RequestClient, {
				get: (_target, name) => (params?: Record<string, unknown>) =>
					invoke(toSnakeCase(String(name)), params).catch((error) => {
						// Tauri rejects with the raw `Err(String)`, not an Error, so every
						// `(error as Error).message` call site logged `undefined`.
						throw error instanceof Error ? error : new Error(asMessage(error));
					}),
			}) as RequestClient)
		: mockRequest,
};
