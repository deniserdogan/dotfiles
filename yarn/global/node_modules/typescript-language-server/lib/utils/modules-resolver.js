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
exports.findPathToModule = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
function findPathToModule(dir, moduleNames) {
    const stat = fs.statSync(dir);
    if (stat.isDirectory()) {
        const candidates = moduleNames.map(moduleName => path.resolve(dir, moduleName));
        const modulePath = candidates.find(fs.existsSync);
        if (modulePath) {
            return modulePath;
        }
    }
    const parent = path.resolve(dir, '..');
    if (parent !== dir) {
        return findPathToModule(parent, moduleNames);
    }
}
exports.findPathToModule = findPathToModule;
//# sourceMappingURL=modules-resolver.js.map