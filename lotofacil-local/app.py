#!/usr/bin/env python3
import itertools
import json
import math
import os
import random
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional
from xml.sax.saxutils import escape

BASE_DIR = Path(__file__).resolve().parent
WEB_DIR = BASE_DIR / "web"
OUTPUT_DIR = BASE_DIR / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

LOTTERY_CONFIG = {
    "lotofacil": {
        "name": "Lotofácil",
        "api": "https://servicebus2.caixa.gov.br/portaldeloterias/api/lotofacil",
        "universe": 25,
        "default_history": 120,
        "default_unit_price": 3.0,
        "presets": [
            {
                "id": "lf_19_164",
                "label": "19 dezenas -> 164 jogos (reduzido heurístico)",
                "base_count": 19,
                "game_size": 15,
                "games_count": 164,
                "strategy": "balanced",
            }
        ],
    },
    "megasena": {
        "name": "Mega-Sena",
        "api": "https://servicebus2.caixa.gov.br/portaldeloterias/api/megasena",
        "universe": 60,
        "default_history": 120,
        "default_unit_price": 6.0,
        "presets": [
            {
                "id": "ms_8_28",
                "label": "8 dezenas -> 28 jogos (fechamento completo)",
                "base_count": 8,
                "game_size": 6,
                "games_count": 28,
                "strategy": "complete",
            },
            {
                "id": "ms_9_84",
                "label": "9 dezenas -> 84 jogos (fechamento completo)",
                "base_count": 9,
                "game_size": 6,
                "games_count": 84,
                "strategy": "complete",
            },
            {
                "id": "ms_10_210",
                "label": "10 dezenas -> 210 jogos (fechamento completo)",
                "base_count": 10,
                "game_size": 6,
                "games_count": 210,
                "strategy": "complete",
            },
            {
                "id": "ms_10_60",
                "label": "10 dezenas -> 60 jogos (reduzido heurístico)",
                "base_count": 10,
                "game_size": 6,
                "games_count": 60,
                "strategy": "balanced",
            },
        ],
    },
}


def fetch_json(url: str, timeout: int = 20) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 (compatible; LoteriasLocal/1.0)",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as res:
        raw = res.read().decode("utf-8")
        return json.loads(raw)


def get_draw_numbers(payload: dict) -> list[int]:
    dezenas = payload.get("listaDezenas", [])
    if not dezenas:
        raise ValueError("Resposta da API sem listaDezenas")
    return sorted(int(d) for d in dezenas)


def percentile_rank(values: dict[int, float]) -> dict[int, float]:
    ordered = sorted(values.items(), key=lambda x: x[1])
    n = len(ordered)
    if n <= 1:
        return {k: 100.0 for k in values}

    result = {}
    for idx, (k, _) in enumerate(ordered):
        result[k] = round((idx / (n - 1)) * 100.0, 2)
    return result


def get_latest_contest(lottery_key: str) -> tuple[int, list[int]]:
    payload = fetch_json(LOTTERY_CONFIG[lottery_key]["api"])
    contest = int(payload["numero"])
    return contest, get_draw_numbers(payload)


def get_contest_draw(lottery_key: str, contest: int) -> list[int]:
    payload = fetch_json(f"{LOTTERY_CONFIG[lottery_key]['api']}/{contest}")
    return get_draw_numbers(payload)


def choose_base_numbers(
    metrics: list[dict],
    base_count: int,
    variation_factor: float,
    latest_draw: list[int],
) -> list[int]:
    if variation_factor <= 0:
        return sorted([m["numero"] for m in metrics[:base_count]])

    latest_set = set(latest_draw)
    temperature = 1.0 + (variation_factor * 8.0)
    pool = []
    for m in metrics:
        desirability = max(0.01, m["score"] / 100.0)
        if m["numero"] in latest_set:
            desirability *= (1.0 - (0.35 * variation_factor))
        weight = desirability ** (1.0 / temperature)
        pool.append({"numero": m["numero"], "weight": weight})

    selected = []
    while len(selected) < base_count and pool:
        total_weight = sum(p["weight"] for p in pool)
        if total_weight <= 0:
            selected.extend([p["numero"] for p in pool[: (base_count - len(selected))]])
            break

        pick = random.uniform(0, total_weight)
        acc = 0.0
        chosen_idx = 0
        for idx, item in enumerate(pool):
            acc += item["weight"]
            if acc >= pick:
                chosen_idx = idx
                break
        selected.append(pool.pop(chosen_idx)["numero"])

    return sorted(selected)


def build_recommendation(
    lottery_key: str,
    history_size: int,
    base_count: int,
    variation_factor: float = 0.0,
) -> dict:
    universe = LOTTERY_CONFIG[lottery_key]["universe"]
    latest_contest, latest_draw = get_latest_contest(lottery_key)

    draws: list[tuple[int, list[int]]] = []
    for c in range(latest_contest, max(0, latest_contest - history_size), -1):
        try:
            draws.append((c, get_contest_draw(lottery_key, c)))
        except urllib.error.HTTPError:
            continue

    if len(draws) < 30:
        raise RuntimeError("Nao foi possivel carregar historico suficiente da API.")

    draws.sort(reverse=True)
    n_draws = len(draws)

    frequency = {n: 0 for n in range(1, universe + 1)}
    delay = {n: n_draws for n in range(1, universe + 1)}
    recency_weight = {n: 0.0 for n in range(1, universe + 1)}

    decay = 0.96
    for idx, (_, draw) in enumerate(draws):
        for n in set(draw):
            frequency[n] += 1
            recency_weight[n] += decay**idx
            if delay[n] == n_draws:
                delay[n] = idx

    freq_pct = percentile_rank({n: frequency[n] / n_draws for n in range(1, universe + 1)})
    recency_pct = percentile_rank(recency_weight)
    inverse_delay = {n: (n_draws - delay[n]) for n in range(1, universe + 1)}
    delay_pct = percentile_rank(inverse_delay)

    metrics = []
    for n in range(1, universe + 1):
        score = round(
            0.55 * freq_pct[n] + 0.30 * recency_pct[n] + 0.15 * delay_pct[n], 3
        )
        metrics.append(
            {
                "numero": n,
                "frequencia": frequency[n],
                "frequenciaPercentil": freq_pct[n],
                "atrasoConcursos": delay[n],
                "recenciaPercentil": recency_pct[n],
                "atrasoPercentil": delay_pct[n],
                "score": score,
            }
        )

    metrics.sort(key=lambda x: x["score"], reverse=True)
    base_numbers = choose_base_numbers(metrics, base_count, variation_factor, latest_draw)

    return {
        "latestContest": latest_contest,
        "latestDraw": latest_draw,
        "historyUsed": n_draws,
        "baseNumbers": base_numbers,
        "metrics": metrics,
        "variationFactor": round(variation_factor, 4),
    }


def generate_complete_closure(base_numbers: list[int], game_size: int) -> list[list[int]]:
    return [list(c) for c in itertools.combinations(sorted(base_numbers), game_size)]


def generate_balanced_closure(
    base_numbers: list[int], game_size: int, games_count: int
) -> list[list[int]]:
    base_numbers = sorted(base_numbers)
    base_size = len(base_numbers)

    candidates = [tuple(c) for c in itertools.combinations(base_numbers, game_size)]
    if games_count >= len(candidates):
        return [list(c) for c in candidates]

    random.seed(sum(base_numbers) + games_count + game_size)

    ideal_num = games_count * game_size / base_size
    total_pairs_per_game = math.comb(game_size, 2)
    ideal_pair = games_count * total_pairs_per_game / math.comb(base_size, 2)

    num_counts = {n: 0 for n in base_numbers}
    pair_counts = {p: 0 for p in itertools.combinations(base_numbers, 2)}

    selected: list[tuple[int, ...]] = []
    selected_set = set()

    pool = candidates[:]
    random.shuffle(pool)

    def delta_score(game: tuple[int, ...]) -> float:
        score = 0.0
        for n in game:
            new = num_counts[n] + 1
            score += (new - ideal_num) ** 2 - (num_counts[n] - ideal_num) ** 2

        for p in itertools.combinations(game, 2):
            new = pair_counts[p] + 1
            score += 0.12 * ((new - ideal_pair) ** 2 - (pair_counts[p] - ideal_pair) ** 2)
        return score

    while len(selected) < games_count:
        best_game = None
        best_delta = None

        sample_size = min(700, len(pool))
        sample = random.sample(pool, sample_size)

        for g in sample:
            if g in selected_set:
                continue
            d = delta_score(g)
            if best_delta is None or d < best_delta:
                best_delta = d
                best_game = g

        if best_game is None:
            for g in pool:
                if g not in selected_set:
                    best_game = g
                    break

        if best_game is None:
            break

        selected.append(best_game)
        selected_set.add(best_game)

        for n in best_game:
            num_counts[n] += 1
        for p in itertools.combinations(best_game, 2):
            pair_counts[p] += 1

    selected.sort()
    return [list(g) for g in selected]


def generate_games(base_numbers: list[int], game_size: int, games_count: int, strategy: str) -> list[list[int]]:
    if strategy == "complete":
        complete = generate_complete_closure(base_numbers, game_size)
        return complete[:games_count]
    return generate_balanced_closure(base_numbers, game_size, games_count)


def build_budget_plan(
    unit_price: float,
    games_count: int,
    monthly_budget: Optional[float],
) -> dict:
    total_value = round(unit_price * games_count, 2)
    plan = {
        "unitPrice": round(unit_price, 2),
        "gamesCount": games_count,
        "estimatedTotal": total_value,
    }
    if monthly_budget is not None:
        plan["monthlyBudget"] = round(monthly_budget, 2)
        plan["remainingInBudget"] = round(monthly_budget - total_value, 2)
        plan["weeklyTarget"] = round(monthly_budget / 4.0, 2)
    return plan


def col_name(idx: int) -> str:
    name = ""
    while idx > 0:
        idx, rem = divmod(idx - 1, 26)
        name = chr(65 + rem) + name
    return name


def sheet_xml(rows: list[list[tuple[str, str]]]) -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
        "<sheetData>",
    ]

    for r_idx, row in enumerate(rows, start=1):
        cells = []
        for c_idx, cell in enumerate(row, start=1):
            if not cell:
                continue
            kind, value = cell
            ref = f"{col_name(c_idx)}{r_idx}"
            if kind == "n":
                cells.append(f'<c r="{ref}"><v>{value}</v></c>')
            else:
                cells.append(
                    f'<c r="{ref}" t="inlineStr"><is><t>{escape(value)}</t></is></c>'
                )
        lines.append(f"<row r=\"{r_idx}\">{''.join(cells)}</row>")

    lines.extend(["</sheetData>", "</worksheet>"])
    return "".join(lines)


def write_xlsx(
    lottery_name: str,
    preset_label: str,
    variation_percent: float,
    game_size: int,
    games: list[list[int]],
    base_numbers: list[int],
    metrics: list[dict],
    latest_contest: int,
    out_path: Path,
) -> None:
    games_rows = [[("s", "Jogo")] + [("s", f"D{i}") for i in range(1, game_size + 1)]]

    for idx, game in enumerate(games, start=1):
        row = [("n", str(idx))]
        row.extend(("n", str(n)) for n in game)
        games_rows.append(row)

    summary_rows = [
        [("s", f"Fechamento {lottery_name}")],
        [("s", "Modelo"), ("s", preset_label)],
        [("s", "Fator de variacao"), ("s", f"{variation_percent:.0f}%")],
        [("s", "Concurso mais recente"), ("n", str(latest_contest))],
        [
            ("s", "Dezenas base"),
            ("s", ", ".join(str(n).zfill(2) for n in base_numbers)),
        ],
        [],
        [
            ("s", "Numero"),
            ("s", "Frequencia"),
            ("s", "Freq Percentil"),
            ("s", "Atraso"),
            ("s", "Recencia Percentil"),
            ("s", "Atraso Percentil"),
            ("s", "Score"),
        ],
    ]

    for m in metrics:
        summary_rows.append(
            [
                ("n", str(m["numero"])),
                ("n", str(m["frequencia"])),
                ("n", str(m["frequenciaPercentil"])),
                ("n", str(m["atrasoConcursos"])),
                ("n", str(m["recenciaPercentil"])),
                ("n", str(m["atrasoPercentil"])),
                ("n", str(m["score"])),
            ]
        )

    workbook = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        "<sheets>"
        '<sheet name="Jogos" sheetId="1" r:id="rId1"/>'
        '<sheet name="Resumo" sheetId="2" r:id="rId2"/>'
        "</sheets>"
        "</workbook>"
    )

    content_types = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/worksheets/sheet2.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        "</Types>"
    )

    root_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/>'
        "</Relationships>"
    )

    wb_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet2.xml"/>'
        "</Relationships>"
    )

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", root_rels)
        zf.writestr("xl/workbook.xml", workbook)
        zf.writestr("xl/_rels/workbook.xml.rels", wb_rels)
        zf.writestr("xl/worksheets/sheet1.xml", sheet_xml(games_rows))
        zf.writestr("xl/worksheets/sheet2.xml", sheet_xml(summary_rows))


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, payload: dict, code: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_file(self, path: Path, content_type: str) -> None:
        if not path.exists() or not path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND, "Arquivo nao encontrado")
            return
        data = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/":
            self._serve_file(WEB_DIR / "index.html", "text/html; charset=utf-8")
            return

        if parsed.path == "/app.js":
            self._serve_file(WEB_DIR / "app.js", "application/javascript; charset=utf-8")
            return

        if parsed.path == "/styles.css":
            self._serve_file(WEB_DIR / "styles.css", "text/css; charset=utf-8")
            return

        if parsed.path == "/api/options":
            options = {
                key: {
                    "name": cfg["name"],
                    "defaultHistory": cfg["default_history"],
                    "defaultUnitPrice": cfg["default_unit_price"],
                    "presets": cfg["presets"],
                }
                for key, cfg in LOTTERY_CONFIG.items()
            }
            self._send_json({"lotteries": options})
            return

        if parsed.path.startswith("/downloads/"):
            filename = Path(parsed.path.replace("/downloads/", "")).name
            self._serve_file(
                OUTPUT_DIR / filename,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
            return

        if parsed.path == "/api/generate":
            query = urllib.parse.parse_qs(parsed.query)
            lottery = query.get("lottery", ["lotofacil"])[0].lower()
            preset_id = query.get("preset", [""])[0]
            try:
                history = int(query.get("history", ["120"])[0])
            except ValueError:
                self._send_json({"error": "Histórico inválido."}, code=400)
                return
            games_query = query.get("games", [""])[0]
            unit_price_query = query.get("unitPrice", [""])[0]
            budget_query = query.get("budget", [""])[0]
            variation_query = query.get("variation", ["0"])[0]

            if lottery not in LOTTERY_CONFIG:
                self._send_json({"error": "Loteria inválida."}, code=400)
                return

            cfg = LOTTERY_CONFIG[lottery]
            preset = next((p for p in cfg["presets"] if p["id"] == preset_id), None)
            if not preset:
                preset = cfg["presets"][0]

            if history < 30:
                self._send_json(
                    {"error": "Parâmetros inválidos. Use history>=30."},
                    code=400,
                )
                return
            try:
                variation = float(variation_query)
            except ValueError:
                self._send_json({"error": "Fator de variacao invalido."}, code=400)
                return
            if variation < 0 or variation > 100:
                self._send_json(
                    {"error": "Fator de variacao deve estar entre 0 e 100."},
                    code=400,
                )
                return

            base_count = preset["base_count"]
            game_size = preset["game_size"]
            games_count = preset["games_count"]
            strategy = preset["strategy"]

            if games_query:
                try:
                    games_count = int(games_query)
                except ValueError:
                    self._send_json({"error": "Quantidade de jogos inválida."}, code=400)
                    return
            if games_count <= 0:
                self._send_json({"error": "Quantidade de jogos deve ser maior que zero."}, code=400)
                return

            try:
                unit_price = float(unit_price_query) if unit_price_query else 0.0
                monthly_budget = float(budget_query) if budget_query else None
            except ValueError:
                self._send_json({"error": "Preço unitário/orçamento inválido."}, code=400)
                return
            if monthly_budget is not None:
                if monthly_budget <= 0:
                    self._send_json({"error": "Orçamento deve ser maior que zero."}, code=400)
                    return
                if unit_price <= 0:
                    self._send_json(
                        {"error": "Informe um preço unitário válido para cálculo por orçamento."},
                        code=400,
                    )
                    return
                budget_games = int(monthly_budget // unit_price)
                if budget_games <= 0:
                    self._send_json(
                        {
                            "error": "Orçamento insuficiente para 1 jogo.",
                            "tip": "Aumente o orçamento ou reduza o preço unitário.",
                        },
                        code=400,
                    )
                    return
                games_count = budget_games

            try:
                recommendation = build_recommendation(
                    lottery, history, base_count, variation_factor=(variation / 100.0)
                )
                max_combinations = math.comb(base_count, game_size)
                if games_count > max_combinations:
                    games_count = max_combinations
                games = generate_games(
                    recommendation["baseNumbers"], game_size, games_count, strategy
                )

                stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"{lottery}_fechamento_{stamp}.xlsx"
                out_file = OUTPUT_DIR / filename

                write_xlsx(
                    lottery_name=cfg["name"],
                    preset_label=preset["label"],
                    variation_percent=variation,
                    game_size=game_size,
                    games=games,
                    base_numbers=recommendation["baseNumbers"],
                    metrics=recommendation["metrics"],
                    latest_contest=recommendation["latestContest"],
                    out_path=out_file,
                )

                self._send_json(
                    {
                        "generatedAt": datetime.now(timezone.utc).isoformat(),
                        "lottery": lottery,
                        "lotteryName": cfg["name"],
                        "preset": preset,
                        "source": cfg["api"],
                        "latestContest": recommendation["latestContest"],
                        "latestDraw": recommendation["latestDraw"],
                        "historyUsed": recommendation["historyUsed"],
                        "variation": variation,
                        "baseNumbers": recommendation["baseNumbers"],
                        "metrics": recommendation["metrics"],
                        "gamesCount": len(games),
                        "games": games,
                        "excelFile": f"/downloads/{filename}",
                        "maxCombinations": max_combinations,
                        "budgetPlan": build_budget_plan(unit_price, len(games), monthly_budget)
                        if unit_price > 0
                        else None,
                        "notes": [
                            "Fechamento estatístico/heurístico para apoio na montagem de jogos.",
                            "Não existe garantia matemática oficial de premiação.",
                        ],
                    }
                )
            except Exception as exc:
                self._send_json(
                    {
                        "error": "Falha ao gerar fechamento.",
                        "details": str(exc),
                        "tip": "Verifique conexão de internet para consultar a API da Caixa.",
                    },
                    code=500,
                )
            return

        self.send_error(HTTPStatus.NOT_FOUND, "Rota nao encontrada")


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Servidor pronto em http://127.0.0.1:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
