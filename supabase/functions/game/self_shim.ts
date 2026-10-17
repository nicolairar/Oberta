// dart2js output reaches the global object as `self` (for crypto, used by
// Random.secure). Make sure it exists before engine.js runs.
const g = globalThis as unknown as { self?: unknown };
if (typeof g.self === 'undefined') g.self = globalThis;

export {};
