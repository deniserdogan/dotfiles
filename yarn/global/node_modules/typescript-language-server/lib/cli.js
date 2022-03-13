#!/usr/bin/env node
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
const commander_1 = require("commander");
const lsp_connection_1 = require("./lsp-connection");
const lsp = __importStar(require("vscode-languageserver/node"));
const DEFAULT_LOG_LEVEL = lsp.MessageType.Info;
const program = new commander_1.Command('typescript-language-server')
    // eslint-disable-next-line @typescript-eslint/no-require-imports, @typescript-eslint/no-var-requires
    .version(require('../package.json').version)
    .requiredOption('--stdio', 'use stdio')
    .option('--log-level <logLevel>', 'A number indicating the log level (4 = log, 3 = info, 2 = warn, 1 = error). Defaults to `2`.')
    .option('--tsserver-log-file <tsserverLogFile>', 'Specify a tsserver log file. example: --tsserver-log-file ts-logs.txt')
    .option('--tsserver-log-verbosity <tsserverLogVerbosity>', 'Specify a tsserver log verbosity (terse, normal, verbose). Defaults to `normal`.' +
    ' example: --tsserver-log-verbosity verbose')
    .option('--tsserver-path <path>', 'Specify path to tsserver directory. example: --tsserver-path=/Users/me/typescript/lib/')
    .parse(process.argv);
const options = program.opts();
if (options.tsserverLogFile && !options.tsserverLogVerbosity) {
    options.tsserverLogVerbosity = 'normal';
}
let logLevel = DEFAULT_LOG_LEVEL;
if (options.logLevel) {
    logLevel = parseInt(options.logLevel, 10);
    if (logLevel && (logLevel < 1 || logLevel > 4)) {
        console.error(`Invalid '--log-level ${logLevel}'. Falling back to 'info' level.`);
        logLevel = DEFAULT_LOG_LEVEL;
    }
}
(0, lsp_connection_1.createLspConnection)({
    tsserverPath: options.tsserverPath,
    tsserverLogFile: options.tsserverLogFile,
    tsserverLogVerbosity: options.tsserverLogVerbosity,
    showMessageLevel: logLevel
}).listen();
//# sourceMappingURL=cli.js.map