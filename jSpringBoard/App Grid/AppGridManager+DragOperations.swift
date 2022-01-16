//
//  AppGridManager+DragOperations.swift
//  jSpringBoard
//
//  Created by Jota Melo on 05/08/17.
//  Copyright © 2017 jota. All rights reserved.
//

import UIKit

extension AppGridManager {
    
    @objc func handleLongGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
        
        switch gestureRecognizer.state {
        case .began:
            self.beginDragOperation(gestureRecognizer)
        case .changed:
            self.updateDragOperation(gestureRecognizer)
        default:
            self.endDragOperation(gestureRecognizer)
        }
    }
    
    func beginDragOperation(_ gestureRecognizer: UILongPressGestureRecognizer) {
        print(event: 010, message: #function )
        self.feedbackGenerator.prepare()
        var touchPoint = gestureRecognizer.location(in: self.viewController.view)
        
        // did we hit an icon?
        guard let view = self.viewController.view.hitTest(touchPoint, with: nil), Int(view.frame.size.width) == 60 && Int(view.frame.size.height) == 60 else { return }
//        let (collectionView, pageCell) = self.collectionViewAndPageCell(at: touchPoint)
        let collectionView = collectionView
        
        touchPoint = gestureRecognizer.location(in: collectionView)
        touchPoint.x -= collectionView.contentOffset.x
        
        if let indexPath = collectionView.indexPathForItem(at: touchPoint),
           let cell = collectionView.cellForItem(at: indexPath) as? HomeItemCell, let item = cell.item {
            // independently of where the user touched, we want to consider that to be the center of the cell
            // this offset will always be applied in the .changed state to get the new position for the placeholder view
            let dragOffset = CGSize(width: cell.center.x - touchPoint.x, height: cell.center.y - touchPoint.y)
            var offsettedTouchPoint = gestureRecognizer.location(in: collectionView)
            offsettedTouchPoint.x += dragOffset.width
            offsettedTouchPoint.y += dragOffset.height
            
            let placeholderView = cell.snapshotView()
            placeholderView.center = self.viewController.view.convert(offsettedTouchPoint, from: collectionView)
            self.viewController.view.addSubview(placeholderView)
            cell.contentView.isHidden = true
            
            self.enterEditingMode(suppressHaptic: false)
            print(event: 012, message: "Starting with \(self.items.map { $0.name })")
            self.currentDragOperation = AppDragOperation(placeholderView: placeholderView, dragOffset: dragOffset, item: item,
//                                                         originalPageCell: pageCell,
                                                         originalIndexPath: indexPath)
            
            UIView.animate(withDuration: 0.25, animations: {
                placeholderView.transform = CGAffineTransform.identity.scaledBy(x: 1.3, y: 1.3)
                placeholderView.alpha = 0.8
                placeholderView.deleteButtonContainer?.transform = .identity
            })
        }
    }
    
    func updateDragOperation(_ gestureRecognizer: UILongPressGestureRecognizer) {
        
        var touchPoint = gestureRecognizer.location(in: self.viewController.view)
        guard let currentOperation = self.currentDragOperation else { return }
        
//        let (collectionView, pageCell) = self.collectionViewAndPageCell(at: touchPoint)
//        let collectionView = collectionView
        touchPoint = gestureRecognizer.location(in: collectionView)
        
        let convertedTouchPoint = self.viewController.view.convert(touchPoint, from: collectionView)
        currentOperation.movePlaceholder(to: convertedTouchPoint)
        
        if currentOperation.needsUpdate {
            return
        }
        
//        touchPoint.x -= collectionView.contentOffset.x
        touchPoint.y -= collectionView.contentOffset.y
        
        //        if self.dockCollectionView == nil {
        if false {
            // print(event: 020, message: #function + "shouldStartDragOutTimer" ) // dragging out of folder
            var shouldStartDragOutTimer = false
            
            if touchPoint.y < self.collectionView.frame.minX && !self.ignoreDragOutOnTop {
                shouldStartDragOutTimer = true
            } else if touchPoint.y > self.collectionView.frame.maxX && !self.ignoreDragOutOnBottom {
                shouldStartDragOutTimer = true
            }
            
            if shouldStartDragOutTimer {
                if self.folderRemovalTimer != nil {
                    return
                }
                print(event: 021, message: #function + " Removing timer ")
                self.folderRemovalTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(folderRemoveTimerHandler), userInfo: nil, repeats: false)
                return
            }
        }
        
        self.folderRemovalTimer?.invalidate()
        self.folderRemovalTimer = nil

        var destinationIndexPath: IndexPath
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let appsPerRow = 1 // Settings.shared.appRowsOnFolder // : Settings.shared.appsPerRow
        var isEdgeCell = false

        if let indexPath = collectionView.indexPathForItem(at: touchPoint) { // , pageCell == currentOperation.currentPageCell
//            print(event: 021, message: #function + "indexPathForItem(at: touchPoint AT IndexPath : \(indexPath)")
            guard let itemCell = collectionView.cellForItem(at: indexPath) as? HomeItemCell else { return }

            let iconCenter = itemCell.iconContainerView.center
            let offset = 20 as CGFloat
            let targetRect = CGRect(x: iconCenter.x - offset, y: iconCenter.y - offset, width: offset * 4, height: offset * 4)

            let convertedPoint = itemCell.convert(touchPoint, from: collectionView)
//            print(event: 022, message: #function + "targetRect.contains(convertedPoint) = \(targetRect.contains(convertedPoint) )")
//            print(event: 022, message: #function + "IndexPath == current Index Path = \(indexPath.row == currentOperation.currentIndexPath.row )")
            
            if targetRect.contains(convertedPoint) && indexPath.row != currentOperation.currentIndexPath.row
//                && collectionView == self.collectionView
            {
                print(event: 022, message: #function + "startingFolderOperation")
                if self.currentFolderOperation != nil || currentOperation.item is Folder {
                    return
                }
                
                self.pageTimer?.invalidate()
                self.startFolderOperation(for: itemCell)
                return
            } else if convertedPoint.y < itemCell.iconContainerView.frame.minY {
                destinationIndexPath = indexPath
            } else if convertedPoint.y > itemCell.iconContainerView.frame.maxY {
                if (indexPath.row + 1) % appsPerRow == 0 {
                    destinationIndexPath = indexPath
                    isEdgeCell = true
                } else {
                    destinationIndexPath = IndexPath(item: indexPath.row + 1, section: 0)
                }
            } else {
                self.cancelFolderOperation()
                return
            }
        }
//        else { return }
        else if touchPoint.y <= flowLayout.sectionInset.top {
            print(event: 021, message: #function + "flowLayout.sectionInset.left")
            self.cancelFolderOperation()

            destinationIndexPath = IndexPath(item: 0, section: 0)
//            if collectionView != self.collectionView {
//                destinationIndexPath = IndexPath(item: 0, section: 0)
//            } else
//            if !(self.pageTimer?.isValid ?? false) && collectionView == self.collectionView {
//                self.pageTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(pageTimerHandler), userInfo: -1, repeats: false)
//                return
//            } else {
//                return
//            }
        }
//        else if touchPoint.x > collectionView.frame.size.width - flowLayout.sectionInset.right {
//            print(event: 021, message: #function + "flowLayout.sectionInset.right")
//            self.cancelFolderOperation()
//
//            if collectionView != self.collectionView {
//                if true {
//                    destinationIndexPath = IndexPath(item: 0, section: 0)
//                } else {
//                    destinationIndexPath = IndexPath(item: 0, section: 0)
//                }
//            } else if !(self.pageTimer?.isValid ?? false)
////                        && collectionView == self.collectionView
//            {
//                self.pageTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(pageTimerHandler), userInfo: 1, repeats: false)
//                return
//            } else {
//                return
//            }
//        }
        else {
            print(event: 021, message: #function + "touchPoint.x")
            touchPoint.y += 15 // maximum spacing between cells

            if let indexPath = collectionView.indexPathForItem(at: touchPoint) {
                destinationIndexPath = indexPath
//            } else if let dockCollectionView = self.dockCollectionView, collectionView == self.mainCollectionView && dockCollectionView.visibleCells.contains(currentOperation.currentPageCell) {
//                if self.items[self.currentPage].count < Settings.shared.appsPerPage {
//                    destinationIndexPath = IndexPath(item: self.items[self.currentPage].count + 1, section: 0)
//                } else {
//                    return
//                }
//            }
            } else {
                self.cancelFolderOperation()
                self.pageTimer?.invalidate()
                return
            }
        }

        self.ignoreDragOutOnTop = false
        self.ignoreDragOutOnBottom = false

        self.cancelFolderOperation()

        self.pageTimer?.invalidate()
        self.pageTimer = nil

        self.folderTimer?.invalidate()
        self.folderTimer = nil

        if destinationIndexPath.row % appsPerRow == 0 {
            isEdgeCell = true
        }

        // The behavior for dragging on the same line is different:
        // the dragged app takes the place of the app on its left
        // On other lines it takes the place of the app on its right
        let destinationLine = destinationIndexPath.row / appsPerRow
        let originalLine = currentOperation.originalIndexPath.row / appsPerRow
        if destinationLine == originalLine
//            && currentOperation.currentPageCell == currentOperation.originalPageCell
            && !isEdgeCell {
            destinationIndexPath = IndexPath(item: destinationIndexPath.row - 1, section: 0)
        }

        if destinationIndexPath.row >= collectionView.numberOfItems(inSection: 0) && destinationIndexPath.row > 0 {
            destinationIndexPath = IndexPath(item: destinationIndexPath.row - 1, section: 0)
        } else if destinationIndexPath.row == -1 {
            destinationIndexPath = IndexPath(item: 0, section: 0)
        }

        if destinationIndexPath.row != currentOperation.currentIndexPath.row {
//            if let dockCollectionView = self.dockCollectionView {
//                if collectionView == dockCollectionView && !dockCollectionView.visibleCells.contains(currentOperation.currentPageCell) {
//                    self.moveToDock(operation: currentOperation, pageCell: pageCell, destinationIndexPath: destinationIndexPath)
//                    return
//                } else if collectionView == self.mainCollectionView && dockCollectionView.visibleCells.contains(currentOperation.currentPageCell) { //&& currentOperation.originalPageCell == currentOperation.currentPageCell {
//                    self.moveFromDock(operation: currentOperation, pageCell: pageCell, destinationIndexPath: destinationIndexPath)
//                    return
//                }
//            }

            let numberOfItems = collectionView.numberOfItems(inSection: 0)
            if currentOperation.currentIndexPath.row < numberOfItems && destinationIndexPath.row < numberOfItems {
                
//                if let sourceItem = (collectionView.cellForItem(at: currentOperation.currentIndexPath) as? HomeItemCell)?.item, let destinationItem = (collectionView.cellForItem(at: destinationIndexPath) as? HomeItemCell)?.item, let sourceIndex = items.firstIndex(where: {$0._id == sourceItem._id}), let destinationIndex = items.firstIndex(where: {$0._id == destinationItem._id}) {
//                    items.swapAt( sourceIndex, destinationIndex)
//                    items.move(at: sourceIndex, to: destinationIndex)
                    
                    items.move(at: currentOperation.currentIndexPath.row, to: destinationIndexPath.row)
//                }
                
                collectionView.moveItem(at: currentOperation.currentIndexPath, to: destinationIndexPath)
                
//                updpateVisibleCells()
//                print(event: 023, message: #function + "BEFORE Swapping : \(self.items.map { $0.name })")
//                if !(self.items[destinationIndexPath.row] is Folder) {
//                    print(event: 023, message: #function + "Swapping \( currentOperation.currentIndexPath.row )  -- with -- \(destinationIndexPath.row) ")
//                    self.items.swapAt(currentOperation.currentIndexPath.row, destinationIndexPath.row)
//                } else {
//                    print(event: 023, message: #function + "Swapping")
//                }
//                print(event: 023, message: #function + "After Swapping : \(self.items.map { $0.name })")
                
//                if currentOperation is AppDragOperation {
//                print(event: 023, message: #function + "Swapping")
//                currentOperation.
//                    self.items.swapAt(currentOperation.currentIndexPath.row, destinationIndexPath.row)
//                }
//                currentOperation.endOperationParameter = (currentOperation.currentIndexPath.row, destinationIndexPath.row)
                currentOperation.currentIndexPath = destinationIndexPath
            }
        }
    }
    
//    func updpateVisibleCells() {
////        self.collectionView.cells.forEach { print(($0 as? HomeItemCell)?.nameLabel?.text) }
////        self.collectionView.getAllCells()
////        self.items = self.collectionView.cells.compactMap { ($0 as? HomeItemCell)?.item }
//    }
    
    func endDragOperation(_ gestureRecognizer: UILongPressGestureRecognizer) {
        
        print(event: 030, message: #function )
        
        if self.currentFolderOperation != nil {
            self.folderTimer?.invalidate()
            self.folderTimer = nil
            
            self.commitFolderOperation(didDrop: true)
            return
        }
        
        guard let currentOperation = self.currentDragOperation,
            let cell = collectionView.cellForItem(at: currentOperation.currentIndexPath) as? HomeItemCell
            else { return }
        
//        updpateVisibleCells()
//        self.updateState(forPageCell: currentOperation.currentPageCell)
//        self.items = currentOperation.currentItems
//        self.updateState()
        
//        if let current = currentOperation.endOperationParameter?.current, let destination = currentOperation.endOperationParameter?.destination {
//            print(event: 023, message: #function + "Swapping \(currentOperation.endOperationParameter)")
//            self.items.swapAt(current, destination)
//        }
        
        let convertedRect = collectionView.convert(cell.frame, to: self.viewController.view)
        
        // fixing possible inconsistencies
//        var visiblePageCells = [self.currentPageCell]
//        if let dockCollectionView = self.dockCollectionView, let pageCell = dockCollectionView.visibleCells[0] as? PageCell {
//            visiblePageCells.append(pageCell)
//        }
        
//        for cell in collectionView.visibleCells { // .reduce([], { $0 + $1 })
//            let cell = cell as! HomeItemCell
//            cell.nameLabel?.alpha = 1
//            cell.animate(force: true)
//        }
        print(self.items.map { $0.name })
        UIView.animate(withDuration: 0.25, animations: {
            currentOperation.placeholderView.transform = .identity
            currentOperation.placeholderView.frame = convertedRect
        }, completion: { _ in
            cell.contentView.isHidden = false
            currentOperation.placeholderView.removeFromSuperview()
            self.currentDragOperation = nil
        })
        
//        print("Stack trace: \(Thread.callStackSymbols)")
    }
    
    func moveToDock(operation: AppDragOperation, pageCell: PageCell, destinationIndexPath: IndexPath) {
        
//        if self.dockItems.count >= Settings.shared.appsPerRow {
//            return
//        }
        
        if operation.item is Folder {
            return
        }
        
//        self.dockItems.insert(operation.item, at: destinationIndexPath.row)
        
//        var didRestoreSavedState = false
//        if let savedState = operation.savedState {
//            self.items = savedState
//            operation.savedState = nil
//            didRestoreSavedState = true
//        } else {
//            self.items[self.currentPage].remove(at: operation.currentIndexPath.row)
//        }
        
//        pageCell.items = self.dockItems
//        pageCell.draggedItem = operation.item
//        pageCell.collectionView.performBatchUpdates({
//            pageCell.collectionView.insertItems(at: [destinationIndexPath])
//        }, completion: nil)
//        pageCell.updateSectionInset()
//
//        let currentPageCell = operation.currentPageCell
//        currentPageCell.items = self.items[self.currentPage]
//        currentPageCell.collectionView.performBatchUpdates({
//            currentPageCell.collectionView.deleteItems(at: [operation.currentIndexPath])
//
//            if didRestoreSavedState {
//                let indexPath = IndexPath(item: (Settings.shared.appsPerPage) - 1, section: 0)
//                currentPageCell.collectionView.insertItems(at: [indexPath])
//            }
//        }, completion: nil)
//
//        operation.currentPageCell = pageCell
//        operation.currentIndexPath = destinationIndexPath
    }
    
    func moveFromDock(operation: AppDragOperation, pageCell: PageCell, destinationIndexPath: IndexPath) {
        
//        var didMoveLastItem = false
//        if self.items[self.currentPage].count == Settings.shared.appsPerPage {
//            didMoveLastItem = true
//            operation.savedState = self.items
//            self.moveLastItem(inPage: self.currentPage)
//            
//            var indexPathsToReload: [IndexPath] = []
//            for i in 0..<self.items.count {
//                guard i != self.currentPage else { continue }
//                let indexPath = IndexPath(item: i, section: 0)
//                indexPathsToReload.append(indexPath)
//            }
//            self.mainCollectionView.reloadItems(at: indexPathsToReload)
//        }
//        
//        self.items[self.currentPage].insert(operation.item, at: destinationIndexPath.row)
////        self.dockItems.remove(at: operation.currentIndexPath.row)
//        
////        operation.currentPageCell.items = self.dockItems
//        operation.currentPageCell.draggedItem = operation.item
//        
//        operation.currentPageCell.collectionView.performBatchUpdates({
//            operation.currentPageCell.collectionView.deleteItems(at: [operation.currentIndexPath])
//        }, completion: nil)
//        operation.currentPageCell.updateSectionInset()
//        
//        pageCell.items = self.items[self.currentPage]
//        pageCell.draggedItem = operation.item
//        pageCell.collectionView.performBatchUpdates({
//            pageCell.collectionView.insertItems(at: [destinationIndexPath])
//            
//            if didMoveLastItem {
//                pageCell.collectionView.deleteItems(at: [IndexPath(item: self.items[self.currentPage].count - 1, section: 0)])
//            }
//        }, completion: nil)
//        
//        operation.currentPageCell = pageCell
//        operation.currentIndexPath = IndexPath(item: destinationIndexPath.row, section: 0)
    }
}

extension UIView
{
    public func debugView() {
        self.layer.borderWidth = 5
        self.layer.borderColor = UIColor.red.cgColor
    }
}

extension UICollectionView {
    /**
     * Returns all cells in a table
     * ## Examples:
     * tableView.cells // array of cells in a tableview
     */
    public var cells: [UICollectionViewCell] {
      (0..<self.numberOfSections).indices.map { (sectionIndex: Int) -> [UICollectionViewCell] in
          (0..<self.numberOfItems(inSection: sectionIndex)).indices.compactMap { (rowIndex: Int) -> UICollectionViewCell? in
              self.cellForItem(at: IndexPath(row: rowIndex, section: sectionIndex))
          }
      }.flatMap { $0 }
    }
    
    func getAllCells() -> [UICollectionViewCell] {

        var cells = [UICollectionViewCell]()
        // assuming tableView is your self.tableView defined somewhere
        for i in 0...self.numberOfSections-1
        {
            for j in 0...self.numberOfItems(inSection: i) - 1
            {
                if let cell = self.cellForItem(at: IndexPath(row: j, section: i)) {
                   cells.append(cell)
                }
            }
        }
        
        return cells
     }
}

extension Array where Element: Equatable {
    mutating func move(_ item: Element, to newIndex: Index) {
        if let index = index(of: item) {
            move(at: index, to: newIndex)
        }
    }

    mutating func bringToFront(item: Element) {
        move(item, to: 0)
    }

    mutating func sendToBack(item: Element) {
        move(item, to: endIndex-1)
    }
}

extension Array {
    mutating func move(at index: Index, to newIndex: Index) {
        insert(remove(at: index), at: newIndex)
    }
}
