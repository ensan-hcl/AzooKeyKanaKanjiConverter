#  KanaKanjiConverter API

KanaKanjiConverterのインスタンスに対して利用できるいくつかのAPIを示します。

## `setKeyboardLanguage`

これから入力しようとしている言語を設定します。このAPIを呼ぶのは必須ではありません。

英語入力の場合、この関数を入力開始前に呼ぶことで事前に必要なデータをロードすることができるため、ユーザ体験が向上する可能性があります。

## `sendToDicdataStore`

辞書データに関する情報を追加します。

### `importDynamicUserDict`

動的ユーザ辞書を登録します。`DicdataElement`構造体の配列を直接渡します。

```Swift
converter.sendToDicdataStore(.importDynamicUserDict([
    DicdataElement(word: "anco", ruby: "アンコ", cid: 1288, mid: 501, value: -5),
]))
```

`ruby`には読みを指定します。カタカナで指定してください。 `cid`はIPADIC品詞ID、`mid`は「501」としてください。`value`は`-5`から`-10`程度の範囲で設定してください。小さい値ほど変換されにくくなります。

### `forgetMemory`

特定の`Candidate`を渡すと、その`Candidate`に含まれている学習データを全てリセットします。

## `setCompletedData`

prefixとして確定された候補を与えてください。

## `updateLearningData`

確定された候補を与えると、学習を更新します。

