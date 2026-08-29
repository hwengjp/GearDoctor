# GearDoctor

自転車メンテナンス用の携帯電話アプリです。交換した部品とその時期を記録し、次の交換時期を知らせます。対象は開発者本人と親しい自転車仲間だけで、アプリストアには出しません。実装は Dart / Flutter の Android アプリです。詳細は [`docs/技術選定.md`](docs/技術選定.md)、入れ方は [`docs/開発と配布.md`](docs/開発と配布.md) を参照してください。

## できること

- タイヤ、チェーン、ブレーキパッドなど、交換した部品と交換日を記録する
- Strava から走行記録を読み取り、交換後の走行距離を把握する
- 部品ごとの交換目安（例: タイヤ 6,000 km）と通知しきい値（例: 80%）を設定する
- しきい値に達したら「そろそろ交換ですよ」と知らせる

例: タイヤを 6,000 km ごとに交換する設定で、しきい値を 80% にした場合、交換後の走行距離が 4,800 km に達すると通知します。

## リポジトリ構成

```
GearDoctor/
├── lib/         # Flutter アプリ本体
├── test/        # 集計・画面のテスト
├── android/     # Android 向けプロジェクト
├── canvases/    # 画面案（Cursor Canvas）
├── README.md
└── docs/        # 詳細ドキュメント
```

初回起動時に、画面確認用のデモ部品・走行・ギアを端末内 SQLite へ入れます。Strava は PC 上で認可し、同期画面から走行を取れます。最初の取得でデモの走行は Strava の内容に置き換わります。手順は [`docs/Strava連携.md`](docs/Strava連携.md) です。`strava_secrets.json` は Git に入れません。

## 動かし方

手順の全体は [`docs/開発と配布.md`](docs/開発と配布.md) です。

リポジトリのフォルダで:

```
flutter test
flutter run -d linux
./scripts/build_apk.sh
```

`flutter` が見つからないときは、その端末で `source ~/.bashrc` を実行するか、新しい端末を開きます。APK は `build/app/outputs/flutter-apk/app-release.apk` です。作るたびに版が 0.0.1 上がり、設定画面の表示と揃います。

## ドキュメント

詳細は [`docs/`](docs/) を参照してください。プライバシーポリシーは [`docs/privacy-policy.html`](docs/privacy-policy.html) です。
