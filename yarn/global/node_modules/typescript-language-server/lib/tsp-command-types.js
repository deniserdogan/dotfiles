"use strict";
/**
 * copied over from typescript/lib/protocol.d.ts due to https://github.com/Microsoft/TypeScript/issues/18468
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.KindModifiers = exports.ScriptElementKind = void 0;
var ScriptElementKind;
(function (ScriptElementKind) {
    ScriptElementKind["unknown"] = "";
    ScriptElementKind["warning"] = "warning";
    /** predefined type (void) or keyword (class) */
    ScriptElementKind["keyword"] = "keyword";
    /** top level script node */
    ScriptElementKind["scriptElement"] = "script";
    /** module foo {} */
    ScriptElementKind["moduleElement"] = "module";
    /** class X {} */
    ScriptElementKind["classElement"] = "class";
    /** var x = class X {} */
    ScriptElementKind["localClassElement"] = "local class";
    /** interface Y {} */
    ScriptElementKind["interfaceElement"] = "interface";
    /** type T = ... */
    ScriptElementKind["typeElement"] = "type";
    /** enum E */
    ScriptElementKind["enumElement"] = "enum";
    ScriptElementKind["enumMemberElement"] = "enum member";
    /**
     * Inside module and script only
     * const v = ..
     */
    ScriptElementKind["variableElement"] = "var";
    /** Inside function */
    ScriptElementKind["localVariableElement"] = "local var";
    /**
     * Inside module and script only
     * function f() { }
     */
    ScriptElementKind["functionElement"] = "function";
    /** Inside function */
    ScriptElementKind["localFunctionElement"] = "local function";
    /** class X { [public|private]* foo() {} } */
    ScriptElementKind["memberFunctionElement"] = "method";
    /** class X { [public|private]* [get|set] foo:number; } */
    ScriptElementKind["memberGetAccessorElement"] = "getter";
    ScriptElementKind["memberSetAccessorElement"] = "setter";
    /**
     * class X { [public|private]* foo:number; }
     * interface Y { foo:number; }
     */
    ScriptElementKind["memberVariableElement"] = "property";
    /** class X { constructor() { } } */
    ScriptElementKind["constructorImplementationElement"] = "constructor";
    /** interface Y { ():number; } */
    ScriptElementKind["callSignatureElement"] = "call";
    /** interface Y { []:number; } */
    ScriptElementKind["indexSignatureElement"] = "index";
    /** interface Y { new():Y; } */
    ScriptElementKind["constructSignatureElement"] = "construct";
    /** function foo(*Y*: string) */
    ScriptElementKind["parameterElement"] = "parameter";
    ScriptElementKind["typeParameterElement"] = "type parameter";
    ScriptElementKind["primitiveType"] = "primitive type";
    ScriptElementKind["label"] = "label";
    ScriptElementKind["alias"] = "alias";
    ScriptElementKind["constElement"] = "const";
    ScriptElementKind["letElement"] = "let";
    ScriptElementKind["directory"] = "directory";
    ScriptElementKind["externalModuleName"] = "external module name";
    /**
     * <JsxTagName attribute1 attribute2={0} />
     */
    ScriptElementKind["jsxAttribute"] = "JSX attribute";
    /** String literal */
    ScriptElementKind["string"] = "string";
    /** Jsdoc @link: in `{@link C link text}`, the before and after text "{@link " and "}" */
    ScriptElementKind["link"] = "link";
    /** Jsdoc @link: in `{@link C link text}`, the entity name "C" */
    ScriptElementKind["linkName"] = "link name";
    /** Jsdoc @link: in `{@link C link text}`, the link text "link text" */
    ScriptElementKind["linkText"] = "link text";
})(ScriptElementKind = exports.ScriptElementKind || (exports.ScriptElementKind = {}));
class KindModifiers {
}
exports.KindModifiers = KindModifiers;
KindModifiers.optional = 'optional';
KindModifiers.deprecated = 'deprecated';
KindModifiers.color = 'color';
KindModifiers.dtsFile = '.d.ts';
KindModifiers.tsFile = '.ts';
KindModifiers.tsxFile = '.tsx';
KindModifiers.jsFile = '.js';
KindModifiers.jsxFile = '.jsx';
KindModifiers.jsonFile = '.json';
KindModifiers.fileExtensionKindModifiers = [
    KindModifiers.dtsFile,
    KindModifiers.tsFile,
    KindModifiers.tsxFile,
    KindModifiers.jsFile,
    KindModifiers.jsxFile,
    KindModifiers.jsonFile
];
//# sourceMappingURL=tsp-command-types.js.map