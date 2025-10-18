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

## ゲームコンセプト

**折り紙パズル - Origami LLM Game**

2Dスーパースクリブルノーツ風のパズルゲーム。プレイヤーがテキストでオブジェクトを記述すると、LLMがそれを解釈してゲーム内に折り紙オブジェクトを生成します。

### コア機能

1. **LLMベースのオブジェクト生成**
   - ユーザーがテキスト入力（例：「消火器」「剣」「水」）
   - LLMがJSON Schema形式で構造化されたデータを生成
   - 色（色名enum）、形状のみの最小限の構造

2. **折り紙アニメーション**
   - スプライト生成時に回転・スケール・透明度アニメーション
   - 折り目が順番に描画される演出
   - Tweenを使用したスムーズな演出

3. **複数オブジェクト管理**
   - 複数のオブジェクトを同時に配置可能
   - ランダムな位置に生成
   - 左クリックで削除（フェードアウトアニメーション付き）
   - マウスホバーでハイライト

4. **物理エンジン統合**
   - RigidBody2Dによる本格的な物理シミュレーション
   - 重力、衝突判定、空気抵抗
   - オブジェクト同士の相互作用
   - 地面との衝突

### 技術的特徴

- **JSON Schema機能**: LLM出力を完全に構造化
- **決定的な出力**: temperature=0.0で再現性を確保
- **最小限のスプライト**: 折り紙の世界観で幾何学的な形状のみ使用
- **リアルタイム生成**: 生成中のJSONをリアルタイム表示

## ゲームの起動方法

```bash
# ゲームを起動
make start

# Godotエディタを開く（任意）
make edit
```

## プロジェクト構造

```
godot-project/
├── game.gd           # メインゲームロジック
├── game.tscn         # メインシーン
├── llm_test.gd       # LLM統合テスト
├── llm_test.tscn     # テストシーン
├── models/           # GGUFモデル格納ディレクトリ
│   └── qwen2-0_5b-instruct-q8_0.gguf
└── addons/
    └── godot_llm/    # Godot LLMプラグイン
```

## LLM設定

現在の設定（`game.gd`）：

```gdscript
llama.model_path = "res://models/qwen2-0_5b-instruct-q8_0.gguf"
llama.n_predict = 200      # 生成トークン数
llama.temperature = 0.0    # 決定的な出力
llama.should_output_prompt = false
llama.should_output_special = false
```

### JSON Schema

```gdscript
{
  "type": "object",
  "properties": {
    "color": {
      "type": "string",
      "enum": ["赤", "青", "緑", "黄", "紫", "橙", "白", "黒", "灰"],
      "description": "折り紙の色"
    },
    "shape": {
      "type": "string",
      "enum": ["三角", "四角", "五角形", "六角形", "円", "星"],
      "description": "折り紙の形"
    }
  },
  "required": ["color", "shape"]
}
```

## 次のステップ（将来の拡張）

- オブジェクト同士の相互作用ルール（例：水+火→消火）
- パズル要素の追加（目標達成システム）
- より多様な形状と色のバリエーション
- オブジェクトの属性による物理パラメータの変更
- セーブ/ロード機能
