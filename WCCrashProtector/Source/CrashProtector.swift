//
//  CrashProtector.swift
//  WCCrashProtector
//
//  Created by Frank on 2019/9/16.
//  Copyright © 2019 Frank. All rights reserved.
//

import Foundation

class CrashProtector: NSObject {

    open override class func resolveInstanceMethod(_ sel: Selector!) -> Bool {
        // Handle the crash
        guard let method = class_getInstanceMethod(self, #selector(nothing)) else {
            print("Cannot find make null function")
            return false
        }
        class_addMethod(self, sel, method_getImplementation(method), method_getTypeEncoding(method))
        print("Grab the crash method: \(NSStringFromSelector(sel))")
        return true
    }

    @objc func nothing() {}
}

var crashProtector: CrashProtector?

// MARK: - NSObject

extension NSObject {

    static func protect() {
        if self != NSObject.self { return }
        DispatchQueue.once(token: "NSObject.protect") { (result) in
            if !result { return }
            crashProtector = CrashProtector()
            swizzleMethod(aClass: self, originalSelector: #selector(forwardingTarget(for:)), swizzledSelector: #selector(swizzleForwardingTarget(for:)))
        }
    }
}

private extension NSObject {

    static func swizzleMethod(aClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(aClass, originalSelector),
            let swizzledMethod = class_getInstanceMethod(aClass, swizzledSelector) else {
                print("Cannot find your custom method")
                return
        }
        let methodAddSuccess = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        if methodAddSuccess {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    @objc func swizzleForwardingTarget(for aSelector: Selector) -> Any? {
        guard let crashProtector = crashProtector else {
            return nil
        }
        // Forward to CrashProtector
        return crashProtector
    }
}

// MARK: - DispatchQueue

extension DispatchQueue {

    private static var tokens = Set<String>()

    class func once(token: String, completion: @escaping (Bool) -> Void) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }
        if tokens.contains(token) {
            completion(false)
            return
        }
        tokens.insert(token)
        completion(true)
    }
}
