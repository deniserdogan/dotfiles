"use strict";
/*
 * Copyright (C) 2017, 2018 TypeFox and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
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
exports.PrefixingLogger = exports.ConsoleLogger = exports.LspClientLogger = void 0;
const lsp = __importStar(require("vscode-languageserver/node"));
class LspClientLogger {
    constructor(client, level) {
        this.client = client;
        this.level = level;
    }
    sendMessage(severity, messageObjects) {
        if (this.level >= severity) {
            const message = messageObjects.map(p => {
                if (typeof p === 'object') {
                    return JSON.stringify(p, null, 2);
                }
                else {
                    return p;
                }
            }).join(' ');
            this.client.logMessage({
                type: severity,
                message: message
            });
        }
    }
    error(...arg) {
        this.sendMessage(lsp.MessageType.Error, arg);
    }
    warn(...arg) {
        this.sendMessage(lsp.MessageType.Warning, arg);
    }
    info(...arg) {
        this.sendMessage(lsp.MessageType.Info, arg);
    }
    log(...arg) {
        this.sendMessage(lsp.MessageType.Log, arg);
    }
}
exports.LspClientLogger = LspClientLogger;
class ConsoleLogger {
    constructor(isLogEnabled) {
        this.isLogEnabled = isLogEnabled;
    }
    toStrings(...arg) {
        return arg.map(a => JSON.stringify(a, null, 2));
    }
    error(...arg) {
        console.error(...this.toStrings(arg));
    }
    warn(...arg) {
        console.warn(...this.toStrings(arg));
    }
    info(...arg) {
        // eslint-disable-next-line no-console
        console.info(...this.toStrings(arg));
    }
    log(...arg) {
        if (this.isLogEnabled) {
            // eslint-disable-next-line no-console
            console.log(...this.toStrings(arg));
        }
    }
}
exports.ConsoleLogger = ConsoleLogger;
class PrefixingLogger {
    constructor(logger, prefix) {
        this.logger = logger;
        this.prefix = prefix;
    }
    error(...arg) {
        this.logger.error(this.prefix, ...arg);
    }
    warn(...arg) {
        this.logger.warn(this.prefix, ...arg);
    }
    info(...arg) {
        this.logger.info(this.prefix, ...arg);
    }
    log(...arg) {
        this.logger.log(this.prefix, ...arg);
    }
}
exports.PrefixingLogger = PrefixingLogger;
//# sourceMappingURL=logger.js.map