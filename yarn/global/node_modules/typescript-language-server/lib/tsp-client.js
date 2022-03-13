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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TspClient = void 0;
const fs = __importStar(require("fs"));
const cp = __importStar(require("child_process"));
const readline = __importStar(require("readline"));
const decoder = __importStar(require("string_decoder"));
const tempy_1 = __importDefault(require("tempy"));
const logger_1 = require("./logger");
const utils_1 = require("./utils");
class TspClient {
    constructor(options) {
        this.options = options;
        this.seq = 0;
        this.deferreds = {};
        this.logger = new logger_1.PrefixingLogger(options.logger, '[tsclient]');
        this.tsserverLogger = new logger_1.PrefixingLogger(options.logger, '[tsserver]');
    }
    start() {
        if (this.readlineInterface) {
            return false;
        }
        const { tsserverPath, logFile, logVerbosity, disableAutomaticTypingAcquisition, maxTsServerMemory, npmLocation, globalPlugins, pluginProbeLocations } = this.options;
        const args = [];
        if (logFile) {
            args.push('--logFile', logFile);
        }
        if (logVerbosity) {
            args.push('--logVerbosity', logVerbosity);
        }
        if (globalPlugins && globalPlugins.length) {
            args.push('--globalPlugins', globalPlugins.join(','));
        }
        if (pluginProbeLocations && pluginProbeLocations.length) {
            args.push('--pluginProbeLocations', pluginProbeLocations.join(','));
        }
        if (disableAutomaticTypingAcquisition) {
            args.push('--disableAutomaticTypingAcquisition');
        }
        if (npmLocation) {
            this.logger.info(`using npm from ${npmLocation}`);
            args.push('--npmLocation', npmLocation);
        }
        this.cancellationPipeName = tempy_1.default.file({ name: 'tscancellation' });
        args.push('--cancellationPipeName', `${this.cancellationPipeName}*`);
        this.logger.log(`Starting tsserver : '${tsserverPath} ${args.join(' ')}'`);
        const options = {
            silent: true,
            execArgv: [
                ...maxTsServerMemory ? [`--max-old-space-size=${maxTsServerMemory}`] : []
            ]
        };
        this.tsserverProc = cp.fork(tsserverPath, args, options);
        this.tsserverProc.on('exit', (exitCode, signal) => {
            this.shutdown();
            if (this.options.onExit) {
                this.options.onExit(exitCode, signal);
            }
        });
        const { stdout, stdin, stderr } = this.tsserverProc;
        if (!stdout || !stdin || !stderr) {
            this.logger.error(`Failed initializing input/output of tsserver (stdin: ${!!stdin}, stdout: ${!!stdout}, stderr: ${!!stderr})`);
            return false;
        }
        this.readlineInterface = readline.createInterface(stdout, stdin, undefined);
        this.readlineInterface.on('line', line => this.processMessage(line));
        const dec = new decoder.StringDecoder('utf-8');
        stderr.addListener('data', data => {
            const stringMsg = typeof data === 'string' ? data : dec.write(data);
            this.tsserverLogger.error(stringMsg);
        });
        return true;
    }
    shutdown() {
        var _a, _b;
        (_a = this.readlineInterface) === null || _a === void 0 ? void 0 : _a.close();
        (_b = this.tsserverProc.stdin) === null || _b === void 0 ? void 0 : _b.destroy();
        this.tsserverProc.kill();
    }
    notify(command, args) {
        this.sendMessage(command, true, args);
    }
    request(command, args, token) {
        this.sendMessage(command, false, args);
        const seq = this.seq;
        const deferred = new utils_1.Deferred();
        this.deferreds[seq] = deferred;
        const request = deferred.promise;
        if (token) {
            const onCancelled = token.onCancellationRequested(() => {
                onCancelled.dispose();
                if (this.cancellationPipeName) {
                    const requestCancellationPipeName = `${this.cancellationPipeName}${seq}`;
                    fs.writeFile(requestCancellationPipeName, '', err => {
                        if (!err) {
                            request.then(() => fs.unlink(requestCancellationPipeName, () => { }));
                        }
                    });
                }
            });
        }
        return request;
    }
    sendMessage(command, notification, args) {
        this.seq = this.seq + 1;
        const request = {
            command,
            seq: this.seq,
            type: 'request'
        };
        if (args) {
            request.arguments = args;
        }
        const serializedRequest = JSON.stringify(request) + '\n';
        this.tsserverProc.stdin.write(serializedRequest);
        this.logger.log(notification ? 'notify' : 'request', request);
    }
    processMessage(untrimmedMessageString) {
        const messageString = untrimmedMessageString.trim();
        if (!messageString || messageString.startsWith('Content-Length:')) {
            return;
        }
        const message = JSON.parse(messageString);
        this.logger.log('processMessage', message);
        if (this.isResponse(message)) {
            this.resolveResponse(message, message.request_seq, message.success);
        }
        else if (this.isEvent(message)) {
            if (this.isRequestCompletedEvent(message)) {
                this.resolveResponse(message, message.body.request_seq, true);
            }
            else {
                if (this.options.onEvent) {
                    this.options.onEvent(message);
                }
            }
        }
    }
    resolveResponse(message, request_seq, success) {
        const deferred = this.deferreds[request_seq];
        this.logger.log('request completed', { request_seq, success });
        if (deferred) {
            if (success) {
                this.deferreds[request_seq].resolve(message);
            }
            else {
                this.deferreds[request_seq].reject(message);
            }
            delete this.deferreds[request_seq];
        }
    }
    isEvent(message) {
        return message.type === 'event';
    }
    isResponse(message) {
        return message.type === 'response';
    }
    isRequestCompletedEvent(message) {
        return this.isEvent(message) && message.event === 'requestCompleted';
    }
}
exports.TspClient = TspClient;
//# sourceMappingURL=tsp-client.js.map