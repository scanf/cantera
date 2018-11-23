//
//  AdsCollectionViewController.swift
//  cantera
//
//  Created by Alexander Alemayhu on 14/11/2018.
//  Copyright © 2018 Alexander Alemayhu. All rights reserved.
//

import UIKit

class AdsCollectionViewController: UICollectionViewController, AdViewCollectionViewCellDelegate {

    enum States: String {
        case all = "Annonser"
        case favorites = "Favoritter"
        case emptyFavorites = "Tomt"
    }

    private let storage = StorageHandler()
    private let api = RequestHandler()

    private var lastSelectedIndexPath: IndexPath?

    private let placeHolderImage = UIImage(imageLiteralResourceName: "placeholder")
    private let missingImage = UIImage(imageLiteralResourceName: "missing-image")

    private lazy var allAdsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: States.all.rawValue, style: .plain, target: self, action: #selector(pressedBackItem))
        return item
    }()

    private lazy var favoritesItem: UIBarButtonItem = {
        let rightBarButtonItem = UIBarButtonItem(title: "Favoritter", style: .plain, target: self, action: #selector(pressedFavoritesItem))
        rightBarButtonItem.tintColor = UIColor.red
        return rightBarButtonItem
    }()

    private let indicatorView = LoadingIndicatorView()
    private var adsToDisplay = [AdObject]()

    private var isShowingFavorites: Bool {
        return States.favorites.rawValue == self.title
    }

    let emptyFavoritesView = EmptyFavoritesView()

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        [indicatorView, emptyFavoritesView].forEach { self.view.addSubview($0) }
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // This is not ideal, but by keeping track of the selected one
        // we can update a single item instead of reloading the whole collection.
        guard let selectedIndexPath = self.lastSelectedIndexPath else {
            collectionView.reloadData()
            return
        }
        collectionView.reloadItems(at: [selectedIndexPath])
        self.lastSelectedIndexPath = nil
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.collectionViewLayout.invalidateLayout()
    }

    override func didReceiveMemoryWarning() {
        // In the unlikely case we get a memory warning, empty out the cache.
        api.freeUpResources()
        super.didReceiveMemoryWarning()
    }

    // MARK: - Private

    private func setup() {
        collectionView.register(AdViewCollectionViewCell.self, forCellWithReuseIdentifier: AdViewCollectionViewCell.ReuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.contentInsetAdjustmentBehavior = .always
        navigationItem.rightBarButtonItem = allAdsItem
        collectionView.backgroundColor = .white
        title = States.all.rawValue

        NSLayoutConstraint.activate([
            indicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            indicatorView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1),
            indicatorView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1)
            ])

        NSLayoutConstraint.activate([
            emptyFavoritesView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyFavoritesView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyFavoritesView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 1),
            emptyFavoritesView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 1)
            ])

        api.cacheLimit = 50
        do {
            try storage.loadFavorites()
            configure(for: .favorites)
        } catch {
            // Note: Still not sure what todo when this fails...
        }

        // If we have favorites, start there
        guard !storage.favoritedAds.isEmpty else {
            configure(for: .all)
            return
        }
    }

    private func loadRemoteAds() {
        indicatorView.animates = true
        api.fetch { (response) in
            guard response.count > 0 else {
                self.indicatorView.animates = false
                return
            }

            self.storage.use(response)
            self.updateCollectionView(from: self.storage.favoritedAds, to: self.storage.allAds)
            self.indicatorView.animates = false
        }
    }

    private func configure(for state: States) {
        emptyFavoritesView.isHidden = true

        switch state {
        case .all:
            navigationItem.rightBarButtonItem = favoritesItem
            title = States.all.rawValue

            guard storage.allAds.count > 0 else {
                loadRemoteAds()
                return
            }
            updateCollectionView(from: storage.favoritedAds, to: storage.allAds)
        case .favorites:
            navigationItem.rightBarButtonItem = allAdsItem
            title = States.favorites.rawValue
            updateCollectionView(from: storage.allAds, to: storage.favoritedAds)
            // No favorites on initial configuring, fallback to empty
            if storage.favoritedAds.isEmpty {
                fallthrough
            }
        case .emptyFavorites:
            emptyFavoritesView.isHidden = false
        }
    }

    private func updateCollectionView(from: [AdObject], to: [AdObject]) {
        // Initially there won't be a properly configured datasource collection
        guard !adsToDisplay.isEmpty else {
            adsToDisplay += to
            collectionView.reloadData()
            return
        }

        let toDeleteItems: [IndexPath?] =  from.enumerated().map { (index, element) in
            var indexPath: IndexPath?
            if !to.contains(where: { $0.id == element.id }) {
                adsToDisplay.removeAll(where: { $0.id == element.id })
                indexPath = IndexPath(item: index, section: 0)
            }
            return indexPath
        }

        let toAddItems: [IndexPath?] = to.enumerated().map { (index, element) in
            var indexPath: IndexPath?
            if !adsToDisplay.contains(where: { $0.id == element.id }) {
                adsToDisplay.append(element)
                indexPath = IndexPath(item: index, section: 0)
            }
            return indexPath
        }

        collectionView.performBatchUpdates({
            collectionView.deleteItems(at: toDeleteItems.compactMap({ $0 }))
            collectionView.insertItems(at: toAddItems.compactMap({ $0 }))
        }, completion: nil)
    }

    // MARK: - UICollectionView delegate and datasource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return adsToDisplay.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AdViewCollectionViewCell.ReuseIdentifier, for: indexPath)
        guard let adCell = cell as? AdViewCollectionViewCell else { return cell }

        let ad = adsToDisplay[indexPath.item]
        let liked = storage.favoritedAds.contains(where: { $0.id == ad.id})
        adCell.delegate = self
        adCell.configure(for: ad, image: self.placeHolderImage, liked: liked)

        api.image(for: ad, completion: { image in
            adCell.configure(for: ad, image: image ?? self.placeHolderImage, liked: liked)
        })
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.lastSelectedIndexPath = indexPath

        let detailViewController = AdsDetailViewController()
        detailViewController.datasource = self
        detailViewController.delegate = self
        self.navigationController?.pushViewController(detailViewController, animated: true)
    }

    // MARK: - User interaction

    @objc func pressedFavoritesItem() {
        configure(for: .favorites)
    }

    @objc func pressedBackItem() {
        configure(for: .all)
    }

    func toggleFavorite(for ad: AdObject, checked: Bool) {
        do {
            checked ? try storage.add(ad) : try storage.remove(ad)
        } catch {
            // Note: we should let user know the operation failed..
        }

        if isShowingFavorites, let item = storage.favoritedAds.firstIndex(where: { $0.id == ad.id }) {
            if storage.favoritedAds.isEmpty {
                configure(for: .emptyFavorites)
            } else {
                collectionView.reloadItems(at: [IndexPath(item: item, section: 0)])
            }
        } else if let item = storage.allAds.firstIndex(where: { $0.id == ad.id }) {
            collectionView.reloadItems(at: [IndexPath(item: item, section: 0)])
        }
    }
}

extension AdsCollectionViewController: AdsDetailViewControllerDatasource, AdsDetailViewControllerDelegate {

    // Datasource

    func isItinFavorites(ad: AdObject) -> Bool {
        return storage.favoritedAds.contains(where: { $0.id == ad.id})
    }

    func retrieveImage(for ad: AdObject, completion: @escaping (UIImage?) -> Void) {
        api.image(for: ad, completion: completion)
    }

    func adForDetailViewController() -> AdObject? {
        guard let indexPath = self.lastSelectedIndexPath else { return nil }
        return adsToDisplay[indexPath.item]
    }

    // Delegate

    func pressedFavorite(for ad: AdObject, checked: Bool) {
        do {
            guard checked else {
                lastSelectedIndexPath = nil /// Handle internal inconcistentcy
                try storage.remove(ad)
                return
            }
            try storage.add(ad)
        } catch {
            // Note: let user know op failed
        }
    }
}
