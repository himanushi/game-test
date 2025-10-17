# CLAUDE.md

このファイルは、このリポジトリで作業する際にClaude Code (claude.ai/code) へのガイダンスを提供します。

## 重要: 言語設定

**このプロジェクトでは必ず日本語で回答してください。**

## プロジェクト概要

このプロジェクトはlocal LLMを使用したゲーム開発の技術検証リポジトリです。

## 技術スタック

### ゲームエンジン
- **Godot 4.5.1** - 2D専用の機能が充実した軽量ゲームエンジン
- 2D物理エンジン、TileMap、Sprite、アニメーション機能を活用

### LLM統合
- **llama.cpp** - クロスプラットフォーム対応のローカルLLM実行環境
- **Godot LLM** ([github.com/Adriankhl/godot-llm](https://github.com/Adriankhl/godot-llm)) - GDExtensionプラグイン
  - GGUF形式のモデルファイルをサポート
  - 全プラットフォーム対応（Windows/Mac/Linux/Android）
  - GPU加速対応（Vulkan/Metal/CPU）

## 開発環境セットアップ手順

### 1. Godot 4のインストール

```bash
# Homebrewでインストール（Mac）
brew install --cask godot

# バージョン確認
godot --version
# 出力例: 4.5.1.stable.official.f62fdbde1
```

### 3. Godot LLMプラグインのセットアップ

#### 方法1: Godot Asset Library（推奨）
1. Godotエディタを開く
2. 上部の「AssetLib」タブをクリック
3. "Godot LLM"を検索
4. ダウンロード＆インストール

#### 方法2: 手動インストール
1. [リリースページ](https://github.com/Adriankhl/godot-llm/releases)からダウンロード
2. 解凍して`addons/godot_llm`フォルダを`godot-project/addons/`に配置
3. GDExtensionが自動的に読み込まれる（Godot 4.2以降）

### 4. GGUFモデルの準備

テスト用に軽量なモデルを推奨：

- **Qwen2.5-0.5B-Instruct** (~300MB) - 最小・最速
- **TinyLlama-1.1B** (~600MB) - バランス型
- **Llama-3.2-1B-Instruct** (~700MB) - Meta公式・高品質

モデルは`godot-project/models/`に配置する。
