import * as lsp from 'vscode-languageserver/node';
import tsp from 'typescript/lib/protocol';
import { LspDocuments } from './document';
export declare function uriToPath(stringUri: string): string | undefined;
export declare function pathToUri(filepath: string, documents: LspDocuments | undefined): string;
/**
 * Normalizes the file system path.
 *
 * On systems other than Windows it should be an no-op.
 *
 * On Windows, an input path in a format like "C:/path/file.ts"
 * will be normalized to "c:/path/file.ts".
 */
export declare function normalizePath(filePath: string): string;
/**
 * Normalizes the path obtained through the "fsPath" property of the URI module.
 */
export declare function normalizeFsPath(fsPath: string): string;
export declare function toPosition(location: tsp.Location): lsp.Position;
export declare function toLocation(fileSpan: tsp.FileSpan, documents: LspDocuments | undefined): lsp.Location;
export declare function toFileRangeRequestArgs(file: string, range: lsp.Range): tsp.FileRangeRequestArgs;
export declare function toSymbolKind(tspKind: string): lsp.SymbolKind;
export declare function toDiagnostic(diagnostic: tsp.Diagnostic, documents: LspDocuments | undefined, publishDiagnosticsCapabilities: lsp.TextDocumentClientCapabilities['publishDiagnostics']): lsp.Diagnostic;
export declare function toTextEdit(edit: tsp.CodeEdit): lsp.TextEdit;
export declare function toTextDocumentEdit(change: tsp.FileCodeEdits, documents: LspDocuments | undefined): lsp.TextDocumentEdit;
export declare function toDocumentHighlight(item: tsp.DocumentHighlightsItem): lsp.DocumentHighlight[];
export declare function asRange(span: tsp.TextSpan): lsp.Range;
export declare function asDocumentation(data: {
    documentation?: tsp.SymbolDisplayPart[];
    tags?: tsp.JSDocTagInfo[];
}): lsp.MarkupContent | undefined;
export declare function asTagsDocumentation(tags: tsp.JSDocTagInfo[]): string;
export declare function asTagDocumentation(tag: tsp.JSDocTagInfo): string;
export declare function asTagBodyText(tag: tsp.JSDocTagInfo): string | undefined;
export declare function asPlainText(parts: string | tsp.SymbolDisplayPart[]): string;
export declare namespace Range {
    function intersection(one: lsp.Range, other: lsp.Range): lsp.Range | undefined;
}
//# sourceMappingURL=protocol-translation.d.ts.map