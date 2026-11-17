#!/usr/bin/env python3
"""홀드아웃 표본을 만든다: 규칙과 프롬프트를 다듬는 데 쓰지 않는 표본.

    python3 eval/tool/build_holdout.py

`golden/holdout_paste.jsonl`과 `golden/holdout_sentences.jsonl`을 쓴다.

규칙을 고칠 때 이 표본을 보고 맞추면 안 된다. 여기서 틀린 형식을 고치려면 같은 종류의
다른 표본을 `paste.jsonl` · `sentences.jsonl`에 더하고 그것으로 고친다. 그래야 이 표본의
점수가 "처음 보는 글"에 대한 점수로 남는다.

표본은 모두 지어낸 것이다. 금융사 이름도 실제와 겹치지 않게 지었거나, 실제 서비스
이름을 썼더라도 문구는 실제 알림과 다르다. 기준일은 2026-11-17(화)이다.
"""

import json
import pathlib

TODAY = "2026-11-17"
OUT = pathlib.Path(__file__).resolve().parent.parent / "golden"


def tx(id_, text, date, amount, direction, counterparty, cancel=None):
    expect = {
        "date": date,
        "amount": amount,
        "direction": direction,
        "counterparty": counterparty,
    }
    if cancel is not None:
        expect["is_cancel"] = cancel
    return {
        "id": id_,
        "today": TODAY,
        "text": text,
        "kind": "transaction",
        "expect": expect,
        "synthetic": True,
    }


def notice(id_, text):
    return {
        "id": id_,
        "today": TODAY,
        "text": text,
        "kind": "non_transaction",
        "synthetic": True,
    }


PASTE = [
    tx("ho_savings_in", "[새솔저축은행] 11/14 09:12 입금 150,000원 김영희 잔액 1,250,000원",
       "2026-11-14", 150000, "in", "김영희"),
    tx("ho_securities_out", "[한빛증권] 홍*동님 CMA계좌 출금 300,000원 (11/13 15:02) 받는분:이민수",
       "2026-11-13", 300000, "out", "이민수"),
    tx("ho_local_currency", "경기지역화폐 결제 8,500원 행복분식 11/15 12:20 잔액 41,500원",
       "2026-11-15", 8500, "out", "행복분식"),
    tx("ho_easy_pay", "네이버페이 결제완료 23,900원 무신사스토어 11.12 21:05",
       "2026-11-12", 23900, "out", "무신사스토어"),
    tx("ho_post_out", "우체국 11/10 13:45 출금 55,000원 한국전력공사 잔액 812,300원",
       "2026-11-10", 55000, "out", "한국전력공사"),
    tx("ho_mg_in", "MG새마을금고 입금 2,000,000원 11/05 (주)대한물산 잔액 2,410,000원",
       "2026-11-05", 2000000, "in", "(주)대한물산"),
    tx("ho_cu_multiline", "신협\n출금 12,000원\n11/16 18:30\n올리브영 강남점\n잔액 88,000원",
       "2026-11-16", 12000, "out", "올리브영 강남점"),
    tx("ho_auto_debit", "[수협은행] 홍*동님 11/09 자동이체 출금 89,000원 삼성화재 잔액 1,023,000원",
       "2026-11-09", 89000, "out", "삼성화재"),
    tx("ho_card_cancel", "[BC카드] 취소 15,800원 11/11 교보문고 광화문점 홍*동님",
       "2026-11-11", 15800, "out", "교보문고 광화문점", cancel=True),
    tx("ho_pipe_format", "토스뱅크 체크카드 4,300원 결제 | 스타벅스 역삼대로점 | 11/17 08:41",
       "2026-11-17", 4300, "out", "스타벅스 역삼대로점"),
    tx("ho_english", "Approved KRW 32,000 at COUPANG 11/08 20:15 Card *1234",
       "2026-11-08", 32000, "out", "COUPANG"),
    tx("ho_salary", "[하늘은행] 10/25 급여입금 3,250,000원 (주)푸른기술 잔액 3,410,220원",
       "2026-10-25", 3250000, "in", "(주)푸른기술"),
    tx("ho_atm", "하늘은행 ATM출금 100,000원 11/02 14:22 강남역지점 잔액 540,000원",
       "2026-11-02", 100000, "out", "강남역지점"),
    tx("ho_interest", "[새솔저축은행] 이자입금 1,234원 11/01 잔액 5,001,234원",
       "2026-11-01", 1234, "in", None),
    tx("ho_bill_multiline", "자동납부 완료\n아파트관리비 187,430원\n11/10 하늘은행 123-***-789",
       "2026-11-10", 187430, "out", "아파트관리비"),
    tx("ho_received_sentence", "김민지님이 50,000원을 보냈어요",
       "2026-11-17", 50000, "in", "김민지"),
    tx("ho_refund", "[쓱페이] 환불 완료 12,900원 이마트몰 11/13",
       "2026-11-13", 12900, "out", "이마트몰", cancel=True),
    tx("ho_transit_topup", "티머니 충전 30,000원 11/15 07:55 하늘카드(1234)",
       "2026-11-15", 30000, "out", "티머니"),
    tx("ho_delivery", "배달의민족 주문이 완료되었습니다. 결제금액 24,500원 (교촌치킨 역삼점)",
       "2026-11-17", 24500, "out", "교촌치킨 역삼점"),
    tx("ho_rent", "하늘은행 11/01 08:00 출금 550,000원 월세(박집주) 잔액 1,200,000원",
       "2026-11-01", 550000, "out", "월세(박집주)"),
    notice("ho_notice_statement", "[하늘카드] 11월 명세서가 발행되었습니다. 결제예정금액 842,300원 결제일 11/25"),
    notice("ho_notice_otp", "[Web발신] [새솔저축은행] 인증번호 [482913] 타인에게 절대 알려주지 마세요"),
    notice("ho_notice_ad", "(광고)[하늘카드] 11월 한정 5만원 이상 결제 시 5,000원 캐시백! 무료수신거부 080-000-0000"),
    notice("ho_notice_limit", "[한빛증권] 홍*동님 계좌 이체한도가 1일 5,000,000원으로 변경되었습니다"),
    notice("ho_notice_failed", "[하늘은행] 잔액부족으로 자동이체 55,000원이 출금되지 않았습니다(한국전력공사)"),
    notice("ho_notice_parcel", "택배가 도착했습니다. 문 앞에 보관했습니다. 운송장 1234-5678-9012"),
]


def sentence(n, text, date, amount, direction, contains=None):
    row = {
        "id": f"ho_sentence_{n:03d}",
        "today": TODAY,
        "text": text,
        "expect": {"date": date, "amount": amount, "direction": direction},
    }
    if contains is not None:
        row["counterparty_contains"] = contains
    return row


SENTENCES = [
    sentence(1, "방금 편의점에서 삼각김밥이랑 우유 3,200원 썼어", "2026-11-17", 3200, "out", "편의점"),
    sentence(2, "그저께 엄마가 20만원 보내주심", "2026-11-15", 200000, "in", "엄마"),
    sentence(3, "지난달 30일 헬스장 3개월 27만원 결제", "2026-10-30", 270000, "out", "헬스장"),
    sentence(4, "토요일 친구 결혼식 축의금 10만원", "2026-11-14", 100000, "out", "축의금"),
    sentence(5, "11월 3일 병원비 45,000원 실비 청구 예정", "2026-11-03", 45000, "out", "병원비"),
    sentence(6, "넷플릭스 구독료 17,000원 자동결제됨", "2026-11-17", 17000, "out", "넷플릭스"),
    sentence(7, "중고나라에 자전거 팔고 15만원 받았음", "2026-11-17", 150000, "in", "중고나라"),
    sentence(8, "어제 회사 동료들이랑 커피 내가 쏨 2만 4천원", "2026-11-16", 24000, "out", "커피"),
    sentence(9, "그제 주유 7만원", "2026-11-15", 70000, "out", "주유"),
    sentence(10, "이번 달 통신비 6만 5천 9백원 빠져나감", "2026-11-17", 65900, "out", "통신비"),
    sentence(11, "적금 이자 12,340원 들어옴", "2026-11-17", 12340, "in", "이자"),
    sentence(12, "지난주 수요일 치과 스케일링 18,000원", "2026-11-11", 18000, "out", "치과"),
    sentence(13, "택시비 만 이천원 어젯밤", "2026-11-16", 12000, "out", "택시비"),
    sentence(14, "5일에 받은 연말정산 환급 32만원", "2026-11-05", 320000, "in", "연말정산"),
    sentence(15, "아이 학원비 35만원 계좌이체 했음", "2026-11-17", 350000, "out", "학원비"),
    sentence(16, "다이소에서 수납함 2개 4천원", "2026-11-17", 4000, "out", "다이소"),
    sentence(17, "부모님 용돈 드림 30만원", "2026-11-17", 300000, "out", "용돈"),
    sentence(18, "오늘 점심 회사 근처 국밥집 9,000원", "2026-11-17", 9000, "out", "국밥집"),
    sentence(19, "어제 온라인으로 책 두 권 31,500원 주문", "2026-11-16", 31500, "out", "책"),
    sentence(20, "11/2 전기요금 42,180원 납부", "2026-11-02", 42180, "out", "전기요금"),
]


def write(name, rows):
    path = OUT / name
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"{path.name}: {len(rows)}건")


if __name__ == "__main__":
    write("holdout_paste.jsonl", PASTE)
    write("holdout_sentences.jsonl", SENTENCES)
