import * as lsp from 'vscode-languageserver/node';
import tsp from 'typescript/lib/protocol';
import { LspDocuments } from './document';
export declare function provideQuickFix(response: tsp.GetCodeFixesResponse | undefined, documents: LspDocuments | undefined): Array<lsp.CodeAction>;
//# sourceMappingURL=quickfix.d.ts.map