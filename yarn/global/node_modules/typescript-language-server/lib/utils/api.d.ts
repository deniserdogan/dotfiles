export default class API {
    /**
     * Human readable string for the current version. Displayed in the UI
     */
    readonly displayName: string;
    /**
     * Semver version, e.g. '3.9.0'
     */
    readonly version: string;
    /**
     * Full version string including pre-release tags, e.g. '3.9.0-beta'
     */
    readonly fullVersionString: string;
    static fromSimpleString(value: string): API;
    static readonly defaultVersion: API;
    static readonly v240: API;
    static readonly v250: API;
    static readonly v260: API;
    static readonly v270: API;
    static readonly v280: API;
    static readonly v290: API;
    static readonly v291: API;
    static readonly v300: API;
    static readonly v310: API;
    static readonly v314: API;
    static readonly v320: API;
    static readonly v333: API;
    static readonly v340: API;
    static readonly v345: API;
    static readonly v350: API;
    static readonly v380: API;
    static readonly v381: API;
    static readonly v390: API;
    static readonly v400: API;
    static readonly v401: API;
    static readonly v420: API;
    static readonly v430: API;
    static readonly v440: API;
    static fromVersionString(versionString: string): API;
    private constructor();
    eq(other: API): boolean;
    gte(other: API): boolean;
    lt(other: API): boolean;
}
//# sourceMappingURL=api.d.ts.map