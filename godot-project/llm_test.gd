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
	llama.n_predict = 100  # 生成するトークン数
	llama.temperature = 0.7

	print("モデルパス: ", llama.model_path)
	print("生成トークン数: ", llama.n_predict)

	# シグナル接続
	llama.generate_text_updated.connect(_on_text_updated)

	# モデル読み込み完了を待つ
	status_label.text = "モデルを読み込み中..."
	await get_tree().create_timer(1.0).timeout

	# テスト実行
	run_test()

func run_test():
	print("--------------------------------------------------")
	print("テスト実行中...")
	status_label.text = "テキスト生成中..."

	var prompt = "火を消すための道具を3つ教えてください。"

	print("プロンプト: ", prompt)

	generated_text = ""

	# テキスト生成開始
	llama.run_generate_text(prompt, "", "")

func _on_text_updated(new_text: String):
	generated_text += new_text

	# リアルタイムで画面更新
	output_label.text = "プロンプト:\n火を消すための道具を3つ教えてください。\n\n応答:\n" + generated_text

	# 生成完了チェック（簡易）
	if new_text == "":
		print("--------------------------------------------------")
		print("生成完了")
		print("生成されたテキスト: ", generated_text)
		print("==================================================")
		status_label.text = "生成完了！"

func _process(_delta):
	# ESCキーで終了
	if Input.is_action_just_pressed("ui_cancel"):
		print("テストを終了します")
		get_tree().quit()
