-- Demo data for two users. NOT RUN -- review first.
--
--   power.user@example.com  every status/urgency tier, fully filled in, several store policies
--   lazy.user@example.com   sparse, stale, rarely updated
--
-- Password for both: Demo-Pass1!   (bcrypt digest below; meets the model's password rules)
--
-- All dates are relative to "today" in each user's own time zone, so the urgency tiers
-- (urgent / soon / later / expired) stay correct whenever this is run.
-- Re-running fails on the unique email index, which is the intended guard against duplicates.
--
-- Assumes the planned code change: blank price is stored as 0, so purchases.price allows 0 (the
-- current CHECK price > 0 and the model's greater_than: 0 would reject every row here).
-- Every purchase has price 0 and belongs to one of its user's store policies.

BEGIN;

CREATE TEMP TABLE seed_today ON COMMIT DROP AS
SELECT (now() AT TIME ZONE 'America/Los_Angeles')::date AS rich,
       (now() AT TIME ZONE 'UTC')::date                 AS lazy;

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
INSERT INTO users (email_address, password_digest, reminder_days_before, time_zone, created_at, updated_at)
VALUES
  ('power.user@example.com', '$2a$12$qOsewGiAKyVd/TQwKzKytOWncEnOw3mu2VpmOi6Dxeic89XvTiCE.',
   3, 'Pacific Time (US & Canada)', now() - interval '200 days', now() - interval '1 day'),
  -- Never touched settings: column defaults for reminder_days_before and time_zone; updated_at = created_at.
  ('lazy.user@example.com',  '$2a$12$qOsewGiAKyVd/TQwKzKytOWncEnOw3mu2VpmOi6Dxeic89XvTiCE.',
   2, 'UTC', now() - interval '120 days', now() - interval '120 days');

-- ---------------------------------------------------------------------------
-- Store policies
-- ---------------------------------------------------------------------------
-- power.user: Zara has two windows (shows the multi-policy case); Costco is unused (deletable).
INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at)
SELECT u.id, v.store_name, v.window_days, now() - interval '190 days', now() - interval '30 days'
FROM (VALUES
  ('Target',       90),
  ('Zara',         30),
  ('Zara',         60),
  ('Best Buy',     15),
  ('REI',         365),
  ('Amazon',       30),
  ('Campus Store', 14),
  ('Costco',       90)
) AS v(store_name, window_days)
JOIN users u ON u.email_address = 'power.user@example.com';

-- lazy.user: only what they were forced to enter to save a purchase.
INSERT INTO store_policies (user_id, store_name, window_days, created_at, updated_at)
SELECT u.id, v.store_name, v.window_days, now() - interval '110 days', now() - interval '110 days'
FROM (VALUES
  ('Amazon', 30),
  ('Target', 90)
) AS v(store_name, window_days)
JOIN users u ON u.email_address = 'lazy.user@example.com';

-- ---------------------------------------------------------------------------
-- power.user purchases (reminder lead time = 3 days: urgent <= 3, soon <= 7, later > 7)
-- ---------------------------------------------------------------------------
-- days_left     = return_by - today   (negative = deadline passed)
-- purchase_date = return_by - window  (matches the model's return_by calculation)
-- shipped/refunded are "days ago"; NULL = not recorded.
INSERT INTO purchases (user_id, store_policy_id, item_name, price, purchase_date, return_by, status,
                       returned_at, refunded_at, reminded_at,
                       created_at, updated_at)
SELECT u.id,
       sp.id,
       v.item_name,
       0,                                   -- price is 0 throughout
       t.rich + v.days_left - v.window_days,
       t.rich + v.days_left,
       v.status,
       t.rich - v.shipped_days_ago::int,
       t.rich - v.refunded_days_ago::int,
       CASE WHEN v.reminded THEN now() - interval '1 day' END,
       (t.rich + v.days_left - v.window_days)::timestamptz,
       now() - interval '1 hour'
FROM (VALUES
  -- item_name,                    store,         window, days_left, status,          shipped_days_ago, refunded_days_ago, reminded
  -- active: urgent / soon / later
  ('Noise-cancelling headphones', 'Best Buy',      15,    0,  'active',         NULL, NULL, false),  -- due today
  ('Wool coat',                   'Zara',          30,    1,  'active',         NULL, NULL, true),   -- already reminded
  ('Standing desk mat',           'Amazon',        30,    3,  'active',         NULL, NULL, false),  -- urgent boundary (= lead time)
  ('Hiking boots',                'REI',          365,    5,  'active',         NULL, NULL, false),  -- soon
  ('Linen shirt',                 'Zara',          60,    7,  'active',         NULL, NULL, false),  -- soon boundary
  ('Coffee grinder',              'Target',        90,    8,  'active',         NULL, NULL, false),  -- later boundary
  ('Desk lamp',                   'Campus Store',  14,   12,  'active',         NULL, NULL, false),
  ('Winter parka',                'Target',        90,   45,  'active',         NULL, NULL, false),
  ('Road bike',                   'REI',          365,  200,  'active',         NULL, NULL, false),
  -- returning (decided to return, not sent yet)
  ('Bluetooth speaker',           'Best Buy',      15,    4,  'returning',      NULL, NULL, true),
  ('Rain jacket',                 'REI',          365,  120,  'returning',      NULL, NULL, false),
  -- shipped_back (sent, shows "Shipped back on ...")
  ('Running shoes',               'Target',        90,   40,  'shipped_back',     3, NULL, false),
  ('Blender',                     'Amazon',        30,   10,  'shipped_back',     6, NULL, false),
  -- refund_pending (one with a ship date, one recorded directly without one)
  ('Yoga mat',                    'Amazon',        30,   -5,  'refund_pending',  12, NULL, false),
  ('Wireless mouse',              'Best Buy',      15,   -2,  'refund_pending', NULL, NULL, false),
  -- keeping (History)
  ('Cast-iron skillet',           'Target',        90,  -20,  'keeping',        NULL, NULL, false),
  ('Graphic tee',                 'Zara',          30,   10,  'keeping',        NULL, NULL, false),  -- decided before the deadline
  -- refunded (History, "Refunded on ...")
  ('Smart thermostat',            'Best Buy',      15,  -30,  'refunded',        37,   25, false),
  ('Tent',                        'REI',          365,  100,  'refunded',        50,   35, false),
  -- expired (History): still "active" with a passed return_by
  ('Phone case',                  'Amazon',        30,   -1,  'active',         NULL, NULL, true),   -- expired yesterday
  ('Throw pillows',               'Target',        90,  -45,  'active',         NULL, NULL, false)   -- expired long ago
) AS v(item_name, store_name, window_days, days_left, status, shipped_days_ago, refunded_days_ago, reminded)
JOIN users u ON u.email_address = 'power.user@example.com'
JOIN store_policies sp ON sp.user_id = u.id
                      AND lower(sp.store_name) = lower(v.store_name)
                      AND sp.window_days = v.window_days
CROSS JOIN seed_today t;

-- ---------------------------------------------------------------------------
-- lazy.user purchases
-- Sparse: terse names, price 0, no ship or refund dates, never reminded,
-- never edited (updated_at = created_at). Statuses are stale: most are still "active" past the deadline.
-- ---------------------------------------------------------------------------
INSERT INTO purchases (user_id, store_policy_id, item_name, price, purchase_date, return_by, status,
                       returned_at, refunded_at, reminded_at,
                       created_at, updated_at)
SELECT u.id,
       sp.id,
       v.item_name,
       0,                                   -- price is 0 throughout
       t.lazy + v.days_left - v.window_days,
       t.lazy + v.days_left,
       v.status,
       NULL, NULL, NULL,
       (t.lazy + v.days_left - v.window_days)::timestamptz,
       (t.lazy + v.days_left - v.window_days)::timestamptz
FROM (VALUES
  ('shoes',         'Amazon',  30,  -40, 'active'),          -- expired, forgot about it
  ('thing for mom', 'Target',  90,   -3, 'active'),          -- just expired
  ('jacket',        'Amazon',  30, -100, 'active'),          -- expired ages ago
  ('headphones',    'Amazon',  30,    6, 'active'),          -- the one live purchase ("soon")
  ('sweater?',      'Target',  90,  -10, 'shipped_back'),    -- sent back, never marked refunded, no ship date
  ('book',          'Amazon',  30,  -60, 'refund_pending')   -- stuck, no dates
) AS v(item_name, store_name, window_days, days_left, status)
JOIN users u ON u.email_address = 'lazy.user@example.com'
JOIN store_policies sp ON sp.user_id = u.id
                      AND lower(sp.store_name) = lower(v.store_name)
                      AND sp.window_days = v.window_days
CROSS JOIN seed_today t;

COMMIT;

-- ---------------------------------------------------------------------------
-- Questions / notes (not executed)
-- ---------------------------------------------------------------------------
-- 1. Every price is 0, so "Money at risk" is $0.00 for both users and every card shows $0.00. That hides the
--    money-at-risk stat and any price-based display. Want a few non-zero prices on power.user after all?
-- 2. This only loads after a migration changes CHECK (price > 0) to price >= 0 (and the model/form change).
-- 3. Store name and return window come from each purchase's store policy; purchases have no store columns of their own.
-- 4. purchase_date and store_policy_id are still required by the card partial, so they're filled for both users.
-- 5. cucumber-mvp.md lists statuses awaiting_refund and expired; the code has shipped_back and
--    refund_pending, and "expired" is derived (active + return_by < today), never stored. I followed the code.
-- 6. Dates anchor on each user's own time zone via the seed_today temp table (Pacific for power.user, UTC for
--    lazy.user), because the app uses Time.use_zone(user.time_zone).
-- 7. power.user has unsent reminders (Noise-cancelling headphones, Standing desk mat). If ReminderJob runs
--    with mail delivery configured, it will email example.com addresses.
-- 8. A "returning" purchase past its return_by isn't covered: the model only expires "active" ones.
-- 9. Password digest is a real bcrypt hash of Demo-Pass1! (computed locally, nothing was inserted anywhere).
