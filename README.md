## macOS_S_FindingWords2
### Full-text search traversing a specified directory Parallel processing by multithreading

Confirmed operation: MacOS 10.14.6 / Xcode 11.3.1

<img src="http://mikomokaru.sakura.ne.jp/data/B43/findingWords2.png" alt="findingWords2" title="findingWords2" width="400">

Full-text search process for a file system is expected to target the number of files on the order of thousands to tens of thousands. If you want the turn around time shorten, it is efective that you divide one process into multiple processes and execute them in parallel. As a result of modifying macOS_S18_FindingWords to parallelization and executing it, I found that a considerable effect can be expected.

### Parallelization requirements
Divide all files to be searched into 2 to 10 and perform text search processes individually in parallel for each file group, and merge the results after all the processes are completed. The results are finally sorted, so the order of each processing does not matter.

Display the progress rate of the process in the progress bar of the window. A progress rate is a ratio of a number of processed files to total number of files. However, from the point of efficiency, this function does not work with a number of files (1,000) or less.

Cancellation of processing can be accepted in the middle of processing. The process is stopped immediately when stop button is clicked.

If the number of target files is too large, the process will take a long time, so if the number of files exceeds 100,000, a warning dialog will be displayed and the user can cancel the process.

### Class structure diagram

<img src="http://mikomokaru.sakura.ne.jp/data/B43/findingWords2-2.png" alt="diagram" title="diagram" width="500">

### (1) Multi-thread processing
The parallelization of processing uses multi-thread function GCD. The queue is concurrent. Subthread processing is asynchronous in order to enable to display data to UI and to get events from UI.

After all text search processes by subthread has been completed, the list is created and displayed. These processes are implemented with delegate method.

UI operations need to be done in main thread, and if you try to do it from sub thread, you must re-queue the function to be done to main thread.

Be careful when multiple subthreads process executed concurrently update properties of an object. For example, when adding an element to an array, this process is not thread-safe and can cause a system crash due to a conflict of multiple assignments.

Then, there is a process that it first gets a currentry value of the property , updates it, and then rewrites it back the property. it is a multi-step process. So if many number of subthreads execute this process at the same time, the consistency of each process is not guaranteed, and unexpected results are likely to occur.

In such cases, you should queue the processing block to serial queue, so sequential processing is guaranteed and problems can be avoided.

In this application, as the above example, the following two processes are executed in main thread via serial queue.
* Merge the records of individual search results into the aggregation table.
* Add the number of processed files for each thread to current total number. This value is displayed in the progress bar as progress.

### (2) Processing synchronization
Wait for the end of all the search processes have been executed in parallel, and then create the list of results. This requires synchronous control. Here, a global counter is prepared, the counter is incremented each time one search process is completed, and when all the processes are completed, a delegate method that creates and displays the list of result is called.

### Execution log output
Output the following values to a log file
* Number of divisions for parallel processing
* Elapsed time
* Total number of files
* Number of files to be searched (text files that can be searched)
* Number of files matched by search
* Time taken for directory traverse
* Directory name for search
* Search keyword
* AND / OR search option
* Search method (is regular expression or not)

