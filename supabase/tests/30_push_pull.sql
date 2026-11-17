-- 30_push_pull.sql
-- push한 행을 다른 기기가 pull로 받는다. 적용 순서, JSON 표현, 증분 pull, 쪽 나눔을 본다.
\ir _helpers.sql

-- 세션 시간대가 무엇이든 함수는 UTC로 답해야 한다.
set timezone = 'Asia/Seoul';

do $$
declare
  u uuid := t.signup();
  k text;
begin
  perform t.set('u', u::text);
  perform t.set('l', t.ledger_of(u)::text);
  foreach k in array array['card', 'bank', 'cat', 'tx_exp', 'tx_inc', 'tx_trf',
                           'budget', 'rule', 'recur', 'summary', 'tx_new', 'tx_min'] loop
    perform t.set(k, gen_random_uuid()::text);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 기기 1이 9개 테이블 모두에 push한다. 거래를 자산 · 분류보다 먼저 적어 보낸다.
-- 서버는 의존 순서로 적용하고, 결과는 보낸 순서로 돌려준다.
-- ---------------------------------------------------------------------------
do $$
declare
  u     uuid := t.id('u');
  l     uuid := t.id('l');
  batch uuid := gen_random_uuid();
  at    timestamptz := now() - interval '5 minutes';
  ch    jsonb;
  r     jsonb;
  s     jsonb;   -- 표:자리 → server_seq
  i     integer;
begin
  ch := jsonb_build_array(
    /* 0 */ t.up('transactions', t.id('tx_exp'), 0, at, jsonb_build_object(
              'type', 'expense', 'occurred_on', '2026-11-16', 'occurred_time', '12:30:00', 'amount', 12500,
              'account_id', t.id('card'), 'category_id', t.id('cat'), 'sender', '홍길동', 'receiver', '김밥천국',
              'memo', '점심', 'tags', jsonb_build_array('식사', '회사'), 'currency', 'USD', 'original_amount', 9.5,
              'installment_months', 3, 'canceled_at', '2026-11-17T01:02:03Z', 'source', 'paste',
              'status', 'needs_review', 'balance_after', 987654321012)),
    /* 1 */ t.up('transactions', t.id('tx_inc'), 0, at, jsonb_build_object(
              'type', 'income', 'occurred_on', '2026-11-10', 'amount', 3000000,
              'account_id', t.id('bank'), 'sender', '(주)회사', 'receiver', '홍길동')),
    /* 2 */ t.up('transactions', t.id('tx_trf'), 0, at, jsonb_build_object(
              'type', 'transfer', 'occurred_on', '2026-11-11', 'amount', 500000,
              'account_id', t.id('bank'), 'to_account_id', t.id('card'), 'sender', '홍길동', 'receiver', '카드대금')),
    /* 3 */ t.up('category_rules', t.id('rule'), 0, at, jsonb_build_object(
              'pattern', '김밥천국', 'category_id', t.id('cat'), 'hit_count', 2)),
    /* 4 */ t.up('monthly_summaries', t.id('summary'), 0, at, jsonb_build_object(
              'month', '2026-10', 'stats', jsonb_build_object('expense', 1234500, 'by_category', jsonb_build_object('식비', 400000)),
              'narrative', '지난달보다 덜 썼다', 'data_hash', 'abc123', 'ai_model', 'local-llm')),
    /* 5 */ t.up('budgets', t.id('budget'), 0, at, jsonb_build_object(
              'month', '2026-11', 'category_id', t.id('cat'), 'amount', 300000)),
    /* 6 */ t.up('recurring_rules', t.id('recur'), 0, at, jsonb_build_object(
              'template', jsonb_build_object('type', 'expense', 'amount', 550000, 'account_id', t.id('bank'), 'memo', '월세'),
              'frequency', 'monthly', 'next_run_on', '2026-12-01', 'auto_post', true)),
    /* 7 */ t.up('categories', t.id('cat'), 0, at, jsonb_build_object(
              'kind', 'expense', 'name', '점심', 'icon', '🍚', 'sort_order', 15)),
    /* 8 */ t.up('accounts', t.id('card'), 0, at, jsonb_build_object(
              'name', '신한카드', 'kind', 'credit_card', 'institution', '신한카드',
              'match_hints', jsonb_build_array('신한카드', '1234'), 'billing_day', 14,
              'payment_account_id', t.id('bank'), 'sort_order', 2)),
    /* 9 */ t.up('accounts', t.id('bank'), 0, at, jsonb_build_object(
              'name', '월급통장', 'kind', 'bank', 'opening_balance', 1500000)),
    /* 10 */ t.up('profiles', u, 1, at, jsonb_build_object(
              'display_name', '길동', 'month_start_day', 25, 'default_account_id', t.id('bank'))),
    /* 11 */ t.up('ledgers', l, 1, at, jsonb_build_object('name', '우리집 가계부')));

  perform t.login(u);
  r := t.push(l, ch, batch, t.dev(1));
  perform t.set('push1', r::text);

  -- 결과의 틀
  assert r ->> 'batch_id' = batch::text, 'batch_id를 그대로 돌려준다';
  assert jsonb_array_length(r -> 'results') = 12, '결과는 변경 수만큼';
  assert (r ->> 'server_time')::timestamptz = now(), 'server_time은 서버 시각';
  assert r ->> 'server_time' ~ '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?\+00:00$',
    format('server_time은 UTC ISO 8601: %s', r ->> 'server_time');

  -- 결과는 보낸 순서 그대로이고 모두 applied다.
  for i in 0..11 loop
    assert r -> 'results' -> i ->> 'table' = ch -> i ->> 'table'
       and r -> 'results' -> i ->> 'id' = ch -> i ->> 'id',
      format('결과 %s의 table · id가 보낸 것과 다르다: %s', i, r -> 'results' -> i);
    assert r -> 'results' -> i ->> 'status' = 'applied', format('결과 %s: %s', i, r -> 'results' -> i);
    assert r -> 'results' -> i -> 'server_row' = 'null' and r -> 'results' -> i -> 'error' = 'null',
      format('applied는 server_row · error가 null: %s', r -> 'results' -> i);
    assert jsonb_typeof(r -> 'results' -> i -> 'version') = 'number'
       and jsonb_typeof(r -> 'results' -> i -> 'server_seq') = 'number', 'version · server_seq는 숫자';
    assert (r -> 'results' -> i ->> 'version')::int = case when i >= 10 then 2 else 1 end,
      format('새 행은 1, 있던 행(프로필 · 가계부)은 2: %s', r -> 'results' -> i);
  end loop;

  -- 적용 순서: ledgers, profiles, accounts, categories, transactions, budgets, recurring_rules,
  -- category_rules, monthly_summaries. 같은 테이블 안에서는 보낸 순서.
  select jsonb_object_agg(e.ord - 1, (e.val ->> 'server_seq')::bigint) into s
    from jsonb_array_elements(r -> 'results') with ordinality as e (val, ord);
  assert (s ->> '11')::bigint < (s ->> '10')::bigint, 'ledgers가 profiles보다 먼저';
  assert (s ->> '10')::bigint < (s ->> '8')::bigint, 'profiles가 accounts보다 먼저';
  assert (s ->> '8')::bigint < (s ->> '9')::bigint, 'accounts 안에서는 보낸 순서(카드, 통장)';
  assert (s ->> '9')::bigint < (s ->> '7')::bigint, 'accounts가 categories보다 먼저';
  assert (s ->> '7')::bigint < (s ->> '0')::bigint, 'categories가 transactions보다 먼저';
  assert (s ->> '0')::bigint < (s ->> '1')::bigint and (s ->> '1')::bigint < (s ->> '2')::bigint,
    'transactions 안에서는 보낸 순서';
  assert (s ->> '2')::bigint < (s ->> '5')::bigint, 'transactions가 budgets보다 먼저';
  assert (s ->> '5')::bigint < (s ->> '6')::bigint, 'budgets가 recurring_rules보다 먼저';
  assert (s ->> '6')::bigint < (s ->> '3')::bigint, 'recurring_rules가 category_rules보다 먼저';
  assert (s ->> '3')::bigint < (s ->> '4')::bigint, 'category_rules가 monthly_summaries보다 먼저';
  assert (r ->> 'max_server_seq')::bigint = (s ->> '4')::bigint, 'max_server_seq는 이 묶음이 쓴 가장 큰 번호';
  assert (r ->> 'max_server_seq')::bigint = t.seq(), '시퀀스의 마지막 값과 같다';
end $$;

-- ---------------------------------------------------------------------------
-- 기기 2가 처음부터 pull한다. 시드 19행에 새 행 10개가 더해진다(가계부 · 프로필은 고쳐진 것).
-- ---------------------------------------------------------------------------
do $$
declare
  u   uuid := t.id('u');
  l   uuid := t.id('l');
  p1  jsonb := t.get('push1')::jsonb;
  r   jsonb;
  ch  jsonb;
  x   jsonb;
  c_ts constant text := '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?\+00:00$';
begin
  perform t.login(u);
  r := public.sync_pull(l, 0);
  ch := r -> 'changes';
  perform t.set('cursor', r ->> 'next_seq');

  assert jsonb_array_length(ch) = 29, format('29행이어야 한다: %s', jsonb_array_length(ch));
  assert not (r ->> 'has_more')::boolean, '한 장에 다 들어온다';
  assert (r ->> 'next_seq')::bigint = (p1 ->> 'max_server_seq')::bigint, 'next_seq는 마지막 행의 server_seq';
  assert r ->> 'server_time' ~ c_ts, 'server_time은 UTC ISO 8601';

  -- server_seq는 테이블을 가로질러 엄격하게 오름차순이다.
  assert (select bool_and(seq > prev) from (
            select (e.val -> 'row' ->> 'server_seq')::bigint as seq,
                   lag((e.val -> 'row' ->> 'server_seq')::bigint) over (order by e.ord) as prev
              from jsonb_array_elements(ch) with ordinality as e (val, ord)) q
           where prev is not null), 'server_seq가 엄격한 오름차순이 아니다';
  -- 각 항목은 {table, row}뿐이다.
  assert (select bool_and((select array_agg(k order by k) from jsonb_object_keys(e) k) = array['row', 'table'])
            from jsonb_array_elements(ch) e), '항목의 키는 table, row';

  -- 지출 거래: 타입별 JSON 표현
  x := t.find(ch, 'transactions', t.id('tx_exp'));
  assert x is not null, '지출 거래가 내려와야 한다';
  assert x ->> 'ledger_id' = l::text and (x ->> 'version')::int = 1 and x -> 'deleted_at' = 'null';
  assert (x ->> 'server_seq')::bigint = (p1 -> 'results' -> 0 ->> 'server_seq')::bigint, 'push 결과의 server_seq와 같다';
  assert x -> 'amount' = '12500' and jsonb_typeof(x -> 'amount') = 'number', 'bigint는 숫자';
  assert x -> 'balance_after' = '987654321012', '큰 bigint도 숫자 그대로';
  assert x -> 'original_amount' = '9.5' and jsonb_typeof(x -> 'original_amount') = 'number', 'numeric은 숫자';
  assert x -> 'installment_months' = '3', 'integer는 숫자';
  assert x -> 'occurred_on' = '"2026-11-16"', format('date는 YYYY-MM-DD: %s', x -> 'occurred_on');
  assert x -> 'occurred_time' = '"12:30:00"', format('time은 HH:MM:SS: %s', x -> 'occurred_time');
  assert x -> 'tags' = '["식사", "회사"]', 'text[]는 문자열 배열';
  assert x ->> 'canceled_at' = '2026-11-17T01:02:03+00:00', format('timestamptz는 UTC: %s', x ->> 'canceled_at');
  assert x ->> 'client_updated_at' ~ c_ts and x ->> 'created_at' ~ c_ts and x ->> 'updated_at' ~ c_ts,
    format('시각은 모두 UTC ISO 8601: %s', x);
  assert (x ->> 'client_updated_at')::timestamptz = (p1 ->> 'server_time')::timestamptz - interval '5 minutes',
    'client_updated_at은 기기가 보낸 값(과거)이다';
  assert (x ->> 'created_at')::timestamptz = (p1 ->> 'server_time')::timestamptz
     and (x ->> 'updated_at')::timestamptz = (p1 ->> 'server_time')::timestamptz, 'created_at · updated_at은 서버 시각';
  assert x ->> 'memo' = '점심' and x ->> 'currency' = 'USD' and x ->> 'source' = 'paste'
     and x ->> 'status' = 'needs_review' and x ->> 'account_id' = t.get('card') and x ->> 'category_id' = t.get('cat');

  -- counterparty: 지출이면 receiver, 수입이면 sender, 이체는 비운다.
  assert x ->> 'counterparty' = '김밥천국', format('지출의 상대방은 receiver: %s', x ->> 'counterparty');
  x := t.find(ch, 'transactions', t.id('tx_inc'));
  assert x ->> 'counterparty' = '(주)회사', format('수입의 상대방은 sender: %s', x ->> 'counterparty');
  -- 빼고 보낸 컬럼은 기본값으로 들어간다.
  assert x -> 'tags' = '[]' and x ->> 'source' = 'manual' and x ->> 'status' = 'confirmed', '빠진 컬럼은 기본값';
  x := t.find(ch, 'transactions', t.id('tx_trf'));
  assert x ? 'counterparty' and x -> 'counterparty' = 'null', format('이체의 상대방은 null: %s', x -> 'counterparty');
  assert x ->> 'to_account_id' = t.get('card');
  perform t.logout();
  assert (select counterparty from public.transactions where id = t.id('tx_exp')) = '김밥천국'
     and (select counterparty from public.transactions where id = t.id('tx_inc')) = '(주)회사'
     and (select counterparty from public.transactions where id = t.id('tx_trf')) is null, '테이블의 생성 컬럼도 같다';
  perform t.login(u);

  -- 그 밖의 테이블
  x := t.find(ch, 'accounts', t.id('card'));
  assert x ->> 'name' = '신한카드' and x ->> 'kind' = 'credit_card' and x -> 'match_hints' = '["신한카드", "1234"]'
     and x -> 'billing_day' = '14' and x ->> 'payment_account_id' = t.get('bank') and x -> 'sort_order' = '2', format('카드: %s', x);
  x := t.find(ch, 'accounts', t.id('bank'));
  assert x -> 'opening_balance' = '1500000' and x -> 'billing_day' = 'null', format('통장: %s', x);
  x := t.find(ch, 'categories', t.id('cat'));
  assert x ->> 'name' = '점심' and x ->> 'icon' = '🍚' and x -> 'parent_id' = 'null', format('분류: %s', x);
  x := t.find(ch, 'budgets', t.id('budget'));
  assert x ->> 'month' = '2026-11' and x -> 'amount' = '300000', format('예산: %s', x);
  x := t.find(ch, 'recurring_rules', t.id('recur'));
  assert jsonb_typeof(x -> 'template') = 'object' and x -> 'template' ->> 'memo' = '월세', 'jsonb는 객체';
  assert x -> 'auto_post' = 'true' and x -> 'is_active' = 'true' and x -> 'interval_count' = '1'
     and x -> 'next_run_on' = '"2026-12-01"' and x -> 'end_on' = 'null', format('반복 거래: %s', x);
  x := t.find(ch, 'category_rules', t.id('rule'));
  assert x ->> 'pattern' = '김밥천국' and x -> 'hit_count' = '2', format('분류 규칙: %s', x);
  x := t.find(ch, 'monthly_summaries', t.id('summary'));
  assert x -> 'stats' -> 'by_category' -> '식비' = '400000' and x ->> 'narrative' = '지난달보다 덜 썼다', format('요약: %s', x);

  -- 프로필
  x := t.find(ch, 'profiles', u);
  assert x ->> 'display_name' = '길동' and x -> 'month_start_day' = '25' and (x ->> 'version')::int = 2
     and x ->> 'default_account_id' = t.get('bank') and x ->> 'ledger_id' = l::text, format('프로필: %s', x);

  -- 가계부 행: id가 가계부 ID이고 ledger_id 키는 없다.
  assert (select count(*) from jsonb_array_elements(ch) e where e ->> 'table' = 'ledgers') = 1, '가계부 행은 하나';
  x := t.find(ch, 'ledgers', l);
  assert x is not null and not (x ? 'ledger_id'), format('ledgers 행에는 ledger_id 키가 없다: %s', x);
  assert x ->> 'name' = '우리집 가계부' and x ->> 'currency' = 'KRW' and (x ->> 'version')::int = 2
     and x ->> 'owner_id' = u::text, format('가계부: %s', x);

  -- 그 밖의 모든 행에는 ledger_id가 있고 이 가계부다.
  assert (select bool_and(e -> 'row' ->> 'ledger_id' = l::text)
            from jsonb_array_elements(ch) e where e ->> 'table' <> 'ledgers'), '모든 행이 이 가계부의 것';

  -- pull이 준 행은 테이블의 행과 같다.
  perform set_config('timezone', 'UTC', true);
  assert (select bool_and(e -> 'row' = t.row_of(e ->> 'table', (e -> 'row' ->> 'id')::uuid))
            from jsonb_array_elements(ch) e), 'pull이 준 행이 테이블의 행과 다르다';
end $$;

-- ---------------------------------------------------------------------------
-- 증분 pull: 커서 뒤의 행만 온다.
-- ---------------------------------------------------------------------------
do $$
declare
  u      uuid := t.id('u');
  l      uuid := t.id('l');
  cursor0 bigint := t.get('cursor')::bigint;
  r      jsonb;
  p      jsonb;
begin
  perform t.login(u);

  -- 새 변경이 없으면 빈 배열이고 next_seq는 p_since 그대로다.
  r := public.sync_pull(l, cursor0);
  assert r -> 'changes' = '[]' and (r ->> 'next_seq')::bigint = cursor0 and not (r ->> 'has_more')::boolean,
    format('새 변경이 없을 때: %s', r);
  r := public.sync_pull(l, cursor0 + 1000000);
  assert r -> 'changes' = '[]' and (r ->> 'next_seq')::bigint = cursor0 + 1000000, '커서가 앞서 있어도 p_since를 돌려준다';

  -- 기기 1이 거래 하나를 고치고 하나를 새로 넣는다.
  p := t.push(l, jsonb_build_array(
         t.up('transactions', t.id('tx_exp'), 1, now() - interval '1 minute', '{"memo": "점심(수정)"}'),
         t.up('transactions', t.id('tx_new'), 0, now() - interval '1 minute', jsonb_build_object(
           'type', 'expense', 'occurred_on', '2026-11-17', 'amount', 4800, 'account_id', t.id('card')))),
       gen_random_uuid(), t.dev(1));
  assert p -> 'results' -> 0 ->> 'status' = 'applied' and (p -> 'results' -> 0 ->> 'version')::int = 2, format('%s', p);
  assert p -> 'results' -> 1 ->> 'status' = 'applied' and (p -> 'results' -> 1 ->> 'version')::int = 1, format('%s', p);

  -- 기기 2는 그 둘만 받는다.
  r := public.sync_pull(l, cursor0);
  assert jsonb_array_length(r -> 'changes') = 2, format('증분은 2행: %s', r);
  assert r -> 'changes' -> 0 -> 'row' ->> 'id' = t.get('tx_exp') and r -> 'changes' -> 1 -> 'row' ->> 'id' = t.get('tx_new'),
    'server_seq 순서로 온다';
  assert (r -> 'changes' -> 0 -> 'row' ->> 'version')::int = 2 and r -> 'changes' -> 0 -> 'row' ->> 'memo' = '점심(수정)';
  -- 고칠 때 빠진 컬럼은 지금 값을 그대로 둔다.
  assert r -> 'changes' -> 0 -> 'row' -> 'amount' = '12500' and r -> 'changes' -> 0 -> 'row' ->> 'receiver' = '김밥천국'
     and r -> 'changes' -> 0 -> 'row' -> 'tags' = '["식사", "회사"]', '고칠 때 빠진 컬럼은 그대로다';
  assert (r ->> 'next_seq')::bigint = (p ->> 'max_server_seq')::bigint and not (r ->> 'has_more')::boolean;
  assert (select min((e -> 'row' ->> 'server_seq')::bigint) from jsonb_array_elements(r -> 'changes') e) > cursor0,
    '커서보다 큰 번호만 온다';

  -- 다시 pull하면 비어 있다.
  r := public.sync_pull(l, (r ->> 'next_seq')::bigint);
  assert r -> 'changes' = '[]', '받은 뒤에는 비어 있다';

  -- 고친 행은 예전 번호로는 더 나오지 않는다(행마다 최신 상태 하나만 내려온다).
  r := public.sync_pull(l, 0);
  assert jsonb_array_length(r -> 'changes') = 30, format('전체는 30행: %s', jsonb_array_length(r -> 'changes'));
  assert (select count(*) from jsonb_array_elements(r -> 'changes') e where e -> 'row' ->> 'id' = t.get('tx_exp')) = 1;
end $$;

-- ---------------------------------------------------------------------------
-- 명시한 null은 null로 쓰고, 모르는 키는 무시한다. README의 예처럼 최소한의 data로도 새 행을 만든다.
-- ---------------------------------------------------------------------------
do $$
declare
  u uuid := t.id('u');
  l uuid := t.id('l');
  x jsonb;
begin
  perform t.login(u);
  x := t.push1(l, t.up('transactions', t.id('tx_min'), 0, now(), jsonb_build_object(
         'type', 'expense', 'occurred_on', '2026-11-16', 'amount', 12500, 'account_id', t.id('card'))));
  assert x ->> 'status' = 'applied', format('최소 data: %s', x);
  x := t.row_of('transactions', t.id('tx_min'));
  assert x -> 'tags' = '[]' and x ->> 'source' = 'manual' and x ->> 'status' = 'confirmed'
     and x -> 'memo' = 'null' and x -> 'category_id' = 'null', format('기본값: %s', x);

  x := t.push1(l, t.up('transactions', t.id('tx_exp'), 2, now(),
         '{"memo": null, "category_id": null, "no_such_column": 1, "tags": []}'));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 3, format('null 쓰기: %s', x);
  x := t.row_of('transactions', t.id('tx_exp'));
  assert x -> 'memo' = 'null' and x -> 'category_id' = 'null' and x -> 'tags' = '[]' and x -> 'amount' = '12500',
    format('명시한 null만 null이 된다: %s', x);
  assert (x ->> 'created_at')::timestamptz < (x ->> 'updated_at')::timestamptz, 'created_at은 처음 그대로, updated_at만 바뀐다';
end $$;

-- ---------------------------------------------------------------------------
-- 쪽 나눔: p_limit이 전체보다 작을 때 has_more, next_seq, 이어 받기.
-- ---------------------------------------------------------------------------
do $$
declare
  u     uuid := t.id('u');
  l     uuid := t.id('l');
  whole jsonb;
  n     integer;
  r     jsonb;
  cur   bigint := 0;
  got   jsonb := '[]';
  pages integer := 0;
  k     integer;
begin
  perform t.login(u);
  whole := public.sync_pull(l, 0, 2000) -> 'changes';
  n := jsonb_array_length(whole);
  assert n = 31, format('전체 31행: %s', n);

  -- 4건씩 받는다.
  loop
    r := public.sync_pull(l, cur, 4);
    k := jsonb_array_length(r -> 'changes');
    pages := pages + 1;
    assert k <= 4, '한 장은 p_limit 이하';
    assert k > 0, '빈 장이 오면 안 된다';
    assert (r ->> 'next_seq')::bigint = (r -> 'changes' -> (k - 1) -> 'row' ->> 'server_seq')::bigint,
      'next_seq는 그 장의 마지막 행의 server_seq';
    assert (r -> 'changes' -> 0 -> 'row' ->> 'server_seq')::bigint > cur, '커서보다 큰 번호부터 온다';
    got := got || (r -> 'changes');
    cur := (r ->> 'next_seq')::bigint;
    if (r ->> 'has_more')::boolean then
      assert k = 4, 'has_more이면 장이 꽉 차 있다';
    else
      exit;
    end if;
    assert pages < 100;
  end loop;
  assert pages = 8, format('31행을 4건씩 받으면 8장: %s', pages);
  assert got = whole, '장을 이어 붙이면 전체와 같다(빠지거나 겹친 행이 없다)';
  assert (select bool_and(seq > prev) from (
            select (e.val -> 'row' ->> 'server_seq')::bigint as seq,
                   lag((e.val -> 'row' ->> 'server_seq')::bigint) over (order by e.ord) as prev
              from jsonb_array_elements(got) with ordinality as e (val, ord)) q
           where prev is not null), '이어 붙인 결과도 엄격한 오름차순';
  -- 여러 테이블이 한 장에 섞여 온다.
  assert (select count(distinct e ->> 'table') from jsonb_array_elements(got) e) = 9, '9개 테이블이 모두 온다';

  -- 경계: 딱 맞으면 has_more는 false, 하나 모자라면 true.
  r := public.sync_pull(l, 0, n);
  assert jsonb_array_length(r -> 'changes') = n and not (r ->> 'has_more')::boolean, 'p_limit = 전체';
  r := public.sync_pull(l, 0, n - 1);
  assert jsonb_array_length(r -> 'changes') = n - 1 and (r ->> 'has_more')::boolean, 'p_limit = 전체 - 1';
  r := public.sync_pull(l, (r ->> 'next_seq')::bigint, n - 1);
  assert jsonb_array_length(r -> 'changes') = 1 and not (r ->> 'has_more')::boolean, '남은 한 건';

  -- p_limit은 1–2000으로 자른다. null이면 기본값(500)이다.
  r := public.sync_pull(l, 0, 0);
  assert jsonb_array_length(r -> 'changes') = 1 and (r ->> 'has_more')::boolean, 'p_limit 0은 1로';
  r := public.sync_pull(l, 0, -100);
  assert jsonb_array_length(r -> 'changes') = 1 and (r ->> 'has_more')::boolean, '음수 p_limit은 1로';
  r := public.sync_pull(l, 0, null);
  assert jsonb_array_length(r -> 'changes') = n, 'p_limit null은 기본값';
  r := public.sync_pull(l, null);
  assert jsonb_array_length(r -> 'changes') = n and (r ->> 'next_seq')::bigint > 0, 'p_since null은 0으로 본다';
  r := public.sync_pull(l, -5);
  assert jsonb_array_length(r -> 'changes') = n, '음수 p_since는 처음부터';

  -- t.pull_all 도우미도 같은 결과를 낸다(다른 시험이 쓴다).
  assert t.pull_all(l, 0, 3) -> 'changes' = whole and (t.pull_all(l, 0, 3) ->> 'pages')::int = 11;
end $$;
