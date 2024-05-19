# Zenzai

Zenzaiはニューラルかな漢字変換エンジンであり、高精度な変換を提供できるモードです。利用するには変換オプションの`zenzaiMode`を設定します。

```swift
let options = ConvertRequestOptions.withDefaultDictionary(
    // ...
    zenzaiMode: .on(weight: url, inferenceLimit: 1)
    // ...
)
```

* `weight`には`gguf`形式の重みファイルを指定します。重みファイルは[Hugging Face](https://huggingface.co/Miwa-Keita/zenz-v1)からダウンロードできます。
* `inferenceLimit`には推論回数の上限を指定します。通常`1`で十分ですが、低速でも良い変換を得たい場合は`10`程度の値にすることもできます。

## 動作環境
* M1以上のスペックのあるmacOS環境が望ましいです
* モデルサイズに依存しますが、現状150MB程度のメモリを必要とします
* Linux環境でも動作しますが、CUDAが使えない可能性があります

## 仕組み

[Zennのブログ](https://zenn.dev/azookey/articles/ea15bacf81521e)をお読みいただくのが最もわかりやすい解説です。

## 制約
現状、Zenzaiを用いた場合学習機能は無効化されます。また、予測変換にはニューラル言語モデルは用いられていません。

## 用語
* Zenzai: ニューラルかな漢字変換システム
* zenz-v1: Zenzaiで用いることのできるかな漢字変換モデル「zenz」の第1世代