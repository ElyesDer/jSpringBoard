//
//  FolderCell.swift
//  jSpringBoard
//
//  Created by Jota Melo on 15/06/17.
//  Copyright © 2017 jota. All rights reserved.
//

import UIKit

class FolderCell: HomeItemCell {
    
    @IBOutlet var collectionView: UICollectionView!
//    @IBOutlet var blurView: UIVisualEffectView!
    
//    var currentPage: Int {
//        return Int(self.collectionView.contentOffset.x) / Int(self.collectionView.frame.size.width)
//    }
    
    private var items: [App] = [] {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    public var isEditing : Bool = false
    var draggedItem: HomeItem?
    
    private var placeholderView: UIView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
    }
    
    override func updateUI() {
        super.updateUI()
        guard let folder = self.item as? Folder else { return }
        
        // when creating a new folder the blur mask needs to
        // be created immediatly beucase in this case it does
        // work and to prevent weird glithces in the animation
        // (check large comment on the bottom of PageCell for more)
        // (and yes this is a GOTO COMMENT pardon me)
//        if folder.isNewFolder && self.blurView.mask == nil {
//            if #available(iOS 11, *) {
//                self.blurView.applyIconMask()
//            } else {
//                self.blurView.applyIconMaskView()
//            }
//        }
        
        // cleaning up possible mess from animateToFolderCreationCancelState
        self.placeholderView?.removeFromSuperview()
        self.containerView.transform = .identity
        
        self.items = folder.items
        self.collectionView.reloadData()
    }
    
    override func leaveEditingMode() {
        super.leaveEditingMode()
        
        if let folder = self.item as? Folder, self.items.count == 0 {
            self.items.removeLast()
            folder.items = self.items
            self.collectionView.reloadData()
        }
    }
    
    override func snapshotView() -> HomeItemCellSnapshotView {
        // this needs to be overridden because taking snapshots of a UIVisualEffectView
        // is not that easy. As Apple notes here:
        // https://developer.apple.com/documentation/uikit/uivisualeffectview
        // "To take a snapshot of a view hierarchy that contains a UIVisualEffectView
        // you must take a snapshot of the entire UIWindow ou UIScreen that contains it."
        // So I thought it was better to recreate that blur in the FolderCell snapshot,
        // by grabbing the part of the wallpaper right behind it, creating another
        // UIVisualEffectView etc.
        
//        self.blurView.isHidden = true
        let snapshotView = super.snapshotView()
//        self.blurView.isHidden = false
        
        let convertedIconFrame = self.convert(self.containerView.frame, to: self.superview!)
        let wallpaperSnapshot = Settings.shared.snapshotOfWallpaper(at: convertedIconFrame)!
        
        let wallpaperImageView = UIImageView(image: wallpaperSnapshot)
        wallpaperImageView.frame = snapshotView.iconView.frame
        wallpaperImageView.clipsToBounds = true
        wallpaperImageView.applyIconMask()
        snapshotView.insertSubview(wallpaperImageView, belowSubview: snapshotView.iconView)
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurView.frame = wallpaperImageView.frame
        
        // if I don't do this the image leaks out of the blur a little
        // bit (exactly 1px (yes, pixel)) on the plus models
        if UIScreen.main.scale == 3 {
            blurView.frame.size.width += (1 / 3)
        }
        
        snapshotView.insertSubview(blurView, aboveSubview: wallpaperImageView)
        
        if #available(iOS 11, *) {
            blurView.applyIconMask()
        } else {
            blurView.applyIconMaskView()
        }
        
        return snapshotView
    }
    
    func moveToFirstAvailablePage(animated: Bool = true) {
        
        if let folder = self.item as? Folder, self.items.count > 0 {
            
//            folder.items.append([])
//            self.items.append([])
        }
        
        let appsPerPage = Settings.shared.appsPerPageOnFolder
        for (index, page) in self.items.enumerated() {
//            if page.count < appsPerPage {
////                fatalError("MEH ?")
//                if index != 0 {
//                    self.moveTo(page: 0, animated: animated)
//                }
//
//                break
//            }
        }
    }
    
    func moveTo(page: Int, animated: Bool) {
        guard page < self.items.count else { return }
        
        let indexPath = IndexPath(item: page, section: 0)
        self.collectionView.scrollToItem(at: indexPath, at: .left, animated: animated)
    }
    
    func move(view: UIView, toCellPositionAtIndex index: Int, completion: (() -> Void)? = nil) {
        guard
            let currentItemCell = self.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? HomeItemCell,
              let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
            let layoutAttributes = flowLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)) else {
                return
                
            }
        
        // when we're at a blank page that's ≠ 0, layoutAttributesForItem.frame will return
        // x = 0 for the first item. Why? Who the fuck knows, but let's adjust it.
        if layoutAttributes.frame.minX == 0 {
            layoutAttributes.frame.origin.x = flowLayout.sectionInset.left
        }
        
        let convertedRect1 = self.convert(layoutAttributes.frame, from: currentItemCell)
        let convertedRect2 = self.convert(convertedRect1, to: view.superview!)
        
        UIView.animate(withDuration: 0.35, animations: {
            view.frame = convertedRect2
        }, completion: { _ in
            completion?()
        })
    }
    
    // what the hell is this name really
    func animateToFolderCreationCancelState(completion: @escaping () -> Void) {
        guard let currentPageCell = self.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? PageCell,
            let itemCell = currentPageCell.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? HomeItemCell else { return }
        
        let convertedRect1 = currentPageCell.convert(itemCell.containerView!.frame, from: itemCell)
        let convertedRect2 = self.convert(convertedRect1, from: currentPageCell)
        
        let imageView = UIImageView(frame: convertedRect2)
//        imageView.image = itemCell.iconImageView!.image
        imageView.applyIconMask()
        self.contentView.addSubview(imageView)
//        itemCell.iconImageView!.isHidden = true
        
        UIView.animate(withDuration: 0.55, animations: {
            imageView.transform = .transform(rect: imageView.frame, to: self.containerView.frame)
            self.containerView.transform = CGAffineTransform.identity.scaledBy(x: 0.01, y: 0.01)
//            self.nameLabel?.alpha = 0
        }, completion: { _ in
            self.placeholderView = imageView
//            itemCell.iconImageView!.isHidden = false
            completion()
        })
    }
}

extension FolderCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return .init(width: self.collectionView.frame.width - 50, height: 80)
    }
}

extension FolderCell: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AppCell", for: indexPath) as! HomeItemCell
        let app = self.items[indexPath.row]
        if self.isEditing {
            cell.animate()
            cell.enterEditingMode()
        } else {
            cell.stopAnimation()
            cell.leaveEditingMode()
        }
        
        if let draggedItem = self.draggedItem, draggedItem === app {
            cell.contentView.isHidden = true
        } else {
            cell.contentView.isHidden = false
        }
        
        cell.item = app
//        cell.delegate = self
        
        return cell
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        self.delegate?.didSelect(cell: collectionView.cellForItem(at: indexPath) as! HomeItemCell, on: self)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
//        if let cell = cell as? FolderCell, cell.blurView.mask == nil {
//            // This most definitely will go wrong sometime (likely in older devices),
//            // or even cause visible glitches on modern devices when showing a folder
//            // cell because apparently blur is fucking hard.
//            // Problem: a FolderCell's background is blurred, but it needs to be
//            // masked with the default icon mask. You can't mask the layer of a
//            // UIVisualEffectView, it'll just break (just like when you mess with
//            // its alpha). You have to set the maskView for it to work. So far ok,
//            // but the problem is now a different one: when to set that mask?
//            // If you set it on awakeFromNib it will just make the effect disappear
//            // completely. Not even broken, just invisible. Apparently I have to wait
//            // until the cell is at least a little bit on screen for that to work.
//            // I tried putting it in didMoveToWindow, didMoveToSuperview etc, nothing.
//            // So I just use my default hack: wait.
//            // It might have something to do with this offscreen pass stuff mentioned here:
//            // https://forums.developer.apple.com/thread/50854#159049
//            // It must be fun making UIVisualEffectView
//            // (note: on iOS 11 settings UIView's mask just doesn't work anymore on the visual
//            // effect view, but masking the layer does! Go figure)
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
//                if #available(iOS 11, *) {
//                    cell.blurView.applyIconMask()
//                } else {
//                    cell.blurView.applyIconMaskView()
//                }
//            })
//        }
    }
}

// this is AppCell delegates
//extension FolderCell: UICollectionViewDataSource, UICollectionViewDelegate {
//
//    func numberOfSections(in collectionView: UICollectionView) -> Int {
//        return 1
//    }
//
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return self.items.count
//    }
//
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCell", for: indexPath) as! PageCell
//        cell.draggedItem = nil
//        cell.items = self.items[indexPath.row]
//        cell.collectionView.reloadData()
//        return cell
//    }
//}

