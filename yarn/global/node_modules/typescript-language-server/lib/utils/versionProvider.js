"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TypeScriptVersionProvider = exports.MODULE_FOLDERS = exports.TypeScriptVersion = void 0;
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const which_1 = __importDefault(require("which"));
const pkg_up_1 = __importDefault(require("pkg-up"));
const api_1 = __importDefault(require("./api"));
const modules_resolver_1 = require("./modules-resolver");
class TypeScriptVersion {
    constructor(source, path, _pathLabel) {
        this.source = source;
        this.path = path;
        this._pathLabel = _pathLabel;
        this._api = null;
    }
    get tscPath() {
        return path_1.default.resolve(this.path, '../bin/tsc');
    }
    get tsServerPath() {
        return path_1.default.resolve(this.path, 'tsserver.js');
    }
    get pathLabel() {
        return typeof this._pathLabel === 'undefined' ? this.path : this._pathLabel;
    }
    get isValid() {
        return this.version !== null;
    }
    get version() {
        if (this._api) {
            return this._api;
        }
        this._api = this.getTypeScriptVersion(this.tsServerPath);
        return this._api;
    }
    get versionString() {
        const version = this.version;
        return version ? version.displayName : null;
    }
    getTypeScriptVersion(serverPath) {
        if (!fs_1.default.existsSync(serverPath)) {
            return null;
        }
        const p = serverPath.split(path_1.default.sep);
        if (p.length <= 2) {
            return null;
        }
        const p2 = p.slice(0, -2);
        const modulePath = p2.join(path_1.default.sep);
        let fileName = path_1.default.join(modulePath, 'package.json');
        if (!fs_1.default.existsSync(fileName)) {
            // Special case for ts dev versions
            if (path_1.default.basename(modulePath) === 'built') {
                fileName = path_1.default.join(modulePath, '..', 'package.json');
            }
        }
        if (!fs_1.default.existsSync(fileName)) {
            return null;
        }
        const contents = fs_1.default.readFileSync(fileName).toString();
        let desc = null;
        try {
            desc = JSON.parse(contents);
        }
        catch (err) {
            return null;
        }
        if (!desc || !desc.version) {
            return null;
        }
        return desc.version ? api_1.default.fromVersionString(desc.version) : null;
    }
}
exports.TypeScriptVersion = TypeScriptVersion;
exports.MODULE_FOLDERS = ['node_modules/typescript/lib', '.vscode/pnpify/typescript/lib', '.yarn/sdks/typescript/lib'];
class TypeScriptVersionProvider {
    constructor(configuration) {
        this.configuration = configuration;
    }
    getUserSettingVersion() {
        const { tsserverPath } = this.configuration || {};
        if (!tsserverPath) {
            return null;
        }
        let resolvedPath = tsserverPath;
        // Resolve full path to the binary if path is not absolute.
        if (!path_1.default.isAbsolute(resolvedPath)) {
            const binaryPath = which_1.default.sync(tsserverPath, { nothrow: true });
            if (binaryPath) {
                resolvedPath = binaryPath;
            }
        }
        // Resolve symbolic link.
        let stat = fs_1.default.lstatSync(resolvedPath, { throwIfNoEntry: false });
        if (stat === null || stat === void 0 ? void 0 : stat.isSymbolicLink()) {
            resolvedPath = fs_1.default.realpathSync(resolvedPath);
        }
        // Get directory path
        stat = fs_1.default.lstatSync(resolvedPath, { throwIfNoEntry: false });
        if (stat === null || stat === void 0 ? void 0 : stat.isFile()) {
            resolvedPath = path_1.default.dirname(resolvedPath);
        }
        // Resolve path to the "lib" dir.
        try {
            const packageJsonPath = pkg_up_1.default.sync({ cwd: resolvedPath });
            if (packageJsonPath) {
                resolvedPath = path_1.default.join(path_1.default.dirname(packageJsonPath), 'lib');
            }
        }
        catch (_a) {
            // ignore
        }
        return new TypeScriptVersion("user-setting" /* UserSetting */, resolvedPath);
    }
    getWorkspaceVersion(workspaceFolders) {
        for (const p of workspaceFolders) {
            const libFolder = (0, modules_resolver_1.findPathToModule)(p, exports.MODULE_FOLDERS);
            if (libFolder) {
                const version = new TypeScriptVersion("workspace" /* Workspace */, libFolder);
                if (version.isValid) {
                    return version;
                }
            }
        }
        return null;
    }
    bundledVersion() {
        try {
            const file = require.resolve('typescript');
            const bundledVersion = new TypeScriptVersion("bundled" /* Bundled */, path_1.default.dirname(file), '');
            return bundledVersion;
        }
        catch (e) {
            // window.showMessage('Bundled typescript module not found', 'error');
            return null;
        }
    }
}
exports.TypeScriptVersionProvider = TypeScriptVersionProvider;
//# sourceMappingURL=versionProvider.js.map