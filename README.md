# AzooKeyKanakanjiConverter

[azooKey](https://github.com/ensan-hcl/azooKey)のかな漢字変換モジュールを切り出したライブラリです。

## KanaKanjiConverterModule
かな漢字変換を受け持つモジュールです。

### セットアップ
* Xcodeprojの場合、XcodeでAdd Packageしてください。
* Swift Packageの場合、Package.swiftの`Package`の引数に`dependencies`以下の記述を追加してください。
  ```swift
  dependencies: [
      .package(url: "https://github.com/ensan-hcl/AzooKeyKanaKanjiConverter", from: "0.1.0")
  ],
  ```
  また、ターゲットの`dependencies`にも同様に追加してください。
  ```swift
  .target(
      name: "MyPackage",
      dependencies: [
          .product(name: "KanaKanjiConverterModule", package: "AzooKeyKanaKanjiConverter")
      ],
  ),
  ```

* [Google DriveからazooKeyの辞書をダウンロード](https://drive.google.com/drive/folders/1Kh7fgMFIzkpg7YwP3GhWTxFkXI-yzT9E?usp=sharing)する必要があります。最新のバージョンのフォルダの中にある「Dictionary」というフォルダを右クリックし、フォルダごとダウンロードします。ついで、本モジュールを利用するアプリケーションのリソースとして配置してください。


> [!IMPORTANT]  
> リソースを追加する際、Folder Referenceをコピーしてください。AzooKeyKanaKanjiConverterはフォルダ構造が存在することを前提に動作します。



### 使い方
```swift
import KanaKanjiConverterModule

// 変換器を初期化する
let converter = KanaKanjiConverter()
// 入力を初期化する
var c = ComposingText()
// 変換したい文章を追加する
c.insertAtCursorPosition("あずーきーはしんじだいのきーぼーどあぷりです", inputStyle: .direct)
// 変換のためのオプションを指定して、変換を要求
let results = converter.requestCandidates(c, options: ConvertRequestOptions(...))
// 結果の一番目を表示
print(results.mainResults.first!.text)  // azooKeyは新時代のキーボードアプリです
```
`ConvertRequestOptions`は、変換リクエストに必要な情報を指定します。詳しくはコードに書かれたドキュメントコメントを参照してください。


### `ConvertRequestOptions`
`ConvertRequestOptions`は変換リクエストに必要な設定値です。例えば以下のように設定します。

```swift
let options = ConvertRequestOptions(
    // 日本語予測変換
    requireJapanesePrediction: true,
    // 英語予測変換 
    requireEnglishPrediction: false,
    // 入力言語 
    keyboardLanguage: .ja_JP,
    // 学習タイプ 
    learningType: .nothing, 
    // 辞書データのURL（先ほど追加した辞書リソースを指定）
    dictionaryResourceURL: Bundle.main.bundleURL.appending(path: "Dictionary", directoryHint: .isDirectory),
    // 学習データを保存するディレクトリのURL（書類フォルダを指定）
    memoryDirectoryURL: .documentsDirectory, 
    // ユーザ辞書データのあるディレクトリのURL（書類フォルダを指定）
    sharedContainerURL: .documentsDirectory, 
    // メタデータ
    metadata: .init(appVersionString: "Version X")
)
```

### `ComposingText`
`ComposingText`は入力管理を行いつつ変換をリクエストするためのAPIです。詳しくは[ドキュメント](./Docs/composing_text.md)を参照してください。

### 辞書データ

上記のとおり、利用時は、ConvertRequestOptionsの`dictionaryResourceURL`に辞書データのディレクトリのURLを指定する必要があります。辞書データは[Google Drive](https://drive.google.com/drive/folders/1Kh7fgMFIzkpg7YwP3GhWTxFkXI-yzT9E?usp=sharing)からダウンロードすることができます。

また、以下のフォーマットであれば自前で用意した辞書データを利用することもできます。カスタム辞書データのサポートは限定的なので、ソースコードを確認の上ご利用ください。

```
- Dictionary/
  - louds/
    - charId.chid
    - X.louds
    - X.loudschars2
    - X.loudstxt3
    - ...
  - p/
    - X.csv
  - cb/
    - 0.binary
    - 1.binary
    - ...
  - mm.binary
```

## SwiftUtils
Swift一般に利用できるユーティリティのモジュールです。
