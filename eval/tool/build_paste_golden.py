#!/usr/bin/env python3
"""붙여넣기 골든 세트(eval/golden/paste.jsonl)를 만든다.

표본은 공개 저장소의 테스트 데이터와 금융사 공식 안내에서 모은 형식이다(설계안 '벤치마킹' 탭).
이름과 계좌 · 카드 번호는 가린 값이다. 표본을 더하거나 고칠 때는 이 파일을 고치고 다시 실행한다.

    python3 eval/tool/build_paste_golden.py
"""
import json
import pathlib

TODAY = "2026-11-17"


def tx(date, amount, direction, party, **extra):
    row = {"date": date, "amount": amount, "direction": direction, "counterparty": party}
    row.update(extra)
    return row


CASES = [
    # ---------------------------------------------------------------- 은행 문자
    ("kb_bank_in", "sms", "KB국민은행",
     "[KB]7/10 16:40\n123456****7890\n홍길동\n1,000,000 입금\n잔액 50,000\n1644-9999",
     tx("2026-07-10", 1000000, "in", "홍길동", time="16:40", balance_after=50000,
        institution="KB국민은행", account_hint="123456****7890")),
    ("kb_bank_check_out", "sms", "KB국민은행",
     "[KB]11/18 14:58\n123456**789\n과일놀이터\n체크카드출금\n18,000\n잔액238,281",
     tx("2026-11-18", 18000, "out", "과일놀이터", time="14:58", balance_after=238281,
        institution="KB국민은행"), {"today": "2026-11-20"}),
    ("shinhan_bank_out", "sms", "신한은행",
     "신한02/01 11:05\n110-***-000000\n출금 14,510\n잔액 532,513\n신한체크교통",
     tx("2026-02-01", 14510, "out", "신한체크교통", time="11:05", balance_after=532513,
        institution="신한은행")),
    ("woori_bank_in", "sms", "우리은행",
     "우리 06/20 11:20 *123456 입금 472원 예금결산 잔액 1,199,234원",
     tx("2026-06-20", 472, "in", "예금결산", time="11:20", balance_after=1199234,
        institution="우리은행")),
    ("woori_bank_out", "sms", "우리은행",
     "우리 02/23 11:32\n*123456\n출금 900원\nSMS수수료\n잔액 41,903,664원",
     tx("2026-02-23", 900, "out", "SMS수수료", time="11:32", balance_after=41903664,
        institution="우리은행")),
    ("hana_bank_out", "sms", "하나은행",
     "하나,09/10 11:17 123******45607 출금13,958원 0908_GOOGLE*i 잔액669,942원",
     tx("2026-09-10", 13958, "out", "0908_GOOGLE*i", time="11:17", balance_after=669942,
        institution="하나은행")),
    ("nh_bank_in", "sms", "NH농협은행",
     "농협 입금73,000원  08/14 23:34  123-****-4567-89  HONGGILD  잔액123,189원",
     tx("2026-08-14", 73000, "in", "HONGGILD", time="23:34", balance_after=123189,
        institution="NH농협은행")),
    ("nh_bank_out", "sms", "NH농협은행",
     "농협 출금701,000원 08/22 22:35 352-****-0000-00 한패스오픈뱅 잔액4,308,001원",
     tx("2026-08-22", 701000, "out", "한패스오픈뱅", time="22:35", balance_after=4308001,
        institution="NH농협은행")),
    ("ibk_bank_out", "sms", "IBK기업은행",
     "2021/08/19 04:55 출금 11,000원 잔액 1,003,145원 HONGGILD_아 123***45678901 기업",
     tx("2021-08-19", 11000, "out", "HONGGILD_아", time="04:55", balance_after=1003145,
        institution="IBK기업은행")),
    ("busan_bank_in", "sms", "부산은행",
     "입금\n10/12 14:53 1\n계좌 123456789***0\n내용 당근143\n잔액 500,000",
     tx("2026-10-12", 1, "in", "당근143", time="14:53", balance_after=500000,
        institution="부산은행")),
    ("busan_bank_out", "sms", "부산은행",
     "출금\n10/12 16:17 24,000\n계좌 123456789***0\n내용\n메모 토스　홍길동\n잔액 476,000",
     tx("2026-10-12", 24000, "out", "토스 홍길동", time="16:17", balance_after=476000,
        institution="부산은행")),
    ("kakaobank_out", "sms", "카카오뱅크",
     "[카카오뱅크] 홍*동(1234) 12/11 15:42 출금 7,250원 세븐일레븐 가평목동 잔액 4,123,123원",
     tx("2025-12-11", 7250, "out", "세븐일레븐 가평목동", time="15:42", balance_after=4123123,
        institution="카카오뱅크", account_hint="1234")),
    ("kbank_out_masked", "sms", "케이뱅크",
     "[케이뱅크]\n***(1234)\n출금 *****원\n잔액 ****원\nSK매직_***",
     "unrecognized", {"note": "공개 표본이 금액을 가린 형태라 읽을 수 없다. 형식만 확인한다."}),
    ("kbank_out", "sms", "케이뱅크",
     "[케이뱅크]\n홍*동(1234)\n출금 35,900원\n잔액 1,204,100원\nSK매직_홍길동",
     tx(TODAY, 35900, "out", "SK매직_홍길동", balance_after=1204100, institution="케이뱅크"),
     {"synthetic": True, "note": "가려진 공개 표본에 숫자를 채운 합성 표본. 날짜가 없는 형식이다."}),
    # ---------------------------------------------------------------- 카드 문자
    ("kb_card", "sms", "KB국민카드",
     "KB국민카드1234승인\n홍*동님\n129,857원 일시불\n02/08 22:39\n마켓컬리\n누적800,000원",
     tx("2026-02-08", 129857, "out", "마켓컬리", time="22:39", institution="KB국민카드",
        account_hint="1234", installment_months=None, is_cancel=False)),
    ("shinhan_card", "sms", "신한카드",
     "신한카드(1234)승인 홍*동 2,400원(일시불)02/23 16:56 세븐일레븐영 누적1,427,265원",
     tx("2026-02-23", 2400, "out", "세븐일레븐영", time="16:56", institution="신한카드")),
    ("shinhan_card_foreign", "sms", "신한카드",
     "신한(1234)해외승인 홍*동 220.00 달러 (US)11/11 22:34 ANTHROPIC* 누적2,027,221원",
     tx("2026-11-11", None, "out", "ANTHROPIC*", time="22:34", institution="신한카드",
        currency="USD", original_amount=220.0)),
    ("samsung_card", "sms", "삼성카드",
     "삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원",
     tx("2026-01-09", 100, "out", "세븐일레븐아산음", time="20:07", institution="삼성카드")),
    ("samsung_card_cancel", "sms", "삼성카드",
     "삼성1234취소 홍*동\n-4,020원 일시불\n10/09 19:41 쿠팡\n누적1,100,000원",
     tx("2026-10-09", 4020, "out", "쿠팡", time="19:41", institution="삼성카드", is_cancel=True)),
    ("hyundai_card", "sms", "현대카드",
     "현대 ZERO 승인\n2,500원 일시불\n04/10 13:15\n코레일유통서울지사\n누적 560,852원",
     tx("2026-04-10", 2500, "out", "코레일유통서울지사", time="13:15", institution="현대카드")),
    ("lotte_card", "sms", "롯데카드",
     "메가엠지씨커피\n12,800원 승인\n홍*동 롯데법인1234\n일시불 11/10 09:27\n누적723,270원",
     tx("2026-11-10", 12800, "out", "메가엠지씨커피", time="09:27", institution="롯데카드",
        account_hint="1234")),
    ("lotte_card_cancel", "sms", "롯데카드",
     "토스페이먼츠 주식회사\n118,329원 취소완료\n홍*동 롯데1*3*\n11/06",
     tx("2026-11-06", 118329, "out", "토스페이먼츠 주식회사", time=None, institution="롯데카드",
        is_cancel=True)),
    ("woori_card_cancel", "sms", "우리카드",
     "우리(1234)승인취소\n홍*동님\n4562원 일시불\n12/07 20:29\n네이버페이\n누적123,456원",
     tx("2025-12-07", 4562, "out", "네이버페이", time="20:29", institution="우리카드",
        is_cancel=True)),
    ("hana_card", "sms", "하나카드",
     "하나1*3*승인 홍*동 200,000원\n일시불 11/05 16:07 국민카메라\n누적2,566,980원",
     tx("2026-11-05", 200000, "out", "국민카메라", time="16:07", institution="하나카드")),
    ("hana_card_key_value", "sms", "하나카드",
     "금액 12,300원\n카드 하나1*2*\n손님명 홍*동\n거래종류 신용\n거래구분 일시불\n"
     "사용처 쿠팡(쿠페이)\n거래시간 10/15 09:05\n누적금액 300,000원",
     tx("2026-10-15", 12300, "out", "쿠팡(쿠페이)", time="09:05", institution="하나카드")),
    ("bc_card", "sms", "BC카드",
     "부산BC(1234)\n12,300원 사용\n개인\n홍길동님\n일시불 04/24 13:45\n총누적\n100,000원\n스타벅스",
     tx("2026-04-24", 12300, "out", "스타벅스", time="13:45", institution="BC카드")),
    ("nh_card_check", "sms", "NH농협카드",
     "NH카드1*3*승인\n홍*동\n10,000원 체크\n03/16 00:44\n(주)이니셜커뮤니케이션즈",
     tx("2026-03-16", 10000, "out", "(주)이니셜커뮤니케이션즈", time="00:44",
        institution="NH농협카드")),
    ("jb_card", "sms", "전북은행 JB카드",
     "[JBCard]4321 500,000원 일시불승인 10/22 13:00 롯데쇼핑주식회사",
     tx("2026-10-22", 500000, "out", "롯데쇼핑주식회사", time="13:00", institution="JB카드")),
    ("citi_card", "sms", "씨티카드",
     "씨티카드(1234*56*)\n홍길동님\n04/24 13:45\n일시불 12,300원\n스타벅스",
     tx("2026-04-24", 12300, "out", "스타벅스", time="13:45", institution="씨티카드")),
    ("shinhan_card_web_header", "sms", "신한카드",
     "[Web발신]\n신한카드(1234)승인 홍*동\n12,500원(일시불) 11/16 12:31\n김밥천국 강남점 누적 345,600원",
     tx("2026-11-16", 12500, "out", "김밥천국 강남점", time="12:31", institution="신한카드"),
     {"note": "설계안 '출력 형식'의 예시"}),
    # ---------------------------------------------------------------- 앱 알림(제목 + 본문)
    ("kakaobank_push_in", "push", "카카오뱅크",
     "입금 50,440원\nNpay정산 → 개인사업자통장(1111)\n잔액 50,440원",
     tx(TODAY, 50440, "in", "Npay정산", balance_after=50440, institution="카카오뱅크")),
    ("kbank_push_in", "push", "케이뱅크",
     "케이뱅크\n입금 3,000,000원\n대출실행 ( 원금 )  | 생활통장(0000)\n잔액 3,109,662원",
     tx(TODAY, 3000000, "in", "대출실행 ( 원금 )", balance_after=3109662, institution="케이뱅크")),
    ("tossbank_push_in", "push", "토스뱅크",
     "200,000원 입금\n홍길동 → 내 토스뱅크 통장",
     tx(TODAY, 200000, "in", "홍길동", institution="토스뱅크")),
    ("tossbank_push_cashback", "push", "토스뱅크",
     "6원 캐시백\n2,300원 결제 | 세븐일레븐 강동열린점\n잔액 146,658원(토스뱅크 체크카드)",
     tx(TODAY, 2300, "out", "세븐일레븐 강동열린점", balance_after=146658, institution="토스뱅크")),
    ("toss_push_pay", "push", "토스",
     "133,500원 결제\n하나카드 | 비비큐 강동밀레니얼점(일시불)",
     tx(TODAY, 133500, "out", "비비큐 강동밀레니얼점", institution="토스")),
    ("kbstar_push_out", "push", "KB국민은행",
     "출금 10,000원\n홍*동님 07/27 09:53 123456-**-***789 한국도로교통 체크카드출금 10,000 잔액52,980",
     tx("2026-07-27", 10000, "out", "한국도로교통", time="09:53", balance_after=52980,
        institution="KB국민은행")),
    ("shinhan_sol_push_out", "push", "신한은행",
     "출금\n1,000원 홍길동 입출금(0000)\n11.09 16:41",
     tx("2026-11-09", 1000, "out", "홍길동", time="16:41", institution="신한은행")),
    ("nh_allone_push_in", "push", "NH농협은행",
     "입출금 알림\n농협 입금123,456원\n10/15 11:30 123-****-5678-90 홍길동 잔액654,321원",
     tx("2026-10-15", 123456, "in", "홍길동", time="11:30", balance_after=654321,
        institution="NH농협은행")),
    ("hana_pay_push", "push", "하나카드",
     "(결제) 4,500원\n동네식품 / 신용(일시불,1*2*) / 11.09 15:16 / 누적이용금액 1,146,438원",
     tx("2026-11-09", 4500, "out", "동네식품", time="15:16", institution="하나카드")),
    ("samsung_wallet_push", "push", "삼성 월렛",
     "₩7,100 결제 완료\n씨유 휘경행복점",
     tx(TODAY, 7100, "out", "씨유 휘경행복점", institution="삼성 월렛")),
    # ---------------------------------------------------------------- 기록하면 안 되는 안내문
    ("notice_lotte_scheduled", "notice", "롯데카드",
     "[롯데카드]11/16출금예정2,668,841원", "non_transaction"),
    ("notice_hyundai_statement", "notice", "현대카드",
     "[현대카드] 홍*동님 11/12결제금액 1,009,601원(11/04기준)", "non_transaction"),
    ("notice_hyundai_payment_received", "notice", "현대카드",
     "[현대카드] 홍*동님 11/13 1,629,213원이 입금되었습니다", "non_transaction"),
    ("notice_kakaobank_loan_due", "notice", "카카오뱅크",
     "[카카오뱅크] 홍*동님 주택담보대출(0000)의 다음 원리금 납입일은 2026.11.23입니다.\n"
     "- 납입예정금액 : 1,725,651원", "non_transaction"),
    ("notice_kbank_loan_started", "notice", "케이뱅크",
     "[케이뱅크] 대출이 실행되었습니다\n- 대출금 : 3,000,000원", "non_transaction"),
    ("notice_toss_scheduled", "notice", "토스",
     "오늘 KB국민카드에서 16,462원 출금할 예정이에요.", "non_transaction"),
    ("notice_toss_failed", "notice", "토스",
     "요금납부 132,810원 출금 실패", "non_transaction"),
    ("notice_verification", "notice", "기타",
     "[Coupang] 본인확인 인증번호 [123456]입니다.", "non_transaction"),
    ("notice_advertisement", "notice", "기타",
     "(광고)안녕하세요. 회원님께 드리는 혜택\n[4개월 특가! 월 10원부터]\n무료수신거부 080-000-0000",
     "non_transaction"),
]


def main():
    out = pathlib.Path(__file__).resolve().parents[1] / "golden" / "paste.jsonl"
    lines = []
    seen = set()
    for case in CASES:
        cid, channel, institution, text, expect = case[:5]
        extra = case[5] if len(case) > 5 else {}
        assert cid not in seen, cid
        seen.add(cid)
        row = {"id": cid, "channel": channel, "institution": institution,
               "today": extra.get("today", TODAY), "text": text}
        if isinstance(expect, str):
            row["kind"] = expect
        else:
            row["kind"] = "transaction"
            row["expect"] = expect
        for key in ("synthetic", "note"):
            if key in extra:
                row[key] = extra[key]
        lines.append(json.dumps(row, ensure_ascii=False))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)}건 → {out}")


if __name__ == "__main__":
    main()
