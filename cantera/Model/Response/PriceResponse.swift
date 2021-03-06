//
//  Price.swift
//  cantera
//
//  Created by Alexander Alemayhu on 14/11/2018.
//  Copyright © 2018 Alexander Alemayhu. All rights reserved.
//

struct PriceResponse: Codable {
    // Note: We are assuming .value is a integer based on the output of the API.
    // There is probably some canonical documentation from FINN.no somewhere, that can answer this.
    let value: Int
}
