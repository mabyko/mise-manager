<script lang="ts">
	import { state } from "../core/state.svelte";
	import { clearLogs } from "../features/logs";
</script>

<div class="page-head">
	<h1>Logs</h1>
	<div class="page-actions">
		<button class="btn" onclick={clearLogs}>Clear Logs</button>
	</div>
</div>

<section class="panel">
	<section class="log-card">
		<pre>{state.logs.join("\n") || "로그가 없습니다."}</pre>
	</section>
</section>
