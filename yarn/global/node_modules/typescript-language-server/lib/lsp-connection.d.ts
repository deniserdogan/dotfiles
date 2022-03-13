import * as lsp from 'vscode-languageserver/node';
export interface IServerOptions {
    tsserverPath: string;
    tsserverLogFile?: string;
    tsserverLogVerbosity?: string;
    showMessageLevel: lsp.MessageType;
}
export declare function createLspConnection(options: IServerOptions): lsp.Connection;
//# sourceMappingURL=lsp-connection.d.ts.map