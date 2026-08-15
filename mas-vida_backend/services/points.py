

def calculate_points(steps: int):
    if steps < 0:
        raise ValueError("Los pasos no pueden ser negativos")
    elif steps < 7500:
        return 0
    elif steps < 10000:
        return 50
    elif steps < 15000:
        return 100
    else: return 200

