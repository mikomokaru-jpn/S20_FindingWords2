## macOS_S_FindingWords2
### ディレクトリをトラバースするしながらファイルを全文検索する（マルチスレッドによる並列処理）

macOS Mojava 10.14.6 / Xcode 11.3.1 / Swift 5.0

<img src="http://mikomokaru.sakura.ne.jp/data/B43/findingWords2.png" alt="findingWords2" title="findingWords2" width="400">

特定のフォルダの下にあるテキストファイルをサブフォルダも含め全て検索し、指定した検索語を含んだファイルの一覧をテーブルビューに表示する。対象フォルダはオープンパネルにより指定する。

ファイルシステムに対するテキスト全文検索処理は、数千から数万のオーダーのファイルを対象とすることが想定される。ターンアラウンドタイムを短くするために、検索処理を分割し、マルチスレッドにより並列して実行する。

詳細　[http://mikomokaru.sakura.ne.jp/data/B43/findingWords2.html](http://mikomokaru.sakura.ne.jp/data/B43/findingWords2.html)
