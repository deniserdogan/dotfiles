import { Logger } from '../logger';
import { LspClient } from '../lsp-client';
export interface IServerOptions {
    logger: Logger;
    tsserverPath?: string;
    tsserverLogFile?: string;
    tsserverLogVerbosity?: string;
    lspClient: LspClient;
}
//# sourceMappingURL=configuration.d.ts.map