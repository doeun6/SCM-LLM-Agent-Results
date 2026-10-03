# Seed별 실험 실행 및 결과 공유 안내

이 문서는 새 컴퓨터에서 코드 저장소를 내려받고, 지정한 seed의 19개 조건을 실행한 뒤, 검증된 결과 ZIP을 이 저장소에 올리는 전체 과정을 설명합니다. 모든 명령은 **Windows PowerShell** 기준입니다.

## 1. 기본 원칙

- 하나의 seed에서는 19개 조건이 동일한 수요경로를 사용합니다.
- 실행 중인 seed의 조건을 임의로 나누거나 설정 파일을 변경하지 않습니다.
- seed `101–110` 결과는 우선 `pilot`으로 구분합니다.
- pilot을 본 뒤 설계를 변경하면 그 pilot seed는 최종 통계분석에서 제외합니다.
- API 키는 PowerShell 환경변수에만 넣고 파일이나 Git에 저장하지 않습니다.
- 결과는 반드시 19개 조건이 모두 완료된 뒤 ZIP으로 만듭니다.

## 2. 최초 1회: 두 저장소 내려받기

작업할 상위 폴더로 이동한 뒤 코드 저장소와 결과 저장소를 나란히 clone합니다.

```powershell
Set-Location "$HOME\Documents"
git clone https://github.com/doeun6/SCM-LLM-Agent.git
git clone https://github.com/doeun6/SCM-LLM-Agent-Results.git
```

비공개 결과 저장소를 받으려면 먼저 저장소 초대를 수락하고 GitHub 로그인을 완료해야 합니다.

정상적인 폴더 배치는 다음과 같습니다.

```text
Documents/
├─ SCM-LLM-Agent/
└─ SCM-LLM-Agent-Results/
```

## 3. 코드 실행 환경 준비

```powershell
Set-Location "$HOME\Documents\SCM-LLM-Agent"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-lock.txt
python -m pytest -q -p no:cacheprovider --basetemp .\work\pytest-study
python -m experiments.study --plan
python -m experiments.study --prepare
```

테스트가 실패하면 실험을 실행하지 말고 오류를 공유합니다.

## 4. OpenRouter 연결 확인

새 PowerShell을 열 때마다 API 키를 다시 설정합니다.

```powershell
$secureKey = Read-Host "OpenRouter API 키 입력" -AsSecureString
$env:OPENROUTER_API_KEY = [System.Net.NetworkCredential]::new("", $secureKey).Password
python -m experiments.api_smoke --config configs/environment.yaml --llm-config configs/model.yaml
```

`API smoke test succeeded`가 나와야 다음 단계로 진행합니다.

## 5. 컴퓨터별 기술 QC

결과는 Git에 포함되지 않으므로 새 컴퓨터에서는 기술 QC를 한 번 수행하고 승인해야 합니다.

```powershell
python -m experiments.study --stage technical_qc --execute
python -m experiments.study --check-qc
python -m experiments.study --approve-qc
```

`passed: true`, `approved: true`, 완료 조건 `19/19`를 확인합니다. QC 결과는 연구 성과 분석에 포함하지 않습니다.

## 6. 담당 seed 계획 확인

아래 예시는 seed 101입니다. 다른 seed를 맡았다면 숫자만 바꿉니다.

```powershell
$seed = 101
python -m experiments.study --stage screening --seeds $seed
```

계획 결과에서 다음을 확인합니다.

- `episodes: 19`
- `status: plan_only`
- seed 번호가 본인 담당 seed와 일치

## 7. 담당 seed 실행

```powershell
python -m experiments.study --stage screening --seeds $seed --execute
```

한 조건이 완전히 끝날 때만 완료 수가 증가합니다. 터미널이 한동안 변하지 않아도 오류 메시지가 없다면 기다립니다.

중간에 PowerShell이나 컴퓨터가 종료되면 API 키를 다시 설정하고 **같은 명령**을 실행합니다. 완료된 조건은 검증 후 자동으로 건너뜁니다.

`.partial` 관련 오류가 명시적으로 나타난 경우에만 다음처럼 복구합니다.

```powershell
python -m experiments.study --stage screening --seeds $seed --execute --recover-incomplete
```

## 8. 진행상황 확인

코드 저장소 최상위 폴더에서 새 PowerShell을 열고 실행합니다.

```powershell
$m = Get-Content "results\experiment\screening\manifest.json" -Raw | ConvertFrom-Json
"$($m.completed_episode_ids.Count)개 누적 완료, 현재 실행: $($m.current_episode)"
```

이 숫자는 그 컴퓨터의 전체 누적 완료 수입니다. 특정 seed가 끝났는지는 다음 패키징 도구가 19개 조건을 모두 검사하여 최종 확인합니다.

실행 명령의 마지막 출력에서 다음을 확인할 수도 있습니다.

- `status: completed`
- `completed_episodes: 19`
- `selected_episodes: 19`

하나의 seed만 끝났을 때 `full_stage_status: paused`인 것은 정상입니다. 전체 등록 seed가 아직 끝나지 않았다는 뜻입니다.

## 9. 완료 seed를 ZIP으로 만들기

결과 저장소의 도구는 다음을 자동 검사합니다.

- 정확히 19개 조건이 존재하는지
- 모든 조건의 `summary.json` 상태가 `completed`인지
- 네 개 필수파일이 모두 있는지
- seed 번호와 조건 코드가 일치하는지
- 19개 조건이 동일한 수요경로와 실행 설정을 사용했는지

pilot seed를 패키징하는 예시는 다음과 같습니다.

```powershell
$codeRepo = "$HOME\Documents\SCM-LLM-Agent"
$resultsRepo = "$HOME\Documents\SCM-LLM-Agent-Results"
& "$resultsRepo\tools\package_seed_results.ps1" -CodeRepository $codeRepo -Seed $seed -Category pilot
```

성공하면 다음 파일이 생성됩니다.

```text
SCM-LLM-Agent-Results/seeds/pilot/seed-101-results.zip
```

설계 동결 후 최종 실험을 패키징할 때만 `-Category final`을 사용합니다.

이미 같은 ZIP이 있으면 도구가 중단합니다. 검토 후 의도적으로 다시 만들 때만 `-Force`를 추가합니다.

## 10. 결과 저장소에 업로드

ZIP 파일은 Git LFS로 관리합니다. 컴퓨터마다 최초 한 번 실행합니다.

```powershell
Set-Location "$HOME\Documents\SCM-LLM-Agent-Results"
git lfs install
git pull --rebase origin main
```

공동작업 충돌을 막기 위해 seed별 브랜치를 만듭니다.

```powershell
git switch -c "seed-$seed-results"
git add "seeds/pilot/seed-$seed-results.zip"
git commit -m "seed $seed pilot 결과 추가"
git push -u origin "seed-$seed-results"
```

GitHub에서 해당 브랜치의 Pull Request를 만들고 `main`에 병합합니다. 다른 사람의 결과를 덮어쓰지 않도록 같은 seed를 중복 업로드하지 않습니다.

최종 seed라면 위 명령의 `pilot`을 `final`로 바꾸고 커밋 메시지도 `최종 결과`로 작성합니다.

## 11. pilot 및 최종 통합 분석

pilot 결과를 보고 설계를 바꿀 가능성이 있으므로 seed `101–110`의 탐색적 분석은 `analysis/pilot/`에 저장합니다. 이 결과는 방향 점검용이며 최종 추론과 분리합니다. `analysis/final/`은 설계를 동결하고 독립적인 최종 seed 결과가 모두 모인 뒤 생성합니다.

각 분석 폴더에는 분석기가 자동 생성한 다음 파일을 수정 없이 저장합니다.

- `episode_summary.csv`
- `condition_summary.csv`
- `condition_summary_clean_sensitivity.csv`
- `paired_differences.csv`
- `paired_comparisons.csv`
- `paired_comparisons_clean_sensitivity.csv`
- `interaction_contrasts.csv`
- `interaction_summary.csv`
- `interaction_summary_clean_sensitivity.csv`
- `analysis_issues.csv`
- `analysis.json`
- `analysis.md`

## 12. 업로드 금지 항목

- OpenRouter API 키 또는 키 저장파일
- `.venv/`
- QC 결과 전체
- `.partial`, `.staging`, `quarantine`
- 실행 잠금파일과 단순 콘솔 로그
- 완료되지 않은 seed 결과
- 임의로 수정한 CSV 또는 JSON

