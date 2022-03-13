/**
 * Helpers for converting FROM LanguageServer types language-server ts types
 */
import type * as lsp from 'vscode-languageserver-protocol';
import type tsp from 'typescript/lib/protocol';
export declare namespace Position {
    const fromLocation: (tslocation: tsp.Location) => lsp.Position;
    const toLocation: (position: lsp.Position) => tsp.Location;
    const toFileLocationRequestArgs: (file: string, position: lsp.Position) => tsp.FileLocationRequestArgs;
}
//# sourceMappingURL=typeConverters.d.ts.map