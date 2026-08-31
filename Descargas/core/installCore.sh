#!/data/data/com.termux/files/usr/bin/bash

echo -e "\033[32m[*] Instalando el intérprete B++ en Termux...\033[0m"

# Asegurar que el directorio bin exista
mkdir -p $PREFIX/bin

# Crear el archivo Bpp con el código del intérprete
cat << 'EOF' > $PREFIX/bin/Bpp
#!/data/data/com.termux/files/usr/bin/env python3
import sys
import os
import time
import random
import subprocess
import re

if len(sys.argv) < 2:
    print("\033[41;37m [!] Uso: Bpp 'archivo.bpp' \033[0m")
    sys.exit(1)

archivo = sys.argv[1]
if not os.path.exists(archivo):
    print(f"\033[41;37m [!] El archivo '{archivo}' no existe. \033[0m")
    sys.exit(1)

LIBS_DIR = "BppProjects/LIBS"
os.makedirs(LIBS_DIR, exist_ok=True)

memoria = {}
libs_cargadas = []
bloques_init = {}

with open(archivo, "r", encoding="utf-8") as f:
    lineas = [linea.strip() for linea in f.readlines()]

# Mapear bloques Init
for i, linea in enumerate(lineas):
    if linea.lower().startswith("init ") and linea.endswith("{"):
        nombre = linea[5:-1].strip()
        bloques_init[nombre] = i

def inyectar_vars(texto):
    for k, v in memoria.items():
        texto = texto.replace(f"${k}$", str(v))
        texto = texto.replace(k, str(v))
    return texto

def ejecutar_interprete():
    total = len(lineas)
    call_stack = []
    pila_repeticiones = []

    start_idx = 0
    for idx, l in enumerate(lineas):
        if l.startswith("Run="):
            target = l.split("=")[1].strip('"')
            if target in bloques_init:
                start_idx = bloques_init[target]
                break
    i = start_idx + 1

    while i < total:
        l = lineas[i]

        if not l or l.startswith("//") or l in ["{", "}", "[", "]"]:
            if l == "}" and call_stack:
                i = call_stack.pop()
            i += 1
            continue

        if l.lower().startswith("init ") and l.endswith("{"):
            nivel = 1
            while i + 1 < total and nivel > 0:
                i += 1
                sig = lineas[i]
                if sig == "{": nivel += 1
                elif sig == "}": nivel -= 1
            i += 1
            continue

        if l.startswith("Run="):
            target = l.split("=")[1].strip('"')
            if target in bloques_init:
                call_stack.append(i)
                i = bloques_init[target] + 1
                continue
            else:
                print(f"\033[41;37m [!] Error: Bloque '{target}' no encontrado \033[0m")
                break

        if l == "limpiar":
            os.system("clear" if os.name == "posix" else "cls")
            i += 1
            continue

        if l.startswith("esperar("):
            try:
                secs = float(l[8:-1])
                time.sleep(secs)
            except:
                pass
            i += 1
            continue

        if l.startswith("text("):
            msg = l[5:-1].strip()
            if msg.startswith('"') and msg.endswith('"'):
                msg = msg[1:-1]
            else:
                msg = memoria.get(msg, msg)
            print(inyectar_vars(str(msg)))
            i += 1
            continue

        if l.startswith("val "):
            rest = l[4:]
            if "=" in rest:
                k, v = rest.split("=", 1)
                k = k.strip()
                v = v.strip().strip('"')
                v = memoria.get(v, v)
                memoria[k] = v
            i += 1
            continue

        if l.startswith("preguntar("):
            match = re.match(r'preguntar\("(.*?)"\)->(.*)', l)
            if match:
                msg = match.group(1)
                var_dest = match.group(2).strip()
                val = input(f"{msg} ")
                memoria[var_dest] = val
            i += 1
            continue

        if l.startswith("azar("):
            match = re.match(r'azar\((.*?)\)->(.*)', l)
            if match:
                max_str = match.group(1).strip()
                var_dest = match.group(2).strip()
                max_val = int(memoria.get(max_str, max_str))
                if max_val > 0:
                    memoria[var_dest] = str(random.randint(1, max_val))
            i += 1
            continue

        if l.startswith("#import <"):
            lib_name = l.split("<")[1].split(">")[0].strip()
            if lib_name not in libs_cargadas:
                libs_cargadas.append(lib_name)
            i += 1
            continue

        if l.startswith("si "):
            cond_part = l[3:]
            if "[" in cond_part:
                cond = cond_part.split("[")[0].strip()
                cumple = False
                for op in ["==", "!=", ">=", "<=", ">", "<"]:
                    if op in cond:
                        i_str, d_str = cond.split(op, 1)
                        vr = str(memoria.get(i_str.strip(), i_str.strip()))
                        vf = str(memoria.get(d_str.strip().strip('"'), d_str.strip().strip('"')))
                        if op == "==": cumple = (vr == vf)
                        elif op == "!=": cumple = (vr != vf)
                        elif op == ">=": cumple = (float(vr) >= float(vf)) if vr.replace('.','',1).isdigit() and vf.replace('.','',1).isdigit() else False
                        elif op == "<=": cumple = (float(vr) <= float(vf)) if vr.replace('.','',1).isdigit() and vf.replace('.','',1).isdigit() else False
                        elif op == ">": cumple = (float(vr) > float(vf)) if vr.replace('.','',1).isdigit() and vf.replace('.','',1).isdigit() else False
                        elif op == "<": cumple = (float(vr) < float(vf)) if vr.replace('.','',1).isdigit() and vf.replace('.','',1).isdigit() else False
                        break

                if not cumple:
                    nivel = 1
                    while i + 1 < total and nivel > 0:
                        i += 1
                        sig = lineas[i]
                        if sig.endswith("[") or sig == "[": nivel += 1
                        elif sig == "]":
                            nivel -= 1
                            if nivel == 0:
                                if i + 1 < total and lineas[i+1].startswith("si_no"):
                                    i += 1
                                break
                i += 1
                continue

        if l.startswith("si_no"):
            nivel = 1
            while i + 1 < total and nivel > 0:
                i += 1
                sig = lineas[i]
                if sig.endswith("[") or sig == "[": nivel += 1
                elif sig == "]": nivel -= 1
            i += 1
            continue

        if l.startswith("Repetir "):
            iters_raw = l.split()[1]
            iters = int(memoria.get(iters_raw, iters_raw))
            nivel = 0
            fb_idx = -1
            for p in range(i + 1, total):
                xt = lineas[p]
                if xt.startswith("Repetir"): nivel += 1
                elif xt == "FB":
                    if nivel == 0:
                        fb_idx = p
                        break
                    else:
                        nivel -= 1
            if fb_idx != -1 and iters > 0:
                pila_repeticiones.append((i + 1, fb_idx, iters))
            else:
                if fb_idx != -1: i = fb_idx
            i += 1
            continue

        if l == "FB":
            if pila_repeticiones:
                inicio, fin, iters = pila_repeticiones[-1]
                iters -= 1
                if iters > 0:
                    pila_repeticiones[-1] = (inicio, fin, iters)
                    i = inicio
                    continue
                else:
                    pila_repeticiones.pop()
            i += 1
            continue

        if "->" in l and "(" in l:
            match = re.match(r'(.*?)\((.*?)\)->(.*)', l)
            if match:
                lib_name = match.group(1).strip()
                arg = match.group(2).strip()
                var_dest = match.group(3).strip()

                if lib_name in libs_cargadas:
                    arg = memoria.get(arg, arg)
                    ruta_lib = os.path.join(LIBS_DIR, f"{lib_name}.py")
                    if os.path.exists(ruta_lib):
                        try:
                            res = subprocess.check_output(["python", ruta_lib, str(arg)], text=True).strip()
                            memoria[var_dest] = res
                        except Exception as e:
                            print(f"[!] Error en librería {lib_name}: {e}")
            i += 1
            continue

        i += 1

ejecutar_interprete()
EOF

# Dar permisos de ejecución
chmod +x $PREFIX/bin/Bpp

echo -e "\033[32m[✔] ¡Instalación completada con éxito! Ya puedes usar: Bpp archivo.bpp\033[0m"
