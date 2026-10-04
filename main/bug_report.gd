class_name BugReport
extends RefCounted
## Hlášení chyby: verze hry a údaje o zařízení (bez osobních údajů) a odkaz
## na formulář „Chyba ve hře“ v repozitáři na GitHubu, kam se údaje předvyplní.
## Text se zároveň zkopíruje do schránky (pro poslání jinou cestou).

const REPO_URL := "https://github.com/JendaNDT/Lemmings-2026"
const TEMPLATE := "chyba.yml"


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "?"))


## Údaje pro autora: verze, systém, grafika, obrazovka a `extra` (nastavení, mise).
static func diagnostics(extra := {}) -> String:
	var lines: Array[String] = [
		"Paperlings %s" % version(),
		"Systém: %s %s, zařízení %s" % [OS.get_name(), OS.get_version(), OS.get_model_name()],
		"Procesor: %s, %d vláken" % [OS.get_processor_name(), OS.get_processor_count()],
		"Grafika: %s %s, %s, API %s" % [RenderingServer.get_video_adapter_vendor(),
			RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_api_version()],
		"Obrazovka: %s, okno %s, měřítko %.2f" % [DisplayServer.screen_get_size(),
			DisplayServer.window_get_size(), DisplayServer.screen_get_scale()],
		"Jazyk: %s" % OS.get_locale(),
	]
	for key: String in extra:
		lines.append("%s: %s" % [key, str(extra[key])])
	return "\n".join(lines)


## Adresa nového hlášení s předvyplněnými údaji (pole `diagnostika` formuláře).
static func issue_url(text: String) -> String:
	return "%s/issues/new?template=%s&diagnostika=%s" % [REPO_URL, TEMPLATE, text.uri_encode()]


## Zkopíruje údaje do schránky a otevře formulář v prohlížeči. Vrací text údajů.
static func send(extra := {}) -> String:
	var text := diagnostics(extra)
	DisplayServer.clipboard_set(text)
	OS.shell_open(issue_url(text))
	return text
