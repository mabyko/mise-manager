<script lang="ts">
	// Throwaway E/F/G study from official Cork, Toolbox and Latest screenshots.
	// D remains untouched. Every action below is in-memory sample data, with no RPC.
	import PrototypeSwitcher from "./PrototypeSwitcher.svelte";
	import appIcon from "../assets/app-icon.png";
	const initial = new URLSearchParams(location.search).get("variant") ?? "E";
	let variant = $state(["E", "F", "G"].includes(initial) ? initial : "E");
	const items = [
		{ id: "node26", name: "Node.js", family: "node", series: "26.x", from: "26.0.0", to: "26.1.0", kind: "도구", mark: "N", note: "JavaScript 런타임" },
		{ id: "node24", name: "Node.js", family: "node", series: "24.x", from: "24.20.0", to: "24.21.0", kind: "도구", mark: "N", note: "JavaScript 런타임" },
		{ id: "python", name: "Python", family: "python", series: "3.x", from: "3.14.7", to: "", kind: "도구", mark: "Py", note: "Python 런타임" },
		{ id: "bun", name: "Bun", family: "bun", series: "1.x", from: "1.2.4", to: "", kind: "도구", mark: "B", note: "JavaScript 툴킷" },
		{ id: "rust", name: "Rust", family: "rust", series: "1.x", from: "1.85.0", to: "", kind: "도구", mark: "Rs", note: "Rust 툴체인" },
		{ id: "mise", name: "mise", family: "mise", series: "", from: "2026.8.12", to: "2026.8.13", kind: "mise", mark: "m", note: "도구 버전 관리자" },
		{ id: "flutter", name: "Flutter", family: "flutter", series: "", from: "a18c42e", to: "b92f813", kind: "플러그인", mark: "F", note: "외부 플러그인 · Git" },
	];
	type Item = typeof items[number];
	const references: Record<string, { app: string; url: string; idea: string; tradeoff: string }> = {
		E: { app: "Cork", url: "https://corkmac.app/", idea: "메뉴 대신 도구를 직접 탐색하는 두 칸 구조", tradeoff: "도구가 많아도 바로 찾기 쉬워요." },
		F: { app: "JetBrains Toolbox", url: "https://www.jetbrains.com/toolbox-app/", idea: "작은 창에서 버전별로 바로 작업하는 관리 목록", tradeoff: "자주 쓰는 몇 가지 도구를 관리할 때 가벼워요." },
		G: { app: "Latest", url: "https://max.codes/latest/", idea: "업데이트 목록과 적용 내용을 나란히 놓는 검토 화면", tradeoff: "무엇이 바뀌는지 확인하고 설치하기 좋아요." },
	};
	let completed = $state<string[]>([]);
	let selection = $state("node");
	let reviewId = $state("node24");
	let query = $state("");
	let settingsOpen = $state(false);
	let startup = $state(true);
	let onlyUpdates = $state(false);
	let checked = $state("3분 전 확인");
	let message = $state("");
	let globals = $state<Record<string, string>>({ node: "26.0.0", python: "3.14.7", bun: "1.2.4", rust: "1.85.0" });
	const pending = $derived(items.filter(item => item.to && !completed.includes(item.id)));
	const families = [...new Set(items.filter(item => item.kind === "도구").map(item => item.family))];
	const matched = $derived(items.filter(item => `${item.name} ${item.series}`.toLowerCase().includes(query.trim().toLowerCase())));
	const explorerItems = $derived(matched.filter(item => selection === "updates" ? pending.includes(item) : item.family === selection));
	const selected = $derived(items.find(item => item.id === reviewId)!);
	const reference = $derived(references[variant]);
	function apply(ids: string[]) {
		const applying = pending.filter(item => ids.includes(item.id));
		if (!applying.length) return;
		completed = [...completed, ...applying.map(item => item.id)];
		message = `${applying.length}개 업데이트 적용 · 시안에서만 변경됐어요`;
	}
	function reset(next = variant) {
		variant = next; completed = []; selection = "node"; reviewId = "node24"; query = "";
		settingsOpen = false; startup = true; onlyUpdates = false; checked = "3분 전 확인"; message = "";
		globals = { node: "26.0.0", python: "3.14.7", bun: "1.2.4", rust: "1.85.0" };
	}
	function check() { checked = "방금 확인"; message = `확인 완료 · 업데이트 ${pending.length}개 · 샘플 데이터`; }
	function showUpdates() { settingsOpen = false; selection = "updates"; onlyUpdates = true; query = ""; }
</script>

{#snippet symbol(name: string)}
	<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
		{#if name === "settings"}<path d="M4 7h16M4 17h16M8 4v6M16 14v6" />
		{:else if name === "check"}<path d="M20 7v5h-5M19 12a7 7 0 1 0-2 5M20 7l-3-3" />
		{:else}<path d="M12 3v12m-4-4 4 4 4-4M4 16v4h16v-4" />{/if}
	</svg>
{/snippet}
{#snippet mark(item: Item)}<span class="rd-mark mark-{item.family}" aria-hidden="true">{item.mark}</span>{/snippet}
{#snippet action(item: Item)}
	{#if pending.includes(item)}<button class="rd-action" aria-label={`${item.name} ${item.series} ${item.to} 적용 시뮬레이션`} onclick={() => apply([item.id])}>{item.kind === "도구" ? "설치" : "업데이트"}</button>
	{:else}<span class="rd-done">{completed.includes(item.id) ? "적용됨" : "최신"}</span>{/if}
{/snippet}
{#snippet settingsPanel()}
	<section class="rd-settings"><h2>설정</h2><label><span><strong>시작할 때 업데이트 확인</strong><small>mise · 설치된 모든 버전 계열 · 외부 플러그인</small></span><input type="checkbox" bind:checked={startup} /></label><div><span><strong>업데이트 설치 방식</strong><small>기존 버전과 전역 선택을 보존합니다.</small></span><span class="rd-done">설치만</span></div></section>
{/snippet}

<div class="reference-study study-{variant}">
	<div class="study-topline"><span>실제 앱에서 출발한 UI 탐색 <span class="study-sample">· 샘플 데이터</span></span><a href="/?variant=D">보관한 시안 보기 ↗</a></div>
	<div class="study-stage">
		{#if variant === "E"}
			<div class="explorer-window">
				<aside class="explorer-rail">
					<div class="rd-brand"><img src={appIcon} alt="" /><strong>Mise Manager</strong></div>
					<label class="rd-search"><span class="sr-only">도구 검색</span><input aria-label="도구 검색" placeholder="도구 검색" bind:value={query} /></label>
					<button class="explorer-updates" class:chosen={selection === "updates" && !settingsOpen} onclick={showUpdates}>{@render symbol("updates")}<span>업데이트</span><b>{pending.length}</b></button>
					<h2 class="rail-label">설치된 도구</h2>
					<nav aria-label="설치된 도구">{#each families as family}
						{@const item = items.find(i => i.family === family)!}
						{#if matched.some(i => i.family === family)}<button class:chosen={selection === family && !settingsOpen} onclick={() => { selection = family; settingsOpen = false; }}><span>{item.name}</span><span class="rail-version">{globals[family]}</span>{#if pending.some(i => i.family === family)}<span class="rd-dot" aria-label="업데이트 있음"></span>{/if}</button>{/if}
					{/each}</nav>
					<h2 class="rail-label">관리</h2><nav aria-label="관리">{#each items.filter(i => i.kind !== "도구") as item}<button class:chosen={selection === item.family && !settingsOpen} onclick={() => { selection = item.family; settingsOpen = false; query = ""; }}><span>{item.name}</span><small>{item.kind === "mise" ? "버전 관리자" : "플러그인"}</small>{#if pending.includes(item)}<span class="rd-dot" aria-label="업데이트 있음"></span>{/if}</button>{/each}</nav>
					<button class="explorer-settings" class:chosen={settingsOpen} onclick={() => settingsOpen = !settingsOpen}>{@render symbol("settings")}설정</button>
				</aside>
				<div class="explorer-main"><header class="explorer-toolbar"><h1>{settingsOpen ? "설정" : selection === "updates" ? "업데이트" : items.find(i => i.family === selection)?.name}</h1><span>{checked}</span><button class="rd-icon" aria-label="업데이트 다시 확인" onclick={check}>{@render symbol("check")}</button></header>
					<main>{#if settingsOpen}{@render settingsPanel()}{:else}
						{#if selection !== "updates"}<button class="explorer-notice" onclick={showUpdates}>{@render symbol("updates")}<span>업데이트 {pending.length}개를 사용할 수 있어요</span><span aria-hidden="true">→</span></button>{/if}
						<div class="explorer-heading"><div><h2>{selection === "updates" ? "업데이트할 항목" : items.find(i => i.family === selection)?.name}</h2><p>{selection === "updates" ? "도구 버전과 mise, 플러그인을 함께 확인합니다." : items.find(i => i.family === selection)?.note}</p></div>{#if selection !== "updates"}{@render mark(items.find(i => i.family === selection)!)}{/if}</div>
						<div class="explorer-versions">{#each explorerItems as item}<div class="explorer-version"><div><strong>{selection === "updates" ? item.name : item.kind === "도구" ? `${item.series} 계열` : "현재 버전"}</strong>{#if selection === "updates"}<small>{item.series || item.kind}</small>{/if}</div><div class="version-description"><span class="rd-mono">{completed.includes(item.id) && item.kind !== "도구" ? item.to : item.from}</span>{#if item.kind === "도구" && globals[item.family] === item.from}<small>전역</small>{/if}{#if pending.includes(item)}<span class="version-arrow" aria-hidden="true">→</span><strong class="rd-mono">{item.to}</strong>{:else if completed.includes(item.id) && item.kind === "도구"}<span class="rd-mono added">+ {item.to}</span>{/if}</div>{@render action(item)}</div>{:else}<p class="rd-empty">{query ? "검색 결과가 없습니다." : "확인된 업데이트를 모두 적용했어요."}</p>{/each}</div>
						{#if selection !== "updates" && items.find(i => i.family === selection)?.kind === "도구"}<section class="explorer-info"><h3>이 도구의 기본값</h3><label>전역 버전<select aria-label="전역 버전" bind:value={globals[selection]}>{#each items.filter(i => i.family === selection) as item}<option value={item.from}>{item.from}</option>{#if completed.includes(item.id)}<option value={item.to}>{item.to}</option>{/if}{/each}</select></label><p>프로젝트에 버전 설정이 있으면 해당 설정이 우선합니다.</p></section>{/if}
					{/if}</main>
					<footer class="explorer-footer"><span>mise 연결됨</span><span>기존 버전 보존 · 전역 설정 유지</span></footer>
				</div>
			</div>
		{:else if variant === "F"}
			<div class="toolbox-window">
				<header class="toolbox-header"><div class="rd-brand"><img src={appIcon} alt="" /><strong>Mise Manager</strong></div><span>내 Mac</span><button class="rd-icon" aria-label="설정 열기" aria-pressed={settingsOpen} onclick={() => settingsOpen = !settingsOpen}>{@render symbol("settings")}</button></header>
				<nav class="toolbox-tabs" aria-label="목록 필터"><button class:active={!onlyUpdates && !settingsOpen} onclick={() => { onlyUpdates = false; settingsOpen = false; }}>내 도구</button><button class:active={onlyUpdates && !settingsOpen} onclick={showUpdates}>업데이트 <b>{pending.length}</b></button><button class="rd-icon" aria-label="업데이트 다시 확인" onclick={check}>{@render symbol("check")}</button></nav>
				<main class="toolbox-list">{#if settingsOpen}{@render settingsPanel()}{:else}
					<div class="toolbox-section-title"><span>{onlyUpdates ? "업데이트 가능" : "설치됨"}</span><button class="rd-link" disabled={!pending.length} onclick={() => apply(pending.map(i => i.id))}>모두 업데이트</button></div>
					{#each items.filter(i => i.kind === "도구" && (!onlyUpdates || pending.includes(i))) as item}<article class="toolbox-tool">{@render mark(item)}<div class="toolbox-tool-body"><div class="toolbox-title"><h2>{item.name}</h2><span class="series-tag">{item.series}</span></div><div class="toolbox-version rd-mono">{item.from}{#if pending.includes(item)}<span aria-hidden="true"> → </span>{item.to}{/if}</div>{#if completed.includes(item.id)}<p class="toolbox-added">{item.to} 추가 설치됨</p>{/if}<details><summary>버전 관리</summary><div class="toolbox-version-options"><span>전역: <b class="rd-mono">{globals[item.family]}</b></span>{#if globals[item.family] !== item.from}<button class="rd-link" onclick={() => { globals[item.family] = item.from; message = `${item.name} ${item.from} 전역 선택 · 시안에서만 적용`; }}>{item.from} 사용</button>{/if}{#if completed.includes(item.id)}<button class="rd-link" onclick={() => { globals[item.family] = item.to; message = `${item.name} ${item.to} 전역 선택 · 시안에서만 적용`; }}>{item.to} 사용</button>{/if}</div></details></div>{@render action(item)}</article>{/each}
					<div class="toolbox-section-title"><span>mise & 플러그인</span></div>{#each items.filter(i => i.kind !== "도구" && (!onlyUpdates || pending.includes(i))) as item}<article class="toolbox-tool">{@render mark(item)}<div class="toolbox-tool-body"><h2>{item.name}<small>{item.kind === "플러그인" ? "플러그인" : ""}</small></h2><div class="toolbox-version rd-mono">{completed.includes(item.id) ? item.to : item.from}</div></div>{@render action(item)}</article>{/each}
					{#if onlyUpdates && !pending.length}<p class="rd-empty">모두 최신 상태예요.</p>{/if}
				{/if}</main><footer class="toolbox-footer"><span class="rd-dot"></span>{checked}<span>전역 기본값 유지</span></footer>
			</div>
		{:else}
			<div class="latest-window">
				<header class="latest-header"><div><h1>Mise Manager</h1><p>업데이트 {pending.length}개</p></div><button class="rd-icon" aria-label="업데이트 다시 확인" onclick={check}>{@render symbol("check")}</button><button class="rd-icon" aria-label="설정 열기" aria-pressed={settingsOpen} onclick={() => settingsOpen = !settingsOpen}>{@render symbol("settings")}</button></header>
				<div class="latest-body"><aside class="latest-list"><label class="rd-search"><span class="sr-only">도구 검색</span><input aria-label="도구 검색" placeholder="검색" bind:value={query} /></label>{#each [true, false] as available}<h2 class="rail-label">{available ? `업데이트 가능 (${pending.length})` : "설치됨"}</h2>{#each matched.filter(i => available ? pending.includes(i) : !pending.includes(i)) as item}<button class="latest-item" class:chosen={reviewId === item.id && !settingsOpen} aria-pressed={reviewId === item.id && !settingsOpen} onclick={() => { reviewId = item.id; settingsOpen = false; }}>{@render mark(item)}<span><strong>{item.name} <small>{item.series}</small></strong><span class="rd-mono">{completed.includes(item.id) ? item.to : item.from}{#if pending.includes(item)} → {item.to}{/if}</span></span></button>{/each}{/each}{#if !matched.length}<p class="rd-empty">검색 결과가 없습니다.</p>{/if}</aside>
					<main class="latest-detail">{#if settingsOpen}{@render settingsPanel()}{:else}
						<div class="latest-detail-heading">{@render mark(selected)}<div><h2>{selected.name} <span>{selected.series}</span></h2><p>{selected.kind === "도구" ? `${selected.series} 안정 버전` : selected.note}</p></div>{@render action(selected)}</div>
						<div class="latest-version-flow"><div><span>{completed.includes(selected.id) ? "이전 버전" : "현재 설치"}</span><strong class="rd-mono">{selected.from}</strong></div>{#if selected.to}<span aria-hidden="true">→</span><div><span>{completed.includes(selected.id) ? "적용 완료" : "업데이트 후보"}</span><strong class="rd-mono">{selected.to}</strong></div>{/if}</div>
						<section class="latest-impact"><h3>적용 내용</h3>{#if selected.kind === "도구"}<p>{selected.to ? `${selected.series} 계열의 새 버전을 추가로 설치합니다.` : "확인된 최신 버전이 설치되어 있습니다."}</p><dl><div><dt>이전 버전</dt><dd>{selected.from} 유지</dd></div><div><dt>전역 기본값</dt><dd>{globals[selected.family]} 유지</dd></div>{#if selected.family === "node"}<div><dt>다른 계열</dt><dd>{selected.id === "node24" ? "26.x" : "24.x"}에 영향 없음</dd></div>{/if}</dl>{:else if selected.kind === "mise"}<p>mise 실행 파일을 새 버전으로 갱신합니다.</p><dl><div><dt>설치된 도구</dt><dd>기존 버전 유지</dd></div><div><dt>외부 플러그인</dt><dd>별도 업데이트</dd></div></dl>{:else}<p>Flutter 플러그인의 소스를 갱신합니다.</p><dl><div><dt>소스 변경</dt><dd class="rd-mono">{selected.from} → {selected.to}</dd></div><div><dt>설치된 도구</dt><dd>기존 버전 유지</dd></div></dl>{/if}</section>
						{#if completed.includes(selected.id)}<div class="latest-complete">적용을 마쳤어요. 왼쪽에서 다음 항목을 선택하세요.</div>{/if}
					{/if}</main>
				</div><footer class="latest-footer"><span>{checked}</span><span>새 버전은 계열별로 확인합니다.</span></footer>
			</div>
		{/if}
	</div>
	<div class="study-caption"><a href={reference.url} target="_blank" rel="noreferrer">참고: {reference.app} ↗</a><span>{reference.idea}</span><small>{reference.tradeoff}</small></div>
	{#if message}<div class="rd-toast" role="status">{message}<button class="rd-icon" aria-label="알림 닫기" onclick={() => message = ""}>×</button></div>{/if}
</div>
<PrototypeSwitcher {variant} variants={["E", "F", "G"]} onchange={reset} onreset={() => reset()} />

<style>
	.reference-study { --rd-ink: #26292d; --rd-muted: #656a72; --rd-line: #dfe1e6; --rd-soft: #f4f5f7; --rd-accent: #2466c5; --rd-selected: #e3edfc; --rd-surface: #fff; height: 100%; overflow: auto; background: #e9eaee; color: var(--rd-ink); font: 13px/1.5 -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif; color-scheme: light; }
	.reference-study button, .reference-study input, .reference-study select { font: inherit; color: inherit; }
	.reference-study button, .reference-study summary, .reference-study a { -webkit-tap-highlight-color: transparent; }
	.reference-study button:focus-visible, .reference-study input:focus-visible, .reference-study summary:focus-visible, .reference-study select:focus-visible, .reference-study a:focus-visible { outline: 2px solid var(--rd-accent); outline-offset: 3px; }
	.reference-study p { color: var(--rd-muted); font-size: 12px; margin-top: 5px; }
	.reference-study h1 { font-size: 14px; font-weight: 600; letter-spacing: -.3px; }
	.reference-study h2 { font-size: 21px; font-weight: 650; letter-spacing: -.5px; }
	.reference-study h3 { font-size: 13px; }
	.reference-study a { color: var(--rd-accent); text-decoration: none; }
	.reference-study a:hover { text-decoration: underline; }
	.reference-study small { color: var(--rd-muted); font-size: 11px; }
	.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); }
	.study-topline { display: flex; justify-content: space-between; align-items: center; gap: 15px; padding: 16px 25px; color: #59616b; font-size: 11px; }
	.study-stage { min-height: 660px; height: calc(100% - 182px); padding: 5px 30px 15px; display: flex; justify-content: center; }
	.study-caption { display: flex; align-items: center; justify-content: center; flex-wrap: wrap; gap: 8px 18px; padding: 10px 20px 94px; text-align: center; font-size: 12px; }
	.study-caption a { font-weight: 600; }
	.study-caption small { width: 100%; }
	.rd-brand { display: flex; align-items: center; gap: 9px; font-size: 14px; white-space: nowrap; letter-spacing: -.4px; }
	.rd-brand img { width: 25px; height: 25px; border-radius: 5px; }
	.rd-mono { font: 12px/1.5 ui-monospace, "SFMono-Regular", monospace; font-variant-numeric: tabular-nums; }
	.rd-mark { display: grid; place-items: center; width: 38px; height: 38px; flex: none; border-radius: 10px; background: #e8ebf1; color: #455066; font: 600 14px ui-monospace, monospace; }
	.mark-node { background: #e3efdf; color: #365d2b; } .mark-python { background: #e1eafb; color: #2e5388; } .mark-bun { background: #f3e9d8; color: #71562f; } .mark-rust { background: #f4e5dd; color: #8a492b; } .mark-flutter { background: #dcedf9; color: #24617b; }
	.rd-action { border: 1px solid #d1d8e3; border-radius: 6px; background: #fff; padding: 5px 13px; min-height: 31px; color: var(--rd-accent) !important; font-size: 12px !important; white-space: nowrap; }
	.rd-action:hover { background: var(--rd-selected); border-color: var(--rd-accent); }
	.rd-icon { display: inline-flex; align-items: center; justify-content: center; padding: 7px; min-width: 32px; min-height: 32px; border: 0; border-radius: 6px; background: transparent; }
	.rd-icon:hover { background: #0000000a; }
	.rd-link { border: 0; background: none; color: var(--rd-accent) !important; font-size: 12px !important; padding: 5px 0; min-height: 30px; }
	.rd-link:hover:enabled { text-decoration: underline; }
	.rd-done { font-size: 11px; color: var(--rd-muted); white-space: nowrap; }
	.rd-dot { width: 6px; height: 6px; display: inline-block; flex: none; border-radius: 50%; background: var(--rd-accent); }
	.rd-search { display: block; }
	.rd-search input { width: 100%; min-width: 0; border: 1px solid transparent; border-radius: 7px; background: #00000006; padding: 7px 10px; color: var(--rd-ink); font-size: 12px; }
	.rd-search input::placeholder { color: var(--rd-muted); }
	.rd-empty { padding: 28px 12px; }
	.rd-settings { padding: 25px; }
	.rd-settings h2 { margin-bottom: 25px; }
	.rd-settings > label, .rd-settings > div { display: flex; align-items: center; justify-content: space-between; gap: 20px; padding: 18px 0; border-bottom: 1px solid var(--rd-line); }
	.rd-settings strong { font-size: 12px; font-weight: 600; }
	.rd-settings small { display: block; margin-top: 6px; }
	.rd-settings input { accent-color: var(--rd-accent); }
	.explorer-window { display: flex; width: 1060px; max-width: 100%; height: 100%; min-height: 590px; border: 1px solid #c9ccd3; border-radius: 13px; overflow: hidden; background: var(--rd-surface); box-shadow: 0 14px 44px #24293616; }
	.explorer-rail { width: 230px; flex: none; padding: 21px 12px 15px; display: flex; flex-direction: column; background: #f0f0f3; border-right: 1px solid var(--rd-line); }
	.explorer-rail .rd-brand { padding: 0 7px 24px; }
	.explorer-rail .rd-search { padding: 0 3px 18px; }
	.explorer-updates, .explorer-settings, .explorer-rail nav button { display: flex; align-items: center; gap: 9px; border: 0; border-radius: 6px; background: none; padding: 9px 10px; min-height: 35px; width: 100%; text-align: left; font-size: 12px !important; }
	.explorer-updates b { margin-left: auto; font-size: 11px; }
	.explorer-updates.chosen, .explorer-rail nav button.chosen, .explorer-settings.chosen { background: var(--rd-selected); color: #174b92; }
	.explorer-rail button:hover { background: #e5e7ec; }
	.rail-label { font-size: 11px !important; font-weight: 600 !important; color: var(--rd-muted); margin: 23px 10px 7px; letter-spacing: 0 !important; }
	.explorer-rail nav button { gap: 7px; }
	.explorer-rail .rail-version { color: var(--rd-muted); font-size: 10px; margin-left: auto; }
	.explorer-rail nav small { margin-left: auto; font-size: 10px; }
	.explorer-settings { margin-top: auto; }
	.explorer-main { flex: 1; min-width: 0; display: flex; flex-direction: column; }
	.explorer-toolbar { display: flex; align-items: center; gap: 12px; min-height: 64px; padding: 10px 24px; border-bottom: 1px solid var(--rd-line); }
	.explorer-toolbar > span { margin-left: auto; font-size: 11px; color: var(--rd-muted); }
	.explorer-main main { flex: 1; overflow: auto; padding: 22px 30px; }
	.explorer-notice { display: flex; align-items: center; gap: 10px; padding: 11px 14px; width: 100%; border: 1px solid #dce5f0; border-radius: 8px; background: #f4f7fc; text-align: left; font-size: 12px !important; }
	.explorer-notice > :last-child { margin-left: auto; }
	.explorer-heading { display: flex; align-items: center; justify-content: space-between; margin: 30px 0 25px; gap: 15px; }
	.explorer-heading h2 { font-size: 26px; }
	.explorer-heading .rd-mark { width: 48px; height: 48px; font-size: 19px; border-radius: 12px; }
	.explorer-versions { border: 1px solid var(--rd-line); border-radius: 8px; overflow: hidden; }
	.explorer-version { display: grid; grid-template-columns: minmax(95px,1fr) minmax(180px,1.7fr) auto; align-items: center; gap: 14px; padding: 16px; border-bottom: 1px solid var(--rd-line); font-size: 12px; }
	.explorer-version:last-child { border-bottom: 0; }
	.explorer-version > div:first-child small { display: block; }
	.version-description { display: flex; align-items: center; flex-wrap: wrap; gap: 6px; }
	.version-description strong, .version-description .added { color: var(--rd-accent); font-weight: 500; }
	.version-description small { background: var(--rd-soft); padding: 1px 4px; border-radius: 3px; font-size: 10px; }
	.version-arrow { color: var(--rd-muted); margin: 0 3px; }
	.explorer-info { margin-top: 32px; }
	.explorer-info label { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--rd-line); padding: 15px 0; font-size: 12px; }
	.explorer-info select { border: 1px solid var(--rd-line); border-radius: 5px; padding: 5px 8px; background: #fff; font-size: 12px; }
	.explorer-info p { font-size: 11px; margin-top: 12px; }
	.explorer-footer, .latest-footer { display: flex; justify-content: space-between; gap: 15px; padding: 12px 22px; font-size: 10px; color: var(--rd-muted); border-top: 1px solid var(--rd-line); }
	.study-F { --rd-accent: #5145be; --rd-selected: #ece9fb; background: #eae9ef; }
	.toolbox-window { width: 490px; max-width: 100%; border: 1px solid #d1cddc; border-radius: 13px; overflow: hidden; background: #f9f8fc; box-shadow: 0 14px 44px #34264220; display: flex; flex-direction: column; }
	.toolbox-header { display: flex; align-items: center; gap: 10px; padding: 19px 20px 15px; background: #eeebf5; }
	.toolbox-header > span { margin-left: auto; font-size: 11px; color: var(--rd-muted); }
	.toolbox-tabs { display: flex; align-items: stretch; gap: 20px; padding: 0 21px; background: #fff; border-bottom: 1px solid var(--rd-line); }
	.toolbox-tabs > button:not(.rd-icon) { border: 0; border-bottom: 2px solid transparent; background: none; padding: 12px 0 10px; font-size: 12px; }
	.toolbox-tabs > button.active { border-bottom-color: var(--rd-accent); color: var(--rd-accent); }
	.toolbox-tabs b { background: var(--rd-selected); color: var(--rd-accent); padding: 1px 5px; border-radius: 4px; font-size: 11px; margin-left: 3px; }
	.toolbox-tabs .rd-icon { margin-left: auto; }
	.toolbox-list { padding: 4px 21px 18px; overflow: auto; flex: 1; }
	.toolbox-section-title { display: flex; align-items: center; justify-content: space-between; color: var(--rd-muted); font-size: 11px; padding: 13px 0 3px; min-height: 38px; }
	.toolbox-tool { display: flex; align-items: flex-start; gap: 12px; padding: 15px 0; border-bottom: 1px solid #e8e6ef; }
	.toolbox-tool .rd-mark { width: 36px; height: 36px; border-radius: 8px; }
	.toolbox-tool-body { flex: 1; min-width: 0; }
	.toolbox-title { display: flex; align-items: center; gap: 7px; }
	.toolbox-tool h2 { font-size: 14px; letter-spacing: -.1px; }
	.toolbox-tool h2 small { margin-left: 6px; font-weight: 400; }
	.series-tag { color: var(--rd-muted); font-size: 11px; }
	.toolbox-version { color: var(--rd-muted); font-size: 11px; margin-top: 4px; }
	.toolbox-version > span { margin-inline: 5px; }
	.toolbox-tool .rd-action { background: var(--rd-accent); color: #fff !important; border-color: var(--rd-accent); padding: 4px 10px; min-height: 28px; margin-top: 3px; font-size: 11px !important; }
	.toolbox-tool .rd-action:hover { background: #403495; }
	.toolbox-tool .rd-done { padding-top: 5px; }
	.toolbox-tool summary { color: var(--rd-accent); padding: 5px 0 0; font-size: 11px; }
	.toolbox-version-options { display: grid; justify-items: start; gap: 5px; padding-top: 8px; color: var(--rd-muted); font-size: 11px; }
	.toolbox-version-options b { font-size: 11px; font-weight: 500; }
	.toolbox-tool p.toolbox-added { font-size: 11px; color: var(--rd-accent); }
	.toolbox-footer { display: flex; align-items: center; gap: 7px; font-size: 10px; color: var(--rd-muted); padding: 12px 21px; border-top: 1px solid var(--rd-line); background: #fff; }
	.toolbox-footer > span:last-child { margin-left: auto; }
	.study-G { background: #e8ecea; --rd-accent: #2d675d; --rd-selected: #dfeee6; }
	.latest-window { width: 980px; max-width: 100%; background: var(--rd-surface); border: 1px solid #cad3cf; border-radius: 12px; overflow: hidden; box-shadow: 0 14px 44px #22342a1a; display: flex; flex-direction: column; }
	.latest-header { display: flex; align-items: center; gap: 9px; padding: 16px 22px; border-bottom: 1px solid var(--rd-line); }
	.latest-header > div { margin-right: auto; }
	.latest-header p { font-size: 11px; margin-top: 1px; }
	.latest-body { flex: 1; min-height: 0; display: flex; }
	.latest-list { width: 300px; flex: none; padding: 18px 12px; background: #f0f2f1; border-right: 1px solid var(--rd-line); overflow: auto; }
	.latest-list .rd-search { padding: 0 5px; }
	.latest-item { display: flex; align-items: center; gap: 11px; border: 0; border-radius: 7px; background: none; width: 100%; text-align: left; padding: 13px 10px; }
	.latest-item.chosen { background: var(--rd-selected); }
	.latest-item:hover { background: #e4e9e6; }
	.latest-item > span:last-child { display: grid; gap: 4px; min-width: 0; }
	.latest-item strong { font-size: 12px; }
	.latest-item .rd-mono { font-size: 10px; color: var(--rd-muted); overflow-wrap: anywhere; }
	.latest-item small { font-weight: 400; }
	.latest-detail { flex: 1; min-width: 0; overflow: auto; padding: 30px; }
	.latest-detail-heading { display: flex; align-items: center; gap: 13px; padding-bottom: 25px; }
	.latest-detail-heading .rd-mark { width: 48px; height: 48px; font-size: 18px; }
	.latest-detail-heading h2 { font-size: 20px; }
	.latest-detail-heading h2 span { color: var(--rd-muted); font-size: 15px; font-weight: 400; }
	.latest-detail-heading > :last-child { margin-left: auto; }
	.latest-detail-heading p { font-size: 11px; }
	.latest-version-flow { display: flex; align-items: center; gap: 25px; padding: 23px 0; border-block: 1px solid var(--rd-line); }
	.latest-version-flow > div { display: grid; gap: 8px; }
	.latest-version-flow span { font-size: 11px; color: var(--rd-muted); }
	.latest-version-flow strong { font-size: 19px; font-weight: 500; overflow-wrap: anywhere; }
	.latest-version-flow > div:last-child strong { color: var(--rd-accent); }
	.latest-impact { padding-top: 28px; }
	.latest-impact > p { margin-top: 12px; line-height: 1.8; }
	.latest-impact dl { margin-top: 21px; }
	.latest-impact dl > div { display: flex; justify-content: space-between; gap: 20px; padding: 12px 0; border-bottom: 1px solid var(--rd-line); font-size: 12px; }
	.latest-impact dt { color: var(--rd-muted); }
	.latest-impact dd { text-align: right; }
	.latest-complete { color: var(--rd-accent); background: var(--rd-selected); padding: 13px; margin-top: 25px; border-radius: 6px; font-size: 12px; }
	.rd-toast { position: fixed; top: 16px; left: 50%; transform: translateX(-50%); z-index: 30; display: flex; align-items: center; gap: 14px; max-width: calc(100vw - 25px); padding: 8px 12px 8px 17px; background: #fff; border: 1px solid var(--rd-line); border-radius: 9px; box-shadow: 0 5px 25px #0002; font-size: 12px; }
	@media(max-width: 1050px) { .study-stage { padding-inline: 20px; } .explorer-rail { width: 200px; } .explorer-main main { padding: 20px; } .explorer-version { grid-template-columns: 1fr auto; gap: 6px 12px; } .explorer-version .version-description { grid-column: 1; grid-row: 2; } .explorer-version > :last-child { grid-column: 2; grid-row: 1 / 3; } .latest-list { width: 250px; } .latest-detail { padding: 24px; } .latest-version-flow { gap: 16px; } .latest-version-flow strong { font-size: 16px; } }
	@media(max-width: 720px) { .study-topline { padding-inline: 15px; font-size: 10px; } .study-sample { display: none; } .study-stage { padding-inline: 12px; height: auto; min-height: 0; } .explorer-window { min-height: 690px; } .explorer-rail { width: 155px; padding-inline: 8px; } .explorer-rail .rd-brand { font-size: 11px; gap: 5px; } .explorer-rail .rd-brand img { width: 20px; height: 20px; } .rail-version { display: none; } .explorer-rail nav small { font-size: 9px; } .explorer-main main { padding: 15px; } .explorer-toolbar { padding-inline: 15px; } .explorer-toolbar > span { display: none; } .explorer-toolbar .rd-icon { margin-left: auto; } .explorer-notice { padding: 10px; flex-wrap: wrap; } .explorer-heading { margin-block: 22px; } .explorer-heading .rd-mark { display: none; } .explorer-version { padding: 11px; } .explorer-footer { flex-wrap: wrap; gap: 3px; padding-inline: 15px; } .toolbox-window { height: 680px; } .latest-window { min-height: 740px; } .latest-body { display: block; } .latest-list { width: 100%; max-height: 250px; border-right: 0; border-bottom: 1px solid var(--rd-line); } .latest-item { padding-block: 9px; } .latest-list .rail-label { margin-top: 14px; } .latest-detail { padding: 23px; } .latest-detail-heading { flex-wrap: wrap; } .study-caption { padding-top: 17px; } .rd-settings { padding: 15px 0; } }
</style>
