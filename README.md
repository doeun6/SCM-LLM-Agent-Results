# SCM-LLM-Agent 실험 결과 저장소

이 저장소는 [`SCM-LLM-Agent`](https://github.com/doeun6/SCM-LLM-Agent)에서 생성한 실험 원자료와 최종 통합 분석 결과를 보관합니다. 실행 코드와 설정은 코드 저장소에서 관리하고, 이 저장소에는 결과만 저장합니다.

## 저장 구조

```text
SCM-LLM-Agent-Results/
├─ seeds/
│  ├─ pilot/       # 설계 점검용 pilot seed ZIP
│  └─ final/       # 설계 동결 후 최종 실험 seed ZIP
├─ analysis/
│  ├─ pilot/       # pilot 10개가 모인 뒤 만드는 탐색적 분석
│  └─ final/       # 설계 동결 후 최종 통합 분석
├─ tools/
│  └─ package_seed_results.ps1
└─ SEED_EXPERIMENT_GUIDE.md
```

각 `seed-XXX-results.zip`에는 해당 seed에서 완료된 19개 조건의 원자료만 들어갑니다. 조건별 필수 파일은 다음과 같습니다.

- `summary.json`
- `periods.csv`
- `demand.csv`
- `result.json`

QC 결과, API 키, 실행 로그, `.partial`, `.staging`, `quarantine`, 가상환경은 업로드하지 않습니다.

## 현재 단계

- seed `101–110`: 설계 점검을 위한 pilot 후보
- `analysis/pilot/`: pilot 10개가 모두 모인 뒤 생성하며 최종 추론과 분리
- `analysis/final/`: 최종 실험의 독립 seed가 모두 모인 뒤 한 번만 생성
- pilot 결과를 보고 설계를 변경하면 pilot 자료는 최종 추론에서 제외

실행과 업로드 방법은 [SEED_EXPERIMENT_GUIDE.md](SEED_EXPERIMENT_GUIDE.md)를 따릅니다.

