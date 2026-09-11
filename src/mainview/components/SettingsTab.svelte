<script lang="ts">
	import { showTray, connection } from "../core/runtime.svelte";
	import { settings, setSetting, type Settings } from "../core/settings.svelte";
</script>

<div class="page-head"><div><h1>설정</h1><p class="page-subtitle">변경 사항은 이 기기에 자동으로 저장됩니다</p></div></div>
<div class="settings-page">
	<section class="panel">
		<h2>업데이트 확인</h2>
		<label class="setting-row"><span><strong>앱을 열 때 확인</strong><span>mise, 설치된 도구의 각 major 계열, 외부 플러그인을 확인합니다.</span></span><input type="checkbox" checked={settings.checkOnStartup} onchange={e => setSetting("checkOnStartup", e.currentTarget.checked)} /></label>
		<label class="setting-row" for="check-interval"><span><strong>자동 확인 주기</strong><span>앱이 실행 중이면 창을 닫아도 확인합니다. 설치는 직접 선택합니다.</span></span><select id="check-interval" value={settings.checkIntervalHours} onchange={e => setSetting("checkIntervalHours", Number(e.currentTarget.value))}><option value={0}>수동으로만</option><option value={1}>1시간마다</option><option value={6}>6시간마다</option><option value={24}>24시간마다</option></select></label>
	</section>
	<section class="panel">
		<h2>도구 버전</h2>
		<label class="setting-row"><span><strong>업데이트 후 전역 기본값 전환</strong><span>현재 전역 버전과 같은 major를 업데이트할 때만 전환합니다. 다른 계열과 프로젝트 설정은 유지합니다.</span></span><input type="checkbox" checked={settings.switchGlobalAfterUpdate} onchange={e => setSetting("switchGlobalAfterUpdate", e.currentTarget.checked)} /></label>
		<label class="setting-row"><span><strong>프리릴리스 후보 표시</strong><span>정식 출시 전 버전은 별도 후보로 표시합니다.</span></span><input type="checkbox" checked={settings.showPrereleases} onchange={e => setSetting("showPrereleases", e.currentTarget.checked)} /></label>
		<p class="settings-note">기존 버전은 항상 보존합니다. 예를 들어 Node 26과 24가 설치되어 있으면 26.x와 24.x의 최신 안정 버전을 각각 확인합니다. 설치만 한 버전은 도구 목록에서 전역으로 선택하거나 프로젝트 설정에 지정할 수 있습니다.</p>
	</section>
	<section class="panel">
		<h2>화면</h2>
		<label class="setting-row"><span><strong>메뉴바 아이콘 표시</strong><span>메뉴바에서 도구와 업데이트를 빠르게 확인합니다.</span></span><input id="show-menu-bar-icon" type="checkbox" checked={settings.showMenuBarIcon} onchange={e => setSetting("showMenuBarIcon", e.currentTarget.checked)} /></label>
		<div class="setting-row"><span><strong>메뉴바 빠른 관리</strong><span>작은 창에서 도구와 업데이트를 확인합니다.</span></span><button class="btn" disabled={!settings.showMenuBarIcon} onclick={() => void showTray().catch(error => connection.error = String(error))}>메뉴바 창 열기</button></div>
		<p class="settings-note">창을 닫아도 앱은 계속 실행됩니다. Dock에서 다시 열거나 앱 메뉴의 종료를 선택할 수 있습니다.{#if settings.showMenuBarIcon} 메뉴바 아이콘을 우클릭해도 종료할 수 있습니다.{/if}</p>
		<label class="setting-row" for="theme"><span><strong>테마</strong><span>시스템 설정을 따르거나 직접 선택하세요.</span></span><select id="theme" value={settings.theme} onchange={e => setSetting("theme", e.currentTarget.value as Settings["theme"])}><option value="system">시스템 설정</option><option value="light">라이트</option><option value="dark">다크</option></select></label>
	</section>
	{#if settings.saveError}<p class="inline-error" role="alert">{settings.saveError}</p>{/if}
</div>
