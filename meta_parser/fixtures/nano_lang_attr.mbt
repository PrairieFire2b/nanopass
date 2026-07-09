///|
#nano.lang(name="NanoLayer", layer="datum")
enum Datum {
  Symbol(String)
}

///|
#nano.lang(name="NanoSurface", extends="NanoLayer", layer="surface")
enum SurfaceDatum {
  Quoted(Datum)
}
