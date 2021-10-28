//
//  RealmStorage+ProtocolImplementations.swift
//  DVPNApp
//
//  Created by Victoria Kostyleva on 13.10.2021.
//

import Foundation
import RealmSwift
import SentinelWallet

// MARK: - StoresNodes

enum NodesServiceError: Error {
    case databaseFailure(String)
    case failToLoadData
}

extension RealmStorage: StoresNodes {
    var sentinelNodes: [SentinelNode] {
        guard let realm = initRealm() else { return [] }
            
        return realm.objects(SentinelNodeObject.self).map { SentinelNode(managedObject: $0) }
    }
    
    func save(sentinelNodes: [SentinelNode]) {
        DispatchQueue.global().async { [weak self] in
            guard let realm = self?.initRealm() else { return }
            
            do {
                try realm.safeWrite() {
                    try self?.save(collection: sentinelNodes, to: realm)
                }
            } catch {
                log.error(NodesServiceError.databaseFailure("Failed to save sentinelNodes \(sentinelNodes)"))
            }
        }
    }
    
    func save(sentinelNode: SentinelNode) {
        DispatchQueue.global().async { [weak self] in
            guard let realm = self?.initRealm() else { return }
            
            do {
                try realm.safeWrite() {
                    try self?.save(object: sentinelNode, to: realm)
                }
            } catch {
                log.error(NodesServiceError.databaseFailure("Failed to save sentinelNode \(sentinelNode)"))
            }
        }
    }
    
    func save(node: Node, for sentinelNode: SentinelNode) {
        let fullSentinelNode = sentinelNode.set(node: node)
        
        DispatchQueue.global().async { [weak self] in
            guard let realm = self?.initRealm() else { return }
            
            do {
                try realm.safeWrite() {
                    try self?.save(object: fullSentinelNode, to: realm)
                }
            } catch {
                log.error(NodesServiceError.databaseFailure("Failed to save node \(node)"))
            }
        }
    }
}