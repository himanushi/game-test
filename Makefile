# Scribble LLM Game - Makefile
# Godot 4プロジェクトの開発用コマンド

# プロジェクトパス
PROJECT_DIR = godot-project
PROJECT_FILE = $(PROJECT_DIR)/project.godot

# Godot実行ファイル
GODOT = godot

.PHONY: help start import edit clean build export-mac export-linux export-windows

# デフォルトターゲット：ヘルプを表示
help:
	@echo "Scribble LLM Game - 利用可能なコマンド:"
	@echo ""
	@echo "  make start          - ゲームを起動（自動的にimport実行）"
	@echo "  make import         - リソースを再インポート"
	@echo "  make edit           - Godotエディタでプロジェクトを開く"
	@echo "  make clean          - キャッシュと一時ファイルをクリーン"
	@echo "  make info           - プロジェクト情報を表示"
	@echo ""

# リソースを再インポート（エディタで開く必要あり）
import:
	@echo "📦 リソースを再インポートするにはエディタを使用してください"
	@echo "実行: make edit"
	@echo ""
	@echo "または、make start で起動すると自動的にインポートされます"

# ゲームを起動（Godotが自動的に必要なインポートを実行）
start:
	@echo "🎮 ゲームを起動しています..."
	@echo "（初回起動時や.godotが無い場合、自動的にリソースをインポートします）"
	$(GODOT) --path $(PROJECT_DIR)

# Godotエディタで開く
edit:
	@echo "🛠️  Godotエディタを起動しています..."
	$(GODOT) -e $(PROJECT_FILE)

# キャッシュクリーン
clean:
	@echo "🧹 キャッシュをクリーンアップしています..."
	rm -rf $(PROJECT_DIR)/.godot/
	@echo "✅ クリーンアップ完了"

# プロジェクト情報
info:
	@echo "📦 プロジェクト情報"
	@echo "===================="
	@echo "プロジェクト: Scribble LLM Game"
	@echo "エンジン: Godot 4"
	@echo "パス: $(PROJECT_FILE)"
	@echo ""
	@echo "Godotバージョン:"
	@$(GODOT) --version
