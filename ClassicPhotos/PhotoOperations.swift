//
//  PhotoOperations.swift
//  ClassicPhotos
//
//  Created by YongRen on 2017/8/18.
//  Copyright © 2017年 raywenderlich. All rights reserved.
//

import UIKit

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
  
//  func applySepiaFilter(_ image:UIImage) -> UIImage? {
//    let inputImage = CIImage(data:UIImagePNGRepresentation(image)!)
//    let context = CIContext(options:nil)
//    let filter = CIFilter(name:"CISepiaTone")
//    filter?.setValue(inputImage, forKey: kCIInputImageKey)
//    filter?.setValue(0.8, forKey: "inputIntensity")
//    if let outputImage = filter?.outputImage {
//      let outImage = context.createCGImage(outputImage, from: outputImage.extent)
//      return UIImage(cgImage: outImage!)
//    }
//    return nil
//    
//  }
}


struct PhotoList {
  let name: String
  let url: URL?
}
