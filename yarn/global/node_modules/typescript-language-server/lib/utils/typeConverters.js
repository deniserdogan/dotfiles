"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Position = void 0;
var Position;
(function (Position) {
    Position.fromLocation = (tslocation) => {
        return {
            line: tslocation.line - 1,
            character: tslocation.offset - 1
        };
    };
    Position.toLocation = (position) => ({
        line: position.line + 1,
        offset: position.character + 1
    });
    Position.toFileLocationRequestArgs = (file, position) => ({
        file,
        line: position.line + 1,
        offset: position.character + 1
    });
})(Position = exports.Position || (exports.Position = {}));
//# sourceMappingURL=typeConverters.js.map