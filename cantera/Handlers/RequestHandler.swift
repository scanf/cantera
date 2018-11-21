//
//  RequestHandler.swift
//  cantera
//
//  Created by Alexander Alemayhu on 14/11/2018.
//  Copyright © 2018 Alexander Alemayhu. All rights reserved.
//

import Foundation
import UIKit

class RequestHandler {

    enum Endpoints {
        case json
        case image(String)

        func url() -> URL? {
            switch self {
            case .json:
                return URL(string: "https://gist.githubusercontent.com/3lvis/3799feea005ed49942dcb56386ecec2b/raw/63249144485884d279d55f4f3907e37098f55c74/discover.json")
            case .image(let id):
                return URL(string: "https://images.finncdn.no/dynamic/480x360c/\(id)")
            }
        }
    }

    private let cache = NSCache<AnyObject, AnyObject>()

    public var cacheLimit: Int {
        get { return cache.countLimit }
        set {
            cache.countLimit = newValue
        }
    }

    public var allAds = [AdObject]()

    // MARK: - Private

    private func downloadImage(id: String, completion completionHandler: @escaping (UIImage?) -> Void) {
        guard let url = Endpoints.image(id).url() else {
            completionHandler(nil)
            return
        }

        URLSession.shared.dataTask(with: url, completionHandler: { (data, _, _) in
            var image: UIImage?
            if let data = data {
                image = UIImage(data: data)
            }
            if let image = image {
                self.cache.setObject(image, forKey: id as AnyObject)
            }
            completionHandler(image)
        }).resume()
    }

    // MARK: - Public

    public func fetch(completion completionHandler: @escaping (Int) -> Void) {
        guard let url = Endpoints.json.url() else { return }

        URLSession.shared.dataTask(with: url) { (data, _, _) in
            if let data = data {
                do {
                    let adsResponse =  try JSONDecoder().decode(AdsResponse.self, from: data)
                    self.allAds = adsResponse.items.map { AdObject(adResponse: $0) }
                    // Drop all of the ads that are missing the price
                    self.allAds.removeAll { $0.price == nil }
                    completionHandler(self.allAds.count)
                } catch {
                    completionHandler(0)
                }
            }
            }.resume()
    }

    public func image(for ad: AdObject, completion completionHandler: @escaping (UIImage?) -> Void) {
        if let image = cache.object(forKey: ad.imageURL as AnyObject) as? UIImage {
            completionHandler(image)
        } else {
            downloadImage(id: ad.imageURL) { (image) in
                completionHandler(image)
            }
        }
    }

    public func freeUpResources() {
        self.cache.removeAllObjects()
    }
}
