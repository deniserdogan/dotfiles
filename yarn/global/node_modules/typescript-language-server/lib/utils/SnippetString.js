"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
class SnippetString {
    constructor(value) {
        this._tabstop = 1;
        this.value = value || '';
    }
    static isSnippetString(thing) {
        if (thing instanceof SnippetString) {
            return true;
        }
        if (!thing) {
            return false;
        }
        return typeof thing.value === 'string';
    }
    static _escape(value) {
        return value.replace(/\$|}|\\/g, '\\$&');
    }
    appendText(str) {
        this.value += SnippetString._escape(str);
        return this;
    }
    appendTabstop(n = this._tabstop++) {
        this.value += '$';
        this.value += n;
        return this;
    }
    appendPlaceholder(value, n = this._tabstop++) {
        if (typeof value === 'function') {
            const nested = new SnippetString();
            nested._tabstop = this._tabstop;
            value(nested);
            this._tabstop = nested._tabstop;
            value = nested.value;
        }
        else {
            value = SnippetString._escape(value);
        }
        this.value += '${';
        this.value += n;
        this.value += ':';
        this.value += value;
        this.value += '}';
        return this;
    }
    appendVariable(name, defaultValue) {
        if (typeof defaultValue === 'function') {
            const nested = new SnippetString();
            nested._tabstop = this._tabstop;
            defaultValue(nested);
            this._tabstop = nested._tabstop;
            defaultValue = nested.value;
        }
        else if (typeof defaultValue === 'string') {
            defaultValue = defaultValue.replace(/\$|}/g, '\\$&');
        }
        this.value += '${';
        this.value += name;
        if (defaultValue) {
            this.value += ':';
            this.value += defaultValue;
        }
        this.value += '}';
        return this;
    }
}
exports.default = SnippetString;
//# sourceMappingURL=SnippetString.js.map