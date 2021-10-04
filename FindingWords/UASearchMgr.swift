//プロトコル宣言
protocol UASearchDelegate: class {
    func msgHandler(text1: String, text2: String)
    func displayTable(_ resultList: [Result])
}
//---- UASearch.Mgrswift ----
import Cocoa
//計測構造体
struct Counter {
    var path: String = ""
    var totalFiles: Int = 0 //全ファイル数
    var targetFiles: Int = 0 //検索ファイル数
    var totalElaps: Double = 0 //合計処理時間
    var traverseElaps: Double = 0 //ファイル名取得処理時間
    var counterList = [Int]() //処理済みファイル数リスト
    //分割数の要素を作成する
    mutating func reset(number:Int){
        totalFiles = 0
        targetFiles = 0
        totalElaps = 0
        traverseElaps = 0
        counterList.removeAll()
        for i in 0 ..< number{
            counterList.append(i)
        }
    }
    let SHOW_PROGRESS = 1000 //files
    let SHOW_CAUTION = 100000 //files
    //処理済みファイル数の加算（各分割処理ごと）
    mutating func add(number:Int, count:Int){
        self.counterList[number-1] = count
    }
    //処理済みファイル数（全体）
    func totalCount()->Int{
        var sum = 0
        for count in counterList{
            sum += count
        }
        return sum
    }
}
//結果レコード構造体
struct Result {
    var fullPath: String = ""       //ファイル名（フルパス）
    var folder: String = ""         //フォルダ名
    var file: String = ""           //ファイル名
    var count: Int = 0              //ヒット件数
    var size: UInt64 = 0            //ファイルサイズ（バイト）
}
//検索条件・AND/OR
enum Condition: Int{
    case AND = 0
    case OR = 1
}
class UASearchMgr: NSObject {
    var resultList = [Result]() //結果リスト
    var searchMethod: SMethod = .RangeOf //検索方法
    var caseInsensitive: Bool = true //大文字・小文字の区別
    var globalEndCounter = 0 //並列処理終了カウンタ
    var globalCancelFlg = false //処理中止フラグ
    var incCounter =  Counter.init() //途中経過カウンタ
    weak var delegate: UASearchDelegate?  = nil  //デリゲートへの参照
    var DIVISION = 1 //並列処理の分割数
    var startDate: Date? = nil      //検索開始時刻
    var sheetController = SheetController()  //途中経過の表示シート・コントローラ
    
    //--------------------------------------------------------------------------
    // 検索 searchメソッド
    // [対象ディレクトリ] path: String
    // [検索語] keyword: String
    // [検索条件 AND/OR] condition: Bool
    // [拡張子] suffix: String
    // [拡張子の除外]　ex: Bool
    //--------------------------------------------------------------------------
    func search(path: String,
                keyword: String,
                condition: Condition,
                suffix: String,
                ex: Bool){
        self.incCounter.reset(number: DIVISION) //計測オブジェクト
        self.incCounter.path = path
        self.globalCancelFlg = false
        self.resultList.removeAll()
        self.startDate = Date() //測定開始 ---->
        //検索語：空白で分割
        let tempKeywords = keyword.components(separatedBy:CharacterSet.whitespaces)
        let keywords = stringArraytrim(tempKeywords)
        if keywords.count == 0{
            delegate?.msgHandler(text1: "キーワード未入力", text2: "")
            return
        }
        //拡張子：空白で分割
        let tempExtensions = suffix.components(separatedBy:CharacterSet.whitespaces)
        let extensions = stringArraytrim(tempExtensions)
        //ファイル名格納リスト
        let fileNameArray = NSMutableArray.init()
        //ディレクトリ存在チェック
        if !FileManager.default.fileExists(atPath: path){
            delegate?.msgHandler(text1: "ディレクトリが存在しない", text2: path)
            return
        }
        //------------------------------------------
        // 特定のディレクトリ下のファイル名を再帰的に取得する
        //------------------------------------------
        traverse(path, fileNameArray)
        incCounter.totalFiles = fileNameArray.count
        let currentDate = Date() //処理時間測定・途中経過
        if incCounter.totalFiles > incCounter.SHOW_CAUTION{
            let alert = NSAlert()
            alert.messageText = "対象ファイル数：\(incCounter.totalFiles)"
            alert.informativeText = "処理に時間がかかります。実行してよろしいですか？"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .critical
            if alert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn{
                return
            }
        }
        //ファイル名リストを分割する
        incCounter.traverseElaps = currentDate.timeIntervalSince(self.startDate!)
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.searchButton.keyEquivalent = ""
        //所定のファイル数以上の場合、検索の開始・途中経過シートを開く
        if incCounter.totalFiles > incCounter.SHOW_PROGRESS{
            appDelegate.window?.beginSheet(sheetController.window!,
                completionHandler:{(response) in
                //コールバック処理
                if response == .cancel{
                    self.globalCancelFlg = true
                    appDelegate.reset()
                    appDelegate.searchButton.keyEquivalent = "\r"
                }
            })
        }
        if fileNameArray.count < 99{
            DIVISION = 1
        }
        var unitNum = fileNameArray.count / DIVISION
        let mod =  fileNameArray.count % DIVISION
        if mod > 0{
           unitNum += 1
        }
        var unitArray =  [[String]]()
        var counter = 0;
        var unit = [String]()
        for i in 0 ..< fileNameArray.count{
            unit.append(fileNameArray[i] as! String)
            counter += 1
            if counter == unitNum{
                unitArray.append(unit)
                counter = 0
                unit.removeAll()
            }
        }
        if counter > 0{
            unitArray.append(unit)
        }
        //----------------------------------------------------------------------
        //テキスト検索処理を起動する
        self.globalEndCounter = 0
        let queue = DispatchQueue(label: "com.mikomokaru", attributes: .concurrent) //並列処理
        for i in 0 ..< DIVISION{
            //concurrentなキューイングだと i のインクリメント順にスレッドが作成されないので注意
            queue.async {
                self.searchOfUnit(number: i+1,
                                  fileNameArray: unitArray[i],
                                  keywords: keywords,
                                  condition: condition,
                                  extensions: extensions,
                                  ex: ex)
            }
        }
        return
    }
    //--------------------------------------------------------------------------
    //個々の検索処理
    //--------------------------------------------------------------------------
    private func searchOfUnit(number: Int,
                              fileNameArray: [String],
                              keywords: [String],
                              condition: Condition,
                              extensions: [String],
                              ex: Bool){
        //ファイルを読み込み、キーワードにマッチする文字列を検索する
        var resultList = [Result]()
        var counter = 0
        for file in fileNameArray{
            //中止
            if self.globalCancelFlg{
                return
            }
            counter += 1
            let url = URL.init(fileURLWithPath: file)
            //--- 対象ファイル（拡張子）の判定 ---
            //正規表現オブジェクト・拡張子による判定
            if extensions.count > 0{
                var pattern = ""
                for ext in extensions{
                    if pattern != ""{
                        pattern += "|"
                    }
                    pattern += "^" + ext.replacingOccurrences(of: "*", with: ".*") + "$"
                }
                let regex: NSRegularExpression
                do { regex = try NSRegularExpression(pattern: pattern,
                                                     options:[.caseInsensitive])
                }catch{
                    delegate?.msgHandler(text1: "正規表現オブエクト作成エラー",
                                         text2: error.localizedDescription)
                    return
                }
                if !self.isTargetFile(extent: url.pathExtension,
                                      regex: regex,
                                      exclusion: ex){
                    continue //抜ける
                }
            }
            //--- テキストマッチング ---
            var matchList = [NSRange]() //初期化
            //URLからUTIを求め、テキストファイルのみ処理対象とする。
            if let values = try? url.resourceValues(forKeys: [.typeIdentifierKey]),
                let uti = values.typeIdentifier {
                if UTTypeConformsTo(uti as CFString, kUTTypeText){
                    //テキストファイルの読み込み
                    guard let text = try? String(contentsOf: url) else{
                        print(String(format:"%@ :The file couldn't open (Shift-JIS etc..)", url.path))
                        continue
                    }
                    //カウンタのインクリメント have to do through serial
                    DispatchQueue.main.async {
                        self.incCounter.targetFiles += 1
                    }
                    //キーワードによる全文検索 拡張・String+Search を使用する
                    for i in 0..<keywords.count{
                        if self.searchMethod == .RangeOf{
                            //range(of:)
                            var mask: NSString.CompareOptions = []
                            if !caseInsensitive{
                                //大文字・小文字を区別しない
                                mask.insert(.caseInsensitive)
                            }
                            let list = text.nsRanges(of: keywords[i], options: mask)
                            if condition == Condition.AND && list.count == 0{
                                //AND検索
                                matchList.removeAll()
                                break
                            }
                            matchList += list
                        }else if self.searchMethod == .Regex{
                            //正規表現
                            var mask: NSRegularExpression.Options = []
                            if !caseInsensitive{
                                //大文字・小文字を区別しない
                                mask.insert(.caseInsensitive)
                            }
                            let list = text.searchReg(keyword: keywords[i], options: mask)
                            if condition == Condition.AND && list.count == 0{
                                //AND検索
                                matchList.removeAll()
                                break
                            }
                            matchList += list
                        }
                    }
                }
            }
            //---- 結果レコードの作成 ----
            if matchList.count > 0{
                var result = Result.init()
                result.fullPath = url.path
                result.file = url.lastPathComponent
                result.folder = url.deletingLastPathComponent().path
                result.count = matchList.count
                if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
                    let size = attr[FileAttributeKey.size] as? UInt64{
                    result.size = size
                }
                //結果レコードの追加
                resultList.append(result)
            }
            //1ファイル終了 for progress bar
            if incCounter.totalFiles > incCounter.SHOW_PROGRESS{
                if counter % 100 == 0{
                    let currentNum = counter  // fix the current number of files
                    DispatchQueue.main.async {
                        //現時点の処理ファイル数
                        self.progress(number, currentNum)
                    }
                }
            }
        }
        //終了処理
        DispatchQueue.main.async {
            self.globalEndCounter += 1 //終了フラグ
            self.finishSearch(resultList)
        }
        return
    }
    //--------------------------------------------------------------------------
    // 終了処理
    //--------------------------------------------------------------------------
    private func finishSearch(_ unitResultList: [Result]){
        //結果リストのマージ
        self.resultList += unitResultList
        //全処理が終了した
        if self.globalEndCounter == DIVISION{
            let endDate = Date() //処理時間測定終了
            incCounter.totalElaps = endDate.timeIntervalSince(self.startDate!)
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            self.logPrint(String(format:"%3ld 分割 %8.03f sec %5ld / %5ld / %6ld files " +
                                        "<traverse> %.03f sec %@ kw:[%@] cnd[%d] regex[%d]",
                                 self.DIVISION,
                                 incCounter.totalElaps,
                                 resultList.count,
                                 incCounter.targetFiles,
                                 incCounter.totalFiles,
                                 incCounter.traverseElaps,
                                 incCounter.path,
                                 appDelegate.keywordField.stringValue,
                                 appDelegate.condMatrix.selectedCell()!.tag,
                                 self.searchMethod.rawValue
                                 ))
            
            //途中経過シートを閉じる
            appDelegate.window?.endSheet(self.sheetController.window!)
            appDelegate.searchButton.keyEquivalent = "\r"
            
            //一覧表の表示・デリゲート
            delegate?.displayTable(self.resultList)
        }
    }
    //--------------------------------------------------------------------------
    // 対象ファイルの判定
    //--------------------------------------------------------------------------
    private func isTargetFile(extent: String,
                             regex: NSRegularExpression,
                             exclusion: Bool) -> Bool{
        //マッチング
        let results = regex.matches(in: extent,
                                    options: [],
                                    range: NSRange(0..<extent.count))
        if exclusion == false{
            //指定された拡張子をは対象とする
            if results.count > 0 {
                return true
            }
        }else{
            //指定された拡張子をは対象外とする
            if results.count == 0 {
                return true
            }
        }
        return false
    }
    //--------------------------------------------------------------------------
    //文字列の配列から長さゼロの文字列を除外する
    //--------------------------------------------------------------------------
    private func stringArraytrim(_ array: [String]) -> [String]{
        var newArray = [String]()
        for item in array{
            if item.count > 0{
                newArray.append(item)
            }
        }
        return newArray
    }
    //--------------------------------------------------------------------------
    // 途中経過の表示
    //--------------------------------------------------------------------------
    func progress(_ number: Int, _ count: Int){
        self.incCounter.add(number: number, count: count)
        let currentFiles = self.incCounter.totalCount()
        let rate:Double = Double(currentFiles) / Double(incCounter.totalFiles)
        self.sheetController.progInd.doubleValue = rate * 100
    }
    
    //--------------------------------------------------------------------------
    //ログ出力
    //--------------------------------------------------------------------------
    func logPrint(_ text: String){
        let log = text + "\n"
        guard let data = log.data(using: String.Encoding.utf8) else {
            return
        }
        let url = URL.init(fileURLWithPath:NSHomeDirectory() + "/Desktop/FindWordsLog.txt")
        if FileManager.default.fileExists(atPath:url.path) == false{
            if !FileManager.default.createFile(
                atPath: url.path,
                contents: "".data(using: .utf8),
                attributes: nil) {
                print("\(url.path) not created")
                return
            }
        }
        do{
            let fileHandle = try FileHandle(forWritingTo:url)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }catch{
            print(error.localizedDescription)
            return
        }
    }
}
