export default class SnippetString {
    static isSnippetString(thing: any): thing is SnippetString;
    private static _escape;
    private _tabstop;
    value: string;
    constructor(value?: string);
    appendText(str: string): SnippetString;
    appendTabstop(n?: number): SnippetString;
    appendPlaceholder(value: string | ((snippet: SnippetString) => any), n?: number): SnippetString;
    appendVariable(name: string, defaultValue?: string | ((snippet: SnippetString) => any)): SnippetString;
}
//# sourceMappingURL=SnippetString.d.ts.map