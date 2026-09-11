<script lang="ts">
	let { variant, onchange, onreset, variants = ["A", "B", "C", "D"] }: { variant: string; onchange: (variant: string) => void; onreset: () => void; variants?: string[] } = $props();
	const labels: Record<string, string> = { A: "업데이트 모아보기", B: "어디서든 열기", C: "항상 펼쳐두기", D: "기존 UI 간소화", E: "Cork에서 착안", F: "Toolbox에서 착안", G: "Latest에서 착안" };
	function change(next: string) {
		const url = new URL(location.href);
		url.searchParams.set("variant", next);
		history.replaceState(null, "", url);
		onchange(next);
	}
	function cycle(direction: number) {
		change(variants[(variants.indexOf(variant) + direction + variants.length) % variants.length]);
	}
	function onkey(event: KeyboardEvent) {
		if (event.defaultPrevented || event.altKey || event.metaKey || event.ctrlKey) return;
		if ((event.target as HTMLElement)?.closest("input, textarea, select, [contenteditable], dialog")) return;
		if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
		event.preventDefault();
		cycle(event.key === "ArrowLeft" ? -1 : 1);
	}
</script>

<svelte:window onkeydown={onkey} />
{#if import.meta.env.DEV}
	<div class="prototype-switcher" aria-label="디자인 시안 비교">
		<span class="prototype-label">디자인 시안 <span>· 샘플 데이터</span></span>
		<button aria-label="이전 시안" onclick={() => cycle(-1)}>←</button>
		{#each variants as key}<button class:chosen={variant === key} aria-pressed={variant === key} onclick={() => change(key)}>{key}<span> {labels[key]}</span></button>{/each}
		<button aria-label="다음 시안" onclick={() => cycle(1)}>→</button>
		<button class="reset" onclick={onreset}>초기화</button>
	</div>
{/if}

<style>
	.prototype-switcher { position: fixed; z-index: 20; bottom: 18px; left: 50%; transform: translateX(-50%); display: flex; align-items: center; gap: 5px; max-width: calc(100vw - 24px); padding: 7px 10px; background: #252823; color: #fff; border: 1px solid #53554f; border-radius: 13px; box-shadow: 0 6px 24px #0002; white-space: nowrap; font-size: 12px; }
	.prototype-label { padding: 0 10px; color: #e2e5dd; font-size: 11px; }
	.prototype-label span { display: block; color: #b4b9ac; font-size: 10px; }
	button { display: inline-flex; gap: 5px; align-items: center; border: 0; border-radius: 7px; padding: 10px 12px; background: none; color: #e2e5dd; font-size: 12px; min-height: 36px; }
	button:hover { background: #3b4035; }
	button.chosen { background: #edf1e6; color: #252823; }
	button:focus-visible { outline: 2px solid #d2e5aa; outline-offset: 2px; }
	.reset { border-left: 1px solid #53554f; border-radius: 0; margin-left: 4px; }
	@media(max-width: 720px) { button span { display: none; } .prototype-label { padding: 0 4px; } button { padding: 9px 11px; } }
</style>
