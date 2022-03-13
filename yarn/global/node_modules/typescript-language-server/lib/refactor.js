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
exports.asApplyRefactoring = exports.asSelectRefactoring = exports.provideRefactors = void 0;
const lsp = __importStar(require("vscode-languageserver/node"));
const commands_1 = require("./commands");
function provideRefactors(response, args) {
    if (!response || !response.body) {
        return [];
    }
    const actions = [];
    for (const info of response.body) {
        if (info.inlineable === false) {
            actions.push(asSelectRefactoring(info, args));
        }
        else {
            for (const action of info.actions) {
                actions.push(asApplyRefactoring(action, info, args));
            }
        }
    }
    return actions;
}
exports.provideRefactors = provideRefactors;
function asSelectRefactoring(info, args) {
    return lsp.CodeAction.create(info.description, lsp.Command.create(info.description, commands_1.Commands.SELECT_REFACTORING, info, args), lsp.CodeActionKind.Refactor);
}
exports.asSelectRefactoring = asSelectRefactoring;
function asApplyRefactoring(action, info, args) {
    return lsp.CodeAction.create(action.description, lsp.Command.create(action.description, commands_1.Commands.APPLY_REFACTORING, Object.assign(Object.assign({}, args), { refactor: info.name, action: action.name })), asKind(info));
}
exports.asApplyRefactoring = asApplyRefactoring;
function asKind(refactor) {
    if (refactor.name.startsWith('function_')) {
        return lsp.CodeActionKind.RefactorExtract + '.function';
    }
    else if (refactor.name.startsWith('constant_')) {
        return lsp.CodeActionKind.RefactorExtract + '.constant';
    }
    else if (refactor.name.startsWith('Move')) {
        return lsp.CodeActionKind.Refactor + '.move';
    }
    return lsp.CodeActionKind.Refactor;
}
//# sourceMappingURL=refactor.js.map