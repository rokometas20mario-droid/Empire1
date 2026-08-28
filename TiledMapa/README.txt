VODA IN GORA ZA TILED

Voda:
- voda.tsx je že pripravljen tileset za Tiled.
- voda_tileset.png vsebuje 16 kosov velikosti 256 x 128.
- Uvozi voda.tsx v svojo mapo, nato naredi novo Tile Layer plast z imenom Voda.
- Plast Voda naj bo nad plastjo trava in pod plastjo Objekti.
- Za risanje prehodov uporabi Terrain Sets > Voda.
- voda_polna.png je samostojna polna vodna ploščica.

Gora:
- gora.png je 1024 x 768 in ima pravo prosojno ozadje.
- Dodaj jo v image-collection tileset objekti_posamicno.tsx.
- Class: mountain
- Postavi jo na plast Objekti.
- V Tile Collision Editorju nariši izometričen poligon samo okoli spodnjega podnožja.
- Predlagani footprint: približno 4 x 4 ploščice; po potrebi jo v Tiled zmanjšaš.

V igri naj bosta voda in gora neprehodni. Tiled shrani samo podatke; tvoja igra mora
lastnost neprehodno oziroma kolizijski poligon tudi prebrati in uporabiti.
