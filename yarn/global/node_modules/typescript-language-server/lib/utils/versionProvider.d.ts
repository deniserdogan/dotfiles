import API from './api';
import { IServerOptions } from './configuration';
export declare const enum TypeScriptVersionSource {
    Bundled = "bundled",
    UserSetting = "user-setting",
    Workspace = "workspace"
}
export declare class TypeScriptVersion {
    readonly source: TypeScriptVersionSource;
    readonly path: string;
    private readonly _pathLabel?;
    private _api;
    constructor(source: TypeScriptVersionSource, path: string, _pathLabel?: string | undefined);
    get tscPath(): string;
    get tsServerPath(): string;
    get pathLabel(): string;
    get isValid(): boolean;
    get version(): API | null;
    get versionString(): string | null;
    private getTypeScriptVersion;
}
export declare const MODULE_FOLDERS: string[];
export declare class TypeScriptVersionProvider {
    private configuration?;
    constructor(configuration?: IServerOptions | undefined);
    getUserSettingVersion(): TypeScriptVersion | null;
    getWorkspaceVersion(workspaceFolders: string[]): TypeScriptVersion | null;
    bundledVersion(): TypeScriptVersion | null;
}
//# sourceMappingURL=versionProvider.d.ts.map