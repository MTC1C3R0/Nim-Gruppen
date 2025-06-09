import subprocess
import os
import tkinter as tk
from tkinter import simpledialog, messagebox
import tkinter.ttk as ttk
import json

# Führt GAP aus und generiert die JSON-Datei mit dem Spielgraphen
def run_gap_and_generate_json(group_str):
    base_dir = os.path.dirname(os.path.abspath(__file__))  # Basisverzeichnis des Skripts
    script_path_win = os.path.join(base_dir, "spielinteraktiv.g")  # Pfad zum GAP-Skript
    output_dir_win = os.path.join(base_dir, "output")  # Ausgabeverzeichnis
    os.makedirs(output_dir_win, exist_ok=True)  # Verzeichnis anlegen, falls nicht vorhanden

    temp_g_path_win = os.path.join(output_dir_win, "temp_input.g")  # temporäre GAP-Datei
    json_output_path_win = os.path.join(output_dir_win, "group_graph.json")  # Pfad zur JSON-Ausgabe

    # Hilfsfunktion: Konvertiert Windows-Pfad zu WSL-kompatiblem Pfad
    def win_to_wsl_path(win_path):
        drive = win_path[0].lower()  # Laufwerksbuchstabe
        path_rest = win_path[2:].replace("\\", "/")  # Backslashes durch Slashes ersetzen
        while '//' in path_rest:  # Doppelte Slashes vermeiden
            path_rest = path_rest.replace('//', '/')
        return f"/mnt/{drive}/{path_rest}"

    # Konvertierte Pfade für WSL (für GAP-Aufruf)
    script_path = win_to_wsl_path(script_path_win)
    temp_g_path = win_to_wsl_path(temp_g_path_win)
    json_output_path = win_to_wsl_path(json_output_path_win)

    # Dynamisch generierter GAP-Code
    gap_code = f'''
Read("{script_path}");
Print("Datei geladen\\n");
G := {group_str};
Print("Gruppe gesetzt\\n");
GenerateGraphAndSaveJSON(G, "{json_output_path}");
Print("JSON erzeugt\\n");
QUIT;
'''

    # Schreibe GAP-Code in temporäre Datei
    with open(temp_g_path_win, "w") as f:
        f.write(gap_code)

    print(f"Starte GAP mit dem Skript {temp_g_path}")

    # GAP ausführen via WSL
    try:
        subprocess.run(["wsl", "gap", "-q", "-b", temp_g_path], check=True, stdout=None, stderr=None)
    except subprocess.CalledProcessError as e:
        print("Fehler beim Ausführen von GAP:", e)
        return False

    return True

# Lädt den erzeugten JSON-Graph aus Datei und entfernt ggf. Zeilenumbrüche
def load_graph_json(json_path):
    with open(json_path, "r", encoding="utf-8") as f:
        text = f.read()
    text = text.replace("\\\n", "")  # Entferne GAP-spezifische Backslash-Zeilenumbrüche
    graph = json.loads(text)  # Parsen als JSON
    return graph

# Gibt alle Kinder eines Knotens anhand der Kantenliste zurück
def find_children(node_id, edges):
    return [edge["to"] for edge in edges if edge["from"] == node_id]

# Gibt die Beschreibung eines Knotens anhand seiner ID zurück
def find_node_desc(node_id, nodes):
    for node in nodes:
        if node["id"] == node_id:
            return node["description"]
    return None

# Zeigt ein Auswahlfenster mit Dropdown zur Knotenauswahl
def ask_id_with_dropdown(root, title, prompt, options):
    """
    options: Liste von (id, beschreibung) tuples, z.B. [(1, "C6"), (2, "C3")]
    Gibt die ausgewählte id als int zurück oder None, wenn abgebrochen.
    """
    selected_id = None

    # OK-Button gedrückt: Auswahl speichern und Fenster schließen
    def on_ok():
        nonlocal selected_id
        sel = combo.get()
        if sel == "":
            messagebox.showerror("Fehler", "Bitte eine Auswahl treffen.")
            return
        try:
            selected_id = int(sel.split(":")[0])  # ID extrahieren
            window.destroy()
        except Exception:
            messagebox.showerror("Fehler", "Ungültige Auswahl.")

    # Abbrechen gedrückt: Keine Auswahl
    def on_cancel():
        nonlocal selected_id
        selected_id = None
        window.destroy()

    # Neues Fenster (modal)
    window = tk.Toplevel(root)
    window.title(title)
    window.grab_set()
    window.geometry("340x160")

    # Beschriftung
    label = tk.Label(window, text=prompt)
    label.pack(pady=10)

    # Dropdown-Menü füllen
    combo_values = [f"{id_}: {desc}" for id_, desc in options]
    combo = ttk.Combobox(window, values=combo_values, state="readonly")
    combo.pack(pady=5)
    if combo_values:
        combo.current(0)

    # Buttons
    button_frame = tk.Frame(window)
    button_frame.pack(pady=10)

    ok_button = tk.Button(button_frame, text="OK", command=on_ok)
    ok_button.pack(side="left", padx=5)
    cancel_button = tk.Button(button_frame, text="Abbrechen", command=on_cancel)
    cancel_button.pack(side="left", padx=5)

    root.wait_window(window)  # Warte, bis Fenster geschlossen wird
    return selected_id

# Navigiert interaktiv durch den erzeugten Gruppengraphen
def navigate_graph(graph, root):
    nodes = graph["nodes"]
    edges = graph["edges"]

    # Liste aller Knoten anzeigen
    node_list_str = "\n".join(f"ID {node['id']}: {node['description']}" for node in nodes)
    messagebox.showinfo("Knoten im Graphen", node_list_str)

    options = [(node["id"], node["description"]) for node in nodes]

    # Startknoten auswählen
    start_id = ask_id_with_dropdown(root, "Startposition wählen", 
                                   "Wähle die Startposition aus:", options)
    if start_id is None:
        messagebox.showinfo("Abbruch", "Navigation abgebrochen.")
        return

    current_id = start_id

    while True:
        desc = find_node_desc(current_id, nodes)
        children = find_children(current_id, edges)

        info_msg = f"Du bist bei Position {current_id}: {desc}\n\n"
        if not children:
            messagebox.showinfo("Ende", info_msg + "Diese Position ist final. Spiel beendet.")
            break

        # Kinderknoten als Optionen anzeigen
        children_options = [(c, find_node_desc(c, nodes)) for c in children]

        next_id = ask_id_with_dropdown(root, "Nächste Option wählen",
                                       f"{info_msg}Wähle eine Option oder Abbrechen zum Beenden:",
                                       children_options)
        if next_id is None:
            messagebox.showinfo("Beenden", "Navigation beendet.")
            return
        current_id = next_id  # Zum nächsten Knoten springen

# Hauptfunktion – Einstiegspunkt des Programms
def main():
    root = tk.Tk()
    root.withdraw()  # Hauptfenster ausblenden

    # Benutzereingabe: GAP-Gruppendefinition
    group_str = simpledialog.askstring(
        "Gruppe eingeben",
        "Gib die GAP-Gruppendefinition ein, z.B. DirectProduct(CyclicGroup(2), CyclicGroup(3))"
    )
    if not group_str:
        print("Keine Gruppe eingegeben. Programm beendet.")
        return

    print("Starte GAP und generiere JSON...")
    success = run_gap_and_generate_json(group_str)
    if not success:
        print("GAP-Ausführung fehlgeschlagen.")
        return

    # JSON-Datei laden
    base_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(base_dir, "output", "group_graph.json")

    print("Lade Graph-Daten...")
    graph = load_graph_json(json_path)

    print("Beginne Navigation durch den Graphen.")
    navigate_graph(graph, root)

# Ausführung beim Start des Skripts
if __name__ == "__main__":
    main()
