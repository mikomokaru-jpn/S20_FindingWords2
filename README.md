## macOS S20_FindingWords2
## Full-text search traversing a specified directory
## Parallel processing by multithreading

Confirmed operation: MacOS 10.14.6 / Xcode 11.3.1

<img src="http://mikomokaru.sakura.ne.jp/data/B43/findingWords2.png" alt="findingWords2" title="findingWords2" width="400">

Full-text search process for a file system is expected to target the number of files on the order of thousands to tens of thousands. If you want the turn around time shorten, it is efective that you divide one process into multiple processes and execute them in parallel. As a result of modifying macOS_S18_FindingWords to parallelization and executing it, I found that a considerable effect can be expected.

## Parallelization requirements
Divide all files to be searched into 2 to 10 and perform text search processes individually in parallel for each file group, and merge the results after all the processes are completed. The results are finally sorted, so the order of each processing does not matter.

Display the progress rate of the process in the progress bar of the window. A progress rate is a ratio of a number of processed files to total number of files. However, from the point of efficiency, this function does not work with a number of files (1,000) or less.

Cancellation of processing can be accepted in the middle of processing. The process is stopped immediately when stop button is clicked.

If the number of target files is too large, the process will take a long time, so if the number of files exceeds 100,000, a warning dialog will be displayed and the user can cancel the process.
