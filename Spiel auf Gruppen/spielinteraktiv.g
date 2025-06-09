# Funktion zum Ersetzen aller Vorkommen eines Substrings in einem String
StringReplaceAll := function(str, search, replace)
    local parts;
    parts := SplitString(str, search);               # Zerlege den String an jeder Stelle von 'search'
    return JoinStringsWithSeparator(parts, replace); # Füge ihn mit 'replace' wieder zusammen
end;

# Funktion zur Vorbereitung eines Strings für JSON (Escape-Sequenzen)
EscapeJSONString := function(str)
    local s;
    s := String(str);
    s := StringReplaceAll(s, "\\", "\\\\");  # Escape Backslashes
    s := StringReplaceAll(s, "\"", "\\\"");  # Escape doppelte Anführungszeichen
    s := StringReplaceAll(s, "\n", "\\n");   # Escape Zeilenumbrüche
    s := StringReplaceAll(s, "\r", "\\r");   # Escape Wagenrücklauf
    s := StringReplaceAll(s, "\t", "\\t");   # Escape Tabulatoren
    return s;
end;

# Wandelt eine Liste von Records in einen JSON-String um
ListOfRecsToJSON := function(list)
    local i, j, keys, parts, jsonRecs, val, valStr;
    jsonRecs := [];
    for i in [1..Length(list)] do
        keys := RecNames(list[i]);       # Alle Schlüssel im Record
        parts := [];
        for j in [1..Length(keys)] do
            val := list[i].(keys[j]);    # Wert zu Schlüssel
            if IsString(val) then        # Wenn es ein String ist: escapen + Anführungszeichen
                valStr := Concatenation("\"", EscapeJSONString(val), "\"");
            else
                valStr := String(val);   # Ansonsten normal umwandeln
            fi;
            Add(parts, Concatenation("\"", keys[j], "\":", valStr));  # Schlüssel-Wert-Paar
        od;
        Add(jsonRecs, Concatenation("{", JoinStringsWithSeparator(parts, ","), "}"));  # Record als JSON
    od;
    return Concatenation("[", JoinStringsWithSeparator(jsonRecs, ","), "]");  # Ganze Liste als JSON-Array
end;

# Speichert einen Graphen (Knoten & Kanten) als JSON-Datei unter 'path'
SaveGraphAsJSON := function(nodesList, edgesList, path)
    local f, nodesJSON, edgesJSON;
    nodesJSON := ListOfRecsToJSON(nodesList);  # Wandle Knotenliste in JSON
    edgesJSON := ListOfRecsToJSON(edgesList);  # Wandle Kantenliste in JSON
    f := OutputTextFile(path, false);          # Öffne Datei zum Schreiben
    AppendTo(f, "{");                          # Beginne JSON-Objekt
    AppendTo(f, "\"nodes\":");
    AppendTo(f, nodesJSON);
    AppendTo(f, ",");
    AppendTo(f, "\"edges\":");
    AppendTo(f, edgesJSON);
    AppendTo(f, "}");                          # Schließe JSON-Objekt
    CloseStream(f);                            # Schließe Datei
end;

# Fügt einen Gruppenknoten hinzu (falls noch nicht vorhanden) und gibt dessen ID zurück
AddNode := function(G, idMap, allNodes, nextId)
    local key, id;
    key := String(IdGroup(G));                # Nutze ID der Gruppe
    if IsBound(idMap.(key)) then              # Wenn schon registriert
        return idMap.(key);                   # Gib bestehende ID zurück
    fi;
    id := nextId[1];                          # Neue ID
    idMap.(key) := id;                        # Merke ID für diese Gruppe
    Add(allNodes, rec(                        # Füge Knoten der Knotenliste hinzu
        id := id,
        description := StructureDescription(G),
        size := Size(G)
    ));
    nextId[1] := nextId[1] + 1;               # Erhöhe ID-Zähler
    return id;                                # Gib ID zurück
end;

# Hauptfunktion: Erzeugt Spielgraph für Gruppe G und speichert ihn als JSON
GenerateGraphAndSaveJSON := function(G, jsonPath)
    local allNodes, allEdges, processed, queue, idMap, nextId, current, currentId, normals, i, N, FG, fgId;

    allNodes := [];    # Liste der Knoten (Gruppen)
    allEdges := [];    # Liste der gerichteten Kanten
    processed := [];   # Knoten, die bereits vollständig behandelt wurden
    queue := [];       # Warteschlange für BFS
    idMap := rec();    # Zuordnung Gruppen-ID → Knoten-ID
    nextId := [1];     # Zähler für Knoten-IDs

    Add(queue, G);     # Starte mit Ursprungsgruppe G

    while Length(queue) > 0 do
        current := queue[1];     # Nächstes Gruppenelement
        Remove(queue, 1);        # Entferne aus der Queue

        currentId := AddNode(current, idMap, allNodes, nextId);  # Füge Knoten ggf. hinzu

        if currentId in processed then  # Falls bereits verarbeitet
            continue;
        fi;

        Add(processed, currentId);  # Markiere als verarbeitet

        # Filtere alle Normalteiler, die von genau einem Element erzeugt sind
        normals := Filtered(NormalSubgroups(current), N -> 
            Size(N) > 1 and
            ForAny(current, g -> NormalClosure(current, Subgroup(current, [g])) = N)
        );

        # Für jeden zulässigen Normalteiler: Faktorgruppe berechnen
        for i in [1..Length(normals)] do
            N := normals[i];
            FG := FactorGroup(current, N);          # Faktorgruppe bilden
            fgId := AddNode(FG, idMap, allNodes, nextId);  # Knoten-ID für Faktorgruppe
            Add(allEdges, rec(                      # Füge Kante ein
                from := currentId,
                to := fgId
            ));
            if not fgId in processed then           # Noch nicht verarbeitet?
                Add(queue, FG);                     # Dann in Queue aufnehmen
            fi;
        od;
    od;

    # Schreibe Ergebnis als JSON-Datei
    SaveGraphAsJSON(allNodes, allEdges, jsonPath);
end;
