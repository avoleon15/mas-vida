
AGE_BONUS_MINIMUM = 65
AGE_BONUS_POINTS = 25
MAX_DAILY_POINTS = 200
MIN_STEPS_FOR_25 = 7000
MIN_STEPS_FOR_50 = 10000
MIN_STEPS_FOR_100 = 15000


class InvalidPoints(ValueError):
    pass

def calculate_points(steps: int)-> int:
    if steps < 0:
        raise InvalidPoints()
    if steps < MIN_STEPS_FOR_25:
        return 0
    if steps < MIN_STEPS_FOR_50:
        return 25
    if steps < MIN_STEPS_FOR_100:

        return 50
    return 100

def apply_daily_points_limit(points: int) -> int:
    if points > MAX_DAILY_POINTS:
        return MAX_DAILY_POINTS
    if points < 0:
        raise InvalidPoints()
    return points

def calculate_daily_step_points(steps: int, edad: int) -> int:
    puntos_pasos = calculate_points(steps)

    if puntos_pasos > 0 and edad >= AGE_BONUS_MINIMUM:
        puntos_pasos += AGE_BONUS_POINTS

    return puntos_pasos
