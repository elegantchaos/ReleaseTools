// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/03/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import BuilderConfiguration

let settings = Settings(specs: [
    .base(
        values: [
        ],
        inherits: [
        ]
    ),
    ]
)

let configuration = Configuration(
    settings: settings,
    actions: [
        .action(name:"build", phases:[
            .toolPhase(name:"Metadata", tool: "metafile", arguments:["ReleaseTools"]),
            .buildPhase(name:"Building", target:"rt"),
            ]),
        .action(name:"run", phases:[
            .actionPhase(name:"Building", action: "build"),
            .toolPhase(name:"Running", tool: "run", arguments:["rt"]),
            ]),
    ]
)

configuration.outputToBuilder()
