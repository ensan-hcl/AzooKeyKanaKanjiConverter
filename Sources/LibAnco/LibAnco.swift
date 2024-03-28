import KanaKanjiConverterModuleWithDefaultDictionary
import struct Foundation.URL

@MainActor
private enum GlobalConverter {
    static var options: ConvertRequestOptions = .withDefaultDictionary(
        requireJapanesePrediction: true,
        requireEnglishPrediction: false,
        keyboardLanguage: .ja_JP,
        learningType: .onlyOutput,
        memoryDirectoryURL: URL(string: "none")!,
        sharedContainerURL: URL(string: "none")!,
        metadata: .init(appVersionString: "")
    )
    static let converter = {
        var converter = KanaKanjiConverter()
        converter.sendToDicdataStore(.setRequestOptions(options))
        return converter
    }()
}

@_cdecl("request_conversion")
@MainActor
public func requestConversion(_ kanaString: UnsafePointer<CChar>, resultBuffer: UnsafeMutablePointer<CChar>, bufferSize: Int) {
    var composingText = ComposingText()
    guard let swiftString = String(cString: kanaString, encoding: .utf8) else {
        resultBuffer.pointee = 0
        return
    }
    composingText.insertAtCursorPosition(swiftString, inputStyle: .direct)
    let results = GlobalConverter.converter.requestCandidates(composingText, options: GlobalConverter.options)
    let resultSwiftString = (results.mainResults.first?.text ?? "")
    // resultBufferに結果をコピーする
    guard let utf8Data = resultSwiftString.cString(using: .utf8) else {
        resultBuffer.pointee = 0
        return
    }
    resultBuffer.initialize(from: utf8Data, count: utf8Data.count)
}
