# Windows対応について

Windows上でAzookeyKanaKanjiConverterを使用するためには、`llama.cpp`をビルドして`llama.lib`と`llama.dll`を準備する必要があります。

## 対応の背景

`llama.cpp`をCUDAに対応させるには`.cu` ファイルのビルドが必要ですが、Swiftが内部で使用している`clang`ではこれに対応していない[^1]ので、[cxx-interop](https://www.swift.org/documentation/cxx-interop/)を使うことができません。WindowsではCUDA対応を実現するために、外部のDLLに依存する形を取ることにしました。

## 実行手順

Windows上で AzookeyKanaKanjiConverter を動作させるためには、以下の手順で`llama.cpp`をビルドする必要があります。

```cmd
git clone -b ku-nlp/gpt2-japanese-char https://github.com/ensan-hcl/llama.cpp.git
cmake -B build -DBUILD_SHARED_LIBS=ON
cmake --build build --config Release
```

> [!TIP]
> CUDAに対応させてビルドする場合、`-DLLAMA_CUDA=ON`オプションを指定してビルドします。

必要なファイルは以下のパスに存在します。
```
build/bin/Release/llama.dll
build/Release/llama.lib
```

## 配置方法

AzookeyKanaKanjiConverterを使って開発を行うとき、`llama.lib` はビルド時に必要になるので、プロジェクトのルートディレクトリ（`Package.swift`と同じフォルダ）に配置します。

また、`llama.dll` は実行時に必要となるため、[DLL検索パス](https://learn.microsoft.com/ja-jp/windows/win32/dlls/dynamic-link-library-search-order#standard-search-order-for-unpackaged-apps)に沿って配置する必要があります。プロジェクトがビルドされたファイルと同じディレクトリに配置するのが適切だと考えられます。


[^1]: https://llvm.org/docs/CompileCudaWithLLVM.html#id3