//
//  AppGridManager.swift
//  jSpringBoard
//
//  Created by Jota Melo on 18/06/17.
//  Copyright © 2017 jota. All rights reserved.
//

import UIKit

protocol AppGridManagerDelegate: class {
    func didUpdateItems(on manager: AppGridManager)
    func didUpdate(pageCount: Int, on manager: AppGridManager)
    func didMove(toPage page: Int, on manager: AppGridManager)
    func collectionViewDidScroll(_ collectionView: UICollectionView, on manager: AppGridManager)
    
    func didEnterEditingMode(on manager: AppGridManager)
    func didBeginFolderDragOut(transfer: AppDragOperationTransfer, on manager: AppGridManager)
    
    func didDelete(item: HomeItem, on manager: AppGridManager)
    func didSelect(app: App, on manager: AppGridManager)
//    func openSettings(fromSnapshotView snapshotView: UIView, on manager: AppGridManager)
}

class AppGridManager: NSObject {
    
    weak var delegate: AppGridManagerDelegate?
    
//    var currentPage: Int {
//        return Int(self.mainCollectionView.contentOffset.x) / Int(self.mainCollectionView.frame.size.width)
//    }
//    var currentPageCell: PageCell {
//        let visibleCells = self.mainCollectionView.visibleCells
//        if visibleCells.count == 0 {
//            return self.mainCollectionView.subviews[0] as! PageCell
//        } else {
//            return visibleCells[0] as! PageCell
//        }
//    }
    
    unowned var viewController: UIViewController
    unowned var collectionView: UICollectionView
//    weak var dockCollectionView: UICollectionView?
    var longPressRecognizer: UILongPressGestureRecognizer
    var threeDTouchRecognizer: ThreeDTouchGestureRecognizer
    
    var items: [HomeItem] {
        didSet {
            self.delegate?.didUpdate(pageCount: self.items.count, on: self)
            self.delegate?.didUpdateItems(on: self)
            
            print(event: 012, message: "Starting with \(self.items.map { $0.name })")
        }
    }
    
//    var dockItems: [HomeItem] {
//        didSet {
//            self.delegate?.didUpdateItems(on: self)
//        }
//    }
    
    var feedbackGenerator = UIImpactFeedbackGenerator()
    
    var isEditing = false
    var draggedItem: HomeItem?
    
    var mode: PageMode = .regular {
        didSet {
            self.updateLayout()
        }
    }
    
    var pageTimer: Timer?
    var folderTimer: Timer?
    var folderRemovalTimer: Timer?
    
    var currentDragOperation: AppDragOperation?
    var currentFolderOperation: FolderOperation?
    var current3DTouchOperation: App3DTouchOperation?
    var openFolderInfo: OpenFolderInfo?
    
    // when you drag an app to a folder and when the folder opens
    // the app happens to be just outside the folder region we have
    // to ignore the default "begin drag out" action.
    var ignoreDragOutOnTop = false
    var ignoreDragOutOnBottom = false
    
    init(viewController: UIViewController,
         mainCollectionView: UICollectionView,
         items: [HomeItem]
//         dockCollectionView: UICollectionView? = nil, dockItems: [HomeItem] = []
    ) {
        
        self.viewController = viewController
        
        self.collectionView = mainCollectionView
//        self.dockCollectionView = dockCollectionView
        
        self.items = items
//        self.dockItems = dockItems
        
        self.longPressRecognizer = UILongPressGestureRecognizer()
        self.threeDTouchRecognizer = ThreeDTouchGestureRecognizer()
        self.threeDTouchRecognizer.cancelsTouchesInView = true
        
        super.init()
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
//        self.collectionView.prefetchDataSource = self
            
//        self.dockCollectionView?.dataSource = self
//        self.dockCollectionView?.delegate = self
        
        self.longPressRecognizer.addTarget(self, action: #selector(handleLongGesture(_:)))
        self.threeDTouchRecognizer.addTarget(self, action: #selector(handle3DTouchGesture(_:)))
        self.viewController.view.addGestureRecognizer(self.threeDTouchRecognizer)
        self.viewController.view.addGestureRecognizer(self.longPressRecognizer)
    }
    
    // don't really like this name
//    func collectionViewAndPageCell(at point: CGPoint) -> (collectionView: UICollectionView, cell: PageCell) {
//
//        let collectionView: UICollectionView
////        if let dockCollectionView = self.dockCollectionView, dockCollectionView.frame.contains(self.viewController.view.convert(point, to: dockCollectionView)) {
////            collectionView = dockCollectionView
////        } else {
//            collectionView = self.mainCollectionView
////        }
//
//        let convertedPoint = self.viewController.view.convert(point, to: collectionView)
//        if let indexPath = collectionView.indexPathForItem(at: convertedPoint), let cell = collectionView.cellForItem(at: indexPath) as? PageCell {
//            return (collectionView, cell)
//        } else {
//            return (collectionView, collectionView.visibleCells[0] as! PageCell)
//        }
//    }
    
    func enterEditingMode(suppressHaptic: Bool) {
        guard !self.isEditing else { return }
        
        if !suppressHaptic {
            self.feedbackGenerator.impactOccurred()
        }
        
        self.isEditing = true
        self.viewController.view.removeGestureRecognizer(self.threeDTouchRecognizer)
        
        for cell in self.collectionView.visibleCells {
            if let cell = cell as? HomeItemCell {
                cell.enterEditingMode()
            }
        }
        
        self.enterEditingMode()
        
        // THIS ADDS A BLANK PAGE ON EDIT MODE
//        if self.items[self.items.count - 1].count > 0 {
//            self.items.append([])
//            self.mainCollectionView.insertItems(at: [IndexPath(item: self.items.count - 1, section: 0)])
//        }
        
        self.delegate?.didEnterEditingMode(on: self)
    }
    
    func leaveEditingMode(suppressHaptic: Bool) {
        guard self.isEditing else { return }
        
        self.isEditing = false
        self.viewController.view.addGestureRecognizer(self.threeDTouchRecognizer)
        
        self.leaveEditingMode()
//        for cell in self.mainCollectionView.visibleCells {
//            let cell = cell as! PageCell
//            cell.leaveEditingMode()
//        }
        
        for cell in self.collectionView.visibleCells {
            if let cell = cell as? HomeItemCell {
                cell.leaveEditingMode()
            }
        }
        
        // THIS REMOVES THE BLANK PAGE ON EDIT MODE
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//            if self.items[self.items.count - 1].count == 0 {
//                self.items.removeLast()
//                self.mainCollectionView.deleteItems(at: [IndexPath(item: self.items.count, section: 0)])
//            }
//        }
    }
    
    @objc func pageTimerHandler(_ timer: Timer) {
        guard let currentOperation = self.currentDragOperation, let offset = timer.userInfo as? Int else { return }

        self.pageTimer = nil
        guard let currentIndex = self.items.index(where: { $0 === currentOperation.item }) else {
            return
        }
        let currentPageInitialCount = self.items.count
//        let nextPage = self.currentPage + offset

//        if nextPage < 0 || nextPage > self.items.count - 1 {
//            return
//        }

        if let savedState = currentOperation.savedState?.first {
            self.items = savedState
            currentOperation.savedState = nil
        } else {
            self.items.remove(at: currentIndex)
        }

        let appsPerPage = Settings.shared.appsPerPageOnFolder
        if self.items.count == appsPerPage {
//            currentOperation.savedState = self.items
//            self.moveLastItem(inPage: nextPage)
        }

        self.items.append(currentOperation.item)

        currentOperation.currentItems = self.items
        currentOperation.needsUpdate = true

        if
//            currentOperation.currentPageCell == currentOperation.originalPageCell &&
            self.items.count < currentPageInitialCount {
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteItems(at: [IndexPath(item: currentIndex, section: 0)])
            }, completion: nil)
        } else {
            self.collectionView.reloadData()
        }

//        var newContentOffset = self.mainCollectionView.contentOffset
//        newContentOffset.x = self.mainCollectionView.frame.width * CGFloat(self.currentPage + offset)
//        self.mainCollectionView.setContentOffset(newContentOffset, animated: true)
    }
    
    // moves last item in page to next and rearranges next pages if needed
//    func moveLastItem(inPage page: Int) {
//
//        var currentPage = self.items[page + 1]
//        currentPage.insert(self.items[page].removeLast(), at: 0)
//        self.items[page + 1] = currentPage
//
//        let appsPerPage = Settings.shared.appsPerPageOnFolder
//        if currentPage.count > appsPerPage {
//            self.moveLastItem(inPage: page + 1)
//        }
//    }
    
    func updateState() { // forPageCell pageCell: PageCell
        
//        var collectionView: UICollectionView
//        if let dockCollectionView = self.dockCollectionView, dockCollectionView.visibleCells.contains(pageCell) {
//            collectionView = dockCollectionView
//        } else {
//            collectionView = self.mainCollectionView
//        }
        
//        var items: [HomeItem] = []
//        for i in 0..<collectionView.visibleCells.count {
//            let indexPath = IndexPath(item: i, section: 0)
//            if let cell = collectionView.cellForItem(at: indexPath) as? HomeItemCell, let item = cell.item {
//                items.append(item)
//            }
//        }
//        
//        self.items = items
        print(self.items)
        // TODO : THIS DIDNT GET WAT IS DOING
//        if collectionView == self.mainCollectionView {
//            guard let pageIndexPath = collectionView.indexPath(for: pageCell) else { return }
//            self.items = items
//        }
//        else {
//            self.dockItems = items
//        }
        
//        pageCell.items = items
    }
    
    func perform(transfer: AppDragOperationTransfer) {
        
        self.viewController.view.removeGestureRecognizer(self.longPressRecognizer)
        
        self.longPressRecognizer = transfer.gestureRecognizer
        self.longPressRecognizer.removeTarget(nil, action: nil)
        self.longPressRecognizer.addTarget(self, action: #selector(handleLongGesture(_:)))
        self.viewController.view.addGestureRecognizer(self.longPressRecognizer)
        
        self.currentDragOperation = transfer.operation.copy()
        self.currentDragOperation?.needsUpdate = true
        UIApplication.shared.keyWindow!.addSubview(transfer.operation.placeholderView)
    }
    
    func homeAction() {
        if self.isEditing {
            self.leaveEditingMode()
        }
//        else if self.currentPage > 0 && self.viewController.presentedViewController == nil {
//            self.mainCollectionView.setContentOffset(.zero, animated: true)
//        }
    }
}

// MARK: - Scroll View delegate

extension AppGridManager: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.frame.width
        self.delegate?.didMove(toPage: Int(roundf(Float(page))), on: self)
//        self.delegate?.collectionViewDidScroll(self.mainCollectionView, on: self)
    }
}

// MARK: - Page Cell delegate

//extension AppGridManager: PageCellDelegate {
//
//    func didSelect(cell: HomeItemCell, on pageCell: PageCell) {
//
//        if let cell = cell as? FolderCell {
//            self.showFolder(from: cell)
//        } else if let item = cell.item as? App, item.bundleID == "com.apple.Preferences" && !self.isEditing {
//            var convertedFrame = self.mainCollectionView.convert(cell.iconContainerView.frame, from: cell)
//            convertedFrame.origin.x -= self.mainCollectionView.contentOffset.x
//            let iconSnapshot = cell.iconContainerView.snapshotView(afterScreenUpdates: true)!
//            iconSnapshot.frame = convertedFrame
////            self.delegate?.openSettings(fromSnapshotView: iconSnapshot, on: self)
//        } else if let item = cell.item as? App, !self.isEditing {
//            self.delegate?.didSelect(app: item, on: self)
//        }
//    }
//
//    func didTapDelete(forItem item: HomeItem, on pageCell: PageCell) {
//
//        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: nil)
//        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { action in
//            self.updateState(forPageCell: pageCell)
//            if self.mainCollectionView.visibleCells.contains(pageCell), let indexPath = self.mainCollectionView.indexPath(for: pageCell), let itemIndex = self.items[indexPath.row].index(where: { $0 === item }) {
//                pageCell.items = self.items[indexPath.row]
//                self.items[indexPath.row].remove(at: itemIndex)
//            }
////            else if let dockCollectionView = self.dockCollectionView, dockCollectionView.visibleCells.contains(pageCell), let itemIndex = self.dockItems.index(where: { $0 === item }) {
////                pageCell.items = self.dockItems
////                self.dockItems.remove(at: itemIndex)
////            }
//
//            pageCell.delete(item: item)
//            self.delegate?.didDelete(item: item, on: self)
//        }
//
//        let alertController = UIAlertController(title: NSLocalizedString("Delete \"\(item.name)\"?", comment: ""), message: NSLocalizedString("Deleting this app will also delete its data.", comment: ""), preferredStyle: .alert)
//        alertController.addAction(cancelAction)
//        alertController.addAction(deleteAction)
//        alertController.preferredAction = deleteAction
//        self.viewController.present(alertController, animated: true, completion: nil)
//    }
//}

extension AppGridManager : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let folder = self.items[indexPath.row] as? Folder {
            return .init(width: 300, height: 89 * ( folder.pages.first?.count ?? 1 ) )
        } else if let _ = self.items[indexPath.row] as? App {
            return .init(width: 300, height: 89)
        }
        return .zero
    }
}

// MARK: - Collection View delegate / data source

extension AppGridManager: UICollectionViewDataSource, UICollectionViewDelegate {
    
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if let folder = self.items[indexPath.row] as? Folder {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FolderCell", for: indexPath) as! FolderCell
            cell.item = folder
            
            if self.isEditing {
                cell.animate()
                cell.enterEditingMode()
                cell.moveToFirstAvailablePage(animated: false)
            } else {
                cell.stopAnimation()
                cell.leaveEditingMode()
            }
            
            if let draggedItem = self.draggedItem, draggedItem === folder {
                cell.contentView.isHidden = true
            } else {
                cell.contentView.isHidden = false
            }
            
            return cell
        } else if let app = self.items[indexPath.row] as? App {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AppCell", for: indexPath) as! HomeItemCell
            
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
//            cell.delegate = self
            
//            if self.mode == .dock && Settings.shared.isD22 {
//                cell.nameLabel?.isHidden = true
//            }
            
            return cell
        }
        
        // not really possible
        return collectionView.dequeueReusableCell(withReuseIdentifier: "wat", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        self.delegate?.didSelect(cell: collectionView.cellForItem(at: indexPath) as! HomeItemCell, on: self)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        if let cell = cell as? FolderCell, cell.blurView.mask == nil {
            // This most definitely will go wrong sometime (likely in older devices),
            // or even cause visible glitches on modern devices when showing a folder
            // cell because apparently blur is fucking hard.
            // Problem: a FolderCell's background is blurred, but it needs to be
            // masked with the default icon mask. You can't mask the layer of a
            // UIVisualEffectView, it'll just break (just like when you mess with
            // its alpha). You have to set the maskView for it to work. So far ok,
            // but the problem is now a different one: when to set that mask?
            // If you set it on awakeFromNib it will just make the effect disappear
            // completely. Not even broken, just invisible. Apparently I have to wait
            // until the cell is at least a little bit on screen for that to work.
            // I tried putting it in didMoveToWindow, didMoveToSuperview etc, nothing.
            // So I just use my default hack: wait.
            // It might have something to do with this offscreen pass stuff mentioned here:
            // https://forums.developer.apple.com/thread/50854#159049
            // It must be fun making UIVisualEffectView
            // (note: on iOS 11 settings UIView's mask just doesn't work anymore on the visual
            // effect view, but masking the layer does! Go figure)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                if #available(iOS 11, *) {
                    cell.blurView.applyIconMask()
                } else {
                    cell.blurView.applyIconMaskView()
                }
            })
        }
    }
    
    
    //    func numberOfSections(in collectionView: UICollectionView) -> Int {
    //        return 1
    //    }
    //
    //    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    //
    //        if collectionView == self.mainCollectionView {
    //            return self.items.count
    //        } else {
    //            return 1
    //        }
    //    }
    //
    //    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    //
    //        let items = self.items[indexPath.row]
    //
    //        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCell", for: indexPath) as! PageCell
    //        cell.items = items
    //        cell.draggedItem = self.currentDragOperation?.item
    //        cell.delegate = self
    //        cell.collectionView.reloadData()
    //
    //        if false {
    //            cell.mode = .folder
    //        } else {
    //            cell.mode = collectionView == self.mainCollectionView ? .regular : .dock
    //        }
    //
    //        return cell
    //    }
    //
    //    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    //
    //        let cell = cell as! PageCell
    //
    //        if let currentOperation = self.currentDragOperation, currentOperation.needsUpdate {
    //            cell.items = self.items[indexPath.row]
    //            currentOperation.currentPageCell = cell
    //            currentOperation.currentIndexPath = IndexPath(item: cell.collectionView(cell.collectionView, numberOfItemsInSection: 0) - 1, section: 0)
    //            currentOperation.needsUpdate = false
    //        }
    //
    //        cell.draggedItem = self.currentDragOperation?.item
    //        cell.collectionView.reloadData()
    //
    //        if self.isEditing {
    //            cell.enterEditingMode()
    //        } else {
    //            cell.leaveEditingMode()
    //        }
    //    }
    //
    //    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    //
    //        let cell = cell as! PageCell
    //        if self.isEditing {
    //            cell.leaveEditingMode()
    //        }
    //    }
    //
    //    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) { }
}


// Ported from pageCell
extension AppGridManager {
    fileprivate func enterEditingMode() {
        guard !self.isEditing else { return }
        
        self.isEditing = true
        for cell in self.collectionView.visibleCells {
            let cell = cell as! HomeItemCell
            cell.animate()
            cell.enterEditingMode()
            
            if let cell = cell as? FolderCell {
                cell.moveToFirstAvailablePage()
            }
        }
    }
    
    fileprivate func leaveEditingMode() {
        guard self.isEditing else { return }
        
        self.isEditing = false
        for cell in self.collectionView.visibleCells {
            let cell = cell as! HomeItemCell
            cell.stopAnimation()
            cell.leaveEditingMode()
            
            if let cell = cell as? FolderCell {
                cell.moveTo(page: 0, animated: true)
            }
        }
    }
    
    fileprivate func updateSectionInset() {
        guard let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout, self.mode == .dock else { return }
        
        let newHorizontalSectionInset: CGFloat
        let appsPerRow = CGFloat(Settings.shared.appsPerRow)
        let interitemSpacing = (self.collectionView.frame.width - (Settings.shared.horizontalMargin * 2) - (appsPerRow * flowLayout.itemSize.width)) / (appsPerRow - 1)
        
        if self.items.count < Settings.shared.appsPerRow {
            let count = CGFloat(self.items.count)
            let totalSpace = (flowLayout.itemSize.width * count) + (interitemSpacing * (count - 1))
            newHorizontalSectionInset = (self.collectionView.frame.size.width - totalSpace) / 2
        } else {
            newHorizontalSectionInset = Settings.shared.horizontalMargin
        }
        
        self.collectionView.performBatchUpdates({
            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: newHorizontalSectionInset, bottom: 0, right: newHorizontalSectionInset)
        }, completion: nil)
    }
    
    fileprivate func updateLayout() {
        
        let flowLayout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.itemSize = Settings.shared.cellSize
        
        if self.mode == .dock {
            flowLayout.sectionInset = UIEdgeInsets(top: Settings.shared.dockTopMargin, left: Settings.shared.horizontalMargin, bottom: 0, right: Settings.shared.horizontalMargin)
            self.updateSectionInset()
        } else if self.mode == .regular {
            flowLayout.sectionInset = UIEdgeInsets(top: Settings.shared.topMargin, left: Settings.shared.horizontalMargin, bottom: 0, right: Settings.shared.horizontalMargin)
            flowLayout.minimumLineSpacing = Settings.shared.lineSpacing
        }
    }
    
    public func delete(item: HomeItem) {
        guard let index = self.items.index(where: { $0 === item }), let cell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) else { return }
        
        UIView.animate(withDuration: 0.25, animations: {
            cell.contentView.transform = CGAffineTransform.identity.scaledBy(x: 0.0001, y: 0.0001)
        }, completion: { _ in
            self.items.remove(at: index)
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            }, completion: { _ in
                cell.contentView.transform = .identity
            })
            
            if self.mode == .dock {
                self.updateSectionInset()
            }
        })
    }
}
