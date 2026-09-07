<script lang="ts">
	import { state } from "../core/state.svelte";
	import { clearLogs } from "../features/logs";
</script>

<div class="page-head">
	<div><h1>작업 기록</h1><p class="page-subtitle">버전 확인과 실행 결과를 확인합니다</p></div>
	<div class="page-actions">
		<button class="btn" onclick={clearLogs}>기록 지우기</button>
	</div>
</div>

<section class="panel">
	<section class="log-card">
		<pre>{state.logs.join("\n") || "로그가 없습니다."}</pre>
	</section>
</section>
