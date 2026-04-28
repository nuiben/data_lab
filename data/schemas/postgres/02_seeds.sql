-- Static reference data — dim_products

INSERT INTO dim_products (product_id, name, description) VALUES
    ('RCA',  'Revenue Continuity Agreement',   'Revenue drops >30% for 90+ consecutive days'),
    ('BLF',  'Bridge Liquidity Facility',      'Short-term cash flow gap, duration <90 days'),
    ('KPRC', 'Key Person Retention Contract',  'C-suite departure or incapacitation event'),
    ('ODC',  'Operational Disruption Contract','Unplanned operational shutdown (facility, system, etc.)'),
    ('DCR',  'Dependency Chain Reserve',       'Critical supplier or customer failure'),
    ('ECA',  'Enterprise Continuity Agreement','Catastrophic business event (acquisition, dissolution, etc.)'),
    ('TEC',  'Trigger Event Contract',         'Named event: cyber breach, litigation, regulatory action'),
    ('WTR',  'Workforce Transition Reserve',   'Mass workforce event or regulatory mandate')
ON CONFLICT (product_id) DO NOTHING;
