## macOS S20_FindingWords2
## Full-text search traversing a specified directory
## Parallel processing by multithreading

Confirmed operation: MacOS 10.14.6 / Xcode 11.3.1

<img src="http://mikomokaru.sakura.ne.jp/data/B43/findingWords2.png" alt="findingWords2" title="findingWords2" width="400">

Full-text search process for a file system is expected to target the number of files on the order of thousands to tens of thousands. If you want the turn around time shorten, it is efective that you divide one process into multiple processes and execute them in parallel. As a result of modifying full-text text search tool No.1 to parallelization and executing it, I found that a considerable effect can be expected.

