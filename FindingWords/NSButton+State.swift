import Cocoa
//NSButton拡張・state値に応じたBool値を返す
extension NSButton {
    var bool: Bool {
        if self.state ==  NSControl.StateValue.on{
            return true
        }else{
            return false
        }
    }
}
