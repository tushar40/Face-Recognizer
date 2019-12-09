//
//  Models.swift
//  Face Recognition iOS
//
//  Created by Tushar Gusain on 04/12/19.
//  Copyright © 2019 Hot Cocoa Software. All rights reserved.
//

import UIKit

struct Face
{
    let faceId: String
    let height: Int
    let width: Int
    let top: Int
    let left: Int
}

private enum SelectedType
{
    case singlePerson
    case photoForIdentification
}

struct Person
{
    var name: String
//    var upn: String
    var image: UIImage?
}

struct Result
{
    let image: UIImage
    let otherInformation: String
}

struct PersonResponse: Codable {
    let personId: String
    let name: String
    let userData: String
    let persistedFaceIds: [String]
}
