create index if not exists campana_notas_campana_fecha_idx
  on public.campana_notas (campaign_id, created_at desc);
