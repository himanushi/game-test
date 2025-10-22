extends Node2D

# 折り紙パズル - メインゲームスクリプト（NobodyWho版）
# プレイヤーがテキストを入力すると、LLMがJSONを生成し、折り紙オブジェクトが出現

var model_node: NobodyWhoModel
var chat_node: NobodyWhoChat
var input_field: LineEdit
var generate_button: Button
var status_label: Label
var json_display: RichTextLabel
var origami_container: Node2D

var is_generating = false
var generated_json_data: Dictionary = {}
var current_json_text: String = ""
var origami_objects: Array = []

# ファミコン52色のカラーマップ（0-9, a-z, A-P）
var fc_color_map: Dictionary = {
	"0": "#ab0013", "1": "#e7005b", "2": "#ff77b7", "3": "#ffc7db", "4": "#a70000",
	"5": "#db2b00", "6": "#ff7763", "7": "#ffbfb3", "8": "#7f0b00", "9": "#cb4f0f",
	"a": "#ff9b3b", "b": "#ffdbab", "c": "#432f00", "d": "#8b7300", "e": "#f3bf3f",
	"f": "#ffe7a3", "g": "#004700", "h": "#009700", "i": "#83d313", "j": "#e3ffa3",
	"k": "#005100", "l": "#00ab00", "m": "#4fdf4B", "n": "#abf3bf", "o": "#003f17",
	"p": "#00933b", "q": "#58f898", "r": "#b3ffcf", "s": "#1b3f5f", "t": "#00838b",
	"u": "#00ebdb", "v": "#9FFFF3", "w": "#271b8f", "x": "#0073ef", "y": "#3fbfff",
	"z": "#abe7ff", "A": "#0000ab", "B": "#233bef", "C": "#5f73ff", "D": "#c7d7ff",
	"E": "#47009f", "F": "#8300f3", "G": "#a78Bfd", "H": "#d7cbff", "I": "#8f0077",
	"J": "#bf00bf", "K": "#f77Bff", "L": "#ffc7ff", "M": "#000000", "N": "#757575",
	"O": "#bcbcbc", "P": "#ffffff"
}

func _ready():
	print("==================================================")
	print("折り紙パズルゲーム起動 (NobodyWho版)")
	print("==================================================")

	# UI要素を取得
	input_field = $UI/InputPanel/VBox/HBox/InputField
	generate_button = $UI/InputPanel/VBox/HBox/GenerateButton
	status_label = $UI/StatusLabel
	json_display = $UI/JsonDisplay
	origami_container = $OrigamiContainer

	# ボタンクリックイベント
	generate_button.pressed.connect(_on_generate_button_pressed)
	input_field.text_submitted.connect(_on_input_submitted)

	# NobodyWhoModelノードを作成
	model_node = NobodyWhoModel.new()
	model_node.name = "OrigamiModel"
	model_node.model_path = "res://models/gemma-3-12b-it.Q5_K_M.gguf"
	add_child(model_node)

	# NobodyWhoChatノードを作成
	chat_node = NobodyWhoChat.new()
	chat_node.name = "OrigamiChat"
	chat_node.model_node = model_node
	chat_node.system_prompt = """You are a creative assistant that generates pixel art patterns in JSON format.

Color Mapping (Famicom 52 colors):
0=#ab0013, 1=#e7005b, 2=#ff77b7, 3=#ffc7db, 4=#a70000, 5=#db2b00, 6=#ff7763, 7=#ffbfb3, 8=#7f0b00, 9=#cb4f0f
a=#ff9b3b, b=#ffdbab, c=#432f00, d=#8b7300, e=#f3bf3f, f=#ffe7a3, g=#004700, h=#009700, i=#83d313, j=#e3ffa3
k=#005100, l=#00ab00, m=#4fdf4B, n=#abf3bf, o=#003f17, p=#00933b, q=#58f898, r=#b3ffcf, s=#1b3f5f, t=#00838b
u=#00ebdb, v=#9FFFF3, w=#271b8f, x=#0073ef, y=#3fbfff, z=#abe7ff, A=#0000ab, B=#233bef, C=#5f73ff, D=#c7d7ff
E=#47009f, F=#8300f3, G=#a78Bfd, H=#d7cbff, I=#8f0077, J=#bf00bf, K=#f77Bff, L=#ffc7ff, M=#000000, N=#757575
O=#bcbcbc, P=#ffffff

Use character '-' (hyphen) for empty/transparent pixels."""
	add_child(chat_node)

	# シグナル接続
	chat_node.response_updated.connect(_on_response_updated)
	chat_node.response_finished.connect(_on_response_finished)

	# モデルをロード
	print("モデルをロード中...")
	status_label.text = "モデルを読み込み中..."
	chat_node.start_worker()

	# モデルロード完了待ち（少し待機）
	await get_tree().create_timer(2.0).timeout
	status_label.text = "準備完了！折り紙を作成しましょう"
	print("LLMモデル準備完了")

func _on_generate_button_pressed():
	_start_generation()

func _on_input_submitted(_text: String):
	_start_generation()

func _start_generation():
	if is_generating:
		return

	var user_input = input_field.text.strip_edges()

	if user_input == "":
		status_label.text = "⚠️ テキストを入力してください"
		return

	is_generating = true
	generate_button.disabled = true
	status_label.text = "折り紙を折っています... 🎨"

	print("--------------------------------------------------")
	print("生成開始: ", user_input)

	# GBNFでJSON形式を定義（10x10ドットパターン、カテゴリ付き）
	var gbnf_grammar = """
root ::= object
object ::= "{" ws "\\"category\\"" ws ":" ws category ws "," ws "\\"dots\\"" ws ":" ws dots ws "}"
category ::= "\\"武器\\"" | "\\"装備\\"" | "\\"爆発物\\"" | "\\"回復アイテム\\""
dots ::= "[" ws row ws ("," ws row ws){9} "]"
row ::= "\\"" char char char char char char char char char char "\\""
char ::= [-0-9a-zA-P]
ws ::= [ \\t\\n]*
"""

	# Samplerを設定してGrammarを適用
	var sampler = NobodyWhoSampler.new()
	sampler.use_grammar = true
	sampler.gbnf_grammar = gbnf_grammar  # カスタムGBNF文法を設定
	sampler.temperature = 0.0  # 決定的な出力
	chat_node.sampler = sampler

	# プロンプトを構築
	var prompt = """10x10ピクセルアートで「%s」を描いてください。

ルール:
- category: "武器", "装備", "爆発物", "回復アイテム"のいずれか
- dots: 10行の配列。各行は10文字の文字列
- 各文字: '-'=透明/空白, 0-9/a-z/A-P=ファミコン52色
- 適切な色を使って魅力的なピクセルアートを作成

例:
剣 → {"category":"武器","dots":["----PP----","----PP----","----PP----","----PP----","---PPPP---","--PPPPPP--","---PPPP---","----NN----","---NNNN---","----------"]}
ポーション → {"category":"回復アイテム","dots":["----------","----PP----","---PPPP---","--PP11PP--","--P1111P--","--P1111P--","--PP11PP--","--PPPPPP--","---PPPP---","----------"]}

「%s」を描いてください:""" % [user_input, user_input]

	print("プロンプト: ", prompt)
	print("GBNF Grammar設定完了")

	# 会話をリセットしてから生成開始
	chat_node.reset_context()
	current_json_text = ""

	# プロンプトを送信
	chat_node.say(prompt)

func _on_response_updated(token: String):
	current_json_text += token

	# リアルタイムでJSON表示
	json_display.text = "[b]生成中のJSON:[/b]\n\n[code]" + current_json_text + "[/code]"

func _on_response_finished(response: String):
	print("生成完了")
	print("完全なレスポンス: ", response)

	current_json_text = response

	# JSONパース
	var json_start = current_json_text.find("{")
	var json_end = current_json_text.rfind("}") + 1

	if json_start == -1 or json_end <= json_start:
		status_label.text = "❌ JSON生成に失敗しました"
		_reset_generation()
		return

	var json_str = current_json_text.substr(json_start, json_end - json_start)
	print("抽出したJSON: ", json_str)

	var json = JSON.new()
	var error = json.parse(json_str)

	if error == OK:
		generated_json_data = json.data
		print("✅ JSONパース成功: ", generated_json_data)

		# JSON表示を整形
		json_display.text = "[b]生成されたJSON:[/b]\n\n"
		json_display.text += "[code]" + JSON.stringify(generated_json_data, "  ") + "[/code]"

		status_label.text = "✅ 折り紙完成！"

		# 折り紙を生成
		create_origami(generated_json_data)
	else:
		print("❌ JSONパースエラー: ", error)
		status_label.text = "❌ JSON解析に失敗しました"

	_reset_generation()

func _reset_generation():
	is_generating = false
	generate_button.disabled = false
	current_json_text = ""

func create_origami(data: Dictionary):
	var dots_count = count_active_dots(data.get("dots", []))
	print("折り紙を生成: ドット数=", dots_count, ", 色=", data.get("color", "AAA"))

	# 新しい折り紙ノードを作成
	var origami = create_origami_sprite(data)

	# ランダムな位置に配置（画面下部のエリア内）
	var spawn_x = randf_range(150.0, 650.0)
	var spawn_y = randf_range(250.0, 450.0)
	origami.position = Vector2(spawn_x, spawn_y)

	# コンテナに追加
	origami_container.add_child(origami)
	origami_objects.append(origami)

	# クリックイベントを追加（削除できるように）
	setup_origami_interaction(origami, data)

	# 折り紙アニメーションを開始
	animate_origami_creation(origami)

	print("配置済みオブジェクト数: ", origami_objects.size())

# ファミコン色を取得（文字→Colorオブジェクト）
func get_fc_color(char: String) -> Color:
	var hex = fc_color_map.get(char, "#ffffff")
	return hex_to_color(hex)

# Hex文字列をColorに変換
func hex_to_color(hex: String) -> Color:
	hex = hex.strip_edges().trim_prefix("#")
	if hex.length() != 6:
		return Color(1.0, 1.0, 1.0)  # デフォルト白

	var r = ("0x" + hex.substr(0, 2)).hex_to_int() / 255.0
	var g = ("0x" + hex.substr(2, 2)).hex_to_int() / 255.0
	var b = ("0x" + hex.substr(4, 2)).hex_to_int() / 255.0

	return Color(r, g, b)

# ドット数をカウント（10x10対応）
func count_active_dots(dots: Array) -> int:
	var count = 0
	for row in dots:
		if row is String:
			# '-'以外はアクティブなドット
			for i in range(row.length()):
				if row[i] != "-":
					count += 1
	return count

func setup_origami_interaction(origami: Node2D, data: Dictionary):
	# RigidBody2D用の当たり判定を追加
	# ドット配列から外接する矩形を作成
	var dots_data = data.get("dots", [])
	var bounds = get_dots_bounds(dots_data)

	var collision = CollisionPolygon2D.new()
	var vertices = PackedVector2Array([
		Vector2(bounds.min_x, bounds.min_y),
		Vector2(bounds.max_x, bounds.min_y),
		Vector2(bounds.max_x, bounds.max_y),
		Vector2(bounds.min_x, bounds.max_y)
	])

	collision.polygon = vertices
	origami.add_child(collision)

	# RigidBody2Dのinput_eventシグナルでクリック検知
	if origami is RigidBody2D:
		origami.input_event.connect(func(viewport, event, shape_idx):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				# 左クリックで削除
				remove_origami(origami)
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				# 右クリックで情報表示
				var vertex_count = data.get("vertices", []).size()
				print("折り紙情報: 頂点数=", vertex_count, ", 色=", data.get("color", "AAA"))
		)

		# マウスホバー時のフィードバック
		origami.mouse_entered.connect(func():
			origami.modulate = Color(1.2, 1.2, 1.2, 1.0)  # 少し明るく
		)

		origami.mouse_exited.connect(func():
			origami.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 元に戻す
		)

func remove_origami(origami: Node2D):
	print("折り紙を削除")

	# フェードアウトアニメーション
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(origami, "scale", Vector2(0.0, 0.0), 0.3)
	tween.tween_property(origami, "modulate:a", 0.0, 0.3)
	tween.tween_property(origami, "rotation", deg_to_rad(180), 0.3)

	# アニメーション終了後に削除
	tween.finished.connect(func():
		origami_objects.erase(origami)
		origami.queue_free()
		print("配置済みオブジェクト数: ", origami_objects.size())
	)

func animate_origami_creation(origami: Node2D):
	# RigidBody2Dの場合、アニメーション中は物理を無効化
	if origami is RigidBody2D:
		origami.freeze = true

	# 初期状態を設定
	origami.scale = Vector2(0.1, 0.1)
	origami.rotation = deg_to_rad(180)
	origami.modulate.a = 0.0

	# Tweenでアニメーション
	var tween = create_tween()
	tween.set_parallel(true)  # 並列実行
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	# スケールアニメーション（折り紙が開く）
	tween.tween_property(origami, "scale", Vector2(1.0, 1.0), 0.8)

	# 回転アニメーション（紙が回転しながら開く）
	tween.tween_property(origami, "rotation", 0.0, 0.8)

	# 透明度アニメーション（徐々に現れる）
	tween.tween_property(origami, "modulate:a", 1.0, 0.6)

	# アニメーション終了後に物理を有効化
	tween.finished.connect(func():
		if origami is RigidBody2D:
			origami.freeze = false
			# 軽く跳ねる初期速度を与える
			origami.linear_velocity = Vector2(randf_range(-50, 50), -100)
			origami.angular_velocity = randf_range(-2, 2)
	)

	# 折り目を順番に描画するアニメーション
	animate_fold_lines(origami)

func animate_fold_lines(origami: Node2D):
	# 折り目の線を探す
	var fold_lines = []
	for child in origami.get_children():
		if child is Line2D and child.default_color.a > 0.5:  # 折り目の線
			fold_lines.append(child)

	# 各折り目を順番に表示
	var delay = 0.3
	for i in range(fold_lines.size()):
		var line = fold_lines[i]
		line.modulate.a = 0.0

		var tween = create_tween()
		tween.tween_interval(delay + i * 0.1)
		tween.tween_property(line, "modulate:a", 1.0, 0.3)

func create_origami_sprite(data: Dictionary) -> Node2D:
	var sprite_node = RigidBody2D.new()

	# 物理設定
	sprite_node.mass = 1.0
	sprite_node.gravity_scale = 0.5  # 軽い重力
	sprite_node.linear_damp = 2.0  # 空気抵抗
	sprite_node.angular_damp = 3.0  # 回転減衰

	# ドット配列を取得
	var dots_data = data.get("dots", [])

	# デフォルトドットパターン（データが不正な場合）
	if dots_data.size() != 10:
		dots_data = create_default_dots()

	var dot_size = 8.0  # 各ドットのサイズ（10x10なので少し小さく）
	var dot_spacing = 10.0  # ドット間の間隔
	var offset_x = -45.0  # 中心からのオフセット
	var offset_y = -45.0

	# 影用のコンテナ
	var shadow_container = Node2D.new()
	shadow_container.position = Vector2(3, 3)
	sprite_node.add_child(shadow_container)

	# メインのドット描画
	var dots_container = Node2D.new()
	sprite_node.add_child(dots_container)

	# 10x10のドットを描画
	for row_idx in range(10):
		if row_idx >= dots_data.size():
			break
		var row = dots_data[row_idx]

		for col_idx in range(10):
			if not (row is String):
				continue

			if col_idx >= row.length():
				continue

			var char = row[col_idx]

			# '-'は透明（描画しない）
			if char == "-":
				continue

			# ファミコン52色にマッピング
			var color = get_fc_color(char)

			var x = offset_x + col_idx * dot_spacing
			var y = offset_y + row_idx * dot_spacing

			# 影
			var shadow_dot = create_dot_rect(x, y, dot_size, Color(0, 0, 0, 0.3))
			shadow_container.add_child(shadow_dot)

			# メインドット
			var dot = create_dot_rect(x, y, dot_size, color)
			dots_container.add_child(dot)

	return sprite_node

# ドット用の矩形を作成
func create_dot_rect(x: float, y: float, size: float, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = Vector2(x, y)
	rect.size = Vector2(size, size)
	rect.color = color
	return rect

# デフォルトのドットパターン（10x10矩形、白色）
func create_default_dots() -> Array:
	var default_pattern = []
	for i in range(10):
		var row_str = ""
		for j in range(10):
			# 外側2マス以外を'P'（白）
			if i >= 2 and i < 8 and j >= 2 and j < 8:
				row_str += "P"
			else:
				row_str += "-"
		default_pattern.append(row_str)
	return default_pattern

# ドット配列の外接矩形を取得（10x10対応）
func get_dots_bounds(dots: Array) -> Dictionary:
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	var dot_spacing = 10.0
	var offset_x = -45.0
	var offset_y = -45.0
	var dot_size = 8.0

	var found_any = false

	for row_idx in range(min(dots.size(), 10)):
		var row = dots[row_idx]

		if not (row is String):
			continue

		for col_idx in range(min(row.length(), 10)):
			var char = row[col_idx]

			# '-'以外はアクティブなドット
			if char != "-":
				found_any = true
				var x = offset_x + col_idx * dot_spacing
				var y = offset_y + row_idx * dot_spacing
				min_x = min(min_x, x)
				max_x = max(max_x, x + dot_size)
				min_y = min(min_y, y)
				max_y = max(max_y, y + dot_size)

	# ドットが1つもない場合はデフォルト
	if not found_any:
		return {"min_x": -50.0, "max_x": 50.0, "min_y": -50.0, "max_y": 50.0}

	# マージンを追加
	var margin = 5.0
	return {
		"min_x": min_x - margin,
		"max_x": max_x + margin,
		"min_y": min_y - margin,
		"max_y": max_y + margin
	}


func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
