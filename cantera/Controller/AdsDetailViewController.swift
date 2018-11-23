//
//  AdsDetailViewController.swift
//  cantera
//
//  Created by Alexander Alemayhu on 14/11/2018.
//  Copyright © 2018 Alexander Alemayhu. All rights reserved.
//

import UIKit

protocol AdsDetailViewControllerDatasource {
    func adForDetailViewController() -> AdObject?
    func retrieveImage(for ad: AdObject, completion: @escaping (UIImage?) -> Void)
    func isItinFavorites(ad: AdObject) -> Bool
}

protocol AdsDetailViewControllerDelegate {
    func pressedFavorite(for ad: AdObject, checked: Bool)
}

class AdsDetailViewController: UIViewController {

    public var datasource: AdsDetailViewControllerDatasource?
    public var delegate: AdsDetailViewControllerDelegate?

    private var currentAd: AdObject?

    private let imageView: UIImageView = {
        let image = UIImage(imageLiteralResourceName: "placeholder")
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let descriptionTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isScrollEnabled = false
        return textView
    }()

    private lazy var shareItem: UIBarButtonItem = {
        let shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(pressShare))
        return shareItem
    }()

    private lazy var favoriteButton = FavoriteButton(delegate: self)
    private lazy var favoriteItem: UIBarButtonItem = {
        let favoriteItem = UIBarButtonItem(customView: favoriteButton)
        favoriteButton.layer.borderColor = UIColor.blue.cgColor
        favoriteButton.layer.borderWidth = 0.5
        return favoriteItem
    }()

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        [imageView, descriptionTextView].forEach { view.addSubview($0) }
        setup()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.updateViewConstraints()
    }

    // MARK: - Private

    private func setup() {
        self.currentAd = datasource?.adForDetailViewController()
        guard let currentAd = currentAd else { return }

        navigationItem.rightBarButtonItems = [favoriteItem, shareItem]
        self.view.backgroundColor = .white

       let attributedText = NSMutableAttributedString(string: currentAd.location, attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        attributedText.append(NSAttributedString(string: "\n\n\(currentAd.title)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black]))
        if let price = currentAd.price {
            attributedText.append(NSAttributedString(string: "\n\n\(price),-", attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 22)
            ]))
        }
        descriptionTextView.attributedText = attributedText

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.5),
            imageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -50),
            imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 50),

            ])

        NSLayoutConstraint.activate([
            descriptionTextView.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            descriptionTextView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            descriptionTextView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
            ])

        favoriteButton.isSelected = datasource?.isItinFavorites(ad: currentAd) ?? false

        datasource?.retrieveImage(for: currentAd, completion: { image in
            self.imageView.image = image ?? UIImage(imageLiteralResourceName: "missing-image")
        })
    }

    // MARK: - User interaction

    @objc func pressFavorite() {
        guard let currentAd = currentAd else { return }
        favoriteButton.isSelected = !favoriteButton.isSelected
        delegate?.pressedFavorite(for: currentAd, checked: favoriteButton.isSelected)
    }

    @objc func pressShare() {
        guard let currentAd = currentAd else { return }
        var items = [Any]()
        items.append(currentAd.title)
        if let image = imageView.image {
            items.append(image)
        }
        let shareViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        shareViewController.popoverPresentationController?.sourceRect = shareItem.accessibilityFrame
        self.present(shareViewController, animated: true, completion: nil)
    }
}

extension AdsDetailViewController: FavoriteButtonDelegate {
    func selectorForPressedFavorite() -> Selector {
        return #selector(pressFavorite)
    }
}
