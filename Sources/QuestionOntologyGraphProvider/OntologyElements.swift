import QuestionOntology
import QuestionParser
import ParserDescription
import ParserDescriptionOperators
import Regex
import OrderedSet


struct ComparableProperty<Mappings>: Hashable
    where Mappings: OntologyMappings
{
    let property: OntologyProperty<Mappings>
    let comparison: Comparison?
}

struct AdjectivePrefix<Mappings>: Hashable
    where Mappings: OntologyMappings
{
    let property: OntologyProperty<Mappings>
    let order: Order?
}


struct AdjectivePrefixMatch<Mappings>: Hashable
    where Mappings: OntologyMappings
{
    let adjectivePrefix: AdjectivePrefix<Mappings>
    let length: Int
}

func beAdjective(lemma: String) -> AnyPattern {
    return AnyPattern(
        Patterns.be ~
            pattern(lemma: lemma, tag: .adjective)
    )
}


final class QuestionOntologyElements<Mappings>
    where Mappings: OntologyMappings
{
    typealias Ontology = QuestionOntology<Mappings>
    typealias Token = QuestionParser.Token
    typealias Property = OntologyProperty<Mappings>
    typealias Class = OntologyClass<Mappings>

    private let namedPropertyInstruction:
        TokenInstruction<Token, Property>

    private let inversePropertyInstruction:
        TokenInstruction<Token, ComparableProperty<Mappings>>

    private let valuePropertyInstruction:
        TokenInstruction<Token, ComparableProperty<Mappings>>

    private let adjectivePropertyInstruction:
        TokenInstruction<Token, ComparableProperty<Mappings>>

    private let adjectivePrefixInstruction:
        TokenInstruction<Token, AdjectivePrefix<Mappings>>

    private let namedClassInstruction:
        TokenInstruction<Token, Class>

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
                    switch propertyPattern {
                    case let ._inverse(pattern, nil):
                        return (
                            pattern,
                            ComparableProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._inverse(pattern, ._named(filter)?):
                        return (
                            .sequence(pattern ~ filter),
                            ComparableProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._inverse(pattern, ._comparative(filter, comparison)?):
                        return (
                            .sequence(pattern ~ filter),
                            ComparableProperty(
                                property: property,
                                comparison: comparison
                            )
                        )
                    default:
                        return nil
                    }
                }

        valuePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    switch propertyPattern {
                    case let ._value(pattern, nil):
                        return (
                            pattern,
                            ComparableProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._value(pattern, ._named(filter)?):
                        return (
                            .sequence(pattern ~ filter),
                            ComparableProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._value(pattern, ._comparative(filter, comparison)?):
                        return (
                            .sequence(pattern ~ filter),
                            ComparableProperty(
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
                    switch propertyPattern {
                    case let ._adjective(lemma, nil):
                        return (
                            beAdjective(lemma: lemma),
                            ComparableProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._adjective(lemma, ._named(filter)?):
                        return (
                            .sequence(beAdjective(lemma: lemma) ~ filter),
                            ComparableProperty(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._adjective(lemma, ._comparative(filter, comparison)?):
                        return (
                            .sequence(beAdjective(lemma: lemma) ~ filter),
                            ComparableProperty(
                                property: property,
                                comparison: comparison
                            )
                        )
                    default:
                        return nil
                    }
                }

        adjectivePrefixInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology, checkEnd: false) {
                    property, propertyPattern in

                    switch propertyPattern {
                    case let ._adjective(lemma, filter: nil):
                        return (
                            AnyPattern(
                                pattern(
                                    lemma: lemma,
                                    tag: .adjective
                                )
                            ),
                            AdjectivePrefix(
                                property: property,
                                order: nil
                            )
                        )
                    case let ._superlativeAdjective(lemma, order):
                        return (
                            AnyPattern(
                                pattern(
                                    lemma: lemma,
                                    tag: .superlativeAdjective
                                )
                            ),
                            AdjectivePrefix(
                                property: property,
                                order: order
                            )
                        )
                    default:
                        return nil
                    }
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

        let patternsAndResults =
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

        return try compilePatternInstruction(
            patternsAndResults: patternsAndResults,
            checkEnd: true
        )
    }

    private static func compilePropertyPatternInstruction<Result>(
        ontology: Ontology,
        checkEnd: Bool = true,
        mapping: (Property, PropertyPattern) -> (AnyPattern, Result)?
    )
        throws -> TokenInstruction<Token, Result>
        where Result: Hashable
    {
        return try compilePatternInstruction(
            patternsAndResults:
                ontology.properties.values.flatMap { property in
                    property.patterns.compactMap { pattern in
                        mapping(property, pattern)
                    }
                },
            checkEnd: checkEnd
        )
    }

    private static func compileClassPatternInstruction(
        ontology: Ontology,
        filter: (ClassPattern) -> AnyPattern?
    )
        throws -> TokenInstruction<Token, Class>
    {
        return try compilePatternInstruction(
            patternsAndResults:
                ontology.classes.values
                    .flatMap { `class` in
                        `class`.patterns
                            .compactMap(filter)
                            .map { ($0, `class`) }
                },
            checkEnd: true
        )
    }

    private static func compilePatternInstruction<Result>(
        patternsAndResults: [(pattern: AnyPattern, result: Result)],
        checkEnd: Bool
    )
        throws -> TokenInstruction<Token, Result>
        where Result: Hashable
    {
        return compile(
            instructions: try patternsAndResults.map {
                try $0.compile(
                    tokenType: Token.self,
                    result: $1,
                    checkEnd: checkEnd
                )
            }
        )
    }

    func findNamedProperties<S>(name: S)
        -> OrderedSet<Property>
        where S: Sequence, S.Element == Token
    {
        let matchResult = namedPropertyInstruction.match(name)
        return OrderedSet(matchResult.map { $0.result })
    }

    func findValueProperties<S>(name: S)
        -> OrderedSet<ComparableProperty<Mappings>>
        where S: Sequence, S.Element == Token
    {
        let matchResult = valuePropertyInstruction.match(name)
        return OrderedSet(matchResult.map { $0.result })
    }

    func findInverseProperties<S>(name: S)
        -> OrderedSet<ComparableProperty<Mappings>>
        where S: Sequence, S.Element == Token
    {
        let matchResult = inversePropertyInstruction.match(name)
        return OrderedSet(matchResult.map { $0.result })
    }

    func findAdjectiveProperties<S>(name: S)
        -> OrderedSet<ComparableProperty<Mappings>>
        where S: Sequence, S.Element == Token
    {
        let matchResult = adjectivePropertyInstruction.match(name)
        return OrderedSet(matchResult.map { $0.result })
    }

    func findAdjectivePrefix<S>(name: S)
        -> OrderedSet<AdjectivePrefixMatch<Mappings>>
        where S: Sequence, S.Element == Token
    {
        let matchResult = adjectivePrefixInstruction.match(name)
        return OrderedSet(matchResult.map {
            return AdjectivePrefixMatch(
                adjectivePrefix: $0.result,
                length: $0.length
            )
        })
    }

    func findNamedClasses<S>(name: S)
        -> OrderedSet<Class>
        where S: Sequence, S.Element == Token
    {
        let matchResult = namedClassInstruction.match(name)
        return OrderedSet(matchResult.map { $0.result })
    }

    func findRelations<S>(name: S)
        -> OrderedSet<DirectedProperty<Mappings>>
        where S: Sequence, S.Element == Token
    {
        let matchResult = relationInstruction.match(name)
        return OrderedSet(matchResult.map { $0.result })
    }
}
