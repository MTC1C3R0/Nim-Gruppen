# Hilfsfunktion: Fügt eine Gruppe G als Knoten hinzu, wenn sie noch nicht existiert.
# - idMap speichert, welche Gruppen-ID (als String) welcher Knoten-ID zugeordnet ist.
# - allNodes enthält alle bisher eingefügten Gruppen.
# - nextId ist ein Eintrag [n], der die nächste verfügbare Knoten-ID angibt.
AddNode := function(G, idMap, allNodes, nextId)
    local key, id;
    key := String(IdGroup(G));  # Nutze die Gruppen-ID als Schlüssel 
    if IsBound(idMap.(key)) then  # Falls dieser Schlüssel schon bekannt ist,
        return idMap.(key);       # gib die zugehörige ID zurück
    fi;
    id := nextId[1];              # Neue ID für diesen Knoten
    idMap.(key) := id;            # Weise dem Schlüssel die neue ID zu
    Add(allNodes, [StructureDescription(G), G]);  # Speichere die Gruppe samt Beschreibung
    nextId[1] := nextId[1] + 1;   # Inkrementiere die ID für den nächsten Knoten
    return id;                    # Gib die vergebene ID zurück
end;

# Hauptfunktion: Erzeugt einen TikZ-Quelltext für ein gerichtetes Spiel-DAG mit Faktorgruppenübergängen
GenerateTikzDAG := function(G)
    local allNodes, allEdges, processed, queue, idMap, nextId, current, currentId, normals, i, N, FG, fgId, j, nodeMap, tikzLines, tikz, fromId, toId, fromStr, toStr, line;

    allNodes := [];     # Liste aller eindeutigen Knoten (Gruppen mit Beschreibung)
    allEdges := [];     # Liste aller gerichteten Kanten (von -> nach)
    processed := [];    # Liste bereits vollständig behandelter Knotennummern
    queue := [];        # Warteschlange für zu verarbeitende Gruppen (BFS)
    idMap := rec();     # Hashmap: Gruppen-ID (als String) → Knoten-ID
    nextId := [1];      # Zähler für die nächste freie Knoten-ID (in Liste für Referenz)

    # Starte mit Eingangsgruppe G
    AddNode(G, idMap, allNodes, nextId);
    Add(queue, G);

    # Durchlaufe die Warteschlange
    while Length(queue) > 0 do
        current := queue[1];        # Nächstes Gruppenelement in der Warteschlange
        Remove(queue, 1);           # Entferne es aus der Warteschlange
        currentId := AddNode(current, idMap, allNodes, nextId);  # Ermittle ID

        if currentId in processed then  # Überspringe bereits verarbeitete Gruppen
            continue;
        fi;
        Add(processed, currentId);  # Markiere als verarbeitet

        # Filtere Normalteiler, die von genau einem Element erzeugt werden können
        normals := Filtered(NormalSubgroups(current), N -> 
            Size(N) > 1 and
            ForAny(current, g -> NormalClosure(current, Subgroup(current, [g])) = N)
        );

        # Für jeden gültigen Normalteiler
        for i in [1..Length(normals)] do
            N := normals[i];                       # Aktueller Normalteiler
            FG := FactorGroup(current, N);         # Faktorgruppe bilden
            fgId := AddNode(FG, idMap, allNodes, nextId);  # Knoten hinzufügen oder finden
            Add(allEdges, [currentId, fgId]);       # Kante zur Faktorgruppe hinzufügen
            if not fgId in processed then           # Wenn noch nicht verarbeitet
                Add(queue, FG);                     # In die Warteschlange einfügen
            fi;
        od;
    od;

    # Erstelle eine Map von ID → Strukturbezeichnung für spätere TikZ-Ausgabe
    nodeMap := rec();
    for j in [1..Length(allNodes)] do
        nodeMap.(String(j)) := allNodes[j][1];
    od;

    # TikZ-Dokumentzeilen vorbereiten
    tikzLines := [];
    Add(tikzLines, "\\documentclass{standalone}");
    Add(tikzLines, "\\usepackage{tikz}");
    Add(tikzLines, "\\usetikzlibrary{graphs, graphdrawing}");
    Add(tikzLines, "\\usegdlibrary{layered}");
    Add(tikzLines, "\\begin{document}");
    Add(tikzLines, "\\begin{tikzpicture}[>=stealth]");
    Add(tikzLines, "  \\graph [layered layout, sibling distance=20mm, level distance=25mm] {");

    # TikZ-Kanten ausgeben mit Labels
    for j in [1..Length(allEdges)] do
        fromId := allEdges[j][1];
        toId := allEdges[j][2];
        fromStr := nodeMap.(String(fromId));  # Strukturbezeichnung Start
        toStr := nodeMap.(String(toId));      # Strukturbezeichnung Ziel
        line := Concatenation(
            "    N", String(fromId), " [as={$", fromStr, "$}]",
            " -> N", String(toId), " [as={$", toStr, "$}];"
        );
        Add(tikzLines, line);  # Kante einfügen
    od;

    # TikZ-Dokument abschließen
    Add(tikzLines, "  };");
    Add(tikzLines, "\\end{tikzpicture}");
    Add(tikzLines, "\\end{document}");

    # Die TikZ-Zeilen zu einem String zusammenfügen
    tikz := JoinStringsWithSeparator(tikzLines, "\n");
    return tikz;  # Rückgabe der TikZ-Datei als String
end;
