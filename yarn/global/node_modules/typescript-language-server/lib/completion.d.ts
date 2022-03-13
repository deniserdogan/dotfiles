import * as lsp from 'vscode-languageserver/node';
import type tsp from 'typescript/lib/protocol';
import { LspDocument } from './document';
import { TspClient } from './tsp-client';
import { CompletionOptions } from './ts-protocol';
interface TSCompletionItem extends lsp.CompletionItem {
    data: tsp.CompletionDetailsRequestArgs;
}
export declare function asCompletionItem(entry: tsp.CompletionEntry, file: string, position: lsp.Position, document: LspDocument): TSCompletionItem;
export declare function asResolvedCompletionItem(item: lsp.CompletionItem, details: tsp.CompletionEntryDetails, client: TspClient, options: CompletionOptions): Promise<lsp.CompletionItem>;
export declare function isValidFunctionCompletionContext(filepath: string, position: lsp.Position, client: TspClient): Promise<boolean>;
export {};
//# sourceMappingURL=completion.d.ts.map