import subprocess
import os
import tkinter as tk
from tkinter import simpledialog

def run_gap_and_compile(group_str):
    # Pfade relativ zum Skriptverzeichnis
    base_dir = os.path.dirname(os.path.abspath(__file__))
    script_path_win = os.path.join(base_dir, "graphdrawsvc.g")
    output_dir_win = os.path.join(base_dir, "output")
    os.makedirs(output_dir_win, exist_ok=True)

    temp_g_path_win = os.path.join(output_dir_win, "temp_input.g")
    tex_output_path_win = os.path.join(output_dir_win, "group_graph.tex")
    pdf_output_path_win = os.path.join(output_dir_win, "group_graph.pdf")

    # Windows-Pfad zu WSL-Pfad umwandeln
    def win_to_wsl_path(win_path):
        drive = win_path[0].lower()
        path_rest = win_path[2:].replace("\\", "/")
        return f"/mnt/{drive}/{path_rest}"

    script_path = win_to_wsl_path(script_path_win)
    temp_g_path = win_to_wsl_path(temp_g_path_win)
    tex_output_path = win_to_wsl_path(tex_output_path_win)

    # GAP-Code in temp_input.g schreiben
    gap_code = f'''
Read("{script_path}");
G := {group_str};
tikz := GenerateTikzDAG(G);
f := OutputTextFile("{tex_output_path}", false);
AppendTo(f, tikz);
CloseStream(f);
QUIT;
'''

    with open(temp_g_path_win, "w") as f:
        f.write(gap_code)

    # GAP über WSL starten und temp_input.g ausführen
    try:
        subprocess.run(["wsl", "gap", "-q", "-b", temp_g_path], check=True)
    except subprocess.CalledProcessError as e:
        print("Fehler beim Aufrufen von GAP:", e)
        return

    # LuaLaTeX kompilieren
    try:
        subprocess.run(["lualatex", "-output-directory", output_dir_win, tex_output_path_win], check=True)
    except subprocess.CalledProcessError as e:
        print("Fehler bei LuaLaTeX-Kompilierung:", e)
        return

    # PDF öffnen (Windows-Standardprogramm)
    try:
        os.startfile(pdf_output_path_win)
    except Exception as e:
        print("Fehler beim Öffnen der PDF-Datei:", e)

def main():
    root = tk.Tk()
    root.withdraw()
    group_str = simpledialog.askstring("Gruppe eingeben", "Gib die GAP-Gruppendefinition ein, z.B. DirectProduct(CyclicGroup(2), CyclicGroup(3))")
    if group_str:
        run_gap_and_compile(group_str)

if __name__ == "__main__":
    main()
