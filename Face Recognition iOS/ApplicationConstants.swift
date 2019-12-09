/*
 * Copyright (c) Microsoft. All rights reserved. Licensed under the MIT license.
 * See LICENSE in the project root for license information.
 */

import Foundation

struct ApplicationConstants
{
    // Graph information
    static let clientId = "8af67ea0-5d1c-412b-a9a9-709daeee55d3"
    static let authority = "https://login.microsoftonline.com/common"
    static let scopes = ["User.ReadBasic.All"]
    
    // Cognitive services information
    static let ocpApimSubscriptionKey = "e74bf6dc7308401790364b84247e1964"
    static let faceApiEndpoint = "https://westcentralus.api.cognitive.microsoft.com/face/v1.0"
    static let personGroupId = "sample-person-group"

}

enum ErrorType: Error
{
    case UnexpectedError(nsError: NSError?)
    case ServiceError(json: [String: AnyObject])
    case JSonSerializationError
}

typealias JSON = AnyObject
typealias JSONDictionary = [String: JSON]
typealias JSONArray = [JSON]
