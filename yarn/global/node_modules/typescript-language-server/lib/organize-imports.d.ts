import * as lsp from 'vscode-languageserver/node';
import tsp from 'typescript/lib/protocol';
import { LspDocuments } from './document';
export declare function provideOrganizeImports(response: tsp.OrganizeImportsResponse | undefined, documents: LspDocuments | undefined): Array<lsp.CodeAction>;
//# sourceMappingURL=organize-imports.d.ts.map