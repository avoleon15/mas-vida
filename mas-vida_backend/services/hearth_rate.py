
gap_max = 5 
H_intensity = 0.70
Mid_intensity = 0.60

def fcm(edad: int) -> int:
    if edad < 0:
        raise ValueError('La edad no puede ser negativa')

    fcm = 219 - edad 

    return fcm

def calc_mid_intensity(fcm: int) -> float:
    mid_int = fcm * Mid_intensity 
    return mid_int

def calc_h_intensitu(fmc: int) -> float:
    h_int = fmc * H_intensity
    return h_int
