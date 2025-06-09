import subprocess
import os
import re
import tkinter as tk
from tkinter import simpledialog, scrolledtext, messagebox

# Wandelt einen Windows-Pfad in das entsprechende WSL-Pendant um
def windows_to_wsl_path(path):
    drive, rest = os.path.splitdrive(path)
    drive_letter = drive.rstrip(':').lower()
    rest = rest.replace('\\', '/')
    return f"/mnt/{drive_letter}{rest}"

# Parsen der Ausgabe aus der Textdatei, die GAP erzeugt hat
def parse_output(output_text):
    abelsch = []
    nicht_abelsch = []
    total_ab = total_nab = 0
    current_section = None

    for line in output_text.splitlines():
        line = line.strip()

        # Abschnittserkennung für abelsche Gruppen
        if line.startswith("=== Abelsche Gruppen"):
            current_section = "abelsch"
            continue
        # Abschnittserkennung für nicht-abelsche Gruppen
        elif line.startswith("=== Nicht-abelsche Gruppen"):
            current_section = "nicht_abelsch"
            continue
        # Ende der Gruppenliste
        elif line.startswith("Insgesamt wurden untersucht:"):
            current_section = None
            continue

        # Extrahiere die Gesamtanzahl der untersuchten Gruppen
        m = None
        if line.startswith("-"):
            m_ab = re.match(r"-\s*(\d+)\s+abelsche Gruppen", line, re.IGNORECASE)
            m_nab = re.match(r"-\s*(\d+)\s+nicht-abelsche Gruppen", line, re.IGNORECASE)
            if m_ab:
                total_ab = int(m_ab.group(1))
            elif m_nab:
                total_nab = int(m_nab.group(1))
            continue

        # Leere Zeilen oder Ergebniszeilen überspringen
        if line == "" or line.startswith("Ergebnis"):
            continue

        # Gruppenzuweisung basierend auf aktuellem Abschnitt
        if current_section == "abelsch":
            abelsch.append(line)
        elif current_section == "nicht_abelsch":
            nicht_abelsch.append(line)

    # Zähle Gruppen mit mex = 0 in beiden Kategorien
    count_ab = len(abelsch)
    count_nab = len(nicht_abelsch)

    return (abelsch, nicht_abelsch, count_ab, count_nab, total_ab, total_nab)

# Führt das GAP-Skript aus und liest die Ergebnisdatei aus
def run_gap_mexnull(z):
    base_dir = os.path.dirname(os.path.abspath(__file__))
    gap_script_path = os.path.join(base_dir, "mexnull.g")
    output_txt_path = os.path.join(base_dir, "output.txt")
    temp_input_path = os.path.join(base_dir, "temp_input.g")

    # Wandle Pfade in das WSL-Format um
    gap_script_wsl = windows_to_wsl_path(gap_script_path)
    output_txt_wsl = windows_to_wsl_path(output_txt_path)
    temp_input_wsl = windows_to_wsl_path(temp_input_path)

    # Erzeuge temporären GAP-Code, der das Skript lädt und ausführt
    gap_code = f'''
Read("{gap_script_wsl}");
FindeGruppenMitMexNull({z}, "{output_txt_wsl}");
QUIT;
'''
    # Speichere temporären GAP-Code in Datei
    with open(temp_input_path, "w", encoding="utf-8") as f:
        f.write(gap_code)

    try:
        # Führe GAP über WSL aus, mit Timeout
        subprocess.run(["wsl", "gap", "-q", "-b", temp_input_wsl], check=True, timeout=900)

        # Lese die Ausgabedatei aus
        with open(output_txt_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Verarbeite die Ausgabedaten
        abelsch, nicht_abelsch, count_ab, count_nab, total_ab, total_nab = parse_output(content)
        return (abelsch, nicht_abelsch, count_ab, count_nab, total_ab, total_nab), None

    # Fehlerbehandlung: GAP hängt, stürzt ab oder Datei fehlt
    except subprocess.TimeoutExpired:
        return None, "Fehler: GAP-Aufruf hat zu lange gedauert (Timeout)."
    except subprocess.CalledProcessError as e:
        return None, f"Fehler beim GAP-Aufruf:\n{e}"
    except FileNotFoundError:
        return None, "Fehler: Die Ausgabedatei wurde nicht gefunden."

# Hauptfunktion für die GUI-Interaktion
def main():
    root = tk.Tk()
    root.withdraw()

    # Benutzer wird nach der maximalen Gruppenordnung gefragt
    z = simpledialog.askinteger("Eingabe", "Gib die maximale Gruppengröße (z) ein:", minvalue=1)
    if z is None:
        return

    # Starte Berechnung
    result, error = run_gap_mexnull(z)

    if error:
        messagebox.showerror("Fehler", error)
        return

    abelsch, nicht_abelsch, count_ab, count_nab, total_ab, total_nab = result

    # Neues Fenster zur Darstellung der Ergebnisse
    out_win = tk.Toplevel()
    out_win.title("Gruppen mit mex = 0 – Abelsch / Nicht abelsch")

    # Übersicht über die Anzahl oben anzeigen
    summary = (
        f"Anzahl Gruppen mit mex = 0:\n"
        f"  Abelsch: {count_ab}\n"
        f"  Nicht-abelsch: {count_nab}\n\n"
        f"Insgesamt untersuchte Gruppen:\n"
        f"  Abelsch: {total_ab}\n"
        f"  Nicht-abelsch: {total_nab}"
    )
    lbl_summary = tk.Label(out_win, text=summary, justify="left")
    lbl_summary.pack(pady=10)

    # Anzeige der abelschen Gruppen
    lbl1 = tk.Label(out_win, text="Abelsche Gruppen mit mex = 0:")
    lbl1.pack()
    txt_abel = scrolledtext.ScrolledText(out_win, width=50, height=20)
    txt_abel.pack(fill="both", expand=True)
    txt_abel.insert("end", "\n".join(abelsch))
    txt_abel.configure(state="disabled")

    # Anzeige der nicht-abelschen Gruppen
    lbl2 = tk.Label(out_win, text="Nicht-abelsche Gruppen mit mex = 0:")
    lbl2.pack()
    txt_nicht_abel = scrolledtext.ScrolledText(out_win, width=50, height=20)
    txt_nicht_abel.pack(fill="both", expand=True)
    txt_nicht_abel.insert("end", "\n".join(nicht_abelsch))
    txt_nicht_abel.configure(state="disabled")

    # Starte GUI
    out_win.mainloop()

# Einstiegspunkt des Skripts
if __name__ == "__main__":
    main()
