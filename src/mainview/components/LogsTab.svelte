<script lang="ts">
	import { state } from "../core/state.svelte";
</script>

<section class="panel">
	<section class="log-card">
		<pre>{state.logs.join("\n") || "로그가 없습니다."}</pre>
	</section>
</section>
