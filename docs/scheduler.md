# スケジューラー機能設計

## 概要
JQuants APIから定期的にデータを取得するためのスケジューラー機能を実装します。
将来的に複数のデータ取得ジョブ（日足データ等）を管理できるように設計します。

## 機能要件

### 1. スケジューラー管理
- スケジューラーのON/OFF切り替え　これはjob単位でできるようにしたい
- スケジューラーの実行状況確認 同様にjob単位で
- ジョブの即時実行機能

### 2. ジョブ管理
- 複数のジョブタイプの管理
  - 上場企業情報取得ジョブ
  - 日足データ取得ジョブ（将来的な拡張）
- ジョブごとの実行スケジュール設定
- ジョブごとの実行履歴管理

## 技術設計

### データベース設計

#### scheduler_settings テーブル
```sql
CREATE TABLE scheduler_settings (
  id SERIAL PRIMARY KEY,
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
```

#### jobs テーブル
```sql
CREATE TABLE jobs (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  job_type VARCHAR(50) NOT NULL,
  schedule VARCHAR(255) NOT NULL, -- cron形式
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  last_run_at TIMESTAMP WITH TIME ZONE,
  next_run_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
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
  status VARCHAR(50) NOT NULL, -- running, completed, failed
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
```

### モジュール構成

```
lib/
  ├── moo_markets/
  │   ├── scheduler/
  │   │   ├── application.ex      # スケジューラーアプリケーション
  │   │   ├── server.ex          # スケジューラーサーバー
  │   │   ├── job.ex             # ジョブの動作定義
  │   │   ├── jobs/
  │   │   │   ├── listed_companies.ex  # 上場企業情報取得ジョブ
  │   │   │   └── daily_quotes.ex      # 日足データ取得ジョブ（将来的な拡張）
  │   │   └── repo.ex            # データベース操作
  │   └── scheduler.ex           # コンテキスト
```

### API設計

#### スケジューラー管理
```elixir
# スケジューラーの状態取得
GET /api/scheduler/status

# スケジューラーのON/OFF切り替え
PUT /api/scheduler/enabled
{
  "enabled": true
}

# ジョブ一覧の取得
GET /api/scheduler/jobs

# ジョブの詳細取得
GET /api/scheduler/jobs/:id

# ジョブの即時実行
POST /api/scheduler/jobs/:id/run

# ジョブの実行履歴取得
GET /api/scheduler/jobs/:id/executions
```

## 実装手順

1. データベースマイグレーションの作成
2. スケジューラーモジュールの実装
   - スケジューラーサーバー
   - ジョブ定義
   - データベース操作
3. APIエンドポイントの実装
4. フロントエンド実装
   - スケジューラー状態表示
   - ジョブ一覧表示
   - ジョブ詳細表示
   - 実行履歴表示
   - 操作UI

## 注意事項

- ジョブの実行は非同期で行い、UIのレスポンスを妨げないようにする
- エラーハンドリングを適切に実装し、失敗時のリトライ機能を検討する
- ジョブの実行状況は定期的に更新し、UIに反映する
- 将来的な拡張性を考慮し、新しいジョブタイプの追加が容易な設計とする 

---- 

## 📌 実装方針（要件変更に柔軟に対応するために）

### 🚩 基本的な考え方
- **スモールスタート**
  - 最小限の実装からスタートし、順次拡張する。
- **Ectoスキーマを中心に設計**
  - テーブル構造はまずEctoスキーマを基準に決定し、マイグレーションで管理。
- **ビジネスロジックとスキーマの分離**
  - DB構造が変更になってもビジネスロジックへの影響を最小限にする。

---

### ✅ 実装ステップ（初期フェーズ）

#### ① データベースマイグレーションとEctoスキーマ作成
```bash
mix phx.gen.schema Scheduler.Job jobs \
  name:string description:text job_type:string schedule:string \
  is_enabled:boolean last_run_at:utc_datetime next_run_at:utc_datetime

mix phx.gen.schema Scheduler.JobExecution job_executions \
  job_id:references:jobs started_at:utc_datetime completed_at:utc_datetime \
  status:string error_message:text

mix ecto.migrate
```

#### ② ジョブ実行ロジックの抽象化
```elixir
defmodule MooMarkets.Scheduler.Job do
  @callback perform() :: :ok | {:error, term()}
end
```

- 各ジョブ（例：`Scheduler.Jobs.ListedCompaniesJob`）は`perform/0`を実装する。

#### ③ Quantumによるスケジューラー設定
```elixir
# config/config.exs
config :moo_markets, MooMarkets.Scheduler,
  jobs: [
    {"0 6 * * *", {MooMarkets.Scheduler.JobRunner, :run_job, [:listed_companies_job]}}
  ]
```

```elixir
defmodule MooMarkets.Scheduler.JobRunner do
  alias MooMarkets.Repo
  alias MooMarkets.Scheduler.{Job, JobExecution}

  def run_job(job_type) do
    job_module = job_module_from_type(job_type)

    execution = %JobExecution{
      job_id: get_job_id(job_type),
      started_at: DateTime.utc_now(),
      status: "running"
    }
    |> Repo.insert!()

    case job_module.perform() do
      :ok ->
        execution
        |> JobExecution.changeset(%{status: "completed", completed_at: DateTime.utc_now()})
        |> Repo.update!()

      {:error, reason} ->
        execution
        |> JobExecution.changeset(%{
          status: "failed",
          completed_at: DateTime.utc_now(),
          error_message: inspect(reason)
        })
        |> Repo.update!()
    end
  end

  defp job_module_from_type(:listed_companies_job), do: MooMarkets.Scheduler.Jobs.ListedCompaniesJob
  defp get_job_id(:listed_companies_job), do: Repo.get_by!(Job, job_type: "listed_companies").id
end
```

#### ④ APIエンドポイントの実装（最小限）
- `GET /api/scheduler/jobs`（ジョブ一覧取得）
- `GET /api/scheduler/jobs/:id`（ジョブ詳細取得）
- `POST /api/scheduler/jobs/:id/run`（ジョブ即時実行）

---

### 🔖 今後の変更に備えるポイント
- ジョブはインターフェース定義を使い、追加・変更が容易になるように設計。
- マイグレーションは小さく分割し、変更を容易にする。
- ロジックを`Scheduler.JobRunner`モジュールに集約し、影響範囲を限定する。

以上の方針で、柔軟なスケジューラー機能の実装を進めていきます。




実装した内容の説明：
JobInterface
perform/0 - ジョブの実行ロジックを定義
description/0 - ジョブの説明を返す
default_schedule/0 - デフォルトの実行スケジュールを返す
ListedCompaniesJob
JobInterfaceの実装
J-Quants APIを使用して上場企業情報を取得
毎日午前6時に実行するスケジュール設定
JobRunner
ジョブの実行を管理
実行履歴の記録
ジョブの状態更新
エラーハンドリング
次のステップとして以下のいずれかを実装できます：
スケジューラーサーバーの実装（Quantumを使用）
ジョブの即時実行用のAPIエンドポイントの実装
スケジュール解析と次回実行時刻計算の実装
どのステップから進めるべきかご指示ください。

---

現在の実装状況を確認しました。以下の実装が完了しています：
データベース設計とマイグレーション
jobsテーブル
job_executionsテーブル
関連するEctoスキーマ
ジョブ実行の基本構造
JobInterfaceの定義
ListedCompaniesJobの実装
JobRunnerの実装
テスト
JobInterfaceのテスト
ListedCompaniesJobのテスト
JobRunnerのテスト（一部コメントアウト）
次のステップとして、Webインターフェースの実装を提案します。以下の順序で実装を進めることをお勧めします：
スケジューラー管理用のLiveViewコンポーネントの作成
ジョブ一覧表示
ジョブの有効/無効切り替え
ジョブの即時実行機能
実行履歴の表示
ルーティングの設定
/schedulerへのルート追加
必要なAPIエンドポイントの設定
LiveViewテンプレートの実装
ジョブ一覧テーブル
ジョブ詳細表示
実行履歴表示
操作ボタン（実行、有効/無効切り替え）
LiveViewのロジック実装
ジョブ一覧の取得と表示
ジョブの状態更新
即時実行の処理
実行履歴の取得と表示
UI/UXの改善
ローディング状態の表示
エラーメッセージの表示
成功メッセージの表示
ページネーション（必要な場合）
これらの実装を進める前に、以下の点を確認することをお勧めします：
スケジューラーの状態管理方法（GenServerを使用するか、LiveViewのステートで管理するか）
ジョブ実行の非同期処理の実装方法
エラーハンドリングの方針
UIのデザイン方針（既存のデザインシステムとの整合性）
これらの点について、具体的な実装方針を決めてから進めることをお勧めします。どの部分から着手すべきかご指示ください。
