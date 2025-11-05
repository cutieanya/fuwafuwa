# fuwafuwa – Gmailをチャットのように扱うFlutterアプリ

## 🎥 デモ動画
今後追加予定

<video src="docs/demo.mp4" width="360" controls autoplay loop muted></video>

---

## 📱 概要
Gmailのスレッドをチャットのように表示・返信できるFlutter製アプリ。  
「メールをもっと親しみやすく使いたい」という思いから開発をスタート。  
Google Sign-Inでログインし、Gmail API経由でメール取得・送信を行います。  
Drift（SQLite）によるローカルキャッシュでオフライン利用にも対応。

---

## ✨ 主な特徴
- Googleアカウントでログイン（Firebase Authentication）
- Gmail APIを用いた受信・送信・既読管理
- LINE風のチャットUIでスレッド表示
- HTML / プレーン本文の自動レンダリング
- Drift（SQLite）でオフラインキャッシュ
- バックグラウンド同期・未読バッジ（開発中）

---

## 🧱 技術構成
| 項目 | 使用技術 |
|------|-----------|
| フレームワーク | Flutter / Dart |
| データベース | Drift（SQLite） |
| 認証 | Firebase Authentication + Google Sign-In |
| 外部API | Gmail REST API |
| 状態管理 | setState + Repository構造（Riverpod移行予定） |
| 同期処理 | ポーリング（60秒ごと）＋Firebase連携（計画中） |

---

## 📂 ディレクトリ構成
lib/
data/
local_db/
repositories/
features/
chat/
views/
services/
main.dart

---

## 🚀 セットアップ手順
### 1. 依存関係を取得
flutter pub get

### 2. Firebase設定
- iOS: `GoogleService-Info.plist` → `ios/Runner`
- Android: `google-services.json` → `android/app`
flutterfire configure

### 3. Gmail API設定
- Gmail APIを有効化し、OAuth同意画面を設定  
- 使用スコープ:
https://www.googleapis.com/auth/gmail.readonly
https://www.googleapis.com/auth/gmail.modify
https://www.googleapis.com/auth/gmail.send

### 4. 実行
flutter run

---

## 🗂 データモデル例
| カラム名 | 内容 |
|-----------|------|
| id | GmailメッセージID |
| threadId | スレッドID |
| from / to | 送受信アドレス |
| subject | 件名 |
| bodyPlain / bodyHtml | 本文 |
| isUnread | 未読フラグ |
| internalDate | 送受信日時 |

---

## 🧭 設計思想
- UI / ロジック / 永続化を分離したシンプルな構成
- ネットワークエラー時でもローカルDBで閲覧可能
- テスト・保守性を考慮したリポジトリ構造
- 将来拡張を前提に、柔軟なモジュール設計

---

## 🧩 よくあるエラーと対処
| エラー | 対処法 |
|--------|--------|
| `Podfile.lock not in sync` | `flutter clean` → `flutter pub get` → `cd ios` → `pod install` |
| `Generated.xcconfig must exist` | FlutterFire設定を再生成 |
| `403 insufficientPermissions` | Gmail APIスコープとOAuth設定を再確認 |

---

## 🔮 今後の予定
- 通知機能（Push + バッジ）
- メール検索 / フィルタ
- 添付ファイルプレビュー
- ダークモード対応
- Riverpod導入とテスト自動化

---

## 👥 開発チーム
| メンバー |
|-----------|
| Miki Nakata | 
| Konoha Moriko |
| Honoka Kataoka | 
| Suzuka Monden | 


---

## 💬 メッセージ
このアプリは「メールをもっと感覚的に扱う」ための実験的プロジェクトです。  
自分は **UI/UX設計 × データ設計 × API連携** の3領域を担当し、  
技術的にもデザイン的にも一貫したプロダクト体験を目指しました。

---

## 🪪 ライセンス
MIT License
