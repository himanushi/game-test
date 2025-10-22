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
	chat_node.system_prompt = """You are a creative assistant that generates 10x10 pixel art using primitive shapes.

Canvas: 10x10 grid (coordinates: x=0-9, y=0-9)
Origin: Top-left is (0,0)

Color Mapping (Famicom 52 colors):
0=#ab0013(red), 1=#e7005b(pink), 2=#ff77b7, 3=#ffc7db, 4=#a70000, 5=#db2b00(orange), 6=#ff7763, 7=#ffbfb3
8=#7f0b00(brown), 9=#cb4f0f, a=#ff9b3b, b=#ffdbab, c=#432f00, d=#8b7300(brown), e=#f3bf3f(yellow), f=#ffe7a3
g=#004700(darkgreen), h=#009700(green), i=#83d313, j=#e3ffa3, k=#005100, l=#00ab00, m=#4fdf4B(green), n=#abf3bf
o=#003f17, p=#00933b, q=#58f898, r=#b3ffcf, s=#1b3f5f(darkblue), t=#00838b, u=#00ebdb(cyan), v=#9FFFF3
w=#271b8f(purple), x=#0073ef(blue), y=#3fbfff, z=#abe7ff, A=#0000ab, B=#233bef, C=#5f73ff(blue), D=#c7d7ff
E=#47009f, F=#8300f3, G=#a78Bfd, H=#d7cbff, I=#8f0077, J=#bf00bf, K=#f77Bff, L=#ffc7ff, M=#000000(black)
N=#757575(gray), O=#bcbcbc(lightgray), P=#ffffff(white)

Primitives:
- rect: {"shape":"rect", "x":X, "y":Y, "w":W, "h":H, "color":"C"}

Combine multiple rectangles to create objects."""
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

	# GBNFでJSON形式を定義（プリミティブ形式）
	var gbnf_grammar = """
root ::= obj
obj ::= "{" ws "\\"category\\"" ws ":" ws category ws "," ws "\\"primitives\\"" ws ":" ws primitives ws "}"
category ::= "\\"武器\\"" | "\\"装備\\"" | "\\"爆発物\\"" | "\\"回復アイテム\\""
primitives ::= "[" ws prim ws ("," ws prim ws)* "]"
prim ::= "{" ws "\\"shape\\"" ws ":" ws shape ws "," ws "\\"x\\"" ws ":" ws num ws "," ws "\\"y\\"" ws ":" ws num ws "," ws size ws "," ws "\\"color\\"" ws ":" ws color ws "}"
shape ::= "\\"rect\\""
size ::= ("\\"w\\"" ws ":" ws num ws "," ws "\\"h\\"" ws ":" ws num)
num ::= [0-9]
color ::= "\\"" [0-9a-zA-P] "\\""
ws ::= [ \\t\\n]*
"""

	# Samplerを設定してGrammarを適用
	var sampler = NobodyWhoSampler.new()
	sampler.use_grammar = true
	sampler.gbnf_grammar = gbnf_grammar  # カスタムGBNF文法を設定
	sampler.temperature = 0.0  # 決定的な出力
	chat_node.sampler = sampler

	# プロンプトを構築
	var prompt = """「%s」を10x10の矩形プリミティブで描いてください。

ルール:
- category: "武器", "装備", "爆発物", "回復アイテム"
- primitives: 矩形のリスト
  - shape: "rect"
  - x, y: 位置（0-9）
  - w, h: 幅と高さ（0-9）
  - color: ファミコン52色（0-9, a-z, A-P）

例:
剣 → {"category":"武器","primitives":[{"shape":"rect","x":4,"y":0,"w":2,"h":6,"color":"P"},{"shape":"rect","x":2,"y":6,"w":6,"h":1,"color":"N"},{"shape":"rect","x":4,"y":7,"w":2,"h":3,"color":"d"}]}
盾 → {"category":"装備","primitives":[{"shape":"rect","x":2,"y":1,"w":6,"h":7,"color":"d"},{"shape":"rect","x":3,"y":0,"w":4,"h":2,"color":"P"}]}

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
	# プリミティブからドット配列を生成
	if data.has("primitives"):
		var dots = generate_dots_from_primitives(data)
		data["dots"] = dots
		print("プリミティブから生成: primitives=", data.get("primitives"))
	# 構造的記述からドット配列を生成
	elif data.has("components"):
		var dots = generate_dots_from_structure(data)
		data["dots"] = dots
		print("構造的記述から生成: components=", data.get("components"))

	var dots_count = count_active_dots(data.get("dots", []))
	print("折り紙を生成: ドット数=", dots_count)

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


# ========================================
# プリミティブからドット配列を生成
# ========================================

# プリミティブデータからドット配列を生成
func generate_dots_from_primitives(data: Dictionary) -> Array:
	var dots = init_empty_dots()
	var primitives = data.get("primitives", [])

	for prim in primitives:
		draw_prim(dots, prim)

	return dots

# プリミティブを描画
func draw_prim(dots: Array, prim: Dictionary):
	var shape = prim.get("shape", "rect")

	match shape:
		"rect":
			draw_rect_prim(dots, prim)

# 矩形プリミティブを描画
func draw_rect_prim(dots: Array, prim: Dictionary):
	var x = prim.get("x", 0)
	var y = prim.get("y", 0)
	var w = prim.get("w", 1)
	var h = prim.get("h", 1)
	var color = prim.get("color", "P")

	for dy in range(h):
		var row_idx = y + dy
		if row_idx < 0 or row_idx >= 10:
			continue

		var row = dots[row_idx]
		var chars = []

		for i in range(10):
			if i >= x and i < x + w:
				chars.append(color)
			else:
				chars.append(row[i] if i < row.length() else "-")

		dots[row_idx] = "".join(chars)

# ========================================
# 構造的記述からドット配列を生成
# ========================================

# 構造データからドット配列を生成（メイン関数）
func generate_dots_from_structure(data: Dictionary) -> Array:
	var dots = init_empty_dots()
	var components = data.get("components", [])

	var y_offset = 0
	for comp in components:
		draw_component(dots, comp, y_offset)
		# 次のコンポーネントのためにY位置を進める
		var comp_height = comp.get("height", comp.get("length", 1))
		y_offset += comp_height

	return dots

# 空の10x10ドット配列を初期化
func init_empty_dots() -> Array:
	var dots = []
	for i in range(10):
		dots.append("----------")
	return dots

# コンポーネントを描画
func draw_component(dots: Array, comp: Dictionary, y_start: int):
	var comp_type = comp.get("type", "")
	var color = comp.get("color", "P")

	match comp_type:
		"blade":
			draw_blade(dots, comp, y_start, color)
		"crossguard":
			draw_crossguard(dots, comp, y_start, color)
		"handle":
			draw_handle(dots, comp, y_start, color)
		"head":
			draw_head(dots, comp, y_start, color)
		"shaft":
			draw_shaft(dots, comp, y_start, color)
		"body":
			draw_body(dots, comp, y_start, color)
		"top", "bottom":
			draw_horizontal_bar(dots, comp, y_start, color)
		"left", "right":
			draw_vertical_bar(dots, comp, y_start, color)

# 刃を描画（中央の縦長矩形）
func draw_blade(dots: Array, comp: Dictionary, y_start: int, color: String):
	var length = comp.get("length", 5)
	var width = comp.get("width", 1)
	var x_center = 5 - int(width / 2.0)

	for y in range(min(length, 10 - y_start)):
		if y_start + y >= 10:
			break
		var row = dots[y_start + y]
		row = set_dots_in_row(row, x_center, width, color)
		dots[y_start + y] = row

# 鍔を描画（横長バー）
func draw_crossguard(dots: Array, comp: Dictionary, y_start: int, color: String):
	var width = comp.get("width", 5)
	var height = comp.get("height", 1)
	var x_start = 5 - int(width / 2.0)

	for y in range(min(height, 10 - y_start)):
		if y_start + y >= 10:
			break
		var row = dots[y_start + y]
		row = set_dots_in_row(row, x_start, width, color)
		dots[y_start + y] = row

# 柄を描画
func draw_handle(dots: Array, comp: Dictionary, y_start: int, color: String):
	var length = comp.get("length", 2)
	var width = comp.get("width", 2)
	var x_center = 5 - int(width / 2.0)

	for y in range(min(length, 10 - y_start)):
		if y_start + y >= 10:
			break
		var row = dots[y_start + y]
		row = set_dots_in_row(row, x_center, width, color)
		dots[y_start + y] = row

# 頭部を描画（斧の刃など）
func draw_head(dots: Array, comp: Dictionary, y_start: int, color: String):
	var width = comp.get("width", 4)
	var height = comp.get("height", 3)
	var x_start = 5 - int(width / 2.0)

	for y in range(min(height, 10 - y_start)):
		if y_start + y >= 10:
			break
		var row = dots[y_start + y]
		row = set_dots_in_row(row, x_start, width, color)
		dots[y_start + y] = row

# 軸を描画（槍の柄など）
func draw_shaft(dots: Array, comp: Dictionary, y_start: int, color: String):
	draw_blade(dots, comp, y_start, color)  # 刃と同じロジック

# 本体を描画
func draw_body(dots: Array, comp: Dictionary, y_start: int, color: String):
	draw_head(dots, comp, y_start, color)  # 頭部と同じロジック

# 横バーを描画
func draw_horizontal_bar(dots: Array, comp: Dictionary, y_start: int, color: String):
	draw_crossguard(dots, comp, y_start, color)

# 縦バーを描画
func draw_vertical_bar(dots: Array, comp: Dictionary, y_start: int, color: String):
	draw_blade(dots, comp, y_start, color)

# 行の指定範囲にドットを設定
func set_dots_in_row(row: String, x_start: int, width: int, color: String) -> String:
	var chars = []
	for i in range(10):
		if i >= x_start and i < x_start + width:
			chars.append(color)
		else:
			chars.append(row[i] if i < row.length() else "-")
	return "".join(chars)

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
