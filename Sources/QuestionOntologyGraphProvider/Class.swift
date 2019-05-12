import QuestionOntology
import OrderedSet


extension Class {
    func allRelations(in ontology: QuestionOntology<Mappings>)
        throws -> OrderedSet<Relation<Mappings>>
    {
        var relations = OrderedSet(self.relations.sorted())
        for superClassIdentifier in superClassIdentifiers {
            guard let superClass = ontology.classes[superClassIdentifier] else {
                throw OntologyError.invalidClassIdentifier(superClassIdentifier)
            }
            relations.formUnion(try superClass.allRelations(in: ontology))
        }
        return relations
    }
}
