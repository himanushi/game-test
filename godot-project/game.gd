extends Node2D

# 折り紙パズル - メインゲームスクリプト
# プレイヤーがテキストを入力すると、LLMがJSONを生成し、折り紙オブジェクトが出現

var llama: GDLlama
var input_field: LineEdit
var generate_button: Button
var status_label: Label
var json_display: RichTextLabel
var origami_container: Node2D

var is_generating = false
var generated_json_data: Dictionary = {}
var current_json_text: String = ""
var origami_objects: Array = []  # 配置済みオブジェクトのリスト
var next_spawn_x: float = 600.0  # 次のスポーン位置

func _ready():
	print("==================================================")
	print("折り紙パズルゲーム起動")
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

	# GDLlamaノードを作成
	llama = GDLlama.new()
	add_child(llama)

	# モデル設定
	llama.model_path = "res://models/Qwen2.5-3B-Instruct-Q8_0.gguf"
	llama.n_predict = 200  # 5x5ドット配列生成に十分な長さ
	llama.temperature = 0.0  # 決定的な出力
	# NOTE: seedプロパティはGDLlamaに存在しない
	llama.should_output_prompt = false
	llama.should_output_special = false

	# シグナル接続
	if llama.generate_text_updated.connect(_on_llm_text_updated) == OK:
		print("✅ シグナル接続成功")
	else:
		print("❌ シグナル接続失敗")

	print("LLMモデル準備完了")
	print("利用可能なシグナル: ", llama.get_signal_list())

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

	# JSON Schemaを定義（5x5ドット文字列配列ベース）
	var json_schema = {
		"type": "object",
		"properties": {
			"color": {
				"type": "string",
				"pattern": "^[0-9A-Fa-f]{3}$",
				"description": "折り紙の色（3桁Hex: RGB）"
			},
			"dots": {
				"type": "array",
				"items": {
					"type": "string",
					"pattern": "^[01]{5}$"
				},
				"minItems": 5,
				"maxItems": 5,
				"description": "5x5のドットパターン。各行は5文字の文字列で、'1'が塗りつぶし、'0'が空白を表す"
			}
		},
		"required": ["color", "dots"]
	}

	var schema_string = JSON.stringify(json_schema)

	# より具体的なプロンプトでユーザー入力を反映
	var prompt = """5x5ドットで「%s」を描いてください。

ルール:
- color: 3桁Hex (例: F00=赤, 0AF=青, 0F0=緑, FF0=黄, 888=灰)
- dots: 5行の文字列配列。各行は5文字。1=塗りつぶし、0=空白

例:
ハート → {"color":"F00","dots":["01010","11111","11111","01110","00100"]}

家 → {"color":"840","dots":["00100","01110","01110","01110","11111"]}

剣 → {"color":"AAA","dots":["00100","00100","01110","01110","00100"]}

「%s」:""" % [user_input, user_input]

	print("プロンプト: ", prompt)
	print("スキーマ: ", schema_string)

	# JSON生成開始
	current_json_text = ""
	llama.run_generate_text(prompt, "", schema_string)
	print("run_generate_text() 呼び出し完了")

func _on_llm_text_updated(new_text: String):
	print("LLM更新: '", new_text, "' (長さ: ", new_text.length(), ")")
	current_json_text += new_text

	# リアルタイムでJSON表示
	json_display.text = "[b]生成中のJSON:[/b]\n\n[code]" + current_json_text + "[/code]"

	# 生成完了チェック
	if new_text == "":
		print("生成完了を検知")
		_on_generation_complete()
	else:
		print("現在のJSON長: ", current_json_text.length())

func _on_generation_complete():
	print("生成完了")
	print("JSON: ", current_json_text)

	# JSONパース
	var json_start = current_json_text.find("{")
	var json_end = current_json_text.rfind("}") + 1

	if json_start == -1 or json_end <= json_start:
		status_label.text = "❌ JSON生成に失敗しました"
		_reset_generation()
		return

	var json_str = current_json_text.substr(json_start, json_end - json_start)

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
		print("❌ JSONパースエラー")
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

# ドット数をカウント
func count_active_dots(dots: Array) -> int:
	var count = 0
	for row in dots:
		if row is String:
			# 文字列形式 "0000110000" の場合
			for i in range(row.length()):
				if row[i] == "1":
					count += 1
		elif row is Array:
			# 配列形式（後方互換性）
			for dot in row:
				if dot:
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

	# 色を取得（3桁Hex）
	var color_hex = data.get("color", "AAA")
	var color = hex3_to_color(color_hex)

	# ドット配列を取得
	var dots_data = data.get("dots", [])

	# デフォルトドットパターン（データが不正な場合）
	if dots_data.size() != 5:
		dots_data = create_default_dots()

	var dot_size = 12.0  # 各ドットのサイズ（5x5なので適度なサイズ）
	var dot_spacing = 15.0  # ドット間の間隔
	var offset_x = -30.0  # 中心からのオフセット
	var offset_y = -30.0

	# 影用のコンテナ
	var shadow_container = Node2D.new()
	shadow_container.position = Vector2(4, 4)
	sprite_node.add_child(shadow_container)

	# メインのドット描画
	var dots_container = Node2D.new()
	sprite_node.add_child(dots_container)

	# 5x5のドットを描画
	for row_idx in range(5):
		if row_idx >= dots_data.size():
			break
		var row = dots_data[row_idx]

		for col_idx in range(5):
			var should_draw = false

			# 文字列形式 "0000110000" の場合
			if row is String:
				if col_idx < row.length() and row[col_idx] == "1":
					should_draw = true
			# 配列形式（後方互換性）
			elif row is Array:
				if col_idx < row.size() and row[col_idx]:
					should_draw = true

			if should_draw:
				var x = offset_x + col_idx * dot_spacing
				var y = offset_y + row_idx * dot_spacing

				# 影
				var shadow_dot = create_dot_rect(x, y, dot_size, Color(0, 0, 0, 0.3))
				shadow_container.add_child(shadow_dot)

				# メインドット
				var dot = create_dot_rect(x, y, dot_size, color)
				dots_container.add_child(dot)

	# ハイライト効果（中央上部に小さな光沢）
	var highlight = create_dot_rect(offset_x + 20, offset_y + 10, dot_size * 1.5, Color(1, 1, 1, 0.4))
	dots_container.add_child(highlight)

	return sprite_node

# ドット用の矩形を作成
func create_dot_rect(x: float, y: float, size: float, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = Vector2(x, y)
	rect.size = Vector2(size, size)
	rect.color = color
	return rect

# デフォルトのドットパターン（矩形）
func create_default_dots() -> Array:
	var default_pattern = []
	for i in range(5):
		var row_str = ""
		for j in range(5):
			# 外側1マス以外を'1'
			if i >= 1 and i < 4 and j >= 1 and j < 4:
				row_str += "1"
			else:
				row_str += "0"
		default_pattern.append(row_str)
	return default_pattern

# ドット配列の外接矩形を取得
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

	for row_idx in range(min(dots.size(), 5)):
		var row = dots[row_idx]

		for col_idx in range(5):
			var is_active = false

			# 文字列形式 "0000110000" の場合
			if row is String:
				if col_idx < row.length() and row[col_idx] == "1":
					is_active = true
			# 配列形式（後方互換性）
			elif row is Array:
				if col_idx < row.size() and row[col_idx]:
					is_active = true

			if is_active:
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

# 頂点配列をパース
func parse_vertices(vertices_data: Array) -> PackedVector2Array:
	var vertices = PackedVector2Array()

	for vertex in vertices_data:
		if vertex is Array and vertex.size() >= 2:
			var x = float(vertex[0])
			var y = float(vertex[1])
			vertices.append(Vector2(x, y))

	return vertices

# 3桁Hex文字列をColorに変換
func hex3_to_color(hex: String) -> Color:
	hex = hex.strip_edges().trim_prefix("#")
	if hex.length() != 3:
		return Color(0.8, 0.8, 0.8)  # デフォルト色

	# 3桁Hexを6桁に拡張（F00 -> FF0000）
	var r = ("0x" + hex.substr(0, 1) + hex.substr(0, 1)).hex_to_int() / 255.0
	var g = ("0x" + hex.substr(1, 1) + hex.substr(1, 1)).hex_to_int() / 255.0
	var b = ("0x" + hex.substr(2, 1) + hex.substr(2, 1)).hex_to_int() / 255.0

	return Color(r, g, b)

# 折り目の線を生成
func create_fold_lines(shape_name: String) -> Array:
	var lines = []
	var size = 80.0

	match shape_name:
		"三角":
			# 中心から頂点への線
			lines.append([Vector2(0, 0), Vector2(0, -size * 0.75)])
		"四角":
			# 対角線
			lines.append([Vector2(-size * 0.5, 0), Vector2(size * 0.5, 0)])
			lines.append([Vector2(0, -size * 0.7), Vector2(0, size * 0.7)])
		"五角形", "六角形":
			# 中心から各頂点への線
			var n = 5 if shape_name == "五角形" else 6
			for i in range(n):
				var angle = -PI/2 + (i * 2 * PI / n)
				lines.append([Vector2(0, 0), Vector2(cos(angle) * size * 0.6, sin(angle) * size * 0.6)])
		"円":
			# 十字の折り目
			lines.append([Vector2(-size * 0.7, 0), Vector2(size * 0.7, 0)])
			lines.append([Vector2(0, -size * 0.7), Vector2(0, size * 0.7)])
		"星":
			# 中心から内側の頂点への線
			for i in range(5):
				var angle = -PI/2 + (i * 2 * PI / 5)
				lines.append([Vector2(0, 0), Vector2(cos(angle) * size * 0.3, sin(angle) * size * 0.3)])

	return lines

# ハイライト部分（光沢）を生成
func get_highlight_points(shape_name: String) -> PackedVector2Array:
	var size = 80.0

	match shape_name:
		"三角":
			return PackedVector2Array([
				Vector2(-10, -size * 0.5),
				Vector2(10, -size * 0.5),
				Vector2(5, -size * 0.3),
				Vector2(-5, -size * 0.3)
			])
		"四角":
			return PackedVector2Array([
				Vector2(-size * 0.4, -size * 0.7),
				Vector2(size * 0.2, -size * 0.7),
				Vector2(size * 0.1, -size * 0.4),
				Vector2(-size * 0.3, -size * 0.4)
			])
		_:
			# その他の形状は小さな円形のハイライト
			var points = PackedVector2Array()
			for i in range(8):
				var angle = (i * 2 * PI / 8)
				points.append(Vector2(cos(angle) * 15, sin(angle) * 15 - size * 0.4))
			return points

func get_origami_color(color_name: String) -> Color:
	match color_name:
		"赤": return Color(0.9, 0.2, 0.2)
		"青": return Color(0.2, 0.5, 0.9)
		"緑": return Color(0.3, 0.8, 0.3)
		"黄": return Color(0.95, 0.85, 0.2)
		"紫": return Color(0.7, 0.3, 0.8)
		"橙": return Color(0.95, 0.6, 0.2)
		"白": return Color(0.95, 0.95, 0.95)
		"黒": return Color(0.2, 0.2, 0.2)
		"灰": return Color(0.6, 0.6, 0.6)
		_: return Color(0.8, 0.8, 0.8)

func get_shape_points(shape_name: String) -> PackedVector2Array:
	var size = 80.0  # サイズを大きく

	match shape_name:
		"三角":
			return PackedVector2Array([
				Vector2(0, -size * 0.75),
				Vector2(-size * 0.65, size * 0.6),
				Vector2(size * 0.65, size * 0.6)
			])
		"四角":
			# ひし形風に
			return PackedVector2Array([
				Vector2(0, -size),
				Vector2(size * 0.7, 0),
				Vector2(0, size),
				Vector2(-size * 0.7, 0)
			])
		"五角形":
			var points = PackedVector2Array()
			for i in range(5):
				var angle = -PI/2 + (i * 2 * PI / 5)
				points.append(Vector2(cos(angle) * size, sin(angle) * size))
			return points
		"六角形":
			var points = PackedVector2Array()
			for i in range(6):
				var angle = -PI/6 + (i * 2 * PI / 6)  # 回転を調整
				points.append(Vector2(cos(angle) * size, sin(angle) * size))
			return points
		"円":
			var points = PackedVector2Array()
			for i in range(32):  # より滑らかに
				var angle = (i * 2 * PI / 32)
				points.append(Vector2(cos(angle) * size, sin(angle) * size))
			return points
		"星":
			var points = PackedVector2Array()
			for i in range(10):
				var angle = -PI/2 + (i * 2 * PI / 10)
				var radius = size if i % 2 == 0 else size * 0.4
				points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
			return points
		_:
			return get_shape_points("四角")

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
