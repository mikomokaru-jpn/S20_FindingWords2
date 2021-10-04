//---- SheetController.swift ----
import Cocoa

class SheetController: NSWindowController {
    @IBOutlet weak var progInd: NSProgressIndicator!    //プログレスバー

    override func windowDidLoad() {
        super.windowDidLoad()
        self.progInd.maxValue = 100.0 //プログレスバー・最大値
        self.progInd.controlTint = .blueControlTint //not work why?
  
    }
    //ゲッターの定義：xibファイル名を返す
    override var windowNibName: NSNib.Name?  {
        return NSNib.Name(rawValue: "Progress")
    }
    //イニシャライザ
    init(){
        super.init(window: nil)
        self.window?.contentView?.wantsLayer = true
        self.window?.contentView?.layer?.backgroundColor = NSColor.gray.cgColor
        
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented");
    }
    //キャンセルボタン
    @IBAction func cancelButton(_ sender: NSButton){
        self.window?.sheetParent?.endSheet(self.window!,
                                           returnCode: .cancel)
    }
}
