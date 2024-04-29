#  anco (azooKey Cli)

`anco`コマンドにより、AzooKeyKanaKanjiConverterをCliで利用することができます。`anco`はデバッグ用ツールの位置付けです。

`anco`を利用するには、最初にinstallが必要です。

```bash
sudo sh install_cli.sh
```

例えば以下のように利用できます。

```bash
your@pc Desktop % anco にほんごにゅうりょく --disable_prediction -n 10
日本語入力
にほんご入力
2本ご入力
2本後入力
2本語入力
日本語
2本
日本
にほんご
2本後
```

## 変換API

`anco run`コマンドを利用して変換を行うことが出来ます。

## 辞書リーダ

`anco dict`コマンドを利用して辞書データを解析することが出来ます。

```bash
your@pc Desktop % anco dict read ア -d ./Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary/                       
=== Summary for target ア ===
- directory: ./Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary/
- target: ア
- memory?: false
- count of entry: 24189
- time for execute: 0.0378040075302124
```

`--ruby`および`--word`オプションを利用して、正規表現でフィルターをかけることが出来ます。

```bash
your@pc Desktop % anco dict read ア -d ./Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary/ --word ".*全"
=== Summary for target ア ===
- directory: ./Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary/
- target: ア
- memory?: false
- count of entry: 24189
- time for execute: 0.07062792778015137
=== Found Entries ===
- count of found entry: 3
Ruby: アキラ Word: 全 Value: -11.7107 CID: (1291, 1291) MID: 424
Ruby: アンゼン Word: 安全 Value: -7.241 CID: (1287, 1287) MID: 169
Ruby: アンシンアンゼン Word: 安心安全 Value: -11.7638 CID: (1283, 1287) MID: 17
```

`--sort`オプションを使うとエントリーの並び替えが可能です。
