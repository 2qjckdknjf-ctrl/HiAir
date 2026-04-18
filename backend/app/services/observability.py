from collections import defaultdict
from dataclasses import dataclass, field
from threading import Lock


@dataclass
class ObservabilityState:
    total_requests: int = 0
    total_errors: int = 0
    by_method: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    by_status: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    by_path: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    latency_ms_total: float = 0.0
    latency_samples: int = 0
    ai_explanations_total: int = 0
    ai_explanations_fallback: int = 0
    ai_guardrail_blocked: int = 0
    risk_level_alias_counts: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    lock: Lock = field(default_factory=Lock)


state = ObservabilityState()


def record_request(method: str, path: str, status_code: int, latency_ms: float) -> None:
    with state.lock:
        state.total_requests += 1
        state.by_method[method] += 1
        state.by_status[str(status_code)] += 1
        state.by_path[path] += 1
        state.latency_ms_total += latency_ms
        state.latency_samples += 1
        if status_code >= 500:
            state.total_errors += 1


def snapshot_metrics() -> dict[str, object]:
    with state.lock:
        avg_latency = 0.0
        if state.latency_samples > 0:
            avg_latency = state.latency_ms_total / state.latency_samples
        return {
            "total_requests": state.total_requests,
            "total_errors": state.total_errors,
            "avg_latency_ms": round(avg_latency, 2),
            "ai_explanations_total": state.ai_explanations_total,
            "ai_explanations_fallback": state.ai_explanations_fallback,
            "ai_guardrail_blocked": state.ai_guardrail_blocked,
            "risk_level_alias_counts": dict(state.risk_level_alias_counts),
            "by_method": dict(state.by_method),
            "by_status": dict(state.by_status),
            "by_path": dict(state.by_path),
        }


def record_ai_explanation(used_fallback: bool, guardrail_blocked: bool) -> None:
    with state.lock:
        state.ai_explanations_total += 1
        if used_fallback:
            state.ai_explanations_fallback += 1
        if guardrail_blocked:
            state.ai_guardrail_blocked += 1


def record_risk_level_alias(domain: str, source_level: str, normalized_level: str) -> None:
    key = f"{domain}:{source_level}->{normalized_level}"
    with state.lock:
        state.risk_level_alias_counts[key] += 1
