AddNode := function(G, idMap, allNodes, nextId)
    local key, id;
    key := String(IdGroup(G));
    if IsBound(idMap.(key)) then
        return idMap.(key);
    fi;
    id := nextId[1];
    idMap.(key) := id;
    Add(allNodes, rec(desc := StructureDescription(G), grp := G, mex := -1));
    nextId[1] := nextId[1] + 1;
    return id;
end;

ComputeMex := function(allNodes, allEdges)
    local i, nodeCount, outgoing, targetMexes, used, mex, j, from, to;

    nodeCount := Length(allNodes);

    # Wiederhole, bis sich keine Werte mehr ändern
    repeat
        changed := false;

        for i in [1..nodeCount] do
            # Finde alle Zielknoten von ausgehenden Kanten
            outgoing := Filtered(allEdges, e -> e[1] = i);
            targetMexes := List(outgoing, e -> allNodes[e[2]].mex);

            # Entferne alle noch undefinierten (-1) MEX-Werte
            targetMexes := Filtered(targetMexes, x -> x >= 0);

            # Wenn alle Ziel-MEX bekannt sind, dann berechne neuen Wert
            if Length(targetMexes) = Length(outgoing) then
                used := Set(targetMexes);
                mex := 0;
                while mex in used do
                    mex := mex + 1;
                od;

                if allNodes[i].mex <> mex then
                    allNodes[i].mex := mex;
                    changed := true;
                fi;
            fi;
        od;
    until not changed;
end;


GenerateTikzDAG := function(G)
    local allNodes, allEdges, processed, queue, idMap, nextId, current, currentId, normals, i, N, FG, fgId, j, nodeMap, tikzLines, tikz, fromId, toId, fromStr, toStr, line;

    allNodes := [];
    allEdges := [];
    processed := [];
    queue := [];
    idMap := rec();
    nextId := [1];

    AddNode(G, idMap, allNodes, nextId);
    Add(queue, G);

    while Length(queue) > 0 do
        current := queue[1];
        Remove(queue, 1);
        currentId := AddNode(current, idMap, allNodes, nextId);

        if currentId in processed then
            continue;
        fi;
        Add(processed, currentId);

        normals := Filtered(NormalSubgroups(current), N -> 
    		Size(N) > 1 and
    		ForAny(current, g -> NormalClosure(current, Subgroup(current, [g])) = N)
	);


        for i in [1..Length(normals)] do
            N := normals[i];
            FG := FactorGroup(current, N);
            fgId := AddNode(FG, idMap, allNodes, nextId);
            Add(allEdges, [currentId, fgId]);
            if not fgId in processed then
                Add(queue, FG);
            fi;
        od;
    od;

    ComputeMex(allNodes, allEdges);

    nodeMap := rec();
    for j in [1..Length(allNodes)] do
        nodeMap.(String(j)) := allNodes[j];
    od;

    tikzLines := [];
    Add(tikzLines, "\\documentclass{standalone}");
    Add(tikzLines, "\\usepackage{tikz}");
    Add(tikzLines, "\\usetikzlibrary{graphs, graphdrawing}");
    Add(tikzLines, "\\usegdlibrary{layered}");
    Add(tikzLines, "\\begin{document}");
    Add(tikzLines, "\\begin{tikzpicture}[>=stealth]");
    Add(tikzLines, "  \\graph [layered layout, sibling distance=20mm, level distance=25mm] {");

for j in [1..Length(allEdges)] do
    fromId := allEdges[j][1];
    toId := allEdges[j][2];

    fromNode := allNodes[fromId];
    toNode := allNodes[toId];

    # LaTeX-Text für fromNode
    if fromNode.mex = 0 then
        fromStr := Concatenation("\\textcolor{red}{\\alpha(\\mathrm{", fromNode.desc, "}) = 0}");
    else
        fromStr := Concatenation("\\alpha(\\mathrm{", fromNode.desc, "}) = ", String(fromNode.mex));
    fi;

    # LaTeX-Text für toNode
    if toNode.mex = 0 then
        toStr := Concatenation("\\textcolor{red}{\\alpha(\\mathrm{", toNode.desc, "}) = 0}");
    else
        toStr := Concatenation("\\alpha(\\mathrm{", toNode.desc, "}) = ", String(toNode.mex));
    fi;

    # Farbe für Pfeil zu Zielknoten mit mex=0
    if toNode.mex = 0 then
        line := Concatenation(
            "    N", String(fromId), " [as={$", fromStr, "$}]",
            " ->[draw=red] ",
            "N", String(toId), " [as={$", toStr, "$}];"
        );
    else
        line := Concatenation(
            "    N", String(fromId), " [as={$", fromStr, "$}]",
            " -> ",
            "N", String(toId), " [as={$", toStr, "$}];"
        );
    fi;

    Add(tikzLines, line);
od;


    Add(tikzLines, "  };");
    Add(tikzLines, "\\end{tikzpicture}");
    Add(tikzLines, "\\end{document}");

    tikz := JoinStringsWithSeparator(tikzLines, "\n");
    return tikz;
end;


