# スケジューラー機能設計

## 概要
JQuants APIから定期的にデータを取得するためのスケジューラー機能を実装します。
将来的に複数のデータ取得ジョブ（日足データ等）を管理できるように設計しています。

## 機能要件と実装状況

### 1. スケジューラー管理
- ✅ スケジューラーのON/OFF切り替え（ジョブ単位）
- ✅ スケジューラーの実行状況確認（ジョブ単位）
- ✅ ジョブの即時実行機能

### 2. ジョブ管理
- ✅ 複数のジョブタイプの管理
  - ✅ 上場企業情報取得ジョブ
  - 🔲 日足データ取得ジョブ（将来的な拡張）
- ✅ ジョブごとの実行スケジュール設定
- ✅ ジョブごとの実行履歴管理

## 技術設計

### データベース設計

#### jobs テーブル
```sql
CREATE TABLE jobs (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  job_type VARCHAR(50) NOT NULL UNIQUE,
  schedule VARCHAR(255) NOT NULL, -- cron形式
  is_enabled BOOLEAN NOT NULL DEFAULT false,
  last_run_at TIMESTAMP WITH TIME ZONE,
  next_run_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
```

#### job_executions テーブル
```sql
CREATE TABLE job_executions (
  id SERIAL PRIMARY KEY,
  job_id INTEGER NOT NULL REFERENCES jobs(id),
  started_at TIMESTAMP WITH TIME ZONE NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL, -- running, completed, failed, stopped
  error_message TEXT,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX job_executions_job_id_idx ON job_executions(job_id);
```

### モジュール構成

```
lib/
  ├── moo_markets/
  │   ├── scheduler/
  │   │   ├── server.ex          # スケジューラーサーバー（実装済）
  │   │   ├── job_runner.ex      # ジョブ実行管理（実装済）
  │   │   ├── job.ex             # ジョブスキーマ（実装済）
  │   │   ├── job_execution.ex   # 実行履歴スキーマ（実装済）
  │   │   ├── job_interface.ex   # ジョブインターフェース（実装済）
  │   │   └── jobs/
  │   │       └── listed_companies_job.ex  # 上場企業情報取得ジョブ（実装済）
  │   └── application.ex         # アプリケーション設定（実装済）
  └── moo_markets_web/
      ├── controllers/
      │   ├── scheduler_controller.ex  # APIコントローラー（実装済）
      │   └── scheduler_json.ex        # JSONレンダリング（実装済）
      └── router.ex                    # ルーティング（実装済）
```

### API実装状況

#### スケジューラー管理API
✅ `GET /api/scheduler/status` - スケジューラーの状態取得
✅ `GET /api/scheduler/jobs` - ジョブ一覧の取得
✅ `GET /api/scheduler/jobs/:id` - ジョブの詳細取得
✅ `PUT /api/scheduler/jobs/:id/enabled` - ジョブの有効/無効切り替え
✅ `POST /api/scheduler/jobs/:id/run` - ジョブの即時実行
✅ `GET /api/scheduler/jobs/:id/executions` - ジョブの実行履歴取得（直近10件）
✅ `POST /api/scheduler/cleanup` - 実行中のジョブのクリーンアップ

### フロントエンド実装状況

現在の実装:
- ✅ 基本的なジョブ一覧表示
  - ジョブの名前、説明、スケジュール、最終実行、次回実行、状態の表示
  - ジョブの有効/無効切り替え機能
  - ジョブの即時実行機能
  - 10秒ごとの自動更新

今後の実装予定:
1. ジョブ詳細・実行履歴機能
   - [ ] ジョブ詳細画面の作成（`/scheduler/:id`）
   - [ ] 実行履歴の一覧表示
   - [ ] 実行履歴の詳細表示（開始時刻、完了時刻、ステータス、エラーメッセージ）
   - [ ] 実行履歴のページネーション

2. UI/UX改善
   - [ ] フラッシュメッセージのスタイリング
   - [ ] ローディング表示の追加
   - [ ] ジョブ操作時の確認ダイアログ
   - [ ] エラー表示の改善
   - [ ] モバイル対応の改善

3. リアルタイム更新機能
   - [ ] PubSubを使用したジョブ状態のリアルタイム更新
   - [ ] 実行中ジョブの進捗表示
   - [ ] 実行履歴のリアルタイム更新

4. 追加機能
   - [ ] ジョブの実行結果の詳細表示
   - [ ] ジョブのログ表示
   - [ ] 実行統計情報の表示（成功率、平均実行時間など）
   - [ ] ジョブの停止機能

## 実装優先順位

1. ジョブ詳細・実行履歴機能
   - ジョブの詳細情報と実行履歴の表示は運用上重要
   - APIは既に実装済みで、UIの実装のみ必要

2. UI/UX改善
   - 基本的な操作性とフィードバックの改善
   - ユーザーの操作ミスを防ぐための確認機能

3. リアルタイム更新機能
   - より正確なジョブ状態の把握
   - 実行状況のリアルタイムフィードバック

4. 追加機能
   - 運用性を向上させる付加的な機能
   - 統計情報による実行状況の分析

## 動作確認手順

### 1. スケジューラーの状態確認
```elixir
# IExシェルで状態確認
iex> MooMarkets.Scheduler.Server.get_state()
```

### 2. ジョブの操作
```elixir
# ジョブの有効化/無効化
iex> MooMarkets.Scheduler.Server.toggle_job(job_id, true)  # 有効化
iex> MooMarkets.Scheduler.Server.toggle_job(job_id, false) # 無効化

# ジョブの即時実行
iex> MooMarkets.Scheduler.Server.run_job(job_id)

# 実行中ジョブのクリーンアップ
iex> MooMarkets.Scheduler.Server.cleanup_running_jobs()
```

### 3. APIでの操作
```bash
# スケジューラーの状態取得
curl -X GET http://localhost:4000/api/scheduler/status | jq

# ジョブ一覧の取得
curl -X GET http://localhost:4000/api/scheduler/jobs | jq

# ジョブの有効化
curl -X PUT http://localhost:4000/api/scheduler/jobs/1/enabled \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' | jq

# ジョブの即時実行
curl -X POST http://localhost:4000/api/scheduler/jobs/1/run | jq

# ジョブの実行履歴取得
curl -X GET http://localhost:4000/api/scheduler/jobs/1/executions | jq
```

## 今後の課題

1. フロントエンド実装
   - LiveViewを使用したUI実装
   - リアルタイムでの実行状況更新
   - 操作性の向上

2. 機能拡張
   - ジョブの停止機能の実装
   - エラー時のリトライ機能
   - 実行履歴の詳細表示
   - 日足データ取得ジョブの追加

3. 運用性の向上
   - ログ機能の強化
   - モニタリング機能の追加
   - バックアップ/リストア機能

4. パフォーマンス最適化
   - 長期実行履歴の管理
   - データベースインデックスの最適化
   - 並行実行の制御
