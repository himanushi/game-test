extends Node2D

# メインゲームスクリプト
# Scribble LLM Game - LLMを使った2Dパズルゲーム

func _ready():
	print("==================================================")
	print("Scribble LLM Game が起動しました！")
	print("Godot バージョン: ", Engine.get_version_info().string)
	print("画像表示テスト実行中...")
	print("==================================================")

func _process(_delta):
	# ESCキーで終了
	if Input.is_action_just_pressed("ui_cancel"):
		print("ゲームを終了します")
		get_tree().quit()
