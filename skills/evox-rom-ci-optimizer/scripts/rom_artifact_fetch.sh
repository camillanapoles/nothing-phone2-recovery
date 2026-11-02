#!/usr/bin/env bash
# rom_artifact_fetch.sh — coleta DETERMINÍSTICA dos dois zips da MESMA build (Vanilla e GApps).
#
# Regras (o "objeto passageiro" é pinado, não escolhido de novo a cada run):
#   • nome do arquivo, URL e build vêm de references/rom-artifacts.json — nunca "a mais nova"
#   • primeiro fetch grava o pin (sha256 + bytes) em <dest>/rom-artifacts.lock.json
#   • fetch seguinte que divergir → exit 4 (drift). Nunca sobrescreve, nunca "corrige" sozinho
#   • download atômico (.part + mv) e retomável (curl -C -), idempotente
#   • grava um env fixo (caminhos absolutos) para o resto da sessão não errar de caminho
#
# Uso:
#   rom_artifact_fetch.sh --variant vanilla|gapps|both [--dest DIR] [--lock FILE]
#                         [--env-out FILE] [--verify] [--json]
#   --verify  não usa rede: só confere arquivos existentes contra o pin
#
# Destino padrão: ${EVOX_CACHE:-$HOME/.cache/evox}/artifacts (+ pins em .../evox.env),
# FORA do workspace — que é limpo a cada sessão e levaria o zip de 2,4 GB e os sha256
# pinados embora. Sobrescreva com --dest/--env-out ou EVOX_ARTIFACTS_DIR/EVOX_ENV_FILE.
# Exit: 0 ok · 2 uso · 3 rede/egress · 4 drift/arquivo divergente · 5 ferramenta ausente
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="${ROM_MANIFEST:-$HERE/../references/rom-artifacts.json}"
CURL_BIN="${ROM_FETCH_CURL:-curl}"
CACHE="${EVOX_CACHE:-$HOME/.cache/evox}"
VARIANT=""; DEST="${EVOX_ARTIFACTS_DIR:-$CACHE/artifacts}"
LOCK=""; ENVOUT="${EVOX_ENV_FILE:-$CACHE/evox.env}"; VERIFY=0; JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --variant) VARIANT="${2:-}"; shift 2 ;;
    --dest) DEST="${2:-}"; shift 2 ;;
    --lock) LOCK="${2:-}"; shift 2 ;;
    --env-out) ENVOUT="${2:-}"; shift 2 ;;
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --verify) VERIFY=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "[ERRO] argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

case "$VARIANT" in vanilla|gapps|both) ;; *) echo "[ERRO] --variant vanilla|gapps|both" >&2; exit 2 ;; esac
[ -f "$MANIFEST" ] || { echo "[ERRO] manifesto ausente: $MANIFEST" >&2; exit 2; }
command -v python3 >/dev/null || { echo "[ERRO] python3 ausente" >&2; exit 5; }
command -v sha256sum >/dev/null || { echo "[ERRO] sha256sum ausente" >&2; exit 5; }
if [ "$VERIFY" -eq 0 ]; then
  command -v "$CURL_BIN" >/dev/null || { echo "[ERRO] curl ausente (instale curl ou aponte ROM_FETCH_CURL)" >&2; exit 5; }
fi

mkdir -p "$DEST" "$(dirname "$LOCK")" "$(dirname "$ENVOUT")"
[ -n "$LOCK" ] || LOCK="$DEST/rom-artifacts.lock.json"

# lista "id|filename|url|sha256" a partir do manifesto
read -r -d '' PY_LIST <<'PY'
import json,sys
m=json.load(open(sys.argv[1],encoding="utf-8"))
want=sys.argv[2]
for v in m["variants"]:
    if want in ("both", v["id"]):
        print("|".join([v["id"], v["filename"], v["url"], v.get("sha256") or ""]))
PY
mapfile -t ENTRIES < <(python3 -c "$PY_LIST" "$MANIFEST" "$VARIANT")
[ "${#ENTRIES[@]}" -gt 0 ] || { echo "[ERRO] variante nao encontrada no manifesto" >&2; exit 2; }

pin_get(){ # pin_get <id> <field>
  [ -f "$LOCK" ] || return 1
  python3 - "$LOCK" "$1" "$2" <<'PY'
import json,sys
try: d=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: sys.exit(1)
v=(d.get("pins") or {}).get(sys.argv[2]) or {}
val=v.get(sys.argv[3])
if val in (None,""): sys.exit(1)
print(val)
PY
}

pin_put(){ python3 - "$LOCK" "$1" "$2" "$3" "$4" <<'PY'
import json,sys,os,datetime
lock,vid,sha,size,src=sys.argv[1:6]
d={"schema":"evox-rom-pins/1","pins":{}}
if os.path.isfile(lock):
    try: d=json.load(open(lock,encoding="utf-8"))
    except Exception: pass
d.setdefault("pins",{}).setdefault(vid,{})
p=d["pins"][vid]
if not p.get("sha256"):
    p.update({"sha256":sha,"bytes":int(size),"source_url":src,
              "pinned_at":datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")})
json.dump(d,open(lock,"w",encoding="utf-8"),indent=2,ensure_ascii=False,sort_keys=True)
PY
}

RC=0; RESULTS=()
for e in "${ENTRIES[@]}"; do
  IFS='|' read -r id fname url msha <<<"$e"
  f="$DEST/$fname"
  have=""; [ -f "$f" ] && have="$(sha256sum "$f" | cut -d' ' -f1)"
  pin="$(pin_get "$id" sha256 || true)"

  if [ -n "$have" ] && [ -n "$pin" ] && [ "$have" != "$pin" ]; then
    echo "[DRIFT] $id: arquivo local não bate com o pin ($have ≠ $pin)" >&2
    RESULTS+=("{\"id\":\"$id\",\"status\":\"drift\",\"sha256\":\"$have\"}"); RC=4; continue
  fi
  if [ -n "$msha" ] && [ -n "$have" ] && [ "$have" != "$msha" ]; then
    echo "[DRIFT] $id: arquivo local não bate com o manifesto" >&2
    RESULTS+=("{\"id\":\"$id\",\"status\":\"drift\",\"sha256\":\"$have\"}"); RC=4; continue
  fi

  if [ -n "$have" ]; then
    RESULTS+=("{\"id\":\"$id\",\"status\":\"cached\",\"path\":\"$f\",\"sha256\":\"$have\"}")
    continue
  fi

  if [ "$VERIFY" -eq 1 ]; then
    echo "[FALTA] $id: $f" >&2
    RESULTS+=("{\"id\":\"$id\",\"status\":\"missing\"}"); RC=4; continue
  fi

  part="$f.part"
  echo "[fetch] $id → $fname" >&2
  if ! "$CURL_BIN" -fL --retry 3 --retry-delay 2 -C - -o "$part" "$url" >/dev/null 2>&1; then
    rm -f "$part"
    echo "[REDE] $id: falha no download (sem egress? URL mudou?) — nada foi gravado" >&2
    RESULTS+=("{\"id\":\"$id\",\"status\":\"network_error\"}"); RC=3; continue
  fi
  got="$(sha256sum "$part" | cut -d' ' -f1)"; size="$(stat -c%s "$part")"
  if [ -n "$msha" ] && [ "$got" != "$msha" ]; then
    mv -f "$part" "$f.mismatch"
    echo "[DRIFT] $id: sha256 baixado ≠ manifesto (guardado em .mismatch)" >&2
    RESULTS+=("{\"id\":\"$id\",\"status\":\"drift\",\"sha256\":\"$got\"}"); RC=4; continue
  fi
  if [ -n "$pin" ] && [ "$got" != "$pin" ]; then
    mv -f "$part" "$f.mismatch"
    echo "[DRIFT] $id: sha256 baixado ≠ pin (conteúdo do CDN mudou)" >&2
    RESULTS+=("{\"id\":\"$id\",\"status\":\"drift\",\"sha256\":\"$got\"}"); RC=4; continue
  fi
  mv -f "$part" "$f"
  [ -n "$pin" ] || pin_put "$id" "$got" "$size" "$url"
  RESULTS+=("{\"id\":\"$id\",\"status\":\"fetched\",\"path\":\"$f\",\"sha256\":\"$got\",\"bytes\":$size}")
done

[ "$VERIFY" -eq 1 ] && { [ "$JSON" -eq 1 ] && printf '{"schema":"evox-rom-fetch/1","variant":"%s","verify":true,"exit_code":%d,"results":[%s]}\n' "$VARIANT" "$RC" "$(IFS=,; echo "${RESULTS[*]}")"; exit "$RC"; }

# env fixo: caminhos absolutos de TODAS as variantes (mesmo que só uma tenha sido baixada)
V="$DEST/$(python3 -c 'import json,sys;print([v["filename"] for v in json.load(open(sys.argv[1]))["variants"] if v["id"]=="vanilla"][0])' "$MANIFEST")"
G="$DEST/$(python3 -c 'import json,sys;print([v["filename"] for v in json.load(open(sys.argv[1]))["variants"] if v["id"]=="gapps"][0])' "$MANIFEST")"
VS="$(pin_get vanilla sha256 || true)"; GS="$(pin_get gapps sha256 || true)"
tmp="$ENVOUT.tmp"
{
  echo "# gerado por rom_artifact_fetch.sh — NÃO editar à mão"
  echo "# build 2026-09-15 · device Pong · Android 16 · versão 11.11"
  echo "export EVOX_ARTIFACTS_DIR=\"$DEST\""
  echo "export EVOX_VARIANT=\"$([ "$VARIANT" = both ] && echo undecided || echo "$VARIANT")\""
  echo "export EVOX_ZIP_VANILLA=\"$V\""
  echo "export EVOX_ZIP_GAPPS=\"$G\""
  [ -n "$VS" ] && echo "export EVOX_SHA256_VANILLA=\"$VS\""
  [ -n "$GS" ] && echo "export EVOX_SHA256_GAPPS=\"$GS\""
  echo "export EVOX_ZIP=\"\${EVOX_ZIP_$([ "$VARIANT" = gapps ] && echo GAPPS || echo VANILLA)}\""
} > "$tmp" && mv -f "$tmp" "$ENVOUT"

if [ "$JSON" -eq 1 ]; then
  printf '{"schema":"evox-rom-fetch/1","variant":"%s","dest":"%s","lock":"%s","env":"%s","exit_code":%d,"results":[%s]}\n' \
    "$VARIANT" "$DEST" "$LOCK" "$ENVOUT" "$RC" "$(IFS=,; echo "${RESULTS[*]}")"
else
  for r in "${RESULTS[@]}"; do
    printf '  %-14s %s\n' "$(echo "$r" | python3 -c 'import json,sys;print(json.load(sys.stdin)["status"])' 2>/dev/null || echo '?')" "$r"
  done
  echo "[rom] variant=$VARIANT dest=$DEST lock=$LOCK env=$ENVOUT → exit $RC"
fi
exit "$RC"
