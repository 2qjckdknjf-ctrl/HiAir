#!/usr/bin/env python3
"""Replayable ACTION ranking check; no provider/model benchmark or clinical claim."""
import argparse
import json
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
from app.models.forecast import EnvironmentalForecast
from app.models.air import UserProfileContext, ProfileType
from app.models.activity_plan import ActivityType
from app.services.forecast.service import get_forecast
from app.services.forecast.mapping import forecast_to_hourly_inputs
from app.services.activity_plan_engine import build_activity_plan


def evaluate(captured):
    results = []
    tier_priority = {'best': 2, 'acceptable': 1}
    for record in captured['forecasts']:
        forecast = EnvironmentalForecast.model_validate(record['forecast'])
        points = forecast_to_hourly_inputs(forecast, from_now=False)
        if not points:
            continue
        profile = UserProfileContext(profile_id='action-evaluation', user_id='reference-context',
            profile_type=ProfileType.ADULT_DEFAULT, home_lat=points[0].lat, home_lon=points[0].lon,
            timezone=points[0].timezone)
        for activity, duration in [(ActivityType.RUNNING, 45), (ActivityType.WALKING, 90), (ActivityType.VENTILATION, 30)]:
            plan = build_activity_plan(profile=profile, environment=points[0], hourly_points=points,
                activity=activity, duration_minutes=duration)
            need = (duration + 59) // 60
            candidates = []
            for i in range(len(plan.hourly)-need+1):
                chunk = plan.hourly[i:i+need]
                if chunk[0].tier.value not in tier_priority or any(x.tier != chunk[0].tier for x in chunk):
                    continue
                if any(datetime.fromisoformat(b.hour)-datetime.fromisoformat(a.hour) != timedelta(hours=1)
                       for a,b in zip(chunk,chunk[1:])):
                    continue
                candidates.append((chunk[0].hour, tier_priority[chunk[0].tier.value], sum(x.score for x in chunk)/need))
            # Historical first-valid baseline within the strongest available tier.
            strongest = max((c[1] for c in candidates), default=0)
            baseline = next((c for c in candidates if c[1] == strongest), None)
            selected = next((c for c in candidates if c[0] == plan.recommendedStart), None)
            results.append({'city':record['city'], 'activity':activity.value, 'duration_minutes':duration,
                'freshness':forecast.freshness.value, 'quality':forecast.quality.value,
                'available_hours':len(points), 'baseline_score':baseline[2] if baseline else None,
                'selected_score':selected[2] if selected else None,
                'delta':round(selected[2]-baseline[2], 3) if selected and baseline else None,
                'honest_unavailable':not candidates and plan.recommendedStart is None})
    deltas = [r['delta'] for r in results if r['delta'] is not None]
    return {'evaluation_time':captured['evaluation_time'], 'source':'captured live Open-Meteo hourly forecasts',
        'scope':'ranking score / contract quality, not forecast accuracy or health outcome validation',
        'cases':results, 'improved':sum(d>0 for d in deltas), 'unchanged':sum(d==0 for d in deltas),
        'regressed':sum(d<0 for d in deltas), 'mean_score_delta':round(sum(deltas)/len(deltas),3) if deltas else None,
        'verdict':'PASS' if deltas and all(d>=0 for d in deltas) else 'INSUFFICIENT_EVIDENCE'}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--capture-live', type=Path)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args=parser.parse_args()
    if args.capture_live:
        captured={'evaluation_time':datetime.now(timezone.utc).isoformat(), 'forecasts':[]}
        for city,lat,lon in [('Barcelona',41.39,2.17),('Dubai',25.20,55.27),('Los Angeles',34.05,-118.24)]:
            forecast=get_forecast(lat,lon,hours=48,force_refresh=True)
            captured['forecasts'].append({'city':city,'forecast':forecast.model_dump(mode='json')})
        args.capture_live.parent.mkdir(parents=True,exist_ok=True)
        args.capture_live.write_text(json.dumps(captured,indent=2)+'\n')
    elif args.input:
        captured=json.loads(args.input.read_text())
    else:
        parser.error('choose --capture-live or --input')
    report=evaluate(captured)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='cases'}))
    return 0 if report['verdict']=='PASS' else 1

if __name__=='__main__':
    raise SystemExit(main())
