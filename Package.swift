// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "QuestionOntologyGraphProvider",
    products: [
        .library(
            name: "QuestionOntologyGraphProvider",
            targets: ["QuestionOntologyGraphProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/turbolent/DiffedAssertEqual.git", from: "0.2.0"),
        .package(url: "https://github.com/turbolent/ParserDescription.git", from: "0.5.0"),
        .package(url: "https://github.com/turbolent/QuestionOntology.git", .branch("master")),
        .package(url: "https://github.com/turbolent/QuestionCompiler.git", .branch("master")),
        .package(url: "https://github.com/turbolent/ReteEngine.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "QuestionOntologyGraphProvider",
            dependencies: [
                "QuestionOntology", 
                "QuestionCompiler",
                "ReteEngine",
                "ParserDescription"
            ]
        ),
        .testTarget(
            name: "QuestionOntologyGraphProviderTests",
            dependencies: [
                "QuestionOntologyGraphProvider",
                "QuestionOntology",
                "DiffedAssertEqual",
                "TestQuestionOntology"
            ]
        ),
    ]
)
