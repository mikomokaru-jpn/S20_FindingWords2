//  AppDelegate+Lib.swift
import Cocoa

extension AppDelegate{
    //--------------------------------------------------------------------------
    //メニュー初期設定
    //--------------------------------------------------------------------------
    func initialSetMenu(){
        //メニュー・検索方法
        for item in seachMethodMenu.items{
            item.state = .off //初期化 全てoff
            item.target = self
            item.action = #selector(selectSeachMethod(_:)) //指定の変更メソッド
        }
        self.seachMethodMenu.items[0].state = .on
        searchMgr.searchMethod = .RangeOf
        //メニュー・アプリケーション
        for item in applicationMenu.items{
            item.state = .off //初期化 全てoff
            item.target = self
            item.action = #selector(selectApplication(_:))
        }
        self.applicationMenu.items[0].state = .on
        self.currentAppIndex = 0
        //メニュー・大文字・小文字の区別
        for item in caseInsentiveMenu.items{
            item.target = self
            item.action = #selector(selectCaseInsentive(_:))
            item.state = .off
        }
        caseInsentiveMenu.items[0].state = .on
        searchMgr.caseInsensitive = true
        //メニュー・並列処理
        for item in divisionMenu.items{
            item.target = self
            item.action = #selector(selectDivision(_:))
            item.state = .off
        }
        divisionMenu.items[0].state = .on
        searchMgr.DIVISION = divisionMenu.items[0].tag //分割数
        //plistを読み込み、前回セッション終了時のメニュー選択値を取得し、更新する
        if let dict = NSDictionary.init(contentsOf: plistURL){
            //検索方法
            if let value = dict["seachMethodMenu"] as? Int{
                menuSetItem(seachMethodMenu, value) //メニューの選択値の更新
                if value == 0{
                    searchMgr.searchMethod = .RangeOf
                }else{
                    searchMgr.searchMethod = .Regex
                }
            }
            //アプリケーション
            if let value = dict["applicationMenu"] as? Int{
                menuSetItem(applicationMenu, value) //メニューの選択値の更新
                currentAppIndex = value             //プロパティの更新
            }
            //大文字・小文字の区別
            if let value = dict["caseInsentiveMenu"] as? Int{
                menuSetItem(caseInsentiveMenu, value)       //メニューの選択値の更新
                searchMgr.caseInsensitive = value.boolValue    //プロパティの更新
            }
            //検索フォルダ名  AppSandbox is OFF
            if let value = dict["pathName"] as? String{
                pathNameField.stringValue = value
            }else{
                //デフォルトのパス名
                pathNameField.stringValue = defaultOpenPath
            }
            //分割数
            if let value = dict["divisionMenu"] as? Int{
                menuSetItem(divisionMenu, value)        //メニューの選択値の更新
                searchMgr.DIVISION = value              //分割数
            }
        }
    }
    //--------------------------------------------------------------------------
    //メニュー・検索方法の変更
    //--------------------------------------------------------------------------
    @objc func selectSeachMethod(_ sender: NSMenuItem){
        for item in seachMethodMenu.items{
            item.state = .off
        }
        seachMethodMenu.item(withTag: sender.tag)?.state = .on
        if sender.tag == 0{
            searchMgr.searchMethod = .RangeOf
        }else{
            searchMgr.searchMethod = .Regex
        }
    }
    //--------------------------------------------------------------------------
    //メニュー・アプリケーションの変更
    //--------------------------------------------------------------------------
    @objc func selectApplication(_ sender: NSMenuItem){
        for item in applicationMenu.items{
            item.state = .off
        }
        applicationMenu.item(withTag: sender.tag)?.state = .on
        currentAppIndex = sender.tag
    }
    //--------------------------------------------------------------------------
    //メニュー・大文字・小文字の区別の変更
    //--------------------------------------------------------------------------
    @objc func selectCaseInsentive(_ sender: NSMenuItem){
        for item in caseInsentiveMenu.items{
            item.state = .off
        }
        caseInsentiveMenu.item(withTag: sender.tag)?.state = .on
        searchMgr.caseInsensitive = sender.tag.boolValue
    }
    //--------------------------------------------------------------------------
    //メニュー・分割数の変更
    //--------------------------------------------------------------------------
    @objc func selectDivision(_ sender: NSMenuItem){
        for item in divisionMenu.items{
            item.state = .off
        }
        divisionMenu.item(withTag: sender.tag)?.state = .on
        searchMgr.DIVISION = sender.tag
    }
    //--------------------------------------------------------------------------
    //メニュー・テーブルビューのクリア
    //--------------------------------------------------------------------------
    @IBAction func clearTableView(_ sender: NSMenuItem){
        self.reset()
    }
    
    //--------------------------------------------------------------------------
    //一覧表示の出力
    //--------------------------------------------------------------------------
    @IBAction func displayAll(_ sender: NSMenuItem){
        var text = ""
        for result in resultList{
            let strCount = String(format:"%ld", result.count)
            let strSize = String(format:"%ld", result.size)
            text += result.fullPath + "\t" + strCount + "\t" + strSize + "\n"
        }
        let outText = URL.init(fileURLWithPath:NSHomeDirectory() + "/Documents/FindWords.txt")
        do{
            try text.write(to: outText, atomically: true, encoding: .utf8)
        }catch{
            alert.messageText = "ファイル出力エラー"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return
        }
        //ファイルを開く
        NSWorkspace.shared.openFile(outText.path,
                                    withApplication:self.applications[self.currentAppIndex])
    }
    
    //--------------------------------------------------------------------------
    //メニューの選択値の取得（tag valMethodue）
    //--------------------------------------------------------------------------
    func menuCurrentItem(_ menu: NSMenu) -> Int{
        for item in menu.items{
            if item.state == .on{
                return item.tag
            }
        }
        return 0
    }
    //--------------------------------------------------------------------------
    //メニューの選択値の設定（tag value）
    //--------------------------------------------------------------------------
    func menuSetItem(_ menu: NSMenu, _ tag: Int){
        for i in 0..<menu.items.count{
            if menu.items[i].tag == tag{
                menu.items[i].state = .on
            }else{
                menu.items[i].state = .off
            }
        }
    }
    //--------------------------------------------------------------------------
    //メニュー・plistへ保存する
    //--------------------------------------------------------------------------
    func savePlist(){
        let plist: NSDictionary = ["seachMethodMenu": menuCurrentItem(seachMethodMenu),
                                   "applicationMenu": menuCurrentItem(applicationMenu),
                                   "caseInsentiveMenu": menuCurrentItem(caseInsentiveMenu),
                                   "pathName": pathNameField.stringValue,
                                   "divisionMenu": menuCurrentItem(divisionMenu)]
        plist.write(to: plistURL, atomically: true)
    }
}
