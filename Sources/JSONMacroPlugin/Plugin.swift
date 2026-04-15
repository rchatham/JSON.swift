//
//  Plugin.swift
//  JSONMacroPlugin
//
//  Created by Reid Chatham on 4/5/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct JSONMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        JSONConvertibleMacro.self,
    ]
}
