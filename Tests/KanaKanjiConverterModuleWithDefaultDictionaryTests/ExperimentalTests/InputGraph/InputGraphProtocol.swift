//
//  InputGraphProtocol.swift
//
//
//  Created by miwa on 2024/02/23.
//

import Foundation

protocol InputGraphNodeProtocol {
    var displayedTextRange: InputGraphStructure.Range  { get set }
    var inputElementsRange: InputGraphStructure.Range  { get set }
}

protocol InputGraphProtocol {
    associatedtype Node: InputGraphNodeProtocol
    var nodes: [Node] { get set }

    var structure: InputGraphStructure { get set }
}

extension InputGraphProtocol {
    var root: Node {
        nodes[0]
    }

    func nextIndices(for node: Node) -> IndexSet {
        self.structure.nextIndices(
            displayedTextEndIndex: node.displayedTextRange.endIndex,
            inputElementsEndIndex: node.inputElementsRange.endIndex
        )
    }

    func next(for node: Node) -> [Node] {
        nextIndices(for: node).map{ self.nodes[$0] }
    }

    func prevIndices(for node: Node) -> IndexSet {
        self.structure.prevIndices(
            displayedTextStartIndex: node.displayedTextRange.startIndex,
            inputElementsStartIndex: node.inputElementsRange.startIndex
        )
    }

    func prev(for node: Node) -> [Node] {
        prevIndices(for: node).map{ self.nodes[$0] }
    }

    mutating func remove(at index: Int) {
        assert(index != 0, "Node at index 0 is root and must not be removed.")
        self.structure.remove(at: index)
    }

    @discardableResult
    mutating func insert(_ node: Node, connection: InputGraphStructure.Connection = .none) -> Int {
        var nodes = self.nodes
        let index = self.structure.insert(node, nodes: &nodes, displayedTextRange: node.displayedTextRange, inputElementsRange: node.inputElementsRange, connection: connection)
        self.nodes = nodes
        return index
    }
}
