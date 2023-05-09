//
//  MKPWaterMarkingError.swift
//  MKWatermarkingSDK
//
//  Created by Deepak Pagadala on 26/04/23.
//

import Foundation

/**
 * Defines the errors generated from watermarking component.
 */
struct MKPWaterMarkingError: Error {
    
    /**
     * Prefix with which the watermarking error codes will begin with.
     *
     * Example: 4-81-<code> will be the format of the watermarking error codes. "81" is the watermarking Error Prefix.
     */
    static let waterMarkingErrorCodePrefix = "4-81-"

    /**
     * Defines the error code.
     */
    var code: String

    /**
     * Defines the error message.
     */
    var message: String

    /**
     * watermarking error modules.
     *
     * Modules within the watermarking component that generate the error codes
     */
    enum ErrorModule: String {
        case imageHashInvalid           = "100"
        case signatureInvalid           = "101"
        case terminateRequested         = "102"
    }

    /**
     * Initialize with watermarking error.
     */
    init(code: String, message: String) {
        self.code = MKPWaterMarkingError.waterMarkingErrorCodePrefix + code
        self.message = message
    }
}
