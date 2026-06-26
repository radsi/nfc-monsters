extends Node

signal nfc_detected(tag_id)
signal nfc_write_success
signal nfc_write_error(error)
signal share_success
signal share_error(error)

var nfc_plugin
var _use_mock: bool = false

func _ready():
	if Engine.has_singleton("NFCPlugin"):
		nfc_plugin = Engine.get_singleton("NFCPlugin")
		nfc_plugin.connect("nfc_tag_detected", Callable(self, "_on_nfc_detected"))
		nfc_plugin.connect("nfc_write_success", Callable(self, "_on_write_success"))
		nfc_plugin.connect("nfc_write_error", Callable(self, "_on_write_error"))
	else:
		_use_mock = true

func _input(event):
	if not _use_mock:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _on_nfc_detected('{"name":"SpellHit", "level":0}')
			KEY_2: _on_nfc_detected('{"name":"SpellDefend", "level":0}')
			KEY_3: _on_nfc_detected('{"name":"SpellHealth", "level":0}')
			KEY_4: _on_nfc_detected('{"name":"SpellDiscount", "level":0}')
			KEY_5: _on_nfc_detected('{"name":"SpellSummon", "level":0}')
			KEY_T: Gamemanager.clear_game_state()
			KEY_R: Gamemanager.add_coins(10000);

func _on_scene_changed():
	if nfc_plugin:
		nfc_plugin.stopNFCReading()
	for conn in nfc_detected.get_connections():
		nfc_detected.disconnect(conn.callable)

func _on_write_success():
	emit_signal("nfc_write_success")

func _on_write_error(error):
	emit_signal("nfc_write_error", error)

func _on_nfc_detected(tag_id: String):
	emit_signal("nfc_detected", tag_id)

func write_nfc(data: String):
	if nfc_plugin == null:
		return
	nfc_plugin.enableWriteMode(data)

func cancel_write():
	if nfc_plugin:
		nfc_plugin.stopNFCReading()

func start_reading():
	if Engine.is_editor_hint():
		return
	if nfc_plugin:
		nfc_plugin.startNFCReading()

func stop_reading():
	if nfc_plugin:
		nfc_plugin.stopNFCReading()

func share_pdf(path: String):
	if nfc_plugin == null:
		emit_signal("share_error", "NFC plugin not available")
		return
	if nfc_plugin.has_method("sharePdf"):
		nfc_plugin.sharePdf(path)
		emit_signal("share_success")
	else:
		emit_signal("share_error", "sharePdf not available")
