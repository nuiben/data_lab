-- XMOB & Co. — Static reference data
-- Applied after 01_fintech_schema.sql via `just db-migrate`.

-- ── MCC codes ─────────────────────────────────────────────────────────────────
-- Core codes relevant to XMOB's fleet / payments / logistics customer base.
-- has_override=TRUE marks codes known to drift in the FCC MCC override table.

INSERT INTO mcc_code (mcc, description, xmob_group, has_override) VALUES
    ('5541', 'Service Stations (with Ancillary Services)',  'Fuel & Energy',       TRUE),
    ('5542', 'Automated Fuel Dispensers',                   'Fuel & Energy',       TRUE),
    ('5172', 'Petroleum and Petroleum Products',            'Fuel & Energy',       TRUE),
    ('4215', 'Courier Services',                            'Logistics',           FALSE),
    ('4231', 'Transit and Ground Passenger Transportation', 'Logistics',           FALSE),
    ('5013', 'Motor Vehicle Supplies and New Parts',        'Fleet Maintenance',   FALSE),
    ('5561', 'Camper, Recreational and Utility Trailers',   'Fleet Maintenance',   FALSE),
    ('5599', 'Automotive Parts and Accessories',            'Fleet Maintenance',   FALSE),
    ('7538', 'Automotive Service Shops',                    'Fleet Maintenance',   FALSE),
    ('5411', 'Grocery Stores and Supermarkets',             'Food & Beverage',     FALSE),
    ('5812', 'Eating Places and Restaurants',               'Food & Beverage',     FALSE),
    ('5511', 'Car and Truck Dealers (New)',                 'Vehicle Dealers',     FALSE),
    ('7514', 'Passenger Car Rental',                        'Vehicle Rental',      FALSE),
    ('7521', 'Parking Lots and Garages',                    'Parking & Tolls',     FALSE),
    ('4111', 'Local and Suburban Commuter Transportation',  'Transportation',      FALSE),
    ('4812', 'Telecommunications Equipment and Telephone',  'Telecom',             FALSE),
    ('4911', 'Utilities — Electric, Gas, Water, Sanitary', 'Utilities',           FALSE),
    ('5065', 'Electrical Parts and Equipment',              'Industrial Supply',   FALSE),
    ('7372', 'Computer Programming and Data Processing',    'Technology',          FALSE),
    ('5999', 'Miscellaneous and Specialty Retail Stores',   'Miscellaneous',       FALSE)
ON CONFLICT (mcc) DO NOTHING;

-- ── Geography ─────────────────────────────────────────────────────────────────
-- Major cities along XMOB's primary trucking corridors.
-- service_region is XMOB's non-standard geographic overlay.

INSERT INTO geography (zip_code, city, state_abbr, msa_name, service_region) VALUES
    ('28201', 'Charlotte',      'NC', 'Charlotte-Concord-Gastonia',      'Southeast'),
    ('30301', 'Atlanta',        'GA', 'Atlanta-Sandy Springs-Roswell',   'Southeast'),
    ('37201', 'Nashville',      'TN', 'Nashville-Davidson-Murfreesboro', 'Southeast'),
    ('75201', 'Dallas',         'TX', 'Dallas-Fort Worth-Arlington',     'South Central'),
    ('77001', 'Houston',        'TX', 'Houston-The Woodlands-Sugar Land','South Central'),
    ('73101', 'Oklahoma City',  'OK', 'Oklahoma City',                   'South Central'),
    ('80201', 'Denver',         'CO', 'Denver-Aurora-Lakewood',          'Mountain West'),
    ('85001', 'Phoenix',        'AZ', 'Phoenix-Mesa-Scottsdale',         'Mountain West'),
    ('89101', 'Las Vegas',      'NV', 'Las Vegas-Henderson-Paradise',    'Mountain West'),
    ('45201', 'Cincinnati',     'OH', 'Cincinnati',                      'Midwest'),
    ('53201', 'Milwaukee',      'WI', 'Milwaukee-Waukesha-West Allis',   'Midwest'),
    ('55401', 'Minneapolis',    'MN', 'Minneapolis-St. Paul-Bloomington','Midwest'),
    ('64101', 'Kansas City',    'MO', 'Kansas City',                     'Midwest'),
    ('97201', 'Portland',       'OR', 'Portland-Vancouver-Hillsboro',    'Pacific Northwest'),
    ('98101', 'Seattle',        'WA', 'Seattle-Tacoma-Bellevue',         'Pacific Northwest')
ON CONFLICT (zip_code) DO NOTHING;

-- ── Industry segments ─────────────────────────────────────────────────────────
-- XMOB's internal NAICS rollup used for risk classification and reporting.

INSERT INTO industry_segment (segment_code, naics_prefix, name) VALUES
    ('TRK', '48', 'Trucking'),
    ('LOG', '49', 'Logistics & Warehousing'),
    ('FLS', '53', 'Fleet Services & Leasing'),
    ('MFG', '31', 'Manufacturing'),
    ('RET', '44', 'Retail Trade'),
    ('FNB', '42', 'Food & Beverage Distribution'),
    ('SVC', '56', 'Business Services'),
    ('TEC', '51', 'Technology & Software')
ON CONFLICT (segment_code) DO NOTHING;

-- ── Model versions ────────────────────────────────────────────────────────────
-- Registry of M-Score underwriting model versions.
-- ~8% of active accounts remain on V2 due to grandfathering (see business_context.md §6.3).

INSERT INTO model_version (model_id, name, version, effective_date, retired_date, is_current) VALUES
    ('MSCORE_V2', 'M-Score', 'v2', '2014-01-01', '2024-03-01', FALSE),
    ('MSCORE_V4', 'M-Score', 'v4', '2024-03-01', NULL,          TRUE)
ON CONFLICT (model_id) DO NOTHING;
