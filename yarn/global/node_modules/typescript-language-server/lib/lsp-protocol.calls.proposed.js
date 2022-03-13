/* --------------------------------------------------------------------------------------------
 * Copyright (c) TypeFox and others. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */
'use strict';
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
exports.DefinitionSymbol = exports.CallDirection = exports.CallsRequest = void 0;
const lsp = __importStar(require("vscode-languageserver/node"));
/**
 * A request to resolve all calls at a given text document position of a symbol definition or a call the same.
 * The request's parameter is of type [CallsParams](#CallsParams), the response is of type [CallsResult](#CallsResult) or a
 * Thenable that resolves to such.
 */
var CallsRequest;
(function (CallsRequest) {
    CallsRequest.type = new lsp.RequestType('textDocument/calls');
})(CallsRequest = exports.CallsRequest || (exports.CallsRequest = {}));
/**
 * Enum of call direction kinds
 */
var CallDirection;
(function (CallDirection) {
    /**
     * Incoming calls aka. callers
     */
    CallDirection["Incoming"] = "incoming";
    /**
     * Outgoing calls aka. callees
     */
    CallDirection["Outgoing"] = "outgoing";
})(CallDirection = exports.CallDirection || (exports.CallDirection = {}));
var DefinitionSymbol;
(function (DefinitionSymbol) {
    function create(uri, symbol) {
        const { name, detail, kind, range, selectionRange } = symbol;
        const location = { uri, range };
        return { name, detail, kind, location, selectionRange };
    }
    DefinitionSymbol.create = create;
})(DefinitionSymbol = exports.DefinitionSymbol || (exports.DefinitionSymbol = {}));
//# sourceMappingURL=lsp-protocol.calls.proposed.js.map