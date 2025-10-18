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

	# JSON Schemaを定義
	var json_schema = {
		"type": "object",
		"properties": {
			"name": {
				"type": "string",
				"description": "オブジェクトの名前"
			},
			"category": {
				"type": "string",
				"enum": ["道具", "武器", "自然", "生き物", "食べ物", "その他"],
				"description": "オブジェクトのカテゴリ"
			},
			"color": {
				"type": "string",
				"enum": ["赤", "青", "緑", "黄", "紫", "橙", "白", "黒", "灰"],
				"description": "折り紙の色"
			},
			"shape": {
				"type": "string",
				"enum": ["三角", "四角", "五角形", "六角形", "円", "星"],
				"description": "折り紙の形"
			},
			"properties": {
				"type": "array",
				"items": {"type": "string"},
				"maxItems": 5,
				"description": "オブジェクトの属性"
			},
			"weight": {
				"type": "string",
				"enum": ["軽い", "普通", "重い"],
				"description": "重さ"
			}
		},
		"required": ["name", "category", "color", "shape", "properties", "weight"]
	}

	var schema_string = JSON.stringify(json_schema)
	var prompt = user_input + "について、ゲームで使用する折り紙オブジェクトの属性を決めてください。"

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
	print("折り紙を生成: ", data.get("name", "不明"))

	# 既存の折り紙を削除
	for child in origami_container.get_children():
		child.queue_free()

	# 新しい折り紙ノードを作成
	var origami = create_origami_sprite(data)
	origami_container.add_child(origami)

func create_origami_sprite(data: Dictionary) -> Node2D:
	var sprite_node = Node2D.new()

	# 色を取得
	var color_name = data.get("color", "白")
	var color = get_origami_color(color_name)

	# 形を取得
	var shape_name = data.get("shape", "四角")

	# ポリゴンを作成（影付き）
	var shadow = Polygon2D.new()
	shadow.polygon = get_shape_points(shape_name)
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(5, 5)
	sprite_node.add_child(shadow)

	var polygon = Polygon2D.new()
	polygon.polygon = get_shape_points(shape_name)
	polygon.color = color
	sprite_node.add_child(polygon)

	# 縁取り（折り紙っぽさを強調）
	var outline = Line2D.new()
	var shape_points = get_shape_points(shape_name)
	for point in shape_points:
		outline.add_point(point)
	outline.add_point(shape_points[0])  # 最初の点に戻る
	outline.width = 3.0
	outline.default_color = Color(0.2, 0.2, 0.2, 0.5)
	sprite_node.add_child(outline)

	# 名前ラベル（背景付き）
	var label_bg = ColorRect.new()
	label_bg.color = Color(1, 1, 1, 0.8)
	label_bg.position = Vector2(-80, 100)
	label_bg.size = Vector2(160, 40)
	sprite_node.add_child(label_bg)

	var label = Label.new()
	label.text = data.get("name", "折り紙")
	label.position = Vector2(-75, 105)
	label.size = Vector2(150, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	label.add_theme_font_size_override("font_size", 24)
	sprite_node.add_child(label)

	return sprite_node

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
