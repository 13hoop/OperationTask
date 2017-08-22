# OperationTask

2种独立且分离的操作队列：`DownloadOperationQueue` 和 `FiltrationOperationQueue`

和tableView结合使用，并做了以下优化：
1 在tableView滑动时，暂停Operation操作，为流畅度做了最大的优化处置
2 对确定显示的visible cell做download／filter处理
3 对于所有操作的集合在Set中，以做缓存
4 不放过任何一个可能耗时操作，做state == cancelled 的判断，及时取消

关键部分：   
- 模型中加入枚举，方便区分状态
```swift
enum PhotoRecordState {
  case new, downloaded, filtered, failed
}

class PhotoRecord {
  let name: String
  let url: URL?
  var state = PhotoRecordState.new
  var image = UIImage(named: "Placeholder")
  
  init(name: String, url: URL?) {
    self.name = name
    self.url = url
  }
}
```
- 分离处理的2个Queue + op集合
```swift
class PendingOperations {
  lazy var donwloadsInProgress = [IndexPath: Operation]()
  lazy var downloadQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "download queue"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
  
  lazy var filtrationsInProgress = [IndexPath: Operation]()
  lazy var filtrationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "Filtration queue"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
}
```

- 继承来的download task 和 filtrarion task
```swift
class ImageDownloader: Operation {
  
  let photoRecord: PhotoRecord
  
  init(photoRecord: PhotoRecord) {
    self.photoRecord = photoRecord
  }
  
  /// https://developer.apple.com/library/content/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationObjects/OperationObjects.html#//apple_ref/doc/uid/TP40008091-CH101-SW1
  override func main() {
    
    if self.isCancelled {
      return
    }
    guard let url = self.photoRecord.url else { return }
    let imageData = try? Data(contentsOf: url)
    
    if self.isCancelled {
      return
    }
    
    if (imageData?.count)! > 0 {
      self.photoRecord.image = UIImage(data: imageData!)
      self.photoRecord.state = .downloaded
    }else {
      self.photoRecord.state = .failed
      self.photoRecord.image = UIImage(named: "Failed")
    }
  }
}

class ImageFiltration: Operation {
  let photoRecord: PhotoRecord
  
  init(photoRecord: PhotoRecord) {
    self.photoRecord = photoRecord
  }
  
  override func main() {
    if self.isCancelled {
      return
    }
    
    if self.photoRecord.state != .downloaded {
      return
    }
    
    if let filteredImage = self.applySepiaFilter(image: self.photoRecord.image!) {
      self.photoRecord.image = filteredImage
      self.photoRecord.state = .filtered
    }
  }
  
  // sepia tone 烏賊色調色/棕褐色调
  func applySepiaFilter(image: UIImage) -> UIImage? {
    let inputImage = CIImage(data: UIImagePNGRepresentation(image)!)
    if self.isCancelled {
      return nil
    }
    let context = CIContext(options: nil)
    let filter = CIFilter(name: "CISepiaTone")
    filter?.setValue(inputImage, forKey: kCIInputImageKey)
    filter?.setValue(0.8, forKey: "InputIntensity")
    let outputImage = filter?.outputImage
    
    if self.isCancelled {
      return nil
    }
    
    let outImage = context.createCGImage(outputImage!, from: (outputImage?.extent)!)
    let returnImage = UIImage(cgImage: outImage!)
    return returnImage
  }
```

优化部分:
- 利用 scrollView Delegate 在适当的时候 suspend／resume task
```swift
//MARK: -- scrollDelegate --: cancle and suspend/resume task
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    suspendAllOperations()
  }
  
  override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      loadImagesForOnscreenCells()
      resumeAllOperations()
    }
  }
  
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    loadImagesForOnscreenCells()
    resumeAllOperations()
  }
  
  func suspendAllOperations() {
    pendingOpetations.downloadQueue.isSuspended = true
    pendingOpetations.filtrationQueue.isSuspended = true
  }
  
  func resumeAllOperations() {
    pendingOpetations.downloadQueue.isSuspended = false
    pendingOpetations.filtrationQueue.isSuspended = false
  }
  
  /*
    核心方法：
      对 visible indexPath 进行处理， 采用最简单的处理方式 -- 统一先cancelled，在将 visible 部分 start
  */
  func loadImagesForOnscreenCells() {
    if let pathsArray = tableView.indexPathsForVisibleRows {
      let allPendingOperations = Set(pendingOpetations.donwloadsInProgress.keys)
      allPendingOperations.union(pendingOpetations.filtrationsInProgress.keys)
    
      var toBeCancelled = allPendingOperations
      let visiblePaths = Set(pathsArray)
      toBeCancelled.subtract(allPendingOperations)
      
      var toBeStarted = visiblePaths
      toBeStarted.subtract(allPendingOperations)
      
      for indexPath in toBeCancelled {
        
        if let pendingDownload = pendingOpetations.donwloadsInProgress[indexPath] {
          pendingDownload.cancel()
        }
        pendingOpetations.donwloadsInProgress.removeValue(forKey: indexPath)
        
        if let pendingFiltration = pendingOpetations.filtrationsInProgress[indexPath] {
          pendingFiltration.cancel()
        }
        pendingOpetations.filtrationsInProgress.removeValue(forKey: indexPath)
      }
    
      for indexPath in toBeStarted {
        let recordToProcess = self.photos[indexPath.row]
        startOperationsForPhotoRecord(photoDetails: recordToProcess, indexPath: indexPath)
      }
    }
    
  }
  ```
