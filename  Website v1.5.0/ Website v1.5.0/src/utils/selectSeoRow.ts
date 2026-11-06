// Zone-aware SEO row selection for get_seo_settings responses.
export const selectSeoRow = (rows: any[], zoneId: number | null = null): any => {
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const zoneRow =
    zoneId != null
      ? rows.find((r) => Number(r?.zone_id) === Number(zoneId))
      : null;
  const defaultRow = rows.find((r) => Number(r?.is_default) === 1);
  return zoneRow || defaultRow || rows[0];
};

export const pickSeoField = (row: any, key: string): any =>
  row?.translations?.[key] ?? row?.[key] ?? null;

