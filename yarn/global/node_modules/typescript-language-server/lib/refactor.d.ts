import * as lsp from 'vscode-languageserver/node';
import tsp from 'typescript/lib/protocol';
export declare function provideRefactors(response: tsp.GetApplicableRefactorsResponse | undefined, args: tsp.FileRangeRequestArgs): Array<lsp.CodeAction>;
export declare function asSelectRefactoring(info: tsp.ApplicableRefactorInfo, args: tsp.FileRangeRequestArgs): lsp.CodeAction;
export declare function asApplyRefactoring(action: tsp.RefactorActionInfo, info: tsp.ApplicableRefactorInfo, args: tsp.FileRangeRequestArgs): lsp.CodeAction;
//# sourceMappingURL=refactor.d.ts.map