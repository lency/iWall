//
//  WebApiBridge.swift
//  webapiDemo
//
//  Created by jicuhanguo on 2019/8/22.
//  Copyright © 2019 jicg. All rights reserved.
//

import Foundation

struct JsValueReturn<T: Encodable> : Encodable {
    let type = "value"
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

struct JsPromiseReturn : Encodable {
    let type = "promise"
    let promise: String
    init(_ promise: String) {
        self.promise = promise
    }
}

struct JsDone : Encodable {
    let type = "done"
}

struct JSCmdHeader : Codable {
    let `class`: String
    let method: String
    let type: CmdType
}

struct JSCmd<T:Codable> : Codable {
    let `class`: String
    let method: String
    let args: T
}

enum JSCmdError : Error {
    case invalidparameters
    case methodnotfound
}

struct SetVal<T:Codable> : Codable {
    let newVal : T
}

typealias AsyncCall = (Data, @escaping (Int) -> () ) throws -> ()
typealias SyncCall = (Data) throws -> Encodable
typealias GetterCall = (Data) throws -> Data
typealias SetterCall = (Data) throws -> ()

protocol WebCommander {
//    func dispatch(_ method: String, _ type: CmdType, _ json: Data, invoker: @escaping (String) -> ()) throws -> String?
    func get_async_pointer(_ method: String) throws -> AsyncCall
    func get_sync_pointer(_ method: String) throws -> SyncCall
    func get_setter_pointer(_ method: String) throws -> SetterCall
}

enum CmdType : String, Codable {
    case AsyncFunction
    case Function
    case Setter
    case Getter
}

extension WebCommander {
    func dispatch_ex(_ method: String, _ type: CmdType, _ json: Data, invoker: @escaping (String) -> ()) throws -> String? {
        var data : Data?

        switch type {
        case .AsyncFunction:
            let ck = "_" + String(format: "%x", json.hashValue)
            data = try JsPromiseReturn( ck ).toJsonData()
            try get_async_pointer(method)(json) {ret in
                invoker("\(ck)(\(ret))")
            }
        case .Function:
            data = try get_sync_pointer(method)(json).toJsonData()
        case .Getter:
            data = try getPropertyData(method)
        case .Setter:
            _ = try get_setter_pointer(method)(json)
            data = try JsDone().toJsonData()
        }
        return data.flatMap { String(data: $0, encoding: .utf8)}
    }

    func getPropertyData(_ name: String) throws -> Data {
        let mirror = Mirror(reflecting: self)
        for prop in mirror.children {
            if prop.label == name {
                if let v = prop.value as? Encodable {
                    return try v.toWrapperJsonData()
                }
                break
            }
        }
        throw JSCmdError.methodnotfound
    }
}

extension Encodable {
    func toJsonData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    func toWrapperJsonData() throws -> Data {
        return try JSONEncoder().encode(JsValueReturn(self))
    }
}
