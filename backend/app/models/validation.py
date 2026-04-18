from pydantic import BaseModel


class HistoricalValidationCaseResult(BaseModel):
    case_id: str
    score: int
    level: str
    expected_min_level: str
    passed: bool


class HistoricalValidationResponse(BaseModel):
    passed: bool
    total_cases: int
    passed_cases: int
    failed_case_ids: list[str]
    cases: list[HistoricalValidationCaseResult]
