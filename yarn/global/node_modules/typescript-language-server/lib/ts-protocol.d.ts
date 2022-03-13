/**
 * **IMPORTANT** this module should not depend on `vscode-languageserver` only protocol and types
 */
import * as lsp from 'vscode-languageserver-protocol';
import { FormatCodeSettings, UserPreferences } from 'typescript/lib/protocol';
import { InlayHintsOptions } from './lsp-protocol.inlayHints.proposed';
export declare namespace TypeScriptRenameRequest {
    const type: lsp.RequestType<lsp.TextDocumentPositionParams, void, void>;
}
export declare class DisplayPartKind {
    static readonly functionName = "functionName";
    static readonly methodName = "methodName";
    static readonly parameterName = "parameterName";
    static readonly propertyName = "propertyName";
    static readonly punctuation = "punctuation";
    static readonly text = "text";
}
export interface TypeScriptPlugin {
    name: string;
    location: string;
}
export interface TypeScriptInitializationOptions {
    disableAutomaticTypingAcquisition?: boolean;
    logVerbosity?: string;
    maxTsServerMemory?: number;
    npmLocation?: string;
    plugins: TypeScriptPlugin[];
    preferences?: UserPreferences;
    hostInfo?: string;
}
export declare type TypeScriptInitializeParams = lsp.InitializeParams & {
    initializationOptions?: Partial<TypeScriptInitializationOptions>;
};
export interface TypeScriptInitializeResult extends lsp.InitializeResult {
    logFileUri?: string;
}
export interface TypeScriptWorkspaceSettingsLanguageSettings {
    format?: FormatCodeSettings;
    inlayHints?: InlayHintsOptions;
}
interface TypeScriptWorkspaceSettingsDiagnostics {
    ignoredCodes?: number[];
}
export interface TypeScriptWorkspaceSettings {
    javascript?: TypeScriptWorkspaceSettingsLanguageSettings;
    typescript?: TypeScriptWorkspaceSettingsLanguageSettings;
    completions?: CompletionOptions;
    diagnostics?: TypeScriptWorkspaceSettingsDiagnostics;
}
export interface CompletionOptions {
    completeFunctionCalls?: boolean;
}
export {};
//# sourceMappingURL=ts-protocol.d.ts.map