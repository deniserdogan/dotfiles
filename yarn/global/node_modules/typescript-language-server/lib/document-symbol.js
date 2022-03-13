"use strict";
/*
 * Copyright (C) 2017, 2018 TypeFox and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.shouldIncludeEntry = exports.collectSymbolInformation = exports.collectDocumentSymbols = void 0;
const protocol_translation_1 = require("./protocol-translation");
const tsp_command_types_1 = require("./tsp-command-types");
function collectDocumentSymbols(parent, symbols) {
    return collectDocumentSymbolsInRange(parent, symbols, { start: (0, protocol_translation_1.asRange)(parent.spans[0]).start, end: (0, protocol_translation_1.asRange)(parent.spans[parent.spans.length - 1]).end });
}
exports.collectDocumentSymbols = collectDocumentSymbols;
function collectDocumentSymbolsInRange(parent, symbols, range) {
    let shouldInclude = shouldIncludeEntry(parent);
    for (const span of parent.spans) {
        const spanRange = (0, protocol_translation_1.asRange)(span);
        if (!protocol_translation_1.Range.intersection(range, spanRange)) {
            continue;
        }
        const children = [];
        if (parent.childItems) {
            for (const child of parent.childItems) {
                if (child.spans.some(childSpan => !!protocol_translation_1.Range.intersection(spanRange, (0, protocol_translation_1.asRange)(childSpan)))) {
                    const includedChild = collectDocumentSymbolsInRange(child, children, spanRange);
                    shouldInclude = shouldInclude || includedChild;
                }
            }
        }
        let selectionRange = spanRange;
        if (parent.nameSpan) {
            const nameRange = (0, protocol_translation_1.asRange)(parent.nameSpan);
            // In the case of mergeable definitions, the nameSpan is only correct for the first definition.
            if (protocol_translation_1.Range.intersection(spanRange, nameRange)) {
                selectionRange = nameRange;
            }
        }
        if (shouldInclude) {
            symbols.push({
                name: parent.text,
                detail: '',
                kind: (0, protocol_translation_1.toSymbolKind)(parent.kind),
                range: spanRange,
                selectionRange: selectionRange,
                children
            });
        }
    }
    return shouldInclude;
}
function collectSymbolInformation(uri, current, symbols, containerName) {
    let shouldInclude = shouldIncludeEntry(current);
    const name = current.text;
    for (const span of current.spans) {
        const range = (0, protocol_translation_1.asRange)(span);
        const children = [];
        if (current.childItems) {
            for (const child of current.childItems) {
                if (child.spans.some(span => !!protocol_translation_1.Range.intersection(range, (0, protocol_translation_1.asRange)(span)))) {
                    const includedChild = collectSymbolInformation(uri, child, children, name);
                    shouldInclude = shouldInclude || includedChild;
                }
            }
        }
        if (shouldInclude) {
            symbols.push({
                name,
                kind: (0, protocol_translation_1.toSymbolKind)(current.kind),
                location: {
                    uri,
                    range
                },
                containerName
            });
            symbols.push(...children);
        }
    }
    return shouldInclude;
}
exports.collectSymbolInformation = collectSymbolInformation;
function shouldIncludeEntry(item) {
    if (item.kind === tsp_command_types_1.ScriptElementKind.alias) {
        return false;
    }
    return !!(item.text && item.text !== '<function>' && item.text !== '<class>');
}
exports.shouldIncludeEntry = shouldIncludeEntry;
//# sourceMappingURL=document-symbol.js.map