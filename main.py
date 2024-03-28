import ctypes

class KanaKanjiConverter:
    def __init__(self):
        self.anco = ctypes.cdll.LoadLibrary("/Users/miwa/Desktop/AzooKeyKanaKanjiConverter/.build/arm64-apple-macosx/release/libanco.dylib")
        self.anco.request_conversion.argtypes = [ctypes.POINTER(ctypes.c_int8), ctypes.POINTER(ctypes.c_int8)]
        self.anco.request_conversion.restype = None

    def convert(self, string: str) -> str:
        cStringUtf8 = (string + "\0").encode('utf-8')
        bufferSize = len(cStringUtf8) * 2
        cStringUtf8 = (ctypes.c_int8 * len(cStringUtf8))(*cStringUtf8)
        buffer = (ctypes.c_int8 * bufferSize)()
        self.anco.request_conversion(cStringUtf8, buffer, bufferSize)
        return bytes(buffer).decode('utf-8')
    
if __name__ == "__main__":
    converter = KanaKanjiConverter()
    print(converter.convert("にほんご")) # 日本語
    print(converter.convert("あずーきーのへんかんえんじんがうごいた")) # 日本語