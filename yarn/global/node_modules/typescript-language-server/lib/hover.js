"use strict";
/*
 * Copyright (C) 2017, 2018 TypeFox and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.asSignatureHelp = void 0;
const protocol_translation_1 = require("./protocol-translation");
function asSignatureHelp(info) {
    return {
        activeSignature: info.selectedItemIndex,
        activeParameter: getActiveParameter(info),
        signatures: info.items.map(asSignatureInformation)
    };
}
exports.asSignatureHelp = asSignatureHelp;
function getActiveParameter(info) {
    const activeSignature = info.items[info.selectedItemIndex];
    if (activeSignature && activeSignature.isVariadic) {
        return Math.min(info.argumentIndex, activeSignature.parameters.length - 1);
    }
    return info.argumentIndex;
}
function asSignatureInformation(item) {
    const parameters = item.parameters.map(asParameterInformation);
    const signature = {
        label: (0, protocol_translation_1.asPlainText)(item.prefixDisplayParts),
        documentation: (0, protocol_translation_1.asDocumentation)({
            documentation: item.documentation,
            tags: item.tags.filter(x => x.name !== 'param')
        }),
        parameters
    };
    signature.label += parameters.map(parameter => parameter.label).join((0, protocol_translation_1.asPlainText)(item.separatorDisplayParts));
    signature.label += (0, protocol_translation_1.asPlainText)(item.suffixDisplayParts);
    return signature;
}
function asParameterInformation(parameter) {
    return {
        label: (0, protocol_translation_1.asPlainText)(parameter.displayParts),
        documentation: (0, protocol_translation_1.asDocumentation)(parameter)
    };
}
//# sourceMappingURL=hover.js.map