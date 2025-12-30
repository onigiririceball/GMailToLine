# GMailToLine 実装計画書

**プロジェクト**: GmailからLINEへの未読メール通知システム
**GCPプロジェクトID**: grounded-region-477206-b6
**リージョン**: asia-northeast1
**作成日**: 2024-12-24

---

## 📋 実装概要

このプロジェクトは、Gmail APIで未読メールを取得し、LINE Messaging APIで通知を送信するサーバーレスシステムです。Terraformでインフラを管理し、GitHub Actionsで自動デプロイを実現します。

### アーキテクチャフロー
```
Cloud Scheduler (5分毎)
  → Cloud Run (Pythonアプリ)
  → Secret Manager (認証情報取得)
  → Gmail API (未読確認)
  → LINE Messaging API (通知送信)
```

---

## 🎯 Phase 1: Terraform インフラ構築

**目標**: GCPリソースをTerraformで完全に定義し、初回デプロイを実行

### 1.1 Terraformコード作成

- [ ] ~~**terraform/variables.tf** を作成~~ (未作成 - main.tfに直接記述で対応)
  - ~~プロジェクトID、リージョン、サービス名などの変数定義~~
  - ~~デフォルト値の設定~~

- [ ] ~~**terraform/outputs.tf** を作成~~ (未作成 - 必要時に追加可)
  - ~~Cloud RunのURL~~
  - ~~Artifact RegistryのリポジトリURL~~
  - ~~Service Accountのメールアドレス~~

- [x] ~~**terraform/main.tf** を更新~~ ✅ **完了**
  - ~~既存のVPCネットワークリソースを削除（サーバーレスには不要）~~ ✅
  - ~~以下のリソースを追加:~~
    - ~~**Artifact Registry**: `gmail-line-repo` (Docker形式)~~ ✅
    - ~~**Cloud Run Service**: `gmail-line-app` (256Mi, CPU 1, timeout 60s, max instances 1)~~ ✅
    - ~~**Cloud Scheduler**: `gmail-line-scheduler` (*/5 * * * *, Asia/Tokyo)~~ ✅
    - ~~**Secret Manager Secrets**: `gmail-credentials`, `line-channel-access-token`~~ ✅
    - ~~**Service Account (Cloud Run用)**: `cloud-run-sa`~~ ✅
      - ~~権限: `secretmanager.secretAccessor`, `logging.logWriter`~~ ✅
    - ~~**Service Account (GitHub Actions用)**: `github-actions-sa`~~ ✅
      - ~~権限: `artifactregistry.writer`, `run.admin`, `iam.serviceAccountUser`~~ ✅
    - ~~**IAM Bindings**: Cloud Schedulerに`run.invoker`権限を付与~~ ✅

- [] ~~**terraform/terraform.tfvars.example** を作成 (オプション - 未作成)~~ 
  - ~~設定例を記載（実際の値は.gitignoreで除外）~~ 

### 1.2 Terraform初回実行

- [ ] ~~feat/1_TerraformSetting ブランチを dev にマージ (現在feat/1_TerraformSettingで作業中)~~ 
- [ ] ~~新ブランチ作成: `feat/2_complete-terraform`~~ (feat/1_TerraformSettingで継続)
- [x] ~~GCP認証設定確認~~ ✅ **完了**
  ```bash
  gcloud auth application-default login
  ```
- [x] ~~Terraform実行~~ ⚠️ **plan完了、apply待ち**
  ```bash
  cd terraform
  terraform init     ✅ 完了
  terraform validate ✅ 完了（推定）
  terraform plan     ✅ 完了
  terraform apply    ⏳ 未実行（キャンセル済み）
  ```
- ~~[ ] GCPコンソールで以下を確認: (terraform apply後に実施)~~
  - ~~Artifact Registryリポジトリ作成~~
  - ~~Cloud Runサービス作成（イメージ未設定でエラー表示は正常）~~
  - ~~Secret Manager secrets作成（空）~~
  - ~~Service Accounts作成~~
  - ~~Cloud Scheduler作成~~

**重要ファイル**:
- [terraform/main.tf](terraform/main.tf)
- [terraform/variables.tf](terraform/variables.tf)
- [terraform/outputs.tf](terraform/outputs.tf)

---

## 🐍 Phase 2: Pythonアプリケーション開発

**目標**: GmailとLINE APIを統合したコンテナ化アプリケーションを構築

### 2.1 アプリケーション構造作成

- [ ] ~~**app/** ディレクトリ作成~~

- [ ] **app/main.py** を作成
  - Flask Webサーバー（Cloud Run用）
  - エンドポイント:
    - `GET /health` - ヘルスチェック
    - `POST /` - Cloud Schedulerからのトリガー受信
  - Secret Managerから認証情報取得
  - Gmail API連携（未読メール取得、最大10件）
  - LINE Messaging API連携（通知送信）
  - 構造化ログ出力（Cloud Logging対応）
  - エラーハンドリング

- [ ] **app/requirements.txt** を作成
  ```
  Flask==3.0.0
  gunicorn==21.2.0
  google-auth==2.25.0
  google-auth-oauthlib==1.2.0
  google-auth-httplib2==0.2.0
  google-api-python-client==2.110.0
  google-cloud-secret-manager==2.17.0
  google-cloud-logging==3.9.0
  line-bot-sdk==3.6.0
  ```

- [ ] **app/Dockerfile** を作成
  ```dockerfile
  FROM python:3.11-slim
  WORKDIR /app
  COPY requirements.txt .
  RUN pip install --no-cache-dir -r requirements.txt
  COPY . .
  ENV PORT=8080
  CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 60 main:app
  ```

- [ ] **app/.dockerignore** を作成
  ```
  __pycache__
  *.pyc
  .env
  .git
  ```

### 2.2 ローカルテスト

- [ ] Dockerビルドをローカルで実行
  ```bash
  cd app
  docker build -t gmail-line-test .
  ```
- [ ] ローカル環境でのコンテナ起動テスト
  ```bash
  docker run -p 8080:8080 -e PROJECT_ID=grounded-region-477206-b6 gmail-line-test
  ```
- [ ] ヘルスチェック確認
  ```bash
  curl http://localhost:8080/health
  ```

**重要ファイル**:
- [app/main.py](app/main.py)
- [app/requirements.txt](app/requirements.txt)
- [app/Dockerfile](app/Dockerfile)

---

## 🚀 Phase 3: CI/CD パイプライン構築

**目標**: GitHub ActionsでビルドからCloud Runデプロイまで自動化

### 3.1 GitHub Actions ワークフロー作成

- [ ] **.github/workflows/** ディレクトリ作成

- [ ] **.github/workflows/deploy.yml** を作成
  - トリガー: main ブランチへの push（app/** または .github/workflows/** の変更時）
  - ステップ:
    1. コードチェックアウト
    2. GCP認証（Service Account Key使用）
    3. Cloud SDK セットアップ
    4. Docker認証設定（Artifact Registry）
    5. Dockerイメージビルド（タグ: ${{ github.sha }} と latest）
    6. Artifact Registryへプッシュ
    7. Cloud Runへデプロイ（環境変数設定含む）
    8. デプロイ検証

### 3.2 GitHub Secrets 設定

- [ ] GitHub Actions用Service Accountキー作成
  ```bash
  gcloud iam service-accounts keys create ~/github-actions-key.json \
    --iam-account=github-actions-sa@grounded-region-477206-b6.iam.gserviceaccount.com
  ```

- [ ] GitHubリポジトリの Settings > Secrets and variables > Actions で以下を登録:
  - `GCP_SA_KEY`: github-actions-key.jsonの内容（JSON全体）
  - `GCP_PROJECT_ID`: `grounded-region-477206-b6`
  - `GCP_REGION`: `asia-northeast1`

- [ ] ローカルのキーファイルを削除
  ```bash
  rm ~/github-actions-key.json
  ```

### 3.3 初回デプロイテスト

- [ ] 新ブランチ作成: `feat/3_github-actions`
- [ ] ワークフローファイル追加 & コミット
- [ ] dev ブランチにマージ
- [ ] main ブランチにマージ（PRまたは直接）
- [ ] GitHub ActionsのActionsタブで実行確認
- [ ] Cloud RunにDockerイメージがデプロイされたことを確認

**重要ファイル**:
- [.github/workflows/deploy.yml](.github/workflows/deploy.yml)

---

## 🔑 Phase 4: 認証情報セットアップ

**目標**: Gmail OAuthとLINE APIトークンをSecret Managerに保存

### 4.1 Gmail API設定

- [ ] GCPコンソールでGmail APIを有効化

- [ ] OAuth 2.0認証情報を作成
  - タイプ: デスクトップアプリまたはService Account
  - スコープ: `https://www.googleapis.com/auth/gmail.readonly`

- [ ] credentials.jsonをダウンロード

- [ ] OAuthフローを実行してtoken.jsonを生成（ローカルスクリプト使用）

- [ ] Secret Managerに保存
  ```bash
  gcloud secrets versions add gmail-credentials \
    --data-file=credentials.json \
    --project=grounded-region-477206-b6
  ```

### 4.2 LINE Messaging API設定

- [ ] LINE Developers (https://developers.line.biz/) でMessaging APIチャネル作成

- [ ] Channel Access Tokenを取得（長期トークン）

- [ ] Secret Managerに保存
  ```bash
  echo -n "YOUR_LINE_CHANNEL_ACCESS_TOKEN" | \
    gcloud secrets versions add line-channel-access-token \
      --data-file=- \
      --project=grounded-region-477206-b6
  ```

- [ ] LINE Official Account ManagerからユーザーIDを取得

### 4.3 Secret アクセステスト

- [ ] Cloud Run Service Accountがsecretsにアクセスできることを確認
  ```bash
  gcloud secrets get-iam-policy gmail-credentials
  gcloud secrets get-iam-policy line-channel-access-token
  ```

---

## 🧪 Phase 5: 統合テスト

**目標**: エンドツーエンドでシステムが動作することを確認

### 5.1 Cloud Run 手動実行テスト

- [ ] Cloud Runを手動で実行
  ```bash
  curl -X POST \
    -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
    $(gcloud run services describe gmail-line-app --region=asia-northeast1 --format='value(status.url)')
  ```

- [ ] Cloud Loggingでアプリケーションログ確認
  ```bash
  gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=gmail-line-app" \
    --limit=50 \
    --format=json
  ```

- [ ] LINEに通知が届くことを確認

### 5.2 Cloud Scheduler テスト

- [ ] Cloud Schedulerジョブを手動実行
  ```bash
  gcloud scheduler jobs run gmail-line-scheduler \
    --location=asia-northeast1
  ```

- [ ] 実行ログを確認
  - Cloud Schedulerのログ
  - Cloud Runの起動ログ
  - アプリケーションログ

- [ ] 5分待って自動実行を確認

### 5.3 エラーシナリオテスト

- [ ] Gmail API エラーハンドリング確認
  - トークン無効化して実行
  - エラーログ確認

- [ ] LINE API エラーハンドリング確認
  - 無効なトークン設定
  - リトライロジック確認

- [ ] 未読メール0件のケース確認

---

## 📚 Phase 6: ドキュメント整備

**目標**: セットアップ手順、トラブルシューティングを文書化

### 6.1 README更新

- [ ] **README.md** を更新
  - プロジェクト概要
  - アーキテクチャ図
  - セットアップ手順（簡易版）
  - デプロイ手順
  - トラブルシューティングの基本

### 6.2 詳細ドキュメント作成（オプション）

- [ ] **docs/SETUP.md** 作成
  - 詳細なセットアップガイド
  - GCPプロジェクト設定
  - Gmail API設定詳細
  - LINE API設定詳細

- [ ] **docs/TROUBLESHOOTING.md** 作成
  - よくあるエラーと解決方法
  - ログ分析ガイド
  - ロールバック手順

### 6.3 コード品質向上

- [ ] ログ出力の改善
  - 構造化JSON形式
  - INFO/WARNING/ERRORレベルの適切な使用

- [ ] エラーハンドリングの強化
  - 具体的な例外処理
  - リトライロジック（exponential backoff）

- [ ] 起動時バリデーション
  - 必須環境変数チェック
  - Secret存在確認

---

## 🎉 Phase 7: 本番稼働

**目標**: 本番環境で安定運用開始

### 7.1 本番前チェックリスト

- [ ] すべてのSecretsが正しく設定されている
- [ ] Cloud Schedulerが有効化されている
- [ ] IAM権限が最小権限原則に従っている
- [ ] Cloud Run ingressが適切に設定されている
- [ ] ログ保持期間が設定されている（30日推奨）
- [ ] GitHub Secretsが正しく設定されている
- [ ] ドキュメントが完成している
- [ ] 緊急停止手順が文書化されている

### 7.2 モニタリング設定

- [ ] Cloud Monitoring アラート作成
  - Cloud Runエラー率 > 5%
  - Cloud Schedulerジョブ失敗
  - Cloud Runレスポンスタイム > 30秒

- [ ] ログベースメトリクス作成
  - Gmail API呼び出し成功数
  - LINE通知送信数
  - エラー種別ごとのカウント

- [ ] 課金アラート設定
  - 月額 $10, $20, $50 でアラート

### 7.3 本番デプロイ

- [ ] すべてのfeatureブランチをdevにマージ
- [ ] dev環境で十分なテスト実施
- [ ] devからmainへPR作成
- [ ] コードレビュー実施
- [ ] mainにマージ → GitHub Actions自動デプロイ
- [ ] デプロイ完了を確認
- [ ] 1時間（12回実行）の監視
- [ ] LINE通知が正常に届くことを確認

### 7.4 運用開始後の監視

- [ ] 初日: 1時間ごとにログ確認
- [ ] 初週: 1日1回ログ確認
- [ ] 以降: 週1回の定期確認 + アラート対応

---

## 🔄 ブランチ戦略

```
main (本番環境)
  ↑ PR
dev (開発統合環境)
  ↑ PR
feat/2_complete-terraform  → Terraformリソース完成
feat/3_python-app          → アプリケーション開発
feat/4_github-actions      → CI/CDパイプライン
feat/5_documentation       → ドキュメント整備
```

**フロー**:
1. devブランチから各featureブランチを作成
2. 実装 & ローカルテスト
3. featureブランチ → dev にPR & マージ
4. dev環境でテスト
5. dev → main にPR & マージ → 本番デプロイ

---

## 🛠️ 重要な設定値

| 項目 | 値 |
|-----|-----|
| GCPプロジェクトID | grounded-region-477206-b6 |
| リージョン | asia-northeast1 |
| タイムゾーン | Asia/Tokyo |
| Cloud Run サービス名 | gmail-line-app |
| Cloud Run メモリ | 256Mi |
| Cloud Run CPU | 1 |
| Cloud Run タイムアウト | 60秒 |
| Artifact Registry | gmail-line-repo |
| Cloud Scheduler | */5 * * * * (5分毎) |
| Secret名（Gmail） | gmail-credentials |
| Secret名（LINE） | line-channel-access-token |

---

## 🚨 ロールバック手順

### アプリケーションのロールバック
```bash
# リビジョン一覧確認
gcloud run revisions list --service=gmail-line-app --region=asia-northeast1

# 前バージョンに戻す
gcloud run services update-traffic gmail-line-app \
  --to-revisions=gmail-line-app-00001-abc=100 \
  --region=asia-northeast1
```

### 緊急停止
```bash
# Cloud Schedulerを一時停止
gcloud scheduler jobs pause gmail-line-scheduler --location=asia-northeast1

# または Cloud Runサービスを削除
gcloud run services delete gmail-line-app --region=asia-northeast1
```

---

## 📊 想定コスト

- Cloud Run: 月額 $1-5（実行時間による）
- Cloud Scheduler: 月額 $0.10
- Artifact Registry: 月額 $0.50以下
- Secret Manager: 月額 $1以下
- **合計**: 月額 $5-10程度

---

## ✅ 完了条件

このプロジェクトは以下の条件を満たした時点で完了とする:

1. ✅ Cloud Schedulerが5分毎にCloud Runを起動している
2. ✅ Gmailの未読メールを正しく取得できている
3. ✅ LINEに適切なフォーマットで通知が送信されている
4. ✅ エラーログが正常（致命的エラーなし）
5. ✅ GitHub Actionsが正常にデプロイできている
6. ✅ ドキュメントが整備されている
7. ✅ コストが予算内（月額$10以下）

---

## 📝 補足事項

- **Terraformの状態管理**: 初期はローカルstateで問題なし。将来的にGCSバックエンドへ移行検討
- **セキュリティ**: Service Accountキーの代わりにWorkload Identity Federationを使用する改善も検討可能
- **テスト**: MVP段階では手動テストで十分。将来的にユニットテスト追加を検討
- **通知頻度**: 5分毎が過剰であれば、Cloud Schedulerの設定変更で調整可能（例: 15分毎）
