#!/data/data/com.termux/files/usr/bin/bash
# -*- coding: utf-8 -*-
# ============================================================
# BUGREPORT-CTL - painel Termux (limpeza de bugreport, so o
# proprio aparelho, via Depuracao Wi-Fi)
# ============================================================
APP_NAME="PRECISION ANDROID | VYLARI SYSTEMS"
APP_VERSION="v1.0"

STATE_DIR="$HOME/.bugreport_ctl"
STATE_FILE="$STATE_DIR/state"
mkdir -p "$STATE_DIR"
touch "$STATE_FILE"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BOLD='\033[1m'
DIM='\033[2m'
ROXO='\033[1;35m'
RESET='\033[0m'

BUGREPORT_DIR="/data/user_de/0/com.android.shell/files/bugreports"

export HOSTNAME="educa.com"
export LOGNAME="escolasantamonica"

# --------------------------------------------------------
# LISTA DE PACOTES A REMOVER DO BUGREPORT
# Separe multiplos pacotes por espaco. Ex:
# PACKAGES="com.pkg1 com.pkg2 com.pkg3"
# --------------------------------------------------------
PACKAGES="com.termux termux"
# --------------------------------------------------------
# ARQUIVO A PROCURAR E LIMPAR (mesma logica dos pacotes)
# Coloque o nome exato do arquivo com extensao.
# Ex: ARQUIVO_NOVO="logcat.txt"  ou  ARQUIVO_NOVO="trace.zip"
# Deixe vazio para desativar a funcionalidade.
# --------------------------------------------------------
ARQUIVO_NOVO="dumpsys_package.txt"

load_state() {
    DEVICE_IP=""
    [ -f "$STATE_FILE" ] && . "$STATE_FILE"
}

save_state() {
    echo "DEVICE_IP=\"$DEVICE_IP\"" > "$STATE_FILE"
}

esta_conectado() {
    adb devices | awk -v ip="$1" '$1==ip && $2=="device"{found=1} END{exit !found}'
}

device_connected() {
    load_state
    [ -n "$DEVICE_IP" ] || return 1
    esta_conectado "$DEVICE_IP" || return 1
    return 0
}

# ------------------------------------------------------------
# Interface
# ------------------------------------------------------------
BOX_WIDTH=48

draw_line() {
    printf "${RED}+"
    printf '%*s' "$BOX_WIDTH" '' | tr ' ' '-'
    printf "+${RESET}\n"
}

draw_title() {
    local text="$1"
    local pad=$(( (BOX_WIDTH - ${#text}) / 2 ))
    printf "${RED}|${RESET}%*s${BOLD}${RED}%s${RESET}%*s${RED}|${RESET}\n" \
        "$pad" '' "$text" $((BOX_WIDTH - pad - ${#text})) ''
}

draw_header() {
    clear
    draw_line
    draw_title "$APP_NAME"
    draw_line
    printf "${DIM} %s${RESET}\n" "$APP_VERSION"
    echo ""

    load_state
    if device_connected; then
        printf " Status : ${GREEN}connected${RESET}\n"
    else
        printf " Status : ${RED}disconnected${RESET}\n"
    fi
    printf "${DIM} Aparelho: %s${RESET}\n" "${DEVICE_IP:-(nao pareado)}"
    echo ""
}

draw_menu() {
    echo " [1] Parear Dispositivo"
    echo " [2] Ativar Precision"
    echo " [3] Ativar Bypass"
    echo " [4] Apagar Bugreports"
    printf " [5] Sair"
    echo ""
}

menu_parear() {
    echo ""
    printf "${BOLD}== Parear/Conectar ==${RESET}\n"
    echo "Na tela 'Depuracao sem fio' do celular, toque em"
    echo "'Parear dispositivo com codigo de pareamento' (se ainda"
    echo "nao pareou antes) para pegar IP:porta + codigo."
    echo ""
    read -p "Ja pareou antes? Pular pareamento e so conectar? (s/N): " PULAR

    if [ "$PULAR" != "s" ] && [ "$PULAR" != "S" ]; then
        read -p "IP:porta de PAREAMENTO: " PAIR_ADDR
        read -p "Codigo de pareamento (6 digitos): " PAIR_CODE
        if ! adb pair "$PAIR_ADDR" "$PAIR_CODE"; then
            printf "${RED}Falha no pareamento. Confira IP/porta/codigo.${RESET}\n"
            read -p "Pressione ENTER para voltar..." _
            return
        fi
        printf "${GREEN}Pareamento aceito.${RESET}\n"
    fi

    read -p "IP:porta de CONEXAO (tela principal da Depuracao sem fio): " CONNECT_ADDR
    adb connect "$CONNECT_ADDR" >/dev/null 2>&1

    if esta_conectado "$CONNECT_ADDR"; then
        DEVICE_IP="$CONNECT_ADDR"
        save_state
        printf "${GREEN}Conectado e salvo: %s${RESET}\n" "$CONNECT_ADDR"
    else
        printf "${RED}Nao apareceu como 'device' no adb devices. Nao foi salvo.${RESET}\n"
    fi
    read -p "Pressione ENTER para voltar ao menu..." _
}

ativar_precision() {

clear

echo ""
echo "🔄 Ativando"
sleep 2

echo ""
echo "■■□□□□□□□□ 20%"
sleep 0.5

echo "■■■■□□□□□□ 40%"
sleep 0.5

echo "■■■■■■□□□□ 60%"
sleep 0.5

echo "■■■■■■■■□□ 80%"
sleep 0.5

echo "■■■■■■■■■■ 100%"
sleep 1

echo ""
echo "${GREEN}✅ ativado com sucesso!!"

echo ""
echo "🎮 Entre no jogo"
echo ""

sleep 3
}

menu_vigilancia() {
    if ! device_connected; then
        printf "${RED}Nao conectado. Use a Opcao 2 primeiro.${RESET}\n"
        read -p "Pressione ENTER para voltar..." _
        return
    fi
    load_state

    PARAR=0
    trap 'PARAR=1' INT

    # Evita que o Android suspenda o processo (Doze/otimizacao de bateria)
    # enquanto o Termux fica em segundo plano. Requer o app Termux:API
    # instalado + 'pkg install termux-api'.
    WAKE_LOCK_ATIVO=0
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock
        WAKE_LOCK_ATIVO=1
    else
        printf "${DIM}Aviso: termux-wake-lock nao encontrado.${RESET}\n"
        printf "${DIM}Instale o app Termux:API + 'pkg install termux-api' para a\n"
        printf "vigilancia continuar rodando com o Termux em segundo plano.${RESET}\n\n"
    fi

    echo ""
    printf "${BOLD}== Modo Vigilancia ativado ==${RESET}\n"
    printf "${DIM}Bugreport   : verifica novo ZIP a cada 5 s.${RESET}\n"
    if [ -n "$ARQUIVO_NOVO" ]; then
        printf "${DIM}Arquivo     : '%s' escaneado a cada 5 s.${RESET}\n" "$ARQUIVO_NOVO"
        printf "${DIM}Busca em    : /sdcard (exceto /sdcard/Android).${RESET}\n"
    fi
    printf "${DIM}Pressione Ctrl+C para parar e voltar ao menu.${RESET}\n\n"

    LOCAL_ZIP="$STATE_DIR/bugreport_work.zip"
    PY_TMP="$STATE_DIR/_clean.py"
    PY_FILE="$STATE_DIR/_clean_file.py"
    PY_VALID="$STATE_DIR/_valid.py"
    PENDENTE=""

    # Controle do scan de arquivo (1 scan a cada 1 ciclo de 5 s = 5 s)
    FILE_INTERVAL=1
    file_counter=0
    TRACK_FILE="$STATE_DIR/.file_track"
    touch "$TRACK_FILE"

    # ---- Validador de ZIP ----
    cat > "$PY_VALID" << 'PYEOF'
import sys, zipfile, os
path = sys.argv[1]
try:
    size = os.path.getsize(path)
    if size < 4096:
        print("invalid")
        sys.exit()
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
    print("ok" if len(names) > 10 else "invalid")
except:
    print("invalid")
PYEOF

    # ---- Limpador de bugreport (ZIP de sistema) ----
    cat > "$PY_TMP" << 'PYEOF'
import sys, zipfile, shutil, os

zip_path = sys.argv[1]
packages = sys.argv[2:]
tmp_path = zip_path + ".tmp"
total = 0

with zipfile.ZipFile(zip_path, "r") as zin:
    infos = zin.infolist()
    seen = set()
    with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as zout:
        for info in infos:
            if info.filename in seen:
                continue
            seen.add(info.filename)
            data = zin.read(info.filename)
            name = info.filename.lower()
            if name.endswith(".txt") or name.endswith(".log"):
                try:
                    text = data.decode("utf-8", errors="ignore")
                    lines = text.splitlines(keepends=True)
                    filtered = [l for l in lines if not any(p in l for p in packages)]
                    removed = len(lines) - len(filtered)
                    if removed:
                        total += removed
                        print(f"  -> {info.filename}: {removed} linha(s) removida(s)")
                    data = "".join(filtered).encode("utf-8")
                except Exception as e:
                    print(f"  -> aviso: {info.filename}: {e}")
            zout.writestr(info, data)

shutil.move(tmp_path, zip_path)
print(f"Total de linhas removidas: {total}")
PYEOF

    # ---- Limpador de arquivo avulso (texto direto ou ZIP) ----
    cat > "$PY_FILE" << 'PYEOF'
import sys, zipfile, shutil, os

path = sys.argv[1]
packages = sys.argv[2:]
total = 0
ext = os.path.splitext(path)[1].lower()

if ext == ".zip":
    tmp = path + ".tmp"
    with zipfile.ZipFile(path, "r") as zin:
        infos = zin.infolist()
        seen = set()
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
            for info in infos:
                if info.filename in seen:
                    continue
                seen.add(info.filename)
                data = zin.read(info.filename)
                name = info.filename.lower()
                if name.endswith(".txt") or name.endswith(".log"):
                    try:
                        text = data.decode("utf-8", errors="ignore")
                        lines = text.splitlines(keepends=True)
                        filtered = [l for l in lines if not any(p in l for p in packages)]
                        removed = len(lines) - len(filtered)
                        if removed:
                            total += removed
                            print(f"  -> {info.filename}: {removed} linha(s) removida(s)")
                        data = "".join(filtered).encode("utf-8")
                    except Exception as e:
                        print(f"  -> aviso: {info.filename}: {e}")
                zout.writestr(info, data)
    shutil.move(tmp, path)
else:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
        filtered = [l for l in lines if not any(p in l for p in packages)]
        removed = len(lines) - len(filtered)
        total += removed
        if removed:
            print(f"  -> {removed} linha(s) removida(s)")
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(filtered)
    except Exception as e:
        print(f"  -> erro: {e}")
        sys.exit(1)

print(f"Total de linhas removidas: {total}")
PYEOF

    # Captura lista inicial de ZIPs (para ignorar os que ja existem)
    SEEN=$(adb -s "$DEVICE_IP" shell "ls $BUGREPORT_DIR/*.zip 2>/dev/null" | tr -d '\r')

    while [ "$PARAR" = "0" ]; do
        sleep 5
        [ "$PARAR" = "1" ] && break

        # ---- Bugreport: processar ZIP pendente ----
        if [ -n "$PENDENTE" ]; then
            printf "\r${DIM}Baixando e validando bugreport...${RESET}                   "
            rm -f "$LOCAL_ZIP"
            adb -s "$DEVICE_IP" pull "$PENDENTE" "$LOCAL_ZIP" >/dev/null 2>&1
            VALIDO=$(python3 "$PY_VALID" "$LOCAL_ZIP" 2>/dev/null)

            if [ "$VALIDO" = "ok" ]; then
                printf "\n${GREEN}ZIP valido e completo! Limpando bugreport...${RESET}\n"
                python3 "$PY_TMP" "$LOCAL_ZIP" $PACKAGES
                adb -s "$DEVICE_IP" push "$LOCAL_ZIP" "$PENDENTE" >/dev/null 2>&1
                printf "${GREEN}Bugreport limpo com sucesso!${RESET}\n"
                SEEN=$(printf "%s\n%s" "$SEEN" "$PENDENTE")
                PENDENTE=""
            else
                printf "\r${DIM}Bugreport ainda sendo gerado, aguardando...${RESET}          "
            fi
            continue
        fi

        # ---- Bugreport: detectar novo ZIP ----
        ATUAL=$(adb -s "$DEVICE_IP" shell "ls $BUGREPORT_DIR/*.zip 2>/dev/null" | tr -d '\r')
        NOVO=""
        for ZIP in $ATUAL; do
            if ! echo "$SEEN" | grep -qF "$ZIP"; then
                NOVO="$ZIP"
                break
            fi
        done
        if [ -n "$NOVO" ]; then
            printf "\n${GREEN}Novo bugreport detectado:${RESET} %s\n" "$NOVO"
            PENDENTE="$NOVO"
            continue
        fi

# ---- Arquivo avulso: scan a cada 5 s ----
        if [ -n "$ARQUIVO_NOVO" ]; then
            file_counter=$((file_counter + 1))
            if [ "$file_counter" -ge "$FILE_INTERVAL" ]; then
                file_counter=0
                printf "\r${DIM}Escaneando '%s'...${RESET}                              " "$ARQUIVO_NOVO"

                # Busca em /sdcard, pulando /sdcard/Android (-prune real: nao desce
                # na pasta, entao nao gera erro de permissao nela). 2>/dev/null
                # descarta qualquer stderr, independente do idioma do aparelho.
                FOUND=$(adb -s "$DEVICE_IP" shell \
                    "find /sdcard -path '/sdcard/Android' -prune -o -name '$ARQUIVO_NOVO' -print 2>/dev/null" \
                    | tr -d '\r' | grep -v '^$')

                # Fallback: garante Download mesmo se a busca acima nao trouxer nada
                if [ -z "$FOUND" ]; then
                    FOUND=$(adb -s "$DEVICE_IP" shell \
                        "find /sdcard/Download -name '$ARQUIVO_NOVO' 2>/dev/null" \
                        | tr -d '\r' | grep -v '^$')
                fi

                printf '%s\n' "$FOUND" | while IFS= read -r FPATH; do
                    [ -z "$FPATH" ] && continue

                    MTIME=$(adb -s "$DEVICE_IP" shell \
                        "stat -c %Y '$FPATH' 2>/dev/null" | tr -d '\r')
                    ENTRY="${FPATH}|${MTIME}"

                    # Pula se ja foi limpo com esse mesmo mtime
                    if grep -qF "$ENTRY" "$TRACK_FILE" 2>/dev/null; then
                        continue
                    fi

                    printf "\n${GREEN}Arquivo detectado/modificado:${RESET} %s\n" "$FPATH"
                    EXT="${ARQUIVO_NOVO##*.}"
                    LOCAL_WORK="$STATE_DIR/arquivo_work.$EXT"
                    rm -f "$LOCAL_WORK"

                    if adb -s "$DEVICE_IP" pull "$FPATH" "$LOCAL_WORK" >/dev/null 2>&1; then
                        python3 "$PY_FILE" "$LOCAL_WORK" $PACKAGES
                        if adb -s "$DEVICE_IP" push "$LOCAL_WORK" "$FPATH" >/dev/null 2>&1; then
                            printf "${GREEN}  Arquivo limpo com sucesso!${RESET}\n"
                            NEW_MTIME=$(adb -s "$DEVICE_IP" shell \
                                "stat -c %Y '$FPATH' 2>/dev/null" | tr -d '\r')
                            grep -v "^${FPATH}|" "$TRACK_FILE" > "${TRACK_FILE}.tmp" \
                                && mv "${TRACK_FILE}.tmp" "$TRACK_FILE"
                            echo "${FPATH}|${NEW_MTIME}" >> "$TRACK_FILE"
                        fi
                    else
                        printf "${RED}  Falha ao baixar. Tentara no proximo ciclo.${RESET}\n"
                    fi
                done
            fi
        fi

        printf "\r${DIM}Monitorando... (Ctrl+C para parar)${RESET}          "
    done

    trap - INT
    [ "$WAKE_LOCK_ATIVO" = "1" ] && termux-wake-unlock
    printf "\n${BOLD}Modo Vigilancia encerrado. Voltando ao menu...${RESET}\n"
    sleep 1
}


# Opcao 4: Apagar todos os bugreports (liberar espaco)
# ------------------------------------------------------------
menu_apagar_tudo() {
    if ! device_connected; then
        printf "${RED}Nao conectado. Use a Opcao 1 primeiro.${RESET}\n"
        read -p "Pressione ENTER para voltar..." _
        return
    fi
    load_state

    echo ""
    printf "${BOLD}== Apagar todos os bugreports ==${RESET}\n"

    LISTA=$(adb -s "$DEVICE_IP" shell "ls $BUGREPORT_DIR/ 2>/dev/null" | tr -d '\r')

    if [ -z "$LISTA" ]; then
        printf "${DIM}Nenhum arquivo encontrado na pasta de bugreports.${RESET}\n"
        read -p "Pressione ENTER para voltar..." _
        return
    fi

    # Conta e mostra o que sera apagado
    TOTAL=$(echo "$LISTA" | wc -l | tr -d ' ')
    printf "Arquivos encontrados (${RED}%s${RESET}):\n" "$TOTAL"
    for F in $LISTA; do
        printf "  ${DIM}%s${RESET}\n" "$F"
    done

    echo ""
    printf "${RED}${BOLD}ATENCAO: essa acao nao pode ser desfeita.${RESET}\n"
    read -p "Confirma apagar tudo? (s/N): " CONF

    if [ "$CONF" != "s" ] && [ "$CONF" != "S" ]; then
        echo "Cancelado."
        read -p "Pressione ENTER para voltar..." _
        return
    fi

    adb -s "$DEVICE_IP" shell "rm -rf $BUGREPORT_DIR/* 2>/dev/null"
    printf "${GREEN}Todos os bugreports apagados. Espaco liberado.${RESET}\n"
    read -p "Pressione ENTER para voltar ao menu..." _
}

# ------------------------------------------------------------
# Modo nao interativo: roda so a vigilancia, sem abrir o menu.
# Serve para deixar rodando desacoplado da sessao do terminal:
#
#   nohup bash bugreport.sh --vigilancia > "$HOME/.bugreport_ctl/vigilancia.log" 2>&1 &
#   disown
#
# Isso faz o processo continuar mesmo se voce fechar a aba/sessao
# do Termux. Combine com termux-wake-lock (ver acima) e com a
# otimizacao de bateria desativada para o Termux nas configuracoes
# do Android, ou o proprio sistema pode suspender o processo.
#
# Para parar depois: pkill -f "bugreport.sh --vigilancia"
# ------------------------------------------------------------
if [ "$1" = "--vigilancia" ]; then
    load_state
    if ! device_connected; then
        echo "Nao conectado. Rode 'bash bugreport.sh' (sem argumento) e use a Opcao 1 primeiro."
        exit 1
    fi
    menu_vigilancia
    exit 0
fi

# =========================
# KEY SYSTEM
# =========================
KEY_CORRETA="key-vylaricheats"
ARQ_KEY="$HOME/.sistema_key"

verificar_key() {

    if [ -f "$ARQ_KEY" ]; then
        SALVA=$(cat "$ARQ_KEY")

        if [ "$SALVA" = "$KEY_CORRETA" ]; then
            echo "${GREEN}" "✔ Acesso liberado"
            sleep 1
            return
        fi
    fi

    clear

echo -e "${ROXO}"
echo " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "     Vylari Systems | KeyHub" 
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo  -e "${ROXO}"
    tentativas=3

    while [ $tentativas -gt 0 ]
    do
        echo "${BOLD}" "Digite a KEY: "
        read key

        if [ "$key" = "$KEY_CORRETA" ]; then
            echo "$KEY_CORRETA" > "$ARQ_KEY"
            echo ""
            echo "${VERDE}" "✔ KEY correta!" "${RESET}"
            sleep 1
            return
        else
            tentativas=$((tentativas - 1))
            echo "${VERMELHO}" "❌ KEY inválida!" "${RESET}"
            echo "Tentativas restantes: $tentativas"
            sleep 1
        fi
    done

    echo ""
    echo "⛔ SISTEMA BLOQUEADO"
    exit
}

# CHAMA A VERIFICAÇÃO
verificar_key


while true; do
    draw_header
    draw_menu
    read -p "> " ESCOLHA

    case "$ESCOLHA" in
        1) menu_parear ;;
        2) ativar_otimizaca ;;
        3) menu_vigilancia ;;
        4) menu_apagar_tudo ;;
        5) echo "Saindo."; exit 0 ;;
        *) echo "Opcao invalida." ; sleep 1 ;;
    esac
done
