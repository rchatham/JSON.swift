//
//  Plugin.swift
//  JSONKitMacroPlugin
//
//  Created by Reid Chatham on 4/5/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros
import JSONKitMacros

@main
struct JSONKitMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        JSONConvertibleMacro.self,
    ]
}
