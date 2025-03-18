# 上場銘柄一覧機能 設計ドキュメント

## 1. 概要

J-Quants APIを使用して上場銘柄一覧を取得し、管理画面から表示・更新できる機能を実装する。

## 2. 要件

### 2.1 基本要件
- 上場銘柄一覧の表示
- ユーザーアクションによるデータ更新
- ページネーション（100件/ページ）
- データ更新は1日1回まで

### 2.2 技術要件
- Elixir/Phoenixを使用した実装
- LiveViewによるUI実装
- PostgreSQLによるデータ永続化

## 3. システム構成

### 3.1 アーキテクチャ
```
[Phoenix LiveView UI] -> [Context] -> [JQuants API Client] -> [Database]
```

### 3.2 コンポーネント構成
- LiveView: 表示・操作UI
- Context: ビジネスロジック
- Schema: データ構造
- API Client: J-Quants API通信

## 4. データモデル

### 4.1 スキーマ定義
```elixir
schema "listed_companies" do
  field :code, :string, null: false
  field :company_name, :string, null: false
  field :company_name_english, :string
  field :sector17_code, :string, null: false
  field :sector17_code_name, :string, null: false
  field :sector33_code, :string, null: false
  field :sector33_code_name, :string, null: false
  field :scale_category, :string
  field :market_code, :string, null: false
  field :market_code_name, :string, null: false
  field :margin_code, :string
  field :margin_code_name, :string
  field :last_updated_at, :date

  timestamps()
end
```

### 4.2 インデックス
- code (unique)
- sector17_code
- sector33_code
- market_code

## 5. 機能設計

### 5.1 データ取得・更新
- JQuants APIからのデータ取得
- データの変換と正規化
- データベースへの保存
- 更新頻度の制御（1日1回）

### 5.2 表示機能
- ページネーション（100件/ページ）
- 基本情報の表示
  - 銘柄コード
  - 会社名
  - 市場区分
  - 業種情報
  - 最終更新日

### 5.3 UI/UX
- 更新ボタン
- ローディング表示
- エラーメッセージ表示
- ページネーションコントロール

## 6. インターフェース設計

### 6.1 Context Interface
```elixir
# 主要な関数
- fetch_and_save/0  # データ取得・保存
- list_companies/1  # ページネーション付き一覧取得
- get_company/1     # 個別銘柄情報取得
```

### 6.2 LiveView Interface
- 一覧表示
- 更新トリガー
- ページネーション制御

## 7. エラーハンドリング

### 7.1 想定されるエラー
- API通信エラー
- データ変換エラー
- データベース操作エラー
- 更新頻度制限エラー

### 7.2 エラー表示
- ユーザーフレンドリーなエラーメッセージ
- エラー発生時のリカバリー方法の提示

## 8. 今後の拡張性

### 8.1 検索機能
- 銘柄コード検索
- 会社名検索
- 業種検索
- 市場区分検索

### 8.2 その他の拡張可能性
- ソート機能
- フィルタリング機能
- データエクスポート機能
- 詳細表示機能

## 9. 実装フェーズ

### Phase 1: 基本機能実装
1. データモデル作成
2. API Client実装
3. Context実装
4. 基本的なLiveView実装

### Phase 2: UI/UX改善
1. ページネーション実装
2. ローディング表示
3. エラーハンドリング
4. 更新制御

### Phase 3: 拡張機能
1. 検索機能
2. ソート機能
3. フィルタリング機能 