const statusEl = document.getElementById("status");
const resultEl = document.getElementById("result");
const baseEl = document.getElementById("baseNumbers");
const contestInfoEl = document.getElementById("contestInfo");
const gamesListEl = document.getElementById("gamesList");
const excelLinkEl = document.getElementById("excelLink");
const lotteryEl = document.getElementById("lottery");
const presetEl = document.getElementById("preset");
const historyEl = document.getElementById("history");
const unitPriceEl = document.getElementById("unitPrice");
const budgetEl = document.getElementById("budget");
const variationEl = document.getElementById("variation");
const baseTitleEl = document.getElementById("baseTitle");
const gamesTitleEl = document.getElementById("gamesTitle");
const budgetInfoEl = document.getElementById("budgetInfo");

let optionsState = null;

function refreshPresets() {
  const lottery = lotteryEl.value;
  const cfg = optionsState.lotteries[lottery];

  presetEl.innerHTML = "";
  cfg.presets.forEach((p) => {
    const op = document.createElement("option");
    op.value = p.id;
    op.textContent = p.label;
    presetEl.appendChild(op);
  });

  historyEl.value = cfg.defaultHistory;
  unitPriceEl.value = Number(cfg.defaultUnitPrice || 0).toFixed(2);
}

async function loadOptions() {
  const res = await fetch("/api/options");
  const data = await res.json();

  if (!res.ok) {
    throw new Error(data.error || "Falha ao carregar opções");
  }

  optionsState = data;

  lotteryEl.innerHTML = "";
  Object.entries(optionsState.lotteries).forEach(([key, cfg]) => {
    const op = document.createElement("option");
    op.value = key;
    op.textContent = cfg.name;
    lotteryEl.appendChild(op);
  });

  lotteryEl.value = "lotofacil";
  refreshPresets();
}

async function generate() {
  const lottery = lotteryEl.value;
  const preset = presetEl.value;
  const history = Number(historyEl.value || 120);
  const unitPrice = Number(unitPriceEl.value || 0);
  const budgetRaw = budgetEl.value.trim();
  const budget = budgetRaw ? Number(budgetRaw) : 0;
  const variation = Number(variationEl.value || 0);

  statusEl.textContent = "Processando... consultando API e gerando fechamento.";
  resultEl.classList.add("hidden");

  try {
    const params = new URLSearchParams({
      lottery,
      preset,
      history: String(history),
      unitPrice: String(unitPrice),
      variation: String(variation),
    });
    if (budget > 0) {
      params.set("budget", String(budget));
    }
    const res = await fetch(`/api/generate?${params.toString()}`);
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.details || data.error || "Erro desconhecido");
    }

    baseTitleEl.textContent = `${data.baseNumbers.length} números base (${data.lotteryName})`;
    gamesTitleEl.textContent = `${data.gamesCount} jogos de ${data.preset.game_size} dezenas`;

    baseEl.innerHTML = "";
    data.baseNumbers.forEach((n) => {
      const chip = document.createElement("span");
      chip.textContent = String(n).padStart(2, "0");
      baseEl.appendChild(chip);
    });

    contestInfoEl.textContent = `Concurso base: ${data.latestContest} | Histórico: ${data.historyUsed} concursos | Modelo: ${data.preset.label} | Variação: ${data.variation}%`;
    if (data.budgetPlan) {
      const b = data.budgetPlan;
      budgetInfoEl.textContent = `Planejamento: ${b.gamesCount} jogos x R$ ${b.unitPrice.toFixed(2)} = R$ ${b.estimatedTotal.toFixed(2)} | Sobra no mês: R$ ${b.remainingInBudget.toFixed(2)} | Meta semanal: R$ ${b.weeklyTarget.toFixed(2)}`;
    } else {
      budgetInfoEl.textContent = "";
    }

    excelLinkEl.href = data.excelFile;
    excelLinkEl.classList.remove("hidden");

    gamesListEl.innerHTML = "";
    data.games.forEach((game, idx) => {
      const row = document.createElement("div");
      row.className = "game-row";
      row.textContent = `${String(idx + 1).padStart(3, "0")}: ${game
        .map((n) => String(n).padStart(2, "0"))
        .join(" ")}`;
      gamesListEl.appendChild(row);
    });

    statusEl.textContent = "Estratégia gerada com sucesso.";
    resultEl.classList.remove("hidden");
  } catch (err) {
    statusEl.textContent = `Falha: ${err.message}`;
  }
}

lotteryEl.addEventListener("change", refreshPresets);
document.getElementById("generateBtn").addEventListener("click", generate);

loadOptions().catch((err) => {
  statusEl.textContent = `Falha ao inicializar: ${err.message}`;
});
