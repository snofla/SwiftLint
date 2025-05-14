import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoMutatingPartialResultInReduceRule: Rule {
    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "no_mutating_partial_result_in_reduce",
        name: "No Mutating Partial Result In Reduce",
        description: "Do not mutate the partial result in a `reduce` operation",
        kind: .idiomatic,
        nonTriggeringExamples: [
        ],
        triggeringExamples: [
            Example("""
                let array: [Type2] = input.reduce(Type1(), { partialResult, type in
                    ↓var partialResult = partialResult
                    partialResult = partialResult + [type]
                    return partialResult
                }
            """),
            Example("""
                let value = input.reduce(0, { accum, inc in
                    ↓var accum = accum
                    accum = accum + 1
                    return accum
                }
            """)
        ]
    )
}

private extension NoMutatingPartialResultInReduceRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        
        /// Looking for:
        /// * a function call `reduce`,
        /// * with a trailing closure,
        /// * the closure's first argument (the accumulator)
        /// * get the variable declarations that reference
        ///   the accumulator,
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard node.isReduceFunctionCall() else { return }
            guard let partialResultVarName = node.reducePartialResultVariableName() else {
                // could not get the var name of the partial result
                return
            }
            guard let variables = node.trailingClosure()?.variablesReferencing(partialResultVarName) else {
                // no variables referencing partial result variable
                return
            }
            let absolutePositions = variables
                .map(\.positionAfterSkippingLeadingTrivia)
            self.violations.append(contentsOf: absolutePositions)
        }
    }
}

private extension FunctionCallExprSyntax {
    
    func isReduceFunctionCall() -> Bool {
        // should be some reduce()
        guard let memberAccessExprSyntax = self.calledExpression.as(MemberAccessExprSyntax.self),
              memberAccessExprSyntax.declName.baseName.text == "reduce" else {
            return false
        }
        guard self.arguments.count == 2 else {
            // we should have two arguments to reduce
            return false
        }
        guard self.arguments.kind == .labeledExprList,
              self.arguments.first?.label?.text != "into" else {
            // it's a `reduce(into:_)`
            return false
        }
        guard self.arguments.last?.expression.as(ClosureExprSyntax.self) != nil else {
            // no closure
            return false
        }
        return true
    }
    
    func reducePartialResultVariableName() -> String? {
        guard let closureExpr = self.arguments.last?.expression.as(ClosureExprSyntax.self),
              let paramList = closureExpr.signature?.parameterClause?.as(ClosureShorthandParameterListSyntax.self),
              let partialResultVarName = paramList.first?.name.text else {
            // could not get the var name of the partial result
            return nil
        }
        return partialResultVarName
    }
    
    func trailingClosure() -> ClosureExprSyntax? {
        return self.arguments.last?.expression.as(ClosureExprSyntax.self)
    }
}

private extension ClosureExprSyntax {

    func variablesReferencing(_ name: String) -> [VariableDeclSyntax]? {
        return self.statements.variablesReferencing(name)
    }
}

private extension CodeBlockItemListSyntax {
    
    func variablesReferencing(_ name: String) -> [VariableDeclSyntax]? {
        let variableDecls = self.compactMap(\.asVariableDecl)
            .filter(\.isAssignmentToAVariable)
            .filter(VariableReference(name: name).matches(_:))
        return !variableDecls.isEmpty ? variableDecls : nil
    }
}

private extension CodeBlockItemSyntax {

    var asVariableDecl: VariableDeclSyntax? {
        return self.item.as(VariableDeclSyntax.self)
    }
}

private extension VariableDeclSyntax {
    
    var isAssignmentToAVariable: Bool {
        return self.bindingSpecifier.tokenKind == .keyword(.var)
    }
}

private struct VariableReference {
    let name: String
    
    func matches(_ variableDeclSyntax: VariableDeclSyntax) -> Bool {
        // should be a variable assignment, with identifier and assignment
        guard let binding = variableDeclSyntax.bindings.first,
              binding.pattern.is(IdentifierPatternSyntax.self),
              let initializer = binding.initializer,
              let rhsValue = initializer.value.as(DeclReferenceExprSyntax.self) else {
            return false
        }
        return rhsValue.baseName.text == name
    }
}
