# Fotos de los comercios

Una carpeta por filtro de Premios:

```
restaurantes/
ropa/
cafecitos/
conveniencia/
deportes-ejercicio/
```

Dejá la foto en la carpeta que le toca, **con el nombre del local** como
te salga: `Cafe Barista.jpg`, `pollo campero.png`, lo que sea. No importa
el formato del nombre.

Lo que hago yo con cada una:

1. La renombro a algo seguro (sin tildes, espacios ni mayúsculas)
2. Le creo su entrada en `assets/mock/premios.json` apuntando a la ruta
3. Le pongo la categoría según la carpeta donde la dejaste

Lo único que **no** puedo inventar es qué da cada premio y cuánto cuesta
en monedas — esa es decisión de negocio. Va marcado como pendiente hasta
que me lo pases.

**Formato:** JPG, PNG o WebP horizontal, mínimo 800 px de ancho. La
tarjeta del catálogo recorta a 1.4:1 y el detalle va a pantalla completa,
así que lo importante del local tiene que quedar al centro.

Los `LEEME.md` de cada subcarpeta están para que la carpeta no quede
vacía: git no versiona carpetas vacías y Flutter se queja si
`pubspec.yaml` declara una que no existe. Cuando la carpeta tenga fotos
se pueden borrar.
