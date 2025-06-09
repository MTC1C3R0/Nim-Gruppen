# Gibt zurück, ob es in der Liste ein Element gibt, das eine bestimmte Bedingung erfüllt
Exists := function(list, pred)
  local i;
  for i in list do
    if pred(i) then
      return true;
    fi;
  od;
  return false;
end;

# Berechnet alle Faktorgruppen einer Gruppe G, bei denen der Normalteiler von einem Element erzeugt wird
ElementarErzeugteFaktorgruppen := function(G)
  local normals;
  normals := Filtered(
    NormalSubgroups(G),
    N -> Size(N) > 1 and
         Exists(Elements(G), g -> N = NormalClosure(G, Group(g)))
  );
  return List(normals, N -> FactorGroup(G, N));
end;

# Berechnet rekursiv die mex-Werte für eine Liste von Gruppen
BerechneMexWerte := function(gruppen)
  local mexMap, berechneMex, G, key, i, faktorgruppen, werte, w;

  # Initialisiere eine leere Map zum Speichern der mex-Werte
  mexMap := rec();

  # Interne rekursive Funktion zum Berechnen des mex-Werts einer Gruppe
  berechneMex := function(G)
    local key, faktorgruppen, werte, i, w;
    key := String(IdGroup(G));

    # Vermeide doppelte Berechnungen durch Zwischenspeicherung
    if IsBound(mexMap.(key)) then
      return mexMap.(key);
    fi;

    # Berechne Faktorgruppen und rekursive mex-Werte
    faktorgruppen := ElementarErzeugteFaktorgruppen(G);
    werte := [];

    for i in [1..Length(faktorgruppen)] do
      Add(werte, berechneMex(faktorgruppen[i]));
    od;

    # mex = kleinste nicht vorkommende natürliche Zahl
    w := 0;
    while w in werte do
      w := w + 1;
    od;

    # Speichere und gib den mex-Wert zurück
    mexMap.(key) := w;
    return w;
  end;

  # Berechne mex-Werte für alle Gruppen in der Eingabeliste
  for i in [1..Length(gruppen)] do
    G := gruppen[i];
    berechneMex(G);
  od;

  return mexMap;
end;

# Entfernt Duplikate aus einer Liste von Gruppen anhand ihrer IdGroup-Repräsentation
RemoveDuplicatesByString := function(list)
  local seen, res, i, s;
  seen := [];
  res := [];
  for i in [1..Length(list)] do
    s := String(IdGroup(list[i]));
    if not s in seen then
      Add(seen, s);
      Add(res, list[i]);
    fi;
  od;
  return res;
end;

# Hauptfunktion: Findet alle Gruppen mit mex = 0 bis zur Ordnung z und schreibt sie in eine Datei
FindeGruppenMitMexNull := function(z, filename)
  local alleGruppen, abelsch, nichtAbelsch, totalAbelsch, totalNichtAbelsch, i, G, key, mexMap, f;

  # Vergleichsfunktion zur Sortierung nach Gruppenordnung
  SortNachOrdnung := function(a, b)
    return Size(a) < Size(b);
  end;

  # Erstelle Liste aller Gruppen bis zur Ordnung z
  alleGruppen := [];
  for i in [1..z] do
    Append(alleGruppen, AllSmallGroups(i));
  od;

  # Zähle die abelschen und nicht-abelschen Gruppen insgesamt
  totalAbelsch := Length(Filtered(alleGruppen, g -> IsAbelian(g)));
  totalNichtAbelsch := Length(Filtered(alleGruppen, g -> not IsAbelian(g)));

  # Berechne mex-Werte für alle Gruppen
  mexMap := BerechneMexWerte(alleGruppen);

  # Initialisiere Listen für Gruppen mit mex = 0
  abelsch := [];
  nichtAbelsch := [];

  # Trenne Gruppen mit mex = 0 nach Abelsche/Nicht-Abelsche
  for i in [1..Length(alleGruppen)] do
    G := alleGruppen[i];
    key := String(IdGroup(G));
    if mexMap.(key) = 0 then
      if IsAbelian(G) then
        Add(abelsch, G);
      else
        Add(nichtAbelsch, G);
      fi;
    fi;
  od;

  # Entferne Duplikate
  abelsch := RemoveDuplicatesByString(abelsch);
  nichtAbelsch := RemoveDuplicatesByString(nichtAbelsch);

  # Sortiere beide Listen nach Gruppenordnung
  abelsch := SortedList(abelsch, SortNachOrdnung);
  nichtAbelsch := SortedList(nichtAbelsch, SortNachOrdnung);

  # Öffne Datei und schreibe Ergebnisse hinein
  f := OutputTextFile(filename, false);
  AppendTo(f, "=== Abelsche Gruppen mit mex = 0 (sortiert nach Gruppenordnung) ===\n");
  AppendTo(f, JoinStringsWithSeparator(List(abelsch, StructureDescription), "\n"));
  AppendTo(f, "\n\n=== Nicht-abelsche Gruppen mit mex = 0 (sortiert nach Gruppenordnung) ===\n");
  AppendTo(f, JoinStringsWithSeparator(List(nichtAbelsch, StructureDescription), "\n"));
  AppendTo(f, "\n\n");
  AppendTo(f, "Insgesamt wurden untersucht:\n");
  AppendTo(f, Concatenation("- ", String(totalAbelsch), " abelsche Gruppen\n"));
  AppendTo(f, Concatenation("- ", String(totalNichtAbelsch), " nicht-abelsche Gruppen\n"));
  CloseStream(f);

  # Gib ein Record mit Ergebnissen zurück
  return rec(
    abelsch := abelsch,
    nichtAbelsch := nichtAbelsch,
    totalAbelsch := totalAbelsch,
    totalNichtAbelsch := totalNichtAbelsch
  );
end;
