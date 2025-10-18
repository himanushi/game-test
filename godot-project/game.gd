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
	llama.model_path = "res://models/qwen2-0_5b-instruct-q8_0.gguf"
	llama.n_predict = 200
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

	# JSON Schemaを定義（頂点座標ベース）
	var json_schema = {
		"type": "object",
		"properties": {
			"color": {
				"type": "string",
				"pattern": "^[0-9A-Fa-f]{3}$",
				"description": "折り紙の色（3桁Hex: RGB）"
			},
			"vertices": {
				"type": "array",
				"items": {
					"type": "array",
					"items": {"type": "number"},
					"minItems": 2,
					"maxItems": 2
				},
				"minItems": 3,
				"maxItems": 10,
				"description": "折り紙の形状を定義する頂点座標のリスト [[x1,y1], [x2,y2], ...]。座標は-100から100の範囲"
			}
		},
		"required": ["color", "vertices"]
	}

	var schema_string = JSON.stringify(json_schema)

	# より具体的なプロンプトでユーザー入力を反映
	var prompt = """あなたは折り紙ゲームのアシスタントです。ユーザーが「%s」というオブジェクトを要求しています。

このオブジェクトのイメージに最も合う「色」と「形状の頂点座標」を決定してください。

生成ルール：
- color: 3桁のHex形式（例: "F00"=赤, "0AF"=青, "0F0"=緑, "FF0"=黄, "F80"=橙）
- vertices: そのオブジェクトの輪郭を表す3-10個の座標点 [[x,y], [x,y], ...]
  - 座標範囲: -100 ~ 100
  - 例: 三角形なら [[0,-80], [-70,60], [70,60]]
  - 例: 四角形なら [[-60,-60], [60,-60], [60,60], [-60,60]]
  - 複雑な形も可能（犬の顔、星、ハートなど）

オブジェクト: %s
このオブジェクトの典型的な色と形状を表現してください。""" % [user_input, user_input]

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
	var vertices_count = data.get("vertices", []).size() if data.has("vertices") else 0
	print("折り紙を生成: 頂点数=", vertices_count, ", 色=", data.get("color", "AAA"))

	# 新しい折り紙ノードを作成
	var origami = create_origami_sprite(data)

	# ランダムな位置に配置（画面下部のエリア内）
	var spawn_x = randf_range(200.0, 1000.0)
	var spawn_y = randf_range(350.0, 550.0)
	origami.position = Vector2(spawn_x, spawn_y)

	# コンテナに追加
	origami_container.add_child(origami)
	origami_objects.append(origami)

	# クリックイベントを追加（削除できるように）
	setup_origami_interaction(origami, data)

	# 折り紙アニメーションを開始
	animate_origami_creation(origami)

	print("配置済みオブジェクト数: ", origami_objects.size())

func setup_origami_interaction(origami: Node2D, data: Dictionary):
	# RigidBody2D用の当たり判定を追加
	var collision = CollisionPolygon2D.new()
	var vertices_data = data.get("vertices", [])
	var vertices = parse_vertices(vertices_data)

	# デフォルト形状（頂点が不正な場合）
	if vertices.size() < 3:
		vertices = PackedVector2Array([
			Vector2(0, -60),
			Vector2(-60, 60),
			Vector2(60, 60)
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

	# 頂点座標を取得
	var vertices_data = data.get("vertices", [])
	var vertices = parse_vertices(vertices_data)

	# デフォルト形状（頂点が不正な場合）
	if vertices.size() < 3:
		vertices = PackedVector2Array([
			Vector2(0, -60),
			Vector2(-60, 60),
			Vector2(60, 60)
		])

	# 影
	var shadow = Polygon2D.new()
	shadow.polygon = vertices
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(8, 8)
	sprite_node.add_child(shadow)

	# メインの折り紙
	var polygon = Polygon2D.new()
	polygon.polygon = vertices
	polygon.color = color
	sprite_node.add_child(polygon)

	# 折り目を表現（中心から各頂点への線）
	var darker_color = color.darkened(0.3)
	for i in range(min(vertices.size(), 6)):  # 最大6本まで
		var fold = Line2D.new()
		fold.add_point(Vector2(0, 0))
		fold.add_point(vertices[i])
		fold.width = 2.0
		fold.default_color = darker_color
		sprite_node.add_child(fold)

	# ハイライト（中央に小さなハイライト）
	var highlight = Polygon2D.new()
	var highlight_points = PackedVector2Array()
	for i in range(8):
		var angle = (i * 2 * PI / 8)
		highlight_points.append(Vector2(cos(angle) * 15, sin(angle) * 15 - 20))
	highlight.polygon = highlight_points
	highlight.color = Color(1, 1, 1, 0.3)
	sprite_node.add_child(highlight)

	# 縁取り
	var outline = Line2D.new()
	for point in vertices:
		outline.add_point(point)
	outline.add_point(vertices[0])
	outline.width = 3.0
	outline.default_color = Color(0.2, 0.2, 0.2, 0.6)
	sprite_node.add_child(outline)

	return sprite_node

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
