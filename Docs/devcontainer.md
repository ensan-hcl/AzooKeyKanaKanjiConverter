# Dev Container

このリポジトリーには、VS Code の Dev Container を使用して開発するための設定が含まれています。
確実に動作する Swift の開発環境が自動的に構築され、すべて Docker コンテナ―内で実行されます。
Docker コンテナーとのやりとりは VS Code が行ってくれます。
もちろん、Docker コンテナーの外に影響を与えることはありません。

## 前提条件

- Docker がインストールされていること
- VS Code （または互換性のあるエディター、たとえば Cursor など）がインストールされていること

## 開発環境の起動

1. このリポジトリーをクローンします
   サブモジュールが含まれているため `--recursive` オプションを使用することを忘れないでください。

2. VS Code でこのリポジトリーを開きます

3. もし、[Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) 拡張機能がインストールされていない場合は、インストールします。
   ただし、VS Code は Dev Container の設定ファイルを検出すると、自動的に拡張機能をインストールするように求めます。

4. 左下の `><` アイコンをクリックし、`Reopen in Container` を選択します。

5. しばらくすると、Dev Container が起動します。
   初回の起動時には、Docker イメージをダウンロードする必要があるので、かなり時間がかかります。
   次回以降は、Docker イメージがキャッシュされるため、起動時間は短縮されます。

6. [Swift](https://marketplace.visualstudio.com/items?itemName=sswg.swift-lang) の拡張機能が自動的にインストールされるようになっていて、この拡張機能が依存関係の解決を行います。

7. これで、Swift の開発環境が起動しました。
   Docker コンテナー内でコマンドを実行したければ、VS Code のターミナルを使用するのがいいでしょう。
   もちろん `ancoo` のコマンドをインストール、実行することもできます。
   