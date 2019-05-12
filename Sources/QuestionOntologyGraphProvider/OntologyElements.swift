import QuestionOntology
import QuestionParser
import ParserDescription
import ParserDescriptionOperators
import Regex
import OrderedSet


struct ValueProperty<Mappings>: Hashable
    where Mappings: OntologyMappings
{
    let property: OntologyProperty<Mappings>
    let comparison: Comparison?
}


struct ComparativeProperty<Mappings>: Hashable
    where Mappings: OntologyMappings
{
    let property: OntologyProperty<Mappings>
    let comparison: Comparison
}


final class QuestionOntologyElements<Mappings>
    where Mappings: OntologyMappings
{
    typealias Ontology = QuestionOntology<Mappings>
    typealias Token = QuestionParser.Token

    private let namedPropertyInstruction:
        TokenInstruction<Token, OntologyProperty<Mappings>>

    private let inversePropertyInstruction:
        TokenInstruction<Token, OntologyProperty<Mappings>>

    private let valuePropertyInstruction:
        TokenInstruction<Token, ValueProperty<Mappings>>

    private let adjectivePropertyInstruction:
        TokenInstruction<Token, OntologyProperty<Mappings>>

    private let comparativePropertyInstruction:
        TokenInstruction<Token, ComparativeProperty<Mappings>>

    private let namedClassInstruction:
        TokenInstruction<Token, OntologyClass<Mappings>>

    private let relationInstruction:
        TokenInstruction<Token, DirectedProperty<Mappings>>

    let ontology: Ontology

    init(ontology: Ontology) throws {
        self.ontology = ontology

        namedPropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._named(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property)
                }

        inversePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._inverse(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property)
                }

        valuePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    switch propertyPattern {
                    case let ._value(pattern):
                        return (
                            pattern,
                            ValueProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._comparative(pattern, comparison):
                        return (
                            pattern,
                            ValueProperty(
                                property: property,
                                comparison: comparison
                            )
                        )
                    default:
                        return nil
                    }
                }

        adjectivePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._adjective(pattern) = propertyPattern else {
                        return nil
                    }

                    // NOTE: prefix with be/VB
                    return (AnyPattern(Patterns.be ~ pattern), property)
                }

        comparativePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._comparative(pattern, comparison) = propertyPattern else {
                        return nil
                    }

                return (
                    pattern,
                    ComparativeProperty(
                        property: property,
                        comparison: comparison
                    )
                )
            }

        namedClassInstruction =
            try QuestionOntologyElements
                .compileClassPatternInstruction(ontology: ontology) {
                    guard case let ._named(pattern) = $0 else {
                        return nil
                    }
                    return pattern
            }

        relationInstruction =
            try QuestionOntologyElements
                .compileRelationInstruction(ontology: ontology)
    }

    private static func compileRelationInstruction(ontology: Ontology)
        throws -> TokenInstruction<Token, DirectedProperty<Mappings>>
    {
        func asDirectedProperty(relation: Relation<Mappings>)
            throws -> (AnyPattern?, DirectedProperty<Mappings>)
        {
            let propertyIdentifier = relation.propertyIdentifier
            guard
                let property = ontology.properties[propertyIdentifier]
            else {
                throw OntologyError.invalidPropertyIdentifier(propertyIdentifier)
            }

            let directedProperty: DirectedProperty<Mappings>
            switch relation.direction {
            case .incoming:
                directedProperty = .incoming(property)
            case .outgoing:
                directedProperty = .outgoing(property)
            }

            return (relation.pattern, directedProperty)
        }

        return try compilePatternInstruction(patternsAndResults:
            try ontology.classes.values
                .flatMap { `class` -> [(AnyPattern, DirectedProperty<Mappings>)] in
                    let directedPropertyPatterns =
                        try `class`.allRelations(in: ontology)
                            .map(asDirectedProperty)

                    return `class`.patterns.flatMap { classPattern in
                        directedPropertyPatterns.map {
                            let (patternSuffix, directedProperty) = $0

                            switch classPattern {
                            case let ._named(namedPattern):
                                let pattern = patternSuffix
                                    .map { AnyPattern(namedPattern ~ $0) }
                                    ?? namedPattern
                                return (
                                    pattern,
                                    directedProperty
                                )
                            }
                        }
                    }
                }
        )
    }

    private static func compilePropertyPatternInstruction<Result>(
        ontology: Ontology,
        mapping: (OntologyProperty<Mappings>, PropertyPattern) -> (AnyPattern, Result)?
    )
        throws -> TokenInstruction<Token, Result>
        where Result: Hashable
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.properties.values.flatMap { property in
                property.patterns.compactMap { pattern in
                    mapping(property, pattern)
                }
            }
        )
    }

    private static func compileClassPatternInstruction(
        ontology: Ontology,
        filter: (ClassPattern) -> AnyPattern?
    )
        throws -> TokenInstruction<Token, OntologyClass<Mappings>>
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.classes.values
                .flatMap { `class` in
                    `class`.patterns
                        .compactMap(filter)
                        .map { ($0, `class`) }
            }
        )
    }

    private static func compilePatternInstruction<Result>(
        patternsAndResults: [(pattern: AnyPattern, result: Result)]
    )
        throws -> TokenInstruction<Token, Result>
        where Result: Hashable
    {
        return compile(
            instructions: try patternsAndResults.map {
                try $0.compile(tokenType: Token.self, result: $1)
            }
        )
    }

    func findNamedProperties(name: [Token]) -> OrderedSet<OntologyProperty<Mappings>> {
        return OrderedSet(
            namedPropertyInstruction.match(name)
        )
    }

    func findInverseProperties(name: [Token]) -> OrderedSet<OntologyProperty<Mappings>> {
        return OrderedSet(
            inversePropertyInstruction.match(name)
        )
    }

    func findAdjectiveProperties(name: [Token]) -> OrderedSet<OntologyProperty<Mappings>> {
        return OrderedSet(
            adjectivePropertyInstruction.match(name)
        )
    }

    func findValueProperties(name: [Token])
        -> OrderedSet<ValueProperty<Mappings>>
    {
        return OrderedSet(
            valuePropertyInstruction.match(name)
        )
    }

    func findComparativeProperties(name: [Token])
        -> OrderedSet<ComparativeProperty<Mappings>>
    {
        return OrderedSet(
            comparativePropertyInstruction.match(name)
        )
    }

    private static func dropInitialDeterminer(name: [Token]) -> ArraySlice<Token> {
        if let first = name.first, first.tag == "DT" {
            return name.dropFirst()
        } else {
            return ArraySlice(name)
        }
    }

    func findNamedClasses(name: [Token]) -> OrderedSet<OntologyClass<Mappings>> {
        return OrderedSet(
            namedClassInstruction.match(
                QuestionOntologyElements.dropInitialDeterminer(name: name)
            )
        )
    }

    func findRelations(name: [Token]) -> OrderedSet<DirectedProperty<Mappings>> {
        return OrderedSet(
            relationInstruction.match(
                QuestionOntologyElements.dropInitialDeterminer(name: name)
            )
        )
    }
}
