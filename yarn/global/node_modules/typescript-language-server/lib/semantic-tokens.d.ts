import { LspDocument } from './document';
/**
 * Transforms the semantic token spans given by the ts-server into lsp compatible spans.
 * @param doc the document we are operating on
 * @param spans the spans given by ts-server
 * @returns lsp compatible spans
 */
export declare function transformSpans(doc: LspDocument, spans: number[]): number[];
//# sourceMappingURL=semantic-tokens.d.ts.map