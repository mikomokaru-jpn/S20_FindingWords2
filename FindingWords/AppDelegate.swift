//---- AppDelegate.swift ----
import Cocoa
//検索方法・range of/regex
enum SMethod: Int{
    case RangeOf = 0
    case Regex = 1
}
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate,NSWindowDelegate, UASearchDelegate {
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var tableView: NSTableView!          //結果結果出力フィールド
    @IBOutlet weak var searchButton: NSButton!          //検索ボタン
    @IBOutlet weak var pathNameField: NSTextField!      //検索フォルダ入力フィールド
    @IBOutlet weak var keywordField: NSTextField!       //検索キーワード入力フィールド
    @IBOutlet weak var extensionField: NSTextField!     //拡張子入力フィールド
    @IBOutlet weak var exclusion: NSButton!             //拡張子の除外指定
    @IBOutlet weak var countField: NSTextField!         //該当ファイル数出力フィールド
    @IBOutlet weak var condMatrix: NSMatrix!            //AND・OR検索指定
    @IBOutlet weak var elapsField: NSTextField!         //処理時間出力フィールド
    @IBOutlet weak var seachMethodMenu: NSMenu!         //検索方法メニュー
    @IBOutlet weak var applicationMenu: NSMenu!         //アプリケーションメニュー
    @IBOutlet weak var caseInsentiveMenu: NSMenu!       //大文字・小文字の区別メニュー
    @IBOutlet weak var divisionMenu: NSMenu!            //分割数メニュー

    var resultList = [Result]()                         //検索結果リスト
    var searchMgr = UASearchMgr.init()                  //テキスト検索オブジェクト
    var tableViewMgr = UATableViewMgr.init()            //テーブルビューコントローラ
    let alert = NSAlert()                               //メッセージダイアログ
    
    //ウィンドウサイズ
    var windowDef: [String:CGFloat] = ["width":500, "height":400]
    //列の識別子と並び
    var columnIds = ["folder", "file", "count", "size"]
    //列の幅
    var columnWidths: [String:CGFloat] = ["folder":120, "file":200, "count":70, "size":70]
    //列のタイトル
    let columnTitles = ["folder":"フォルダ", "file":"ファイル", "count":"語数", "size":"サイズ"]
    //ファイルを開くときのアプリケーション
    let applications = ["/Applications/Visual Studio Code.app",
                        "/Applications/Xcode.app",
                        "/Applications/mi.app",
                        "/Applications/Safari.app"]
    var currentAppIndex = 0 //選択中のアプリケーション
    //plistファイル（メニュー設定値他）
    let plistURL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/DirectoryTraverse.plist")
    //結果一覧ファイル
    let outText = URL.init(fileURLWithPath:NSHomeDirectory() + "/Documents/DirectoryTraverse.txt")
    //オープンパネルのデフォルトパス名
    let defaultOpenPath = NSHomeDirectory() + "/Desktop/NewPractice_Swift" //to change for yourself
    
    //--------------------------------------------------------------------------
    // アプリケーション起動時
    //--------------------------------------------------------------------------
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //デリゲートの引き受け
        window.delegate = self
        tableView.delegate = tableViewMgr
        tableView.dataSource = tableViewMgr
        searchMgr.delegate = self
        //背景色
        //window.contentView?.wantsLayer = true
        //window.contentView?.layer?.backgroundColor = NSColor.darkGray.cgColor
        //ユーザデフォルトの読み込み
        if let windowDef = UserDefaults.standard.dictionary(forKey: "windowDef")
               as? [String:CGFloat],
           let columnIds = UserDefaults.standard.array(forKey: "columnIds")
               as? [String],
           let columnWidths = UserDefaults.standard.dictionary(forKey: "columnWidths")
               as? [String:CGFloat]{
            self.windowDef = windowDef          //ウィンドウのサイズ
            self.columnIds = columnIds          //列の識別子と並び
            self.columnWidths = columnWidths    //列の幅
        }
        //コントロールプロパティの設定
        self.searchButton.keyEquivalent = "\r" //検索ボタンのキー登録・リターンキー
        //ウィンドウサイズ
        if let width = windowDef["width"], let height = windowDef["height"]{
            self.window.setContentSize(NSMakeSize(width, height))
        }
        //テーブルビューの列の再配置
        self.rearrange()
        //テーブルビューのファイルを開くアクションの定義
        tableView.target = self
        tableView.doubleAction = #selector(self.openFile(_:))
        //AND・OR検索指定 デフォルト:AND
        condMatrix.selectCell(withTag: Condition.AND.rawValue)
        //拡張子の除外指定 デフォルト:off
        exclusion.state = .off
        //メニュー初期設定
        self.initialSetMenu()
        //検索語フィールドをファーストレスポンダにする
        window.makeFirstResponder(keywordField)
    }
    //--------------------------------------------------------------------------
    //オープンパネルからディレクトリを選択する
    //--------------------------------------------------------------------------
    @IBAction func selectDir(_ sender: NSButton){
        let openPanel = NSOpenPanel.init()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "ディレクトリを選択する"
        
        var openPath = pathNameField.stringValue
        if openPath.count == 0{
            //パス未入力（長さゼロの文字列）
            openPath = defaultOpenPath
        }
        let url = NSURL.fileURL(withPath: openPath)
        //最初に位置付けるディレクトリパス
        openPanel.directoryURL = url
        //オープンパネルを開く
        openPanel.beginSheetModal(for: self.window, completionHandler: { (result) in
            if result == .OK{
                //ディレクトリの選択
                let selectedUrl = openPanel.urls[0]
                self.pathNameField.stringValue = selectedUrl.path
            }
        })
    }
    //--------------------------------------------------------------------------
    //検索
    //--------------------------------------------------------------------------
    @IBAction func sreach(_ sender: NSButton){
        //AND検索/OR検索の判定
        var cond = Condition.AND //default AND
        if let cell = self.condMatrix.selectedCell() {
            if cell.tag == Condition.OR.rawValue{
                cond = Condition.OR
            }
        }
        //検索を行う
        searchMgr.search(path: pathNameField.stringValue,
                         keyword: keywordField.stringValue,
                         condition: cond,
                         suffix: extensionField.stringValue,
                         ex: exclusion.bool)
       
    }
    //--------------------------------------------------------------------------
    //検索後デリゲート処理：一覧表の作成
    //--------------------------------------------------------------------------
    func displayTable(_ resultList: [Result]){
        self.resultList = resultList
        //一覧のフォルダ名を畳む
        for i in 0 ..< self.resultList.count{
            self.resultList[i].folder = resultList[i].folder.replacingOccurrences(of:
                pathNameField.stringValue, with: "")
        }
        //テーブルビューの編集・表示
        tableView.reloadData()
        tableViewMgr.sortByPath(accending: true)
        tableViewMgr.sortedTitle()
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        window.makeFirstResponder(tableView)
        //実行結果サマリ表示
        countField.stringValue = String(format:"%ld / %ld / %ld files",
                                        resultList.count,
                                        searchMgr.incCounter.targetFiles,
                                        searchMgr.incCounter.totalFiles)
        elapsField.stringValue = String(format:"%.3f sec", searchMgr.incCounter.totalElaps)
    }

    //--------------------------------------------------------------------------
    //NSWindowDelegate：ウィンドウクローズ
    //--------------------------------------------------------------------------
    func windowWillClose(_ notification: Notification) {
        //現状のUIプロパティをユーザデフォルトに保存する
        //ウィンドウのサイズ
        windowDef["width"] = self.window.contentView?.frame.size.width
        windowDef["height"] = self.window.contentView?.frame.size.height
        //テーブルビューの列の幅
        columnIds.removeAll()
        for i in 0..<self.tableView.tableColumns.count{
            let id = self.tableView.tableColumns[i].identifier.rawValue
            columnIds.append(id)
            columnWidths[id] = self.tableView.tableColumns[i].width
        }
        UserDefaults.standard.set(windowDef, forKey: "windowDef")
        UserDefaults.standard.set(columnIds, forKey: "columnIds")
        UserDefaults.standard.set(columnWidths, forKey: "columnWidths")
        //メニュー選択値と選択フォルダ名をplistに保存する
        self.savePlist()
    }
    //--------------------------------------------------------------------------
    //ファイルを開く
    //--------------------------------------------------------------------------
    @objc private func openFile(_ sender: NSButton){
        let index = tableView.selectedRow
        NSWorkspace.shared.openFile(resultList[index].fullPath,
                                    withApplication:self.applications[self.currentAppIndex])
    }
    //--------------------------------------------------------------------------
    //テーブルクリア
    //--------------------------------------------------------------------------
    @IBAction func clearTable(_ sender: NSButton){
        let alert = NSAlert()
        alert.messageText = "テーブルクリア"
        alert.informativeText = "実行してよろしいですか？"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn{
            self.reset()
        }
    }
    //--------------------------------------------------------------------------
    //テーブルビューの列の再配置（前回セッション終了時の並びを再現する）
    //--------------------------------------------------------------------------
    private func rearrange(){
        //xibで定義されたTableViewオブジェクトの列の並びを前回セッション終了時の並びに入れ替える
        var tempArray = [NSTableColumn]() //一時配列
        for i in 0 ..< columnIds.count{
            var index: Int = -1
            //xib定義上の列の位置（index）を求める
            index = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(columnIds[i]))
            if index > -1 {
                //xibで定義されたTableViewオブジェクトを取得する
                let columnObject = tableView.tableColumns[index]
                if let width = columnWidths[columnIds[i]]{
                    columnObject.width = width  //列の幅を設定する（前回セッション終了時の幅）
                }
                if let title = columnTitles[columnIds[i]]{
                    columnObject.title = title  //列のタイトルを設定する
                }
                tempArray.append(columnObject)  //一時配列に格納・順序は前回セッション終了時と同じ
            }
        }
        //TableViewオブジェクトの列の削除
        for column in tableView.tableColumns{
            tableView.removeTableColumn(column)
        }
        //一時配列から並び替えた列オブジェクトを追加する
        for column in tempArray{
            tableView.addTableColumn(column)
        }
    }
    //--------------------------------------------------------------------------
    //テーブルビューのクリア
    //--------------------------------------------------------------------------
    func reset(){
        resultList.removeAll()
        tableView.reloadData()
        tableViewMgr.sortStatus = ("", false)
        tableViewMgr.sortedTitle()
        elapsField.stringValue = ""
        countField.stringValue = ""
    }
    //--------------------------------------------------------------------------
    // NSApplicationDelegate：ウィンドウの再表示
    //--------------------------------------------------------------------------
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool{
        if !flag{
            window.makeKeyAndOrderFront(self)
        }
        return true
    }
    //--------------------------------------------------------------------------
    //メッセージダイアログ
    //--------------------------------------------------------------------------
    @objc func msgHandler(text1: String, text2: String){
        //エラーメッセージダイアログ
        let alert = NSAlert()
        alert.messageText = text1
        alert.informativeText = text2
        alert.runModal()
    }
}

