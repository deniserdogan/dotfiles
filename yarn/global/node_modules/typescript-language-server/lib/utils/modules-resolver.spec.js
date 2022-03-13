"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai = __importStar(require("chai"));
const path = __importStar(require("path"));
const modules_resolver_1 = require("./modules-resolver");
const versionProvider_1 = require("./versionProvider");
describe('findPathToModule', () => {
    it('resolves tsserver in own directory', () => {
        const dir = path.join(__dirname, '../..');
        const tsserverPath = (0, modules_resolver_1.findPathToModule)(dir, versionProvider_1.MODULE_FOLDERS);
        chai.assert.equal(tsserverPath, path.resolve(dir, 'node_modules/typescript/lib'));
    });
    it('resolves tsserver in parent directory', () => {
        const tsserverPath = (0, modules_resolver_1.findPathToModule)(__dirname, versionProvider_1.MODULE_FOLDERS);
        chai.assert.equal(tsserverPath, path.resolve(__dirname, '../../node_modules/typescript/lib'));
    });
});
//# sourceMappingURL=modules-resolver.spec.js.map