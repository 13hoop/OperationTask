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
  }
  
  // #pragma mark - Table view data source
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath) 
    let rowKey = photos.allKeys[indexPath.row] as! String
    
    var image : UIImage?
    if let imageURL = URL(string:photos[rowKey] as! String),
    let imageData = try? Data(contentsOf: imageURL){
      //1
      let unfilteredImage = UIImage(data:imageData)
      //2
      image = self.applySepiaFilter(unfilteredImage!)
    }
    
    // Configure the cell...
    cell.textLabel?.text = rowKey
    if image != nil {
      cell.imageView?.image = image!
    }
    
    return cell
  }
  
  func fetchPhotoDetails() {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    URLSession.shared.dataTask(with: dataSourceURL!) { (data, response, error) in
      
      guard error == nil && data != nil else {
        print("error is : ", error?.localizedDescription)
        return
      }
            
      let parsedData = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions)
      
    }
  }
  
}
