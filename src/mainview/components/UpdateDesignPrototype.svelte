<script lang="ts">
	// Throwaway: A–C explore new layouts; D simplifies the existing list/detail UI.
	// All mutations are simulated locally; no preferences, tools or plugins are changed.
	import PrototypeSwitcher from "./PrototypeSwitcher.svelte";
	import appIcon from "../assets/app-icon.png";
	type Screen = "updates" | "tools" | "plugins" | "settings" | "logs" | "mise";
	const initial = new URLSearchParams(location.search).get("variant");
	const initialVariant = ["A", "B", "C", "D"].includes(initial ?? "") ? initial! : "A";
	let variant = $state(initialVariant);
	let screen = $state<Screen>(initialVariant === "A" ? "updates" : "tools");
	let drawerOpen = $state(true);
	let completed = $state<string[]>([]);
	let message = $state("");
	let checked = $state("3분 전에 확인");
	let search = $state("");
	let startup = $state(true);
	let simpleUpdatesOpen = $state(false);
	let selectedTool = $state("Node.js");
	let globals = $state<Record<string, string>>({});
	const updates = [
		{ id: "node26", name: "Node.js", mark: "N", line: "26.x", kind: "도구", from: "26.0.0", to: "26.1.0", hint: "현재 전역 계열 · 설치 후 기본값 유지" },
		{ id: "node24", name: "Node.js", mark: "N", line: "24.x", kind: "도구", from: "24.20.0", to: "24.21.0", hint: "함께 쓰는 계열 · 26.x와 독립적으로 설치" },
		{ id: "mise", name: "mise", mark: "m", line: "", kind: "mise", from: "2026.8.12", to: "2026.8.13", hint: "mise 자체 업데이트" },
		{ id: "flutter", name: "Flutter", mark: "F", line: "플러그인", kind: "플러그인", from: "a18c42e", to: "b92f813", hint: "플러그인 소스 갱신 · 도구 버전 유지" },
	];
	const tools = [
		{ name: "Node.js", mark: "N", version: "26.0.0", extra: "24.20.0", description: "JavaScript 런타임", updateIds: ["node26", "node24"] },
		{ name: "Python", mark: "Py", version: "3.14.7", extra: "3.12.8", description: "Python 런타임", updateIds: [] },
		{ name: "Bun", mark: "B", version: "1.2.4", extra: "", description: "JavaScript 툴킷", updateIds: [] },
		{ name: "Go", mark: "Go", version: "1.24.0", extra: "", description: "Go 툴체인", updateIds: [] },
		{ name: "Rust", mark: "Rs", version: "1.85.0", extra: "", description: "Rust 툴체인", updateIds: [] },
		{ name: "Ruby", mark: "Rb", version: "3.4.2", extra: "", description: "Ruby 런타임", updateIds: [] },
	];
	const pending = $derived(updates.filter(item => !completed.includes(item.id)));
	const filteredTools = $derived(tools.filter(tool => tool.name.toLowerCase().includes(search.toLowerCase())));
	const toolCount = $derived(pending.filter(item => item.kind === "도구").length);
	const selected = $derived(filteredTools.find(tool => tool.name === selectedTool) ?? filteredTools[0]);
	const description = $derived(variant === "D" ? "익숙한 목록·상세 구조에 업데이트 한 줄만 더합니다." : variant === "A" ? "업데이트를 한곳에서 처리하고, 내 도구는 관리할 때 엽니다." : variant === "B" ? "지금 보고 있는 화면을 유지하며 업데이트를 확인합니다." : "설치된 도구와 업데이트를 한 화면에서 함께 봅니다.");
	function installedVersions(tool: typeof tools[number]) {
		return [tool.version, tool.extra, ...updates.filter(item => tool.updateIds.includes(item.id) && completed.includes(item.id)).map(item => item.to)].filter(Boolean);
	}

	function reset(next = variant) {
		variant = next;
		screen = next === "A" ? "updates" : "tools";
		drawerOpen = true;
		completed = [];
		search = "";
		message = "";
		checked = "3분 전에 확인";
		startup = true;
		simpleUpdatesOpen = false;
		selectedTool = "Node.js";
		globals = {};
	}
	function finish(id: string) {
		if (completed.includes(id)) return;
		const item = updates.find(update => update.id === id)!;
		completed = [...completed, id];
		message = `${item.name} ${item.line} ${item.to} ${item.kind === "도구" ? "설치" : "업데이트"} 완료 · 시안에서만 적용`;
	}
	function openUpdates() {
		if (variant === "A") screen = "updates";
		else drawerOpen = !drawerOpen;
	}
</script>

{#snippet icon(name: string)}
	<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
		{#if name === "updates"}<path d="M12 3v12m-4-4 4 4 4-4M4 16v4h16v-4" />
		{:else if name === "tools"}<path d="M4 7h16v13H4zM9 7V4h6v3M4 12h16" />
		{:else if name === "plugins"}<path d="M8 4v5m8-5v5M6 9h12v3a6 6 0 0 1-12 0zM12 18v3" />
		{:else if name === "logs"}<path d="m4 7 5 5-5 5M13 17h7" />
		{:else}<path d="M4 7h16M4 17h16M8 4v6M16 14v6" />{/if}
	</svg>
{/snippet}

{#snippet brand()}
	<div class="prototype-brand"><img src={appIcon} alt="" /><strong>Mise Manager</strong></div>
{/snippet}

{#snippet checkButton()}
	<button class="prototype-btn quiet" onclick={() => { checked = "방금 확인"; message = `확인 완료 · 업데이트 ${pending.length}개 · 샘플 데이터`; }}><span aria-hidden="true">↻</span> 다시 확인</button>
{/snippet}

{#snippet updateRows(compact = false)}
	{#each ["도구", "mise", "플러그인"] as kind}
		{@const items = pending.filter(item => item.kind === kind)}
		{#if items.length}
			<div class="prototype-group-label">{kind === "도구" ? "도구 버전" : kind === "mise" ? "mise 자체" : "외부 플러그인"}<span>{items.length}</span></div>
			{#each items as item (item.id)}
				<div class="prototype-update-row" class:compact>
					{#if !compact}<span class="prototype-mark" aria-hidden="true">{item.mark}</span>{/if}
					<div class="prototype-update-content"><div class="prototype-item-title"><strong>{item.name}</strong>{#if item.line}<span>{item.line}</span>{/if}</div>
						<div class="prototype-version-change"><span>{item.from}</span><span aria-hidden="true">→</span><b>{item.to}</b></div>
						{#if !compact}<p>{item.hint}</p>{/if}
					</div>
					<button class="prototype-btn" aria-label={`${item.name} ${item.line} ${item.to} ${item.kind === "도구" ? "설치" : "업데이트"} 시뮬레이션`} onclick={() => finish(item.id)}>{item.kind === "도구" ? "설치" : "업데이트"}</button>
				</div>
			{/each}
		{/if}
	{/each}
	{#if !pending.length}<div class="prototype-empty"><span aria-hidden="true">✓</span><h3>모두 최신 상태예요</h3><p>새 업데이트가 생기면 여기에 표시됩니다.</p></div>{/if}
{/snippet}

{#snippet inventory()}
	<div class="prototype-page-heading"><div><div class="prototype-kicker">내 개발 환경</div><h1>내 도구 <span>6</span></h1><p>설치된 버전을 확인하고 기본 버전을 관리하세요.</p></div></div>
	<label class="prototype-search"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><circle cx="10" cy="10" r="6" /><path d="m15 15 5 5" /></svg><input aria-label="도구 검색" placeholder="도구 검색" bind:value={search} /></label>
	<div class="prototype-table-head"><span>도구</span><span>설치된 버전</span><span>상태</span></div>
	{#each filteredTools as tool}
		{@const count = tool.updateIds.filter(id => !completed.includes(id)).length}
		<div class="prototype-tool-row"><div class="prototype-tool-name"><span class="prototype-mark" aria-hidden="true">{tool.mark}</span><span><strong>{tool.name}</strong><small>{tool.description}</small></span></div>
			<div class="prototype-installed"><span>{tool.version}<small>전역</small></span>{#if tool.extra}<span>{tool.extra}</span>{/if}{#each tool.updateIds.filter(id => completed.includes(id)) as id}<span class="prototype-added">{updates.find(item => item.id === id)?.to}<small>추가됨</small></span>{/each}</div>
			{#if count}<button class="prototype-text-action" onclick={() => { if (variant === "A") screen = "updates"; else drawerOpen = true; }}>업데이트 {count}<span aria-hidden="true">↗</span></button>{:else}<span class="prototype-current">최신</span>{/if}
		</div>
	{:else}<p class="prototype-no-results">검색 결과가 없습니다.</p>{/each}
	<p class="prototype-inventory-note">설치만 한 버전은 기존 전역 기본값을 바꾸지 않습니다.</p>
{/snippet}

{#snippet secondaryScreen()}
	{#if variant !== "D"}<div class="prototype-page-heading"><div><div class="prototype-kicker">내 개발 환경</div><h1>{screen === "settings" ? "설정" : "플러그인"}</h1><p>다른 화면에서도 업데이트 현황을 바로 확인할 수 있어요.</p></div></div>{/if}
	{#if screen === "settings"}
		<div class="prototype-setting"><div><strong>앱을 열 때 업데이트 확인</strong><p>mise, 도구, 플러그인을 함께 확인합니다.</p></div><input type="checkbox" aria-label="앱을 열 때 업데이트 확인" bind:checked={startup} /></div>
		<div class="prototype-setting"><div><strong>설치 후 이전 버전 보존</strong><p>필요할 때 기존 버전으로 돌아갈 수 있습니다.</p></div><span class="prototype-current">항상 보존</span></div>
		<div class="prototype-setting"><div><strong>화면 테마</strong><p>시스템 설정을 따릅니다.</p></div><span class="prototype-current">시스템</span></div>
	{:else}
		<div class="prototype-setting"><div><strong>Flutter</strong><p>외부 플러그인 · Git</p></div>{#if !completed.includes("flutter")}<button class="prototype-text-action" onclick={() => { if (variant === "A") screen = "updates"; else if (variant === "D") simpleUpdatesOpen = true; else drawerOpen = true; }}>업데이트 있음 ↗</button>{:else}<span class="prototype-current">최신</span>{/if}</div>
		<div class="prototype-setting"><div><strong>mise 내장 플러그인</strong><p>Node.js, Python, Bun, Go, Rust, Ruby</p></div><span class="prototype-current">mise와 함께 관리</span></div>
	{/if}
{/snippet}

<div class="update-design-prototype variant-{variant}">
	{#if variant === "D"}
		<div class="shell simple-shell">
			<aside class="sidebar">
				<div class="brand"><img class="brand-ico" src={appIcon} alt="" /><span>Mise Manager</span></div>
				<nav aria-label="시안 메뉴">
					{#each [{ id: "tools", label: "내 도구" }, { id: "plugins", label: "플러그인 관리" }, { id: "logs", label: "작업 기록" }, { id: "settings", label: "설정" }] as item}
						<button class:on={screen === item.id} aria-current={screen === item.id ? "page" : undefined} onclick={() => screen = item.id as Screen}>{@render icon(item.id)}<span>{item.label}</span>{#if item.id === "tools"}<span class="cnt">6</span>{/if}</button>
					{/each}
				</nav>
				<div class="side-foot"><span class="side-status"><span class="dot ok"></span>mise 연결됨</span><span class="mono">{completed.includes("mise") ? "2026.8.13" : "2026.8.12"}</span><button class="text-btn simple-mise-link" onclick={() => screen = "mise"}>mise 관리 →</button></div>
			</aside>
			<div class="simple-workspace">
				<header class="page-head"><div><h1>{screen === "tools" ? "내 도구" : screen === "plugins" ? "플러그인 관리" : screen === "logs" ? "작업 기록" : screen === "mise" ? "mise 관리" : "설정"}</h1><p class="page-subtitle">{screen === "tools" ? "설치된 도구 6개" : "내 개발 환경"}</p></div><div class="page-actions">{@render checkButton()}</div></header>
				<details class="simple-updates" bind:open={simpleUpdatesOpen}>
					<summary><span class="simple-summary-main"><span class="dot" class:ok={!pending.length} class:pending={!!pending.length}></span><strong>{pending.length ? `업데이트 ${pending.length}개` : "모두 최신 상태"}</strong><span class="simple-breakdown">도구 {toolCount} · mise {pending.filter(i => i.kind === "mise").length} · 플러그인 {pending.filter(i => i.kind === "플러그인").length}</span></span><span class="simple-checktime">{checked}</span><span class="simple-disclosure" aria-hidden="true">⌄</span></summary>
					<div class="simple-pending-list" aria-label="전체 업데이트 목록">
						{#each pending as item (item.id)}
							<div class="simple-pending-row"><div><strong>{item.name}</strong> <span class="subtle">{item.line}</span></div><span class="mono simple-flow">{item.from}<span aria-hidden="true"> → </span><b>{item.to}</b></span><button class="mini-btn" aria-label={`${item.name} ${item.line} ${item.to} 빠른 ${item.kind === "도구" ? "설치" : "업데이트"} 시뮬레이션`} onclick={() => finish(item.id)}>{item.kind === "도구" ? "설치" : "업데이트"}</button></div>
						{:else}<p>확인된 업데이트를 모두 적용했어요.</p>{/each}
					</div>
				</details>
				<main class="simple-page">
					{#if screen === "tools"}
						<div class="tools-split">
							<section class="tool-list" aria-label="설치된 도구"><input class="search-input" aria-label="도구 검색" placeholder="도구 검색" bind:value={search} /><div class="tool-list-items">
								{#each filteredTools as tool}
									{@const count = pending.filter(item => tool.updateIds.includes(item.id)).length}
									<button class="tool-item" class:selected={selected?.name === tool.name} aria-pressed={selected?.name === tool.name} onclick={() => selectedTool = tool.name}><span class="tool-glyph" aria-hidden="true">{tool.mark}</span><span class="tool-item-info"><strong>{tool.name}</strong><span class="mono">{globals[tool.name] ?? tool.version}</span></span>{#if count}<span class="simple-tool-count" aria-label={`업데이트 ${count}개`}>{count}</span>{/if}</button>
								{/each}
							</div></section>
							<section class="tool-detail" aria-label="선택한 도구 상세">
								{#if selected}
									<div class="simple-detail-heading"><div><h2>{selected.name}</h2><p>{selected.description}</p></div><label class="simple-global">전역 버전<select aria-label={`${selected.name} 전역 버전`} value={globals[selected.name] ?? selected.version} onchange={(event) => { globals[selected.name] = event.currentTarget.value; message = `${selected.name} ${event.currentTarget.value} 전역 선택 · 시안에서만 적용`; }}>{#each installedVersions(selected) as version}<option value={version}>{version}</option>{/each}</select></label></div>
									<h3 class="section-label">설치된 버전</h3>
									<div class="simple-version-list">
										{#each installedVersions(selected) as version}
											{@const update = pending.find(item => selected.updateIds.includes(item.id) && item.from === version)}
											<div class="simple-version-row"><div class="simple-version-name"><strong class="mono">{version}</strong>{#if version === (globals[selected.name] ?? selected.version)}<span class="pill">전역</span>{/if}</div>{#if update}<span class="simple-version-target mono"><span aria-hidden="true">→</span> {update.to}</span><button class="mini-btn" aria-label={`${selected.name} ${update.to} 설치 시뮬레이션`} onclick={() => finish(update.id)}>설치</button>{:else}<span class="subtle simple-installed-label">설치됨</span>{/if}</div>
									{/each}</div>
									<p class="simple-version-note">새 버전을 설치해도 이전 버전과 전역 설정은 유지됩니다.</p>
								{:else}<div class="empty-detail"><h2>검색 결과가 없습니다.</h2><button class="text-btn" onclick={() => search = ""}>검색 초기화</button></div>{/if}
							</section>
						</div>
					{:else if screen === "logs"}<div class="simple-secondary"><h2>이번 실행</h2>{#each completed as id}<div class="prototype-setting">{updates.find(item => item.id === id)?.name} {updates.find(item => item.id === id)?.to} · 설치 / 업데이트 완료</div>{:else}<p>아직 실행한 업데이트가 없습니다.</p>{/each}</div>
					{:else if screen === "mise"}<div class="simple-secondary"><h2>mise</h2><div class="prototype-setting"><span>현재 버전</span><span class="mono">{completed.includes("mise") ? "2026.8.13" : "2026.8.12"}</span></div>{#if !completed.includes("mise")}<div class="prototype-setting"><span>새 버전 2026.8.13</span><button class="mini-btn" onclick={() => finish("mise")}>업데이트</button></div>{/if}</div>
					{:else}<div class="simple-secondary">{@render secondaryScreen()}</div>{/if}
				</main>
			</div>
		</div>
	{:else if variant === "A"}
		<aside class="prototype-sidebar">
			{@render brand()}
			<div class="prototype-workspace-label">개인 환경 <span>로컬</span></div>
			<nav aria-label="시안 메뉴">
				<button class:active={screen === "updates"} onclick={() => screen = "updates"}>{@render icon("updates")}업데이트 <span class="prototype-count" aria-label={`${pending.length}개`}>{pending.length}</span></button>
				<button class:active={screen === "tools"} onclick={() => screen = "tools"}>{@render icon("tools")}내 도구 <small>6</small></button>
				<button class:active={screen === "plugins"} onclick={() => screen = "plugins"}>{@render icon("plugins")}플러그인</button>
			</nav>
			<div class="prototype-side-bottom"><button class:active={screen === "settings"} onclick={() => screen = "settings"}>{@render icon("settings")}설정</button><span class="prototype-connection"><i></i> mise 연결됨</span></div>
		</aside>
		<div class="prototype-body">
			<header class="prototype-breadcrumb"><span>{screen === "updates" ? "업데이트" : screen === "tools" ? "내 도구" : screen === "plugins" ? "플러그인" : "설정"}</span><span>내 Mac</span></header>
			<main class="prototype-main inbox">
				{#if screen === "updates"}
					<div class="prototype-page-heading"><div><div class="prototype-kicker">한곳에서 확인하고 업데이트</div><h1>업데이트 <span>{pending.length}</span></h1><p>{pending.length ? "새 버전이 있는 항목만 모았어요." : "확인된 업데이트를 모두 적용했어요."}</p></div>{@render checkButton()}</div>
					<div class="prototype-checkline"><span><i></i>{checked}</span><span>도구 {toolCount} · mise {pending.filter(i => i.kind === "mise").length} · 플러그인 {pending.filter(i => i.kind === "플러그인").length}</span></div>
					{@render updateRows()}
					<div class="prototype-footnote">이전 버전은 보존됩니다. 새 major로의 전환은 별도로 선택합니다.</div>
				{:else if screen === "tools"}{@render inventory()}{:else}{@render secondaryScreen()}{/if}
			</main>
		</div>
	{:else if variant === "B"}
		<div class="prototype-toolbar">
			{@render brand()}
			<nav aria-label="시안 메뉴">{#each [{id: "tools", label: "내 도구"}, {id: "plugins", label: "플러그인"}, {id: "settings", label: "설정"}] as item}<button class:active={screen === item.id} onclick={() => screen = item.id as Screen}>{item.label}</button>{/each}</nav>
			<button class="prototype-update-trigger" aria-expanded={drawerOpen} onclick={openUpdates}>{@render icon("updates")}업데이트 <span class="prototype-count">{pending.length}</span></button>
		</div>
		<div class="prototype-drawer-layout" class:open={drawerOpen}>
			<main class="prototype-main">{#if screen === "tools"}{@render inventory()}{:else}{@render secondaryScreen()}{/if}</main>
			{#if drawerOpen}<aside class="prototype-drawer" aria-label="업데이트 패널"><div class="prototype-panel-heading"><div><h2>업데이트 <span>{pending.length}</span></h2><p>{checked}</p></div><button class="prototype-close" aria-label="업데이트 패널 닫기" onclick={() => drawerOpen = false}>×</button></div><p class="prototype-panel-intro">mise부터 도구까지, 여기서 바로.</p>{@render updateRows(true)}<div class="prototype-panel-footer">{@render checkButton()}<span>기존 버전 보존</span></div></aside>{/if}
		</div>
	{:else}
		<header class="prototype-console-header">{@render brand()}<span class="prototype-connection"><i></i>내 Mac · mise 연결됨</span><nav aria-label="시안 메뉴"><button class:active={screen === "tools"} onclick={() => screen = "tools"}>내 도구</button><button class:active={screen === "plugins"} onclick={() => screen = "plugins"}>플러그인</button><button class:active={screen === "settings"} onclick={() => screen = "settings"}>설정</button></nav></header>
		<div class="prototype-always-layout">
			<main class="prototype-main">{#if screen === "tools"}{@render inventory()}{:else}{@render secondaryScreen()}{/if}</main>
			<aside class="prototype-update-column" aria-label="항상 보이는 업데이트"><div class="prototype-panel-heading"><div><div class="prototype-kicker">지금 업데이트할 수 있어요</div><h2>업데이트 <span class="prototype-count">{pending.length}</span></h2></div></div><div class="prototype-column-status"><span>{checked}</span>{@render checkButton()}</div>{@render updateRows(true)}<p class="prototype-column-note">새 버전이 나오면 이 목록에 추가됩니다.<br />도구 목록을 뒤져볼 필요가 없어요.</p></aside>
		</div>
	{/if}
	<div class="prototype-design-note"><span>시안 {variant}</span>{description}</div>
	{#if message}<div class="prototype-toast" role="status">{message}<button aria-label="알림 닫기" onclick={() => message = ""}>×</button></div>{/if}
</div>
<PrototypeSwitcher {variant} onchange={reset} onreset={() => reset()} />

<style>
	.update-design-prototype { --p-ink: #292d29; --p-muted: #687260; --p-border: #e7e9e3; --p-accent: #426345; --p-tint: #edf2e8; height: 100%; overflow: auto; background: #fff; color: var(--p-ink); font-size: 13px; line-height: 1.5; color-scheme: light; }
	.update-design-prototype button { font: inherit; color: inherit; cursor: pointer; }
	.update-design-prototype p { color: var(--p-muted); margin: 7px 0 0; font-size: 12px; }
	.update-design-prototype button:focus-visible, .update-design-prototype input:focus-visible { outline: 2px solid var(--p-accent); outline-offset: 3px; }
	.prototype-brand { display: flex; align-items: center; gap: 9px; white-space: nowrap; letter-spacing: -.4px; font-size: 15px; }
	.prototype-brand img { width: 25px; height: 25px; border-radius: 5px; }
	.prototype-main { padding: 46px 48px 130px; min-width: 0; }
	.prototype-page-heading { display: flex; gap: 20px; align-items: center; justify-content: space-between; margin-bottom: 28px; }
	.prototype-page-heading h1 { font-size: 31px; font-weight: 620; letter-spacing: -1.3px; margin-top: 8px; }
	h1 span { color: #687260; font-size: 25px; font-weight: 400; margin-left: 8px; }
	.prototype-kicker { font-size: 11px; color: var(--p-muted); }
	.prototype-btn { background: #fff; border: 1px solid #dce1d5; border-radius: 6px; min-height: 33px; padding: 6px 13px; font-size: 12px !important; flex: none; }
	.prototype-btn:hover { border-color: var(--p-accent); background: var(--p-tint); }
	.prototype-btn.quiet { color: var(--p-muted); }
	.prototype-btn.quiet span { padding-right: 4px; font-size: 16px; }
	.prototype-count { display: inline-flex; align-items: center; justify-content: center; font-size: 11px; min-width: 22px; height: 21px; padding: 0 6px; border-radius: 5px; background: var(--p-accent); color: white; font-weight: 650; }
	.prototype-checkline { display: flex; align-items: center; justify-content: space-between; gap: 14px; border-block: 1px solid var(--p-border); padding: 12px 0; color: var(--p-muted); font-size: 11px; }
	.prototype-checkline > span:first-child, .prototype-connection { display: flex; align-items: center; gap: 7px; }
	i { display: inline-block; width: 5px; height: 5px; border-radius: 50%; background: #7b976c; }
	.prototype-group-label { display: flex; align-items: center; gap: 8px; font-weight: 600; font-size: 11px; color: #687260; margin: 29px 0 5px; }
	.prototype-group-label span { color: #687260; font-size: 10px; }
	.prototype-update-row { display: flex; align-items: center; gap: 15px; padding: 20px 0; border-bottom: 1px solid var(--p-border); }
	.prototype-mark { display: grid; place-items: center; flex: none; width: 35px; height: 35px; background: #f4f5f1; color: #6b7462; border: 1px solid #e8ebe2; border-radius: 9px; font: 500 12px ui-monospace, monospace; }
	.prototype-update-content { flex: 1; min-width: 0; }
	.prototype-item-title { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
	.prototype-item-title strong { font-size: 13px; font-weight: 620; }
	.prototype-item-title > span { font: 11px ui-monospace, monospace; color: var(--p-muted); }
	.prototype-version-change { display: flex; align-items: center; flex-wrap: wrap; gap: 10px; margin-top: 5px; font: 11px/1.5 ui-monospace, monospace; font-variant-numeric: tabular-nums; }
	.prototype-version-change span { color: #687260; }
	.prototype-version-change b { font-weight: 500; color: var(--p-accent); }
	.prototype-update-content p { font-size: 11px; margin-top: 6px; }
	.prototype-footnote { font-size: 11px; color: #687260; margin-top: 26px; }
	.prototype-empty { padding: 58px 8px; text-align: center; }
	.prototype-empty > span { color: var(--p-accent); font-size: 28px; }
	.prototype-empty h3 { margin-top: 15px; }
	.variant-A { display: flex; }
	.prototype-sidebar { width: 208px; flex: none; padding: 26px 14px 96px; display: flex; flex-direction: column; background: #f7f8f4; border-right: 1px solid var(--p-border); }
	.prototype-sidebar .prototype-brand { padding: 0 8px; }
	.prototype-workspace-label { display: flex; justify-content: space-between; font-size: 10px; color: #687260; padding: 0 10px; margin: 40px 0 13px; }
	.prototype-workspace-label span { color: #687260; }
	.prototype-sidebar nav, .prototype-side-bottom { display: grid; gap: 5px; }
	.prototype-sidebar button { display: flex; align-items: center; gap: 10px; min-height: 39px; padding: 9px 11px; text-align: left; border: 0; border-radius: 6px; background: transparent; color: #687260; font-size: 12px; }
	.prototype-sidebar button.active { background: #e9efdf; color: #355136; font-weight: 600; }
	.prototype-sidebar button:hover { background: #edf1e7; }
	.prototype-sidebar .prototype-count, .prototype-sidebar button small { margin-left: auto; }
	.prototype-sidebar button small { color: #687260; font-size: 11px; }
	.prototype-side-bottom { margin-top: auto; padding-top: 40px; }
	.prototype-connection { font-size: 10px; color: #687260; padding: 12px 11px; }
	.prototype-body { flex: 1; min-width: 0; overflow: auto; }
	.prototype-breadcrumb { display: flex; justify-content: space-between; padding: 20px 35px; border-bottom: 1px solid var(--p-border); color: #687260; font-size: 11px; }
	.prototype-main.inbox { max-width: 920px; margin: 0 auto; padding-top: 44px; }
	.prototype-search { display: flex; align-items: center; gap: 9px; padding: 10px 11px; margin-bottom: 25px; max-width: 280px; border: 1px solid var(--p-border); border-radius: 6px; color: #687260; }
	.prototype-search input { min-width: 0; width: 100%; color: var(--p-ink); background: transparent; border: 0; font-size: 12px; outline-offset: 2px; }
	.prototype-table-head, .prototype-tool-row { display: grid; grid-template-columns: minmax(160px,1.2fr) minmax(150px,1fr) 100px; align-items: center; gap: 16px; }
	.prototype-table-head { padding: 10px 0; border-bottom: 1px solid var(--p-border); font-size: 10px; color: #687260; }
	.prototype-table-head > :last-child { text-align: right; }
	.prototype-tool-row { padding: 20px 0; border-bottom: 1px solid var(--p-border); }
	.prototype-tool-name { display: flex; align-items: center; gap: 12px; }
	.prototype-tool-name strong { font-size: 13px; font-weight: 600; }
	.prototype-tool-name small { display: block; color: #687260; font-size: 10px; margin-top: 2px; }
	.prototype-installed { display: grid; gap: 5px; font: 11px ui-monospace, monospace; color: #687260; }
	.prototype-installed small { font: 9px -apple-system, sans-serif; color: #687260; margin-left: 7px; padding: 2px 4px; background: #f3f5ef; border-radius: 3px; }
	.prototype-installed .prototype-added { color: var(--p-accent); }
	.prototype-text-action { display: flex; align-items: center; justify-content: end; gap: 8px; border: 0; padding: 6px 0; min-height: 30px; background: none; color: var(--p-accent) !important; font-size: 11px !important; white-space: nowrap; }
	.prototype-text-action:hover { text-decoration: underline; }
	.prototype-current { color: #687260; font-size: 11px; text-align: right; }
	.prototype-inventory-note, .prototype-no-results { margin-top: 23px !important; font-size: 11px !important; }
	.prototype-setting { display: flex; justify-content: space-between; align-items: center; gap: 24px; padding: 24px 0; border-bottom: 1px solid var(--p-border); }
	.prototype-setting strong { font-weight: 550; }
	.variant-B { --p-accent: #49627b; --p-tint: #edf2f7; --p-border: #e8ecf0; --p-muted: #647383; background: #fcfdfe; }
	.prototype-toolbar { height: 76px; display: flex; align-items: center; gap: 48px; border-bottom: 1px solid var(--p-border); padding: 0 34px; background: #fff; }
	.prototype-toolbar nav { display: flex; gap: 27px; height: 100%; }
	.prototype-toolbar nav button { border: 0; border-bottom: 2px solid transparent; color: #647383; background: none; padding: 0 3px; font-size: 12px; }
	.prototype-toolbar nav button.active { border-bottom-color: #425b77; color: #344b62; }
	.prototype-update-trigger { margin-left: auto; display: flex; align-items: center; gap: 9px; border: 1px solid #d8e1e9; background: #f3f6fa; border-radius: 7px; padding: 8px 11px; font-size: 12px !important; }
	.prototype-update-trigger[aria-expanded="true"] { background: #eaf0f7; }
	.prototype-drawer-layout { display: grid; grid-template-columns: minmax(0,1fr); min-height: calc(100% - 76px); }
	.prototype-drawer-layout.open { grid-template-columns: minmax(0,1fr) 355px; }
	.prototype-drawer-layout .prototype-main { max-width: 1100px; width: 100%; margin: 0 auto; padding: 47px 45px 140px; }
	.prototype-drawer { padding: 30px 26px 140px; background: #fff; border-left: 1px solid var(--p-border); }
	.prototype-panel-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; }
	.prototype-panel-heading h2 { font-size: 20px; font-weight: 600; letter-spacing: -.6px; }
	.prototype-panel-heading h2 > span { color: var(--p-accent); margin-left: 4px; }
	.prototype-panel-heading p { font-size: 10px; }
	.prototype-close { border: 0; background: none; color: #647383 !important; font-size: 21px !important; width: 28px; height: 28px; }
	.prototype-panel-intro { margin-top: 22px !important; padding-bottom: 22px; border-bottom: 1px solid var(--p-border); }
	.prototype-update-row.compact { gap: 10px; padding: 18px 0; }
	.compact .prototype-btn { padding-inline: 9px; font-size: 11px !important; }
	.compact .prototype-version-change { gap: 6px; font-size: 10px; }
	.prototype-panel-footer { margin-top: 27px; display: flex; align-items: center; justify-content: space-between; }
	.prototype-panel-footer > span { font-size: 10px; color: var(--p-muted); }
	.variant-C { --p-accent: #454941; --p-border: #e6e8e0; background: #fff; }
	.prototype-console-header { display: flex; align-items: center; gap: 24px; height: 68px; border-bottom: 1px solid var(--p-border); padding: 0 30px; }
	.prototype-console-header > .prototype-connection { border-left: 1px solid var(--p-border); padding-left: 23px; }
	.prototype-console-header nav { margin-left: auto; display: flex; gap: 8px; }
	.prototype-console-header nav button { padding: 7px 12px; border: 0; border-radius: 5px; color: #687260; background: none; font-size: 11px; }
	.prototype-console-header nav button.active { background: #f0f2eb; color: #434a39; }
	.prototype-always-layout { display: grid; grid-template-columns: minmax(0,1fr) 370px; min-height: calc(100% - 68px); }
	.prototype-always-layout .prototype-main { padding: 42px 42px 140px; }
	.prototype-update-column { padding: 40px 28px 140px; border-left: 1px solid var(--p-border); background: #f8f9f5; }
	.prototype-update-column h2 { margin-top: 9px; display: flex; align-items: center; gap: 5px; }
	.prototype-update-column h2 .prototype-count { color: white; }
	.prototype-column-status { display: flex; align-items: center; justify-content: space-between; padding-block: 17px; border-bottom: 1px solid var(--p-border); font-size: 10px; color: #687260; }
	.prototype-column-status .prototype-btn { border: 0; background: none; padding-right: 0; font-size: 10px !important; }
	.prototype-column-note { font-size: 11px !important; margin-top: 25px !important; line-height: 1.9; }
	.prototype-design-note { position: fixed; bottom: 84px; left: 50%; transform: translateX(-50%); display: flex; align-items: center; gap: 8px; max-width: calc(100vw - 30px); padding: 5px 10px; background: #fffE; border-radius: 5px; color: #687260; font-size: 11px; text-align: center; pointer-events: none; }
	.prototype-design-note > span { color: #49653a; border: 1px solid #dce7ce; background: #f2f6ec; border-radius: 4px; padding: 2px 5px; white-space: nowrap; }
	.prototype-toast { position: fixed; top: 16px; left: 50%; transform: translateX(-50%); z-index: 30; display: flex; align-items: center; gap: 14px; max-width: calc(100vw - 30px); padding: 12px 16px; border: 1px solid #cbd8be; border-radius: 8px; box-shadow: 0 4px 15px #0001; background: #f3f8ed; color: #405532; font-size: 12px; }
	.prototype-toast button { border: 0; background: none; font-size: 18px; }
	/* D reuses the app's sidebar, controls and list/detail proportions. */
	.variant-D { --p-ink: var(--ink); --p-muted: var(--muted); --p-accent: var(--accent); --p-border: var(--line); color: var(--ink); background: var(--bg); }
	.simple-shell { height: 100%; }
	.variant-D .sidebar nav button { font-size: 13px; }
	.simple-mise-link { text-align: left; padding-left: 0; }
	.simple-workspace { flex: 1; min-width: 0; display: flex; flex-direction: column; }
	.simple-workspace .page-head { flex: none; padding-block: 22px; }
	.simple-workspace .page-subtitle { margin-top: 3px; }
	.simple-workspace .prototype-btn { background: var(--control-bg); border-color: var(--line); }
	.simple-updates { flex: none; border-bottom: 1px solid var(--line); background: var(--surface); }
	.simple-updates summary { display: flex; align-items: center; gap: 14px; padding: 13px 28px; color: var(--muted); list-style: none; }
	.simple-updates summary::-webkit-details-marker { display: none; }
	.simple-updates summary:hover { background: var(--control-bg); }
	.simple-summary-main { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
	.simple-summary-main strong { color: var(--ink); font-size: 12px; font-weight: 600; }
	.simple-summary-main .dot.pending { background: var(--warn); }
	.simple-breakdown { margin-left: 8px; font-size: 11px; }
	.simple-checktime { margin-left: auto; white-space: nowrap; font-size: 11px; }
	.simple-disclosure { font-size: 17px; line-height: 1; }
	.simple-updates[open] .simple-disclosure { transform: rotate(180deg); }
	.simple-pending-list { padding: 0 28px 12px; max-height: 260px; overflow: auto; }
	.simple-pending-row { display: grid; grid-template-columns: minmax(135px,1fr) minmax(210px,1.5fr) auto; align-items: center; gap: 16px; padding: 10px 0; border-top: 1px solid var(--line-soft); font-size: 12px; }
	.simple-pending-row strong { font-weight: 600; }
	.simple-flow { color: var(--muted); font-size: 11px; }
	.simple-flow b { color: var(--accent); font-weight: 500; }
	.simple-page { flex: 1; min-height: 0; overflow: auto; }
	.simple-page .tools-split { min-height: 100%; }
	.simple-page .tool-list { padding-top: 16px; }
	.simple-page .search-input { margin: 0 0 16px; }
	.simple-page .tool-item { font-size: 13px; }
	.simple-tool-count { margin-left: auto; border-radius: 4px; min-width: 19px; padding: 1px 5px; background: var(--warn-bg); color: var(--warn); text-align: center; font-size: 10px; }
	.simple-page .tool-detail { padding: 28px 30px 140px; }
	.simple-detail-heading { display: flex; align-items: center; justify-content: space-between; gap: 20px; margin-bottom: 36px; }
	.simple-detail-heading h2 { font-size: 24px; }
	.simple-detail-heading p { margin-top: 4px; }
	.simple-global { display: flex; align-items: center; gap: 9px; color: var(--muted); font-size: 11px; }
	.simple-global select { min-width: 105px; padding: 6px 8px; min-height: 32px; border: 1px solid var(--line); border-radius: 6px; color: var(--ink); background: var(--control-bg); font: 12px ui-monospace, monospace; }
	.simple-version-list { border-top: 1px solid var(--line); }
	.simple-version-row { display: grid; grid-template-columns: minmax(125px,1fr) minmax(90px,1fr) auto; align-items: center; gap: 14px; min-height: 61px; padding: 12px 0; border-bottom: 1px solid var(--line-soft); font-size: 13px; }
	.simple-version-name { display: flex; align-items: center; gap: 9px; flex-wrap: wrap; }
	.simple-version-name strong { font-weight: 500; }
	.simple-version-name .pill { font-size: 10px; padding: 2px 6px; }
	.simple-version-target { color: var(--accent); font-size: 12px; }
	.simple-version-target > span { color: var(--muted); margin-right: 10px; }
	.simple-installed-label { grid-column: 2 / 4; text-align: right; font-size: 11px; }
	.simple-version-note { margin-top: 18px !important; font-size: 11px !important; }
	.simple-secondary { padding: 28px 30px 140px; max-width: 900px; }
	@media(max-width: 850px) { .simple-workspace .page-head { padding: 20px; } .simple-updates summary { padding-inline: 20px; } .simple-page .tool-detail { padding-inline: 20px; } .simple-detail-heading { flex-wrap: wrap; gap: 15px; } .simple-breakdown { margin-left: 0; } .simple-checktime { display: none; } .simple-disclosure { margin-left: auto; } .simple-pending-list { padding-inline: 20px; } .simple-pending-row { grid-template-columns: 1fr auto; gap: 4px 12px; } .simple-pending-row .simple-flow { grid-column: 1; grid-row: 2; } .simple-pending-row button { grid-column: 2; grid-row: 1 / 3; } }
	@media(max-width: 580px) { .variant-D .sidebar nav button { font-size: 11px; } .variant-D .sidebar nav svg { display: none; } .simple-workspace { min-height: 0; } .simple-workspace .page-actions { margin-left: auto; } .simple-summary-main { gap: 6px; } .simple-breakdown { font-size: 10px; } .simple-version-row { grid-template-columns: minmax(100px,1fr) minmax(75px,1fr) auto; gap: 8px; } }
	@media(min-width: 1400px) { .prototype-main.inbox { max-width: 1020px; } .prototype-toolbar { padding-inline: 48px; } .prototype-drawer-layout.open { grid-template-columns: minmax(0,1fr) 390px; } .prototype-always-layout { grid-template-columns: minmax(0,1fr) 400px; } }
	@media(max-width: 1080px) { .prototype-sidebar { width: 184px; } .prototype-main, .prototype-drawer-layout .prototype-main, .prototype-always-layout .prototype-main { padding-inline: 28px; } .prototype-drawer-layout.open, .prototype-always-layout { grid-template-columns: minmax(0,1fr) 310px; } .prototype-drawer, .prototype-update-column { padding-inline: 20px; } .prototype-table-head, .prototype-tool-row { grid-template-columns: minmax(100px,1fr) 115px 78px; gap: 10px; } .prototype-tool-name .prototype-mark { display: none; } .prototype-toolbar { gap: 27px; padding-inline: 25px; } }
	@media(max-width: 760px) { .prototype-sidebar { width: 155px; padding-inline: 9px; } .prototype-sidebar .prototype-brand { font-size: 12px; gap: 6px; padding: 0; } .prototype-brand img { width: 22px; height: 22px; } .prototype-main { padding-inline: 20px; } .prototype-page-heading { align-items: flex-start; gap: 10px; flex-wrap: wrap; } .prototype-checkline { flex-wrap: wrap; gap: 5px; } .prototype-update-row { gap: 10px; } .prototype-update-row > .prototype-mark { display: none; } .prototype-toolbar { flex-wrap: wrap; height: auto; min-height: 105px; gap: 10px; padding: 15px 20px; } .prototype-toolbar nav { order: 3; height: 30px; width: 100%; gap: 24px; } .prototype-drawer-layout.open { display: block; } .prototype-drawer { position: fixed; inset: 105px 0 0 auto; z-index: 5; width: min(355px,100vw); box-shadow: -10px 0 30px #24344912; overflow: auto; padding-bottom: 150px; } .prototype-always-layout { display: flex; flex-direction: column; } .prototype-update-column { order: -1; border-left: 0; border-bottom: 1px solid var(--p-border); padding: 26px 28px; } .prototype-console-header { height: auto; min-height: 100px; flex-wrap: wrap; padding: 15px 22px; gap: 12px; } .prototype-console-header > .prototype-connection { display: none; } .prototype-console-header nav { width: 100%; margin: 0; } .prototype-design-note { width: max-content; max-width: calc(100vw - 28px); font-size: 10px; bottom: 80px; } }
	@media(max-width: 520px) { .variant-A { display: block; } .prototype-sidebar { width: 100%; padding: 14px 14px 9px; border-right: 0; border-bottom: 1px solid var(--p-border); } .prototype-workspace-label, .prototype-side-bottom { display: none; } .prototype-sidebar nav { display: flex; gap: 5px; margin-top: 10px; } .prototype-sidebar button { flex: 1; justify-content: center; padding: 7px 5px; gap: 5px; font-size: 11px; } .prototype-sidebar button svg { display: none; } .prototype-sidebar .prototype-count { margin-left: 0; } .prototype-sidebar button small { display: none; } .prototype-breadcrumb { display: none; } .prototype-main.inbox { padding-top: 25px; } .prototype-main, .prototype-drawer-layout .prototype-main, .prototype-always-layout .prototype-main { padding-inline: 20px; } .prototype-table-head, .prototype-tool-row { grid-template-columns: minmax(90px,1fr) 100px 82px; } .prototype-tool-name small { display: none; } .prototype-page-heading h1 { font-size: 28px; } .prototype-design-note { line-height: 1.6; } }
</style>
