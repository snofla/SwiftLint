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
        ]
    )
}

private extension NoMutatingPartialResultInReduceRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        
        override func visitPost(_ node: FunctionCallExprSyntax) {
            // should be some reduce()
            guard let memberAccessExprSyntax = node.calledExpression.as(MemberAccessExprSyntax.self),
                  memberAccessExprSyntax.declName.baseName.text == "reduce" else {
                return
            }
            guard node.arguments.count == 2 else {
                // we should have two arguments to reduce
                return
            }
            guard node.arguments.kind == .labeledExprList,
                  node.arguments.first?.label?.text != "into" else {
                // it's a `reduce(into:_)`
                return
            }
            guard let closureExpr = node.arguments.last?.expression.as(ClosureExprSyntax.self),
                  let parameterList = closureExpr.signature?.parameterClause?.as(ClosureShorthandParameterListSyntax.self),
                  let partialResultVarName = parameterList.first?.name.text else {
                // could not get the var name of the partial result
                return
            }
            guard let variableDecls = closureExpr.statements.findVariablesReferencing(partialResultVarName) else {
                // nothing found
                return
            }
            let absolutePositions = variableDecls
                .map(\.positionAfterSkippingLeadingTrivia)
            self.violations.append(contentsOf: absolutePositions)
        }
    }
}


extension CodeBlockItemListSyntax {
    
    func findVariablesReferencing(_ name: String) -> [VariableDeclSyntax]? {
        
        func asVariableDecl(_ syntax: CodeBlockItemSyntax) -> VariableDeclSyntax? {
            return syntax.item.as(VariableDeclSyntax.self)
        }
        
        func isAssignmentToAVariable(_ variableDeclSyntax: VariableDeclSyntax) -> Bool {
            return variableDeclSyntax.bindingSpecifier.tokenKind == .keyword(.var)
        }
        
        func isReferencingOurVariable(_ variableDeclSyntax: VariableDeclSyntax) -> Bool {
            guard let binding = variableDeclSyntax.bindings.first else {
                // no variable assignment
                return false
            }
            guard binding.pattern.is(IdentifierPatternSyntax.self) else {
                // no identifier
                return false
            }
            guard let initializer = binding.initializer else {
                // no assignment
                return false
            }
            guard let rhsValue = initializer.value.as(DeclReferenceExprSyntax.self) else {
                return false
            }
            return rhsValue.baseName.text == name
        }
        let variableDecls = self.compactMap(asVariableDecl)
            .filter(isAssignmentToAVariable)
            .filter(isReferencingOurVariable)
        return variableDecls.count > 0 ? variableDecls : nil
    }
    
}
