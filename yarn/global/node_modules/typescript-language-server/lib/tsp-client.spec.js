"use strict";
/*
 * Copyright (C) 2017, 2018 TypeFox and others.
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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai = __importStar(require("chai"));
const tsp_client_1 = require("./tsp-client");
const logger_1 = require("./logger");
const test_utils_1 = require("./test-utils");
const versionProvider_1 = require("./utils/versionProvider");
const assert = chai.assert;
const typescriptVersionProvider = new versionProvider_1.TypeScriptVersionProvider();
const bundled = typescriptVersionProvider.bundledVersion();
const server = new tsp_client_1.TspClient({
    logger: new logger_1.ConsoleLogger(),
    tsserverPath: bundled.tsServerPath
});
describe('ts server client', () => {
    before(() => {
        server.start();
    });
    it('completion', () => __awaiter(void 0, void 0, void 0, function* () {
        const f = (0, test_utils_1.filePath)('module2.ts');
        server.notify("open" /* Open */, {
            file: f,
            fileContent: (0, test_utils_1.readContents)(f)
        });
        const completions = yield server.request("completionInfo" /* CompletionInfo */, {
            file: f,
            line: 1,
            offset: 0,
            prefix: 'im'
        });
        assert.isDefined(completions.body);
        assert.equal(completions.body.entries[1].name, 'ImageBitmap');
    })).timeout(10000);
    it('references', () => __awaiter(void 0, void 0, void 0, function* () {
        const f = (0, test_utils_1.filePath)('module2.ts');
        server.notify("open" /* Open */, {
            file: f,
            fileContent: (0, test_utils_1.readContents)(f)
        });
        const references = yield server.request("references" /* References */, {
            file: f,
            line: 8,
            offset: 16
        });
        assert.isDefined(references.body);
        assert.equal(references.body.symbolName, 'doStuff');
    })).timeout(10000);
    it('inlayHints', () => __awaiter(void 0, void 0, void 0, function* () {
        const f = (0, test_utils_1.filePath)('module2.ts');
        server.notify("open" /* Open */, {
            file: f,
            fileContent: (0, test_utils_1.readContents)(f)
        });
        yield server.request("configure" /* Configure */, {
            preferences: {
                // @ts-expect-error preference exist
                includeInlayFunctionLikeReturnTypeHints: true
            }
        });
        const inlayHints = yield server.request("provideInlayHints" /* ProvideInlayHints */, {
            file: f,
            start: 0,
            length: 1000
        });
        assert.isDefined(inlayHints.body);
        assert.equal(inlayHints.body[0].text, ': boolean');
    })).timeout(10000);
    it('documentHighlight', () => __awaiter(void 0, void 0, void 0, function* () {
        const f = (0, test_utils_1.filePath)('module2.ts');
        server.notify("open" /* Open */, {
            file: f,
            fileContent: (0, test_utils_1.readContents)(f)
        });
        const response = yield server.request("documentHighlights" /* DocumentHighlights */, {
            file: f,
            line: 8,
            offset: 16,
            filesToSearch: [f]
        });
        assert.isDefined(response.body);
        assert.isTrue(response.body.some(({ file }) => file.endsWith('module2.ts')), JSON.stringify(response.body, undefined, 2));
        assert.isFalse(response.body.some(({ file: file_1 }) => file_1.endsWith('module1.ts')), JSON.stringify(response.body, undefined, 2));
    })).timeout(10000);
});
//# sourceMappingURL=tsp-client.spec.js.map