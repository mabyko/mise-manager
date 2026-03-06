import { Electroview } from "electrobun/view";

import type { AppRPC } from "../../shared/contracts";

export const rpc = Electroview.defineRPC<AppRPC>({
	maxRequestTime: 1000 * 60 * 20,
	handlers: { requests: {} },
});

new Electroview({ rpc });
