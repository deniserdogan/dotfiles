"use strict";
/*
 * Copyright (C) 2017, 2018 TypeFox and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = __importDefault(require("chai"));
const test_utils_1 = require("./test-utils");
const assert = chai_1.default.assert;
let server;
before(() => __awaiter(void 0, void 0, void 0, function* () {
    server = yield (0, test_utils_1.createServer)({
        rootUri: (0, test_utils_1.uri)(),
        publishDiagnostics: () => { }
    });
}));
beforeEach(() => {
    server.closeAll();
});
describe('documentHighlight', () => {
    it('simple test', () => __awaiter(void 0, void 0, void 0, function* () {
        const doc = {
            uri: (0, test_utils_1.uri)('module2.ts'),
            languageId: 'typescript',
            version: 1,
            text: (0, test_utils_1.readContents)((0, test_utils_1.filePath)('module2.ts'))
        };
        server.didOpenTextDocument({
            textDocument: doc
        });
        const result = yield server.documentHighlight({
            textDocument: doc,
            position: (0, test_utils_1.lastPosition)(doc, 'doStuff')
        });
        assert.equal(2, result.length, JSON.stringify(result, undefined, 2));
    })).timeout(10000);
});
describe('completions', () => {
    it('receives completion that auto-imports from another module', () => __awaiter(void 0, void 0, void 0, function* () {
        const doc = {
            uri: (0, test_utils_1.uri)('completion.ts'),
            languageId: 'typescript',
            version: 1,
            text: (0, test_utils_1.readContents)((0, test_utils_1.filePath)('completion.ts'))
        };
        server.didOpenTextDocument({ textDocument: doc });
        const proposals = yield server.completion({
            textDocument: doc,
            position: (0, test_utils_1.positionAfter)(doc, 'doStuff')
        });
        assert.isNotNull(proposals);
        const completion = proposals.items.find(item => item.label === 'doStuff');
        assert.isDefined(completion);
        const resolvedCompletion = yield server.completionResolve(completion);
        assert.isDefined(resolvedCompletion.additionalTextEdits);
        assert.isUndefined(resolvedCompletion.command);
        server.didCloseTextDocument({ textDocument: doc });
    })).timeout(10000);
});
//# sourceMappingURL=file-lsp-server.spec.js.map