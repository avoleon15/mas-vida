
MAX_DAILY_POINTS = 200
MIN_STEPS_FOR_25 = 7000
MIN_STEPS_FOR_50 = 10000
MIN_STEPS_FOR_100 = 15000


class InvalidPoints(ValueError):
    pass

def calculate_points(steps: int)-> int:

    #Calculo de puntos según pasos
    if steps < 0:
        raise InvalidPoints()
    if steps < MIN_STEPS_FOR_25:
        return 0
    if steps < MIN_STEPS_FOR_50:
        return 25
    if steps < MIN_STEPS_FOR_100:

        return 50
    return 100

def puntos_brutos(puntos_pasos: int, puntos_intensidad: int) -> int:
    puntos_brutos = puntos_pasos + puntos_intensidad
    return puntos_brutos
    

def apply_daily_points_limit(points: int) -> tuple[int, bool]:
    if points < 0:
        raise InvalidPoints()
    applied_cap = points > MAX_DAILY_POINTS
    net_points = min(points, MAX_DAILY_POINTS)
    return net_points, applied_cap



   


    
