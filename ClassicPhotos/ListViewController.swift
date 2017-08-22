//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string:"https://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {
  
  var photos = [PhotoRecord]()
  
  let pendingOpetations = PendingOperations()
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    
    fetchPhotoDetails()
  }
  
  // #pragma mark - Table view data source
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
    
    if cell.accessoryView == nil {
      let indicator = UIActivityIndicatorView(activityIndicatorStyle:
      .gray)
      cell.accessoryView = indicator
    }
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    let photoDetails = photos[indexPath.row]
    
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    switch photoDetails.state {
    case .failed:
      indicator.stopAnimating()
      cell.textLabel?.text = "Failed to load"
    case .filtered:
      indicator.stopAnimating()
    case .new, .downloaded:
      
      // MARK： 优化一： 仅仅在不滚动时才开始图片操作，避免卡顿
      if !tableView.isDragging && !tableView.isDecelerating {
        indicator.startAnimating()
        startOperationsForPhotoRecord(photoDetails: photoDetails, indexPath: indexPath)
      }
    }
    
    return cell
  }
  
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
  
  
  // the methods for downloading and filtering images are implemented separately
  func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
    switch photoDetails.state {
    case .new:
      startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
    case .downloaded:
      startFiltrationForRecord(photoDetails: photoDetails, indexPath: indexPath)
    default:
      print("no thi ng ...")
    }
  }
  
  func startDownloadForRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
    if pendingOpetations.donwloadsInProgress[indexPath] != nil {
      return
    }
    
    let downloader = ImageDownloader(photoRecord: photoDetails)
    downloader.completionBlock = {
      if downloader.isCancelled {
        return
      }
      DispatchQueue.main.async {
        self.pendingOpetations.donwloadsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
      }
    }
    pendingOpetations.donwloadsInProgress[indexPath] = downloader
    pendingOpetations.downloadQueue.addOperation(downloader)
  }
  
  func startFiltrationForRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
      if pendingOpetations.filtrationsInProgress[indexPath] != nil {
        return
      }
      
      let filterer = ImageFiltration(photoRecord: photoDetails)
      filterer.completionBlock = {
        if filterer.isCancelled {
          return
        }
        DispatchQueue.main.async {
          self.pendingOpetations.filtrationsInProgress.removeValue(forKey: indexPath)
          self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
        }
      }
      pendingOpetations.filtrationsInProgress[indexPath] = filterer
      pendingOpetations.filtrationQueue.addOperation(filterer)
  }
  
  // an asynchronous request for .plist
  func fetchPhotoDetails() {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    let request = URLRequest(url: dataSourceURL!)
    
    URLSession.shared.dataTask(with: request) { (data, response, error) in
      
      print(response.debugDescription)
      
      if data != nil {
        
        do {
          // plist ~> [String: Any]
          let dict = try PropertyListSerialization.propertyList(from: data!, options: PropertyListSerialization.ReadOptions.mutableContainers, format: nil) as! [String: String]
          
          
          for(key, value) in dict {
            let photoLists = PhotoList(name: key, url: URL(string:value))
            let photoRecord = PhotoRecord(name:photoLists.name, url:photoLists.url)
            self.photos.append(photoRecord)
          }
        }catch {
          print("plist read error: ", error.localizedDescription)
        }
        
        self.tableView.reloadData()
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
      }
    }.resume()
  }
  
}
