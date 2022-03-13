import * as lsp from 'vscode-languageserver/node';
import tsp from 'typescript/lib/protocol';
import { RequestHandler } from 'vscode-jsonrpc';
export declare type InlayHintsParams = {
    /**
     * The document to format.
     */
    textDocument: lsp.TextDocumentIdentifier;
    /**
     * The range to format
     */
    range?: lsp.Range;
};
declare type InlayHint = {
    text: string;
    position: lsp.Position;
    kind: tsp.InlayHintKind;
    whitespaceBefore?: boolean;
    whitespaceAfter?: boolean;
};
export declare type InlayHintsResult = {
    inlayHints: InlayHint[];
};
export declare const type: lsp.RequestType<InlayHintsParams, InlayHintsResult, lsp.TextDocumentRegistrationOptions>;
export declare type HandlerSignature = RequestHandler<InlayHintsParams, InlayHintsResult | null, void>;
export interface InlayHintsOptions {
    includeInlayParameterNameHints?: 'none' | 'literals' | 'all';
    includeInlayParameterNameHintsWhenArgumentMatchesName?: boolean;
    includeInlayFunctionParameterTypeHints?: boolean;
    includeInlayVariableTypeHints?: boolean;
    includeInlayPropertyDeclarationTypeHints?: boolean;
    includeInlayFunctionLikeReturnTypeHints?: boolean;
    includeInlayEnumMemberValueHints?: boolean;
}
export {};
//# sourceMappingURL=lsp-protocol.inlayHints.proposed.d.ts.map