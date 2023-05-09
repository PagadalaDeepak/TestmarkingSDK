//
//  MKPLog.swift
//  MKPlayer
//
//  Created by Karthik K on 20/01/21.
//  Copyright © 2021 MediaKind. All rights reserved.
//

import Foundation
import OSLog

class MKPLog {

    private static var isEnabled = false

    class func enable() {
        isEnabled = true
    }

    class func disable() {
        isEnabled = false
    }

    class func d(_ message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        log(tag: "D", message: message, filename: filename, line: line, column: column, funcName: funcName)
    }

    class func e(_ message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        log(tag: "E", message: message, filename: filename, line: line, column: column, funcName: funcName)
    }

    class func i(_ message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        log(tag: "I", message: message, filename: filename, line: line, column: column, funcName: funcName)
    }

    class func v(_ message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        log(tag: "V", message: message, filename: filename, line: line, column: column, funcName: funcName)
    }

    class func w(_ message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        log(tag: "W", message: message, filename: filename, line: line, column: column, funcName: funcName)
    }

    class func s(_ message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        log(tag: "S", message: message, filename: filename, line: line, column: column, funcName: funcName)
    }

    private class func log(tag: String, message: String, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isEnabled {
            let messageWithOtherDetails = "\(tag)/\(String(describing: self)): [\(extractFileFromPath(filePath: filename)):\(trimFunctionName(funcName: funcName)):\(line)] -> \(message)"
            if #available(iOS 12.0, *) {
                os_log("%{public}@", messageWithOtherDetails)
            } else {
                // Fallback on earlier versions
                NSLog("\(messageWithOtherDetails)")
            }
        }
    }

    private class func extractFileFromPath(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        if components.isEmpty {
            return ""
        } else {
            // Remove .swift from file name
            let fileName = components.last!
            return fileName.components(separatedBy: ".").first ?? fileName
        }
    }

    private class func trimFunctionName(funcName: String) -> String {
        // Remove () from function name
        return funcName.components(separatedBy: "(").first ?? funcName
    }
}
