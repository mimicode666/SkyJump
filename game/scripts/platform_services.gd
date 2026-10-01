extends RefCounted
## Native/local fallback and asynchronous Yandex Games bridge for Godot Web.
signal availability_changed
signal suspension_changed(suspended: bool)
signal reward_completed(granted: bool)
signal initialization_completed
var initializing := false
var status := "native"
var language := "ru"
var available := false
var bridge: JavaScriptObject
var _event_callback: JavaScriptObject
var _request_id := 0
var _pending := false

func initialize(qa: bool = false) -> void:
	if not OS.has_feature("web"): return
	initializing = true
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/yandex_bridge.js"), true)
	bridge = JavaScriptBridge.get_interface("SkyJumpPlatform")
	if bridge == null:
		status = "unavailable"
		initializing = false
		return
	_event_callback = JavaScriptBridge.create_callback(_on_event)
	bridge.listen(_event_callback)
	bridge.init(qa)

func _on_event(args: Array) -> void:
	if args.is_empty(): return
	var event = JSON.parse_string(str(args[0]))
	# SDK callbacks may fire synchronously. Deliver after the await is installed.
	if event is Dictionary: _deliver_event.call_deferred(event)

func _deliver_event(event: Dictionary) -> void:
	match event.get("type", ""):
		"state":
			status = str(event.get("status", "unavailable"))
			language = str(event.get("language", "ru"))
			available = bool(event.get("available", false))
			availability_changed.emit()
			if initializing and status in ["ready", "local", "unavailable"]:
				initializing = false
				initialization_completed.emit()
		"suspend": suspension_changed.emit(bool(event.get("value", false)))
		"reward":
			if _pending and int(event.get("id", -1)) == _request_id:
				_pending = false
				reward_completed.emit(bool(event.get("granted", false)))

func mark_ready() -> void:
	if bridge != null: bridge.markReady()

func set_gameplay(playing: bool) -> void:
	if bridge != null: bridge.setGameplay(playing)

func now_seconds() -> int:
	return int(bridge.nowSeconds()) if bridge != null else int(Time.get_unix_time_from_system())

func is_rewarded_available() -> bool:
	return available and not _pending

func request_rewarded(placement: String) -> bool:
	if not is_rewarded_available() or bridge == null: return false
	_pending = true
	_request_id += 1
	bridge.requestRewarded(_request_id, placement)
	return await reward_completed
