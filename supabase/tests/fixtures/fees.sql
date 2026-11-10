-- Пул ҳисоби учун энг кам созламалар (fee_settings). Фақат CI/маҳаллий бўш базада: бор калитга тегмайди.
-- Қийматлар тахминий, ҳақиқий тарифлар эмас. Тестлар аниқ сонга эмас, қоидага таянади (жами = товар + хизмат ...).
insert into public.fee_settings (key, value, note) values
  ('fixed_fee', 5000, 'ci'), ('tier_mode', 0, 'ci'),
  ('tier1_max', 1000000, 'ci'), ('tier2_max', 5000000, 'ci'),
  ('tier1_pct', 5, 'ci'), ('tier2_pct', 4, 'ci'), ('tier3_pct', 3, 'ci'),
  ('collector_fixed', 10000, 'ci'), ('collector_max', 50000, 'ci'), ('collector_share', 30, 'ci'),
  ('driver_pct', 10, 'ci'), ('min_order', 50000, 'ci')
on conflict (key) do nothing;
