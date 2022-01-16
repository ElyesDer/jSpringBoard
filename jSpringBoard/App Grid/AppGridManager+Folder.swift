//
//  AppGridManager+Folder.swift
//  jSpringBoard
//
//  Created by Jota Melo on 05/08/17.
//  Copyright © 2017 jota. All rights reserved.
//

import UIKit

func print (event : Int, message : String) {
    print("__Event\(Int.random(in: 10...99)) : \(event) : \(message)")
    print("___")
}
extension AppGridManager {
    
    @discardableResult
    func showFolder(from cell: FolderCell, isNewFolder: Bool = false, startInRename: Bool = false) -> FolderViewController {
        
        self.openFolderInfo = OpenFolderInfo(cell: cell, isNewFolder: isNewFolder)
        cell.stopAnimation()
        
        let convertedFrame = cell.convert(cell.iconContainerView.frame, to: self.viewController.view)
        
        let folderViewController = self.viewController.storyboard?.instantiateViewController(withIdentifier: "FolderViewController") as! FolderViewController
        folderViewController.modalPresentationStyle = .overFullScreen
        folderViewController.isEditing = self.isEditing
        folderViewController.folder = cell.item as! Folder
//        folderViewController.currentPage = cell.currentPage
        folderViewController.sourcePoint = convertedFrame.origin
        folderViewController.startInRename = startInRename
        folderViewController.delegate = self
        
        if let dragOperation = self.currentDragOperation {
            folderViewController.dragOperationTransfer = AppDragOperationTransfer(gestureRecognizer: self.longPressRecognizer, operation: dragOperation)
            self.currentDragOperation = nil
            
            self.longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture(_:)))
            self.viewController.view.addGestureRecognizer(self.longPressRecognizer)
        }
        
        UIView.animate(withDuration: 0.25) {
            // There's aprox. 300 million lines of code where I need the
            // badge container, why don't I just make an outlet for it?
            // Honestly I could've done that in the time it took me to
            // write this comment. But nah...
            cell.badgeLabel?.superview?.alpha = 0
        }
        
        self.viewController.present(folderViewController, animated: false, completion: nil)
        return folderViewController
    }
    
    func startFolderOperation(for itemCell: HomeItemCell) {
        guard let dragOperation = self.currentDragOperation else { return }
        print(event: 100, message: #function + " TIMER Start ")
        self.folderTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(folderTimerHandler), userInfo: nil, repeats: false)
        
        dragOperation.transitionToIconPlaceholder()
        
        let folderPlaceholderView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        folderPlaceholderView.frame = itemCell.iconContainerView.frame
        
        if #available(iOS 11, *) {
            folderPlaceholderView.applyIconMask()
        } else {
            folderPlaceholderView.applyIconMaskView()
        }
        
        itemCell.contentView.insertSubview(folderPlaceholderView, belowSubview: itemCell.iconContainerView)
        
        self.cancelFolderOperation()
        if let folder = itemCell.item as? Folder, let folderCell = itemCell as? FolderCell {
            self.currentFolderOperation = FolderDropOperation(dragOperation: dragOperation, folder: folder, placeholderView: folderPlaceholderView)
            folderCell.blurView.isHidden = true
        } else if let app = itemCell.item as? App {
            self.currentFolderOperation = FolderCreationOperation(dragOperation: dragOperation, destinationApp: app, placeholderView: folderPlaceholderView)
        }
        
        itemCell.stopAnimation()
        UIView.animate(withDuration: 0.25) {
            folderPlaceholderView.transform = CGAffineTransform.identity.scaledBy(x: 1.2, y: 1.2)
            self.currentDragOperation?.placeholderView.transform = .identity
            itemCell.nameLabel?.alpha = 0
        }
    }
    
    @objc func folderTimerHandler() {
        print(event: 11, message: #function)
        guard let folderOperation = self.currentFolderOperation, !folderOperation.isDismissing else {
            print(event: 110, message: #function + " DISMISSINS ")
            return
        }
        
        self.folderTimer = nil
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.autoreverses = true
        animation.repeatCount = 2
        animation.toValue = 0.5
        animation.duration = 0.15
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.commitFolderOperation()
        }
        folderOperation.placeholderView.layer.add(animation, forKey: nil)
        CATransaction.commit()
    }
    
    func commitFolderOperation(didDrop: Bool = false) {
        guard let folderOperation = self.currentFolderOperation, !folderOperation.isDismissing else { return }
        
        // usually state is only updated when a drag operation ends
        // but folder operations need an updated state and they happen
        // during a drag operation
//        self.updateState(forPageCell: folderOperation.dragOperation.currentPageCell)
//        self.updpateVisibleCells()
//        self.updateState()
        
        if let creationOperation = folderOperation as? FolderCreationOperation {
            self.commit(folderCreationOperation: creationOperation, didDrop: didDrop)
        } else if let dropOperation = folderOperation as? FolderDropOperation {
            self.commit(folderDropOperation: dropOperation, didDrop: didDrop)
        }
    }
    
    func showFolderPostOperation(_ operation: FolderOperation,
//                                 page: Int,
                                 sourceIndex: Int, destinationIndex: Int, folderIndexPath: IndexPath, isNewFolder: Bool = false) {
        
        let folderIndexPath = IndexPath(item: destinationIndex, section: 0)
        operation.dragOperation.currentItems = self.items
        
        let folderCell = collectionView.cellForItem(at: folderIndexPath) as! FolderCell
//        let folderViewController = self.showFolder(from: folderCell, isNewFolder: isNewFolder)
//        folderViewController.openAnimationDidEndBlock = { [unowned folderViewController] in
            self.items.remove(at: sourceIndex)
            operation.dragOperation.currentItems = self.items
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteItems(at: [IndexPath(item: sourceIndex, section: 0)])
            }, completion: { _ in
//                folderCell.stopAnimation()
////                let convertedFrame = folderCell.convert(folderCell.iconContainerView.frame, to: self.viewController.view)
////                folderViewController.sourcePoint = convertedFrame.origin
//
//                if !isNewFolder {
//                    folderCell.blurView.isHidden = false
//                }
//
//                operation.placeholderView.removeFromSuperview()
                self.currentFolderOperation = nil
            })
//        }
    }
    
    func commit(folderCreationOperation operation: FolderCreationOperation, didDrop: Bool) {
        
        guard
//            let page = self.items.index(where: { $0.contains { $0 === operation.destinationApp } }),
            let sourceIndex = self.items.index(where: { $0 === operation.dragOperation.item }),
            let destinationIndex = self.items.index(where: { $0 === operation.destinationApp }),
            let sourceApp = operation.dragOperation.item as? App else { return }
        
        let newFolder = Folder(name: NSLocalizedString("New Folder", comment: ""), pages: [[operation.destinationApp, sourceApp]])
        newFolder.isNewFolder = true
        self.items[destinationIndex] = newFolder
        
        let folderIndexPath = IndexPath(item: destinationIndex, section: 0)
        operation.dragOperation.currentItems = self.items
        
        if !didDrop {
            collectionView.reloadItems(at: [folderIndexPath])
            self.showFolderPostOperation(operation,
//                                         page: page,
                                         sourceIndex: sourceIndex, destinationIndex: destinationIndex, folderIndexPath: folderIndexPath, isNewFolder: true)
            newFolder.isNewFolder = false
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                operation.dragOperation.placeholderView.alpha = 1
                operation.dragOperation.placeholderView.overlayView.alpha = 0
                operation.dragOperation.placeholderView.badgeOverlayView?.alpha = 0
            })
            // operation.dragOperation.currentPageCell.
            let destinationCell = collectionView.cellForItem(at: IndexPath(item: destinationIndex, section: 0)) as! HomeItemCell
            let iconSnapshot = destinationCell.iconContainerView.snapshotView(afterScreenUpdates: false)!
            
            // TODO : THIS LOOKS LIKE IMPORTANT FOR UI
            
            iconSnapshot.frame = destinationCell.convert(destinationCell.iconContainerView.frame, to: destinationCell)
            destinationCell.contentView.addSubview(iconSnapshot)
//
//            fatalError("Which subview should i add to")
            
            let convertedIconFrame = operation.dragOperation.placeholderView.convert(operation.dragOperation.placeholderView.iconView.frame, to: operation.dragOperation.placeholderView.superview!)
            operation.dragOperation.placeholderView.iconView.frame = convertedIconFrame
            operation.dragOperation.placeholderView.superview!.addSubview(operation.dragOperation.placeholderView.iconView)
            operation.dragOperation.placeholderView.removeFromSuperview()
            
            //            let array = Array(arrayLiteral: sourceIndex)
            collectionView.performBatchUpdates({
                collectionView.reloadItems(at: [folderIndexPath])
//                collectionView.reloadItems(at: [.init(row: sourceIndex, section: 0)])
//                collectionView.reloadData()
            }, completion: { _ in
                let folderCell = self.collectionView.cellForItem(at: folderIndexPath) as! FolderCell
                folderCell.move(view: iconSnapshot, toCellPositionAtIndex: 0)
                folderCell.move(view: operation.dragOperation.placeholderView.iconView, toCellPositionAtIndex: 1) {
                    iconSnapshot.removeFromSuperview()
                    operation.dragOperation.placeholderView.iconView.removeFromSuperview()
                    self.currentFolderOperation = nil
                    self.currentDragOperation = nil
                    self.showFolderPostOperation(operation, sourceIndex: sourceIndex, destinationIndex: destinationIndex, folderIndexPath: folderIndexPath, isNewFolder: true)
                    
                    newFolder.isNewFolder = false
                }
            })
        }
    }
    
    func commit(folderDropOperation operation: FolderDropOperation, didDrop: Bool) {
        guard
//            let page = self.items.index(where: { $0.contains { $0 === operation.folder } }),
            let sourceIndex = self.items.index(where: { $0 === operation.dragOperation.item }),
            let destinationIndex = self.items.index(where: { $0 === operation.folder }),
            let sourceApp = operation.dragOperation.item as? App else { return }
        
        let folderIndexPath = IndexPath(item: destinationIndex, section: 0)
        let folderCell = collectionView.cellForItem(at: folderIndexPath) as! FolderCell
        let item = folderCell.item as! Folder
        item.pages[0].append(sourceApp)
        
        if !didDrop {
            self.showFolderPostOperation(operation,
//                                         page: page,
                                         sourceIndex: sourceIndex, destinationIndex: destinationIndex, folderIndexPath: folderIndexPath)
            self.cancelFolderOperation()
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                operation.dragOperation.placeholderView.alpha = 1
                operation.dragOperation.placeholderView.overlayView.alpha = 0
                operation.dragOperation.placeholderView.badgeOverlayView?.alpha = 0
            })
            
            let convertedIconFrame = operation.dragOperation.placeholderView.convert(operation.dragOperation.placeholderView.iconView.frame, to: operation.dragOperation.placeholderView.superview!)
            operation.dragOperation.placeholderView.iconView.frame = convertedIconFrame
            operation.dragOperation.placeholderView.superview!.addSubview(operation.dragOperation.placeholderView.iconView)
            operation.dragOperation.placeholderView.removeFromSuperview()
            
            let folderCell = collectionView.cellForItem(at: folderIndexPath) as! FolderCell
            folderCell.move(view: operation.dragOperation.placeholderView.iconView, toCellPositionAtIndex: item.pages[0].count - 1) {
                var didRestoreSavedState = false
                if let savedState = operation.dragOperation.savedState {
                    fatalError("We saving or something")
//                    self.items = savedState
                    operation.dragOperation.currentItems = self.items
                    didRestoreSavedState = true
                } else if folderIndexPath.row < sourceIndex {
                    self.items.remove(at: sourceIndex)
                    operation.dragOperation.currentItems = self.items
                }
                
                self.currentFolderOperation = nil
                self.currentDragOperation = nil
                
                self.collectionView.performBatchUpdates({
                    folderCell.item = item
                    operation.dragOperation.placeholderView.iconView.removeFromSuperview()
                    folderCell.moveToFirstAvailablePage()
                    
                    // if the folder icon is gonna move after this drop operation
                    // we should wait until it's all updated otherwise bad things
                    // happen (bad things meaning ugly fade animations)
                    if folderIndexPath.row < sourceIndex {
                        self.collectionView.deleteItems(at: [IndexPath(item: sourceIndex, section: 0)])
                        
                        if didRestoreSavedState {
                            self.collectionView.insertItems(at: [IndexPath(item: Settings.shared.appsPerPage - 1, section: 0)])
                        }
                    }
                }, completion: { _ in
                    operation.dragOperation.placeholderView.iconView.removeFromSuperview()
                    
                    if folderIndexPath.row > sourceIndex {
                        if !didRestoreSavedState {
                            self.items.remove(at: sourceIndex)
                        }
                        
                        operation.dragOperation.currentItems = self.items
                        self.collectionView.performBatchUpdates({
                            self.collectionView.deleteItems(at: [IndexPath(item: sourceIndex, section: 0)])
                            
                            if didRestoreSavedState {
                                self.collectionView.insertItems(at: [IndexPath(item: Settings.shared.appsPerPage - 1, section: 0)])
                            }
                        }, completion: nil)
                    }
                })
            }
            
            UIView.animate(withDuration: 0.35, animations: {
                operation.placeholderView.transform = .identity
                folderCell.nameLabel?.alpha = 1
            }, completion: { _ in
                operation.placeholderView.removeFromSuperview()
                folderCell.blurView.isHidden = false
                folderCell.animate()
            })
        }
    }
    
    func cancelFolderOperation() {
//        print(event: 120, message: #function + " CANCELING FOLDER TIMER ")
        guard
            let folderOperation = self.currentFolderOperation,
            let index = self.items.index(where: { $0 === folderOperation.item }),
            let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? HomeItemCell,
            !folderOperation.isDismissing else {
                return
            }
        
        folderOperation.dragOperation.transitionFromIconPlaceholder()
        print(event: 121, message: #function + "PASSED GUARD CHECK CANCELING FOLDER TIMER ")
        self.folderTimer?.invalidate()
        self.folderTimer = nil
        self.currentFolderOperation = nil
        
        folderOperation.isDismissing = true
        
        UIView.animate(withDuration: 0.25, animations: {
            folderOperation.placeholderView.transform = .identity
            self.currentDragOperation?.placeholderView.transform = CGAffineTransform.identity.scaledBy(x: 1.3, y: 1.3)
            cell.nameLabel?.alpha = 1
        }, completion: { _ in
            if let folderCell = cell as? FolderCell {
                folderCell.blurView.isHidden = false
            }
            
            folderOperation.placeholderView.removeFromSuperview()
            cell.animate(force: true)
        })
    }
    
    func updateFolderDragOutFlags() {
        guard let operation = self.currentDragOperation else { return }
        
        if operation.placeholderView.center.y < self.collectionView.superview!.frame.minY {
            self.ignoreDragOutOnTop = true
        } else if operation.placeholderView.center.y > self.collectionView.superview!.frame.maxY {
            self.ignoreDragOutOnBottom = true
        }
    }
    
    @objc func folderRemoveTimerHandler() {
        guard let operation = self.currentDragOperation else { return }
        
//        self.updpateVisibleCells()
//        self.updateState() // forPageCell: operation.currentPageCell
//        var pageCellIndexPath = self.collectionView.indexPath(for: 0)! // operation.currentPageCell
        self.items.remove(at: operation.currentIndexPath.row)
        operation.currentItems = self.items
        collectionView.deleteItems(at: [operation.currentIndexPath])
        
        let transfer = AppDragOperationTransfer(gestureRecognizer: self.longPressRecognizer, operation: operation)
        self.delegate?.didBeginFolderDragOut(transfer: transfer, on: self)
    }
}

extension AppGridManager: FolderViewControllerDelegate {
    
    func openAnimationWillStart(on viewController: FolderViewController) {
        guard let info = self.openFolderInfo else { return }
        
        info.cell.iconContainerView?.isHidden = true
        info.cell.blurView.isHidden = true
    }
    
    func didChange(name: String, on viewController: FolderViewController) {
        guard let info = self.openFolderInfo else { return }
        info.cell.nameLabel?.text = name
    }
    
    func didSelect(app: App, on viewController: FolderViewController) {
        self.delegate?.didSelect(app: app, on: self)
    }
    
    func didEnterEditingMode(on viewController: FolderViewController) {
        self.enterEditingMode(suppressHaptic: false)
    }
    
    func didBeginFolderDragOut(withTransfer transfer: AppDragOperationTransfer, on viewController: FolderViewController) {
        guard let info = self.openFolderInfo else { return }
        
        let folderIndex = self.items.index(where: { $0 === info.folder })!
//        let pageCell = self.currentPageCell
        
        if info.folder.pages.flatMap({ $0 }).count == 0 {
            self.items.append(transfer.operation.item)
            self.items.remove(at: folderIndex)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: {
                self.perform(transfer: transfer)
                
                self.draggedItem = transfer.operation.item
//                pageCell.draggedItem = transfer.operation.item
//                pageCell.items = self.items[self.currentPage]
                
//                self.currentDragOperation?.currentPageCell = pageCell
                self.currentDragOperation?.currentItems = self.items
                
                self.currentDragOperation?.currentIndexPath = IndexPath(row: folderIndex , section: 0)
//                self.currentDragOperation?.currentIndexPath = IndexPath(item: pageCell.collectionView(pageCell.collectionView, numberOfItemsInSection: 0) - 1, section: 0)
                self.currentDragOperation?.needsUpdate = false
                
                self.collectionView.performBatchUpdates({
                    self.collectionView.deleteItems(at: [IndexPath(item: folderIndex, section: 0)])
                    self.collectionView.insertItems(at: [IndexPath(item: self.items.count - 1, section: 0)])
                }, completion: { _ in
                    // if the state is "possible" the gesture ended before the transition
                    // could be completed, so we'll force end the operation.
                    if self.longPressRecognizer.state == .possible {
                        self.endDragOperation(self.longPressRecognizer)
                    }
                })
            })
        } else {
            self.perform(transfer: transfer)
//            self.currentDragOperation?.currentPageCell = pageCell
            
            if self.items.count == Settings.shared.appsPerPage {
//                self.currentDragOperation?.savedState = self.items
//                self.moveLastItem(inPage: self.currentPage)
            }
            
            self.items.append(transfer.operation.item)
            draggedItem = transfer.operation.item
            
            var indexPathRow = collectionView(collectionView, numberOfItemsInSection: 0)
            if indexPathRow == Settings.shared.appsPerPage {
                indexPathRow -= 1
            }
            let indexPath = IndexPath(item: indexPathRow, section: 0)
            self.currentDragOperation?.currentIndexPath = indexPath
            self.currentDragOperation?.needsUpdate = false
//            items = self.items
            
            collectionView.performBatchUpdates({
                if self.currentDragOperation?.savedState == nil {
                    self.collectionView.insertItems(at: [indexPath])
                } else {
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }, completion: { _ in
                if self.longPressRecognizer.state == .possible {
                    self.endDragOperation(self.longPressRecognizer)
                }
            })
        }
        
        if info.isNewFolder {
            info.shouldCancelCreation = true
        }
    }
    
    func dismissAnimationWillStart(currentPage: Int, updatedPages: [[App]], on viewController: FolderViewController) {
        guard let info = self.openFolderInfo else { return }
        
        info.folder.pages = updatedPages
        info.cell.item = info.folder
        info.cell.moveTo(page: currentPage, animated: false)
        self.delegate?.didUpdateItems(on: self)
    }
    
    func dismissAnimationDidFinish(on viewController: FolderViewController) {
        guard let info = self.openFolderInfo else { return }
        
        viewController.dismiss(animated: false, completion: {
            self.openFolderInfo = nil
            info.cell.iconContainerView?.isHidden = false
            info.cell.blurView.isHidden = false
            
            if self.isEditing {
                info.cell.animate()
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            if self.isEditing {
                info.cell.moveToFirstAvailablePage()
            } else {
                info.cell.moveTo(page: 0, animated: true)
            }
        })
        
        UIView.animate(withDuration: 0.25) {
            info.cell.badgeLabel?.superview?.alpha = 1
        }
        
        guard let folderIndex = self.items.index(where: { $0 === info.folder }) else { return }
        if info.shouldCancelCreation {
            let cell = collectionView.cellForItem(at: IndexPath(item: folderIndex, section: 0)) as! FolderCell
            cell.animateToFolderCreationCancelState {
                self.items[folderIndex] = info.folder.pages[0][0]
//                self.items = self.items[self.currentPage]
                self.collectionView.performBatchUpdates({
                    self.collectionView.reloadItems(at: [IndexPath(item: folderIndex, section: 0)])
                }, completion: nil)
            }
        } else if info.folder.pages.reduce(0, { $0 + $1.count }) == 0 {
            self.items.remove(at: folderIndex)
            self.delete(item: info.folder)
        }
    }
}
