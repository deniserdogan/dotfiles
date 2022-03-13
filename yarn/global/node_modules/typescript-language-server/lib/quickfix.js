"use strict";
/*
 * Copyright (C) 2018 TypeFox and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.provideQuickFix = void 0;
const lsp = __importStar(require("vscode-languageserver/node"));
const commands_1 = require("./commands");
const protocol_translation_1 = require("./protocol-translation");
const node_1 = require("vscode-languageserver/node");
function provideQuickFix(response, documents) {
    if (!response || !response.body) {
        return [];
    }
    return response.body.map(fix => lsp.CodeAction.create(fix.description, {
        title: fix.description,
        command: commands_1.Commands.APPLY_WORKSPACE_EDIT,
        arguments: [{ documentChanges: fix.changes.map(c => (0, protocol_translation_1.toTextDocumentEdit)(c, documents)) }]
    }, node_1.CodeActionKind.QuickFix));
}
exports.provideQuickFix = provideQuickFix;
//# sourceMappingURL=quickfix.js.map