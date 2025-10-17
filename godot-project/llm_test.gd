extends Node2D

# LLM統合テスト
# Qwen2-0.5B-Instructモデルを使用したテキスト生成テスト

var llama: GDLlama
var status_label: Label
var output_label: Label
var generated_text: String = ""

func _ready():
	print("==================================================")
	print("LLM統合テスト開始")
	print("==================================================")

	# ラベル取得
	status_label = $StatusLabel
	output_label = $OutputLabel

	# GDLlamaノードを作成
	llama = GDLlama.new()
	add_child(llama)

	# モデル設定
	llama.model_path = "res://models/qwen2-0_5b-instruct-q8_0.gguf"
	llama.n_predict = 200  # 生成するトークン数
	llama.temperature = 0.7
	llama.should_output_prompt = false  # プロンプトを出力しない
	llama.should_output_special = false  # 特殊トークンを出力しない

	print("モデルパス: ", llama.model_path)
	print("生成トークン数: ", llama.n_predict)
	print("JSON Schema機能: 有効")

	# シグナル接続
	llama.generate_text_updated.connect(_on_text_updated)

	# モデル読み込み完了を待つ
	status_label.text = "モデルを読み込み中..."
	await get_tree().create_timer(1.0).timeout

	# テスト実行
	run_test()

func run_test():
	print("--------------------------------------------------")
	print("JSON出力テスト実行中...")
	status_label.text = "JSON生成中（JSON Schema使用）..."

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
				"description": "オブジェクトのカテゴリ"
			},
			"properties": {
				"type": "array",
				"items": {"type": "string"},
				"description": "オブジェクトの属性リスト"
			},
			"can_extinguish_fire": {
				"type": "boolean",
				"description": "火を消すことができるか"
			},
			"weight": {
				"type": "string",
				"enum": ["軽い", "普通", "重い"],
				"description": "オブジェクトの重さ"
			}
		},
		"required": ["name", "category", "properties", "can_extinguish_fire", "weight"]
	}

	var schema_string = JSON.stringify(json_schema)
	print("JSON Schema: ", schema_string)

	# プロンプト（シンプルに）
	var prompt = "消火器というゲームオブジェクトについて説明してください。"

	print("プロンプト: ", prompt)

	generated_text = ""

	# JSON Schemaを使ってテキスト生成
	llama.run_generate_text(prompt, "", schema_string)

func _on_text_updated(new_text: String):
	generated_text += new_text

	# リアルタイムで画面更新
	output_label.text = "生成中のJSON:\n\n" + generated_text

	# 生成完了チェック（簡易）
	if new_text == "":
		print("--------------------------------------------------")
		print("生成完了")
		print("生成されたテキスト: ", generated_text)

		# JSONパース試行
		parse_json_output()

		print("==================================================")
		status_label.text = "生成完了！"

func parse_json_output():
	print("\n--- JSONパース試行 ---")

	# JSON部分を抽出（{ から } まで）
	var json_start = generated_text.find("{")
	var json_end = generated_text.rfind("}") + 1

	if json_start == -1 or json_end <= json_start:
		print("エラー: JSON形式が見つかりません")
		return

	var json_str = generated_text.substr(json_start, json_end - json_start)
	print("抽出されたJSON: ", json_str)

	# JSONパース
	var json = JSON.new()
	var error = json.parse(json_str)

	if error == OK:
		var data = json.data
		print("\n✅ JSONパース成功！")
		print("オブジェクト名: ", data.get("name", "不明"))
		print("カテゴリ: ", data.get("category", "不明"))
		print("属性: ", data.get("properties", []))
		print("消火可能: ", data.get("can_extinguish_fire", false))
		print("重さ: ", data.get("weight", "不明"))

		# 画面に整形して表示
		output_label.text = "✅ JSON生成成功！\n\n"
		output_label.text += "オブジェクト: " + str(data.get("name", "不明")) + "\n"
		output_label.text += "カテゴリ: " + str(data.get("category", "不明")) + "\n"
		output_label.text += "属性: " + str(data.get("properties", [])) + "\n"
		output_label.text += "消火可能: " + str(data.get("can_extinguish_fire", false)) + "\n"
		output_label.text += "重さ: " + str(data.get("weight", "不明")) + "\n\n"
		output_label.text += "生のJSON:\n" + json_str
	else:
		print("❌ JSONパースエラー: ", json.get_error_message())
		print("エラー行: ", json.get_error_line())

func _process(_delta):
	# ESCキーで終了
	if Input.is_action_just_pressed("ui_cancel"):
		print("テストを終了します")
		get_tree().quit()
