// Shared staleness sequence counter for async zone and city resolution.
let seq = 0;

export const nextZoneRequestSeq = (): number => ++seq;
export const currentZoneRequestSeq = (): number => seq;

