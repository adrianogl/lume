import json
import sys
from datetime import date, timedelta
from pathlib import Path

from garminconnect import Garmin


def safe(call, default=None):
    try:
        return call()
    except Exception:
        return default


def body_battery(client, day):
    data = safe(lambda: client.get_body_battery(day), []) or []
    values = [v[1] for item in data for v in (item.get("bodyBatteryValuesArray") or []) if v and len(v) > 1 and v[1] is not None]
    return values[-1] if values else None


def sleep_seconds(client, day):
    data = safe(lambda: client.get_sleep_data(day), {}) or {}
    return (data.get("dailySleepDTO") or {}).get("sleepTimeSeconds")


def steps(client, day):
    data = safe(lambda: client.get_stats(day), {}) or {}
    return data.get("totalSteps")


def readiness(client, day):
    data = safe(lambda: client.get_training_readiness(day), []) or []
    if isinstance(data, dict):
        data = [data]
    if not data:
        return None, None
    latest = data[0]
    return latest.get("score"), latest.get("level")


def scheduled_today(client, today):
    data = safe(lambda: client.get_scheduled_workouts(today.year, today.month), None)
    items = []
    if isinstance(data, dict):
        items = data.get("calendarItems") or []
    elif isinstance(data, list):
        items = data
    for item in items:
        if item.get("date") == today.isoformat() and item.get("itemType") == "workout":
            return item
    return None


def workout_steps(client, workout_id):
    detail = safe(lambda: client.get_workout_by_id(workout_id), {}) or {}
    exercises = []
    for segment in detail.get("workoutSegments") or []:
        for step in segment.get("workoutSteps") or []:
            nested = step.get("workoutSteps") or [step]
            reps_total = step.get("numberOfIterations")
            for inner in nested:
                name = inner.get("exerciseName") or inner.get("category")
                if not name or inner.get("stepType", {}).get("stepTypeKey") == "rest":
                    continue
                reps = inner.get("endConditionValue")
                weight = inner.get("weightValue")
                exercises.append({
                    "name": name.replace("_", " ").title(),
                    "sets": reps_total,
                    "reps": int(reps) if isinstance(reps, (int, float)) else None,
                    "weightKg": round(weight, 1) if isinstance(weight, (int, float)) else None,
                })
    return exercises, detail.get("estimatedDurationInSecs")


def week(client, today):
    start = today - timedelta(days=today.weekday())
    activities = safe(lambda: client.get_activities_by_date(start.isoformat(), today.isoformat()), []) or []
    minutes = {}
    for activity in activities:
        day = (activity.get("startTimeLocal") or "")[:10]
        minutes[day] = minutes.get(day, 0) + round((activity.get("duration") or 0) / 60)
    return [
        {"date": (start + timedelta(days=i)).isoformat(), "minutes": minutes.get((start + timedelta(days=i)).isoformat(), 0)}
        for i in range(7)
    ]


def main():
    tokens = str(Path.home() / ".garminconnect")
    client = Garmin()
    client.login(tokens)
    today = date.today()
    iso = today.isoformat()

    score, level = readiness(client, iso)
    workout = scheduled_today(client, today)
    exercises, duration = ([], None)
    if workout and workout.get("workoutId"):
        exercises, duration = workout_steps(client, workout["workoutId"])

    print(json.dumps({
        "bodyBattery": body_battery(client, iso),
        "sleepSeconds": sleep_seconds(client, iso),
        "steps": steps(client, iso),
        "readinessScore": score,
        "readinessLevel": level,
        "workout": {
            "name": workout.get("title"),
            "durationSeconds": duration,
            "exercises": exercises,
        } if workout else None,
        "week": week(client, today),
    }, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}), file=sys.stdout)
        sys.exit(1)
