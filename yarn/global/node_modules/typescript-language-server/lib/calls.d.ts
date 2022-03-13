import * as lsp from 'vscode-languageserver/node';
import * as lspcalls from './lsp-protocol.calls.proposed';
import { TspClient } from './tsp-client';
import { TextDocument } from 'vscode-languageserver-textdocument';
export declare function computeCallers(tspClient: TspClient, args: lsp.TextDocumentPositionParams): Promise<lspcalls.CallsResult>;
export declare type DocumentProvider = (file: string) => TextDocument | undefined;
export declare function computeCallees(tspClient: TspClient, args: lsp.TextDocumentPositionParams, documentProvider: DocumentProvider): Promise<lspcalls.CallsResult>;
//# sourceMappingURL=calls.d.ts.map