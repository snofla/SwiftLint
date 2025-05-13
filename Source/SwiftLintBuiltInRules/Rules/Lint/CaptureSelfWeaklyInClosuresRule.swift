import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct CaptureSelfWeaklyInClosuresRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "capture_self_weakly_in_closures",
        name: "Capture Self Weakly In Closures",
        description: "",
        kind: .lint,
        nonTriggeringExamples: [
            Example("let x = 1"),
        ],
        triggeringExamples: [
            Example("var ↓foo = 1"),
        ]
    )
}

private extension CaptureSelfWeaklyInClosuresRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: VariableDeclSyntax) {
            node.bindings.forEach { binding in
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                   pattern.identifier.text == "foo" {
                    violations.append(.init(
                        position: pattern.positionAfterSkippingLeadingTrivia,
                        reason: "Variable named 'foo' should be named 'bar' instead"
                    ))
                }
            }
        }
    }
}
