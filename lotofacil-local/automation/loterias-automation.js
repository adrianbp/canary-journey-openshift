#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const readline = require('readline/promises');
const { stdin: input, stdout: output } = require('process');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

function colToIdx(col) {
  let n = 0;
  for (const ch of col) {
    n = n * 26 + (ch.charCodeAt(0) - 64);
  }
  return n;
}

function decodeXml(text) {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function readGamesFromXlsx(xlsxPath) {
  let xml;
  try {
    xml = execFileSync('unzip', ['-p', xlsxPath, 'xl/worksheets/sheet1.xml'], {
      encoding: 'utf8',
    });
  } catch (err) {
    throw new Error('Falha ao ler xlsx. Confirme se o comando unzip está disponível no sistema.');
  }

  const rowRegex = /<row[^>]*>([\s\S]*?)<\/row>/g;
  const cellRegex = /<c\s+([^>]*)>([\s\S]*?)<\/c>/g;
  const refRegex = /r="([A-Z]+)(\d+)"/;
  const typeRegex = /t="([^"]+)"/;

  const table = [];
  let rowMatch;
  while ((rowMatch = rowRegex.exec(xml)) !== null) {
    const rowXml = rowMatch[1];
    const rowVals = {};

    let cellMatch;
    while ((cellMatch = cellRegex.exec(rowXml)) !== null) {
      const attrs = cellMatch[1];
      const cellBody = cellMatch[2];
      const ref = attrs.match(refRegex);
      if (!ref) continue;

      const col = ref[1];
      const colIdx = colToIdx(col);
      const t = (attrs.match(typeRegex) || [])[1] || '';

      let value = '';
      if (t === 'inlineStr') {
        const m = cellBody.match(/<t[^>]*>([\s\S]*?)<\/t>/);
        value = m ? decodeXml(m[1]) : '';
      } else {
        const m = cellBody.match(/<v>([\s\S]*?)<\/v>/);
        value = m ? decodeXml(m[1]) : '';
      }

      rowVals[colIdx] = value;
    }

    if (Object.keys(rowVals).length > 0) {
      table.push(rowVals);
    }
  }

  if (table.length < 2) {
    throw new Error('Planilha sem jogos suficientes na aba Jogos.');
  }

  const games = [];
  for (let r = 1; r < table.length; r += 1) {
    const row = table[r];
    const nums = Object.keys(row)
      .map((k) => Number(k))
      .filter((k) => k >= 2)
      .sort((a, b) => a - b)
      .map((k) => Number(row[k]))
      .filter((n) => Number.isInteger(n) && n > 0);

    if (nums.length > 0) {
      games.push(nums);
    }
  }

  if (games.length === 0) {
    throw new Error('Nenhum jogo encontrado na aba Jogos.');
  }

  return games;
}

async function clickByNumber(page, n, numberPattern, numberSelector) {
  const padded = String(n).padStart(2, '0');
  const idLocator = page.locator(`#n${padded}, #n${n}`).first();
  if (await idLocator.count()) {
    await idLocator.click();
    return;
  }

  const pattern = new RegExp(numberPattern.replace('{n}', String(n)));

  if (numberSelector) {
    const scoped = page.locator(numberSelector).filter({ hasText: pattern }).first();
    if (await scoped.count()) {
      await scoped.click();
      return;
    }
  } else {
    const byRole = page.getByRole('button', { name: pattern }).first();
    if (await byRole.count()) {
      await byRole.click();
      return;
    }
  }

  const locator = page.locator(`text=${padded}`).first();
  if (await locator.count()) {
    await locator.click();
    return;
  }

  throw new Error(`Não encontrei botão para dezena ${n}.`);
}

async function maybeClick(page, selector) {
  if (!selector) return;
  const loc = page.locator(selector).first();
  if (await loc.count()) {
    await loc.click();
  }
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const excelPath = path.resolve(args.excel || '');
  const configPath = path.resolve(args.config || path.join(__dirname, 'config.example.json'));
  const startAt = Number(args.start || 1);
  const maxGames = args.max ? Number(args.max) : null;
  const headless = String(args.headless || 'false') !== 'false';
  const confirmEach = Boolean(args['confirm-each']);
  const dryRun = Boolean(args['dry-run']);

  if (!excelPath || !fs.existsSync(excelPath)) {
    throw new Error('Use --excel /caminho/arquivo.xlsx');
  }
  if (!fs.existsSync(configPath)) {
    throw new Error('Config não encontrado. Use --config /caminho/config.json');
  }

  const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const gamesAll = readGamesFromXlsx(excelPath);
  let games = gamesAll.slice(Math.max(0, startAt - 1));
  if (maxGames && maxGames > 0) {
    games = games.slice(0, maxGames);
  }

  console.log(`Arquivo: ${excelPath}`);
  console.log(`Jogos lidos: ${gamesAll.length}. Jogos para preencher: ${games.length}.`);

  if (dryRun) {
    games.forEach((g, i) => {
      console.log(`${String(startAt + i).padStart(3, '0')}: ${g.map((n) => String(n).padStart(2, '0')).join(' ')}`);
    });
    return;
  }

  const { chromium } = require('playwright');
  const browser = await chromium.launch({ headless });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(cfg.siteUrl, { waitUntil: 'domcontentloaded' });

  const rl = readline.createInterface({ input, output });
  await rl.question('Faça login manualmente e deixe a tela pronta para marcação. Pressione ENTER para iniciar... ');

  let filled = 0;
  for (let i = 0; i < games.length; i += 1) {
    const game = games[i];
    const idx = startAt + i;

    console.log(`Preenchendo jogo ${idx}: ${game.join(' ')}`);

    await maybeClick(page, cfg.selectors && cfg.selectors.clearSelection);

    for (const n of game) {
      await clickByNumber(
        page,
        n,
        cfg.numberPattern || '^0?{n}$',
        cfg.numberSelector || '',
      );
      await page.waitForTimeout(Number(cfg.delayBetweenNumbersMs || 150));
    }

    await maybeClick(page, cfg.selectors && cfg.selectors.addGame);
    await page.waitForTimeout(Number(cfg.delayAfterGameMs || 600));
    filled += 1;

    if (confirmEach) {
      await rl.question(`Jogo ${idx} concluído. Pressione ENTER para continuar... `);
    }
  }

  console.log(`Concluído. Jogos preenchidos: ${filled}.`);
  console.log('Revise os jogos no site e finalize o pagamento manualmente.');

  await rl.close();
  await browser.close();
}

run().catch((err) => {
  console.error(`Erro: ${err.message}`);
  process.exit(1);
});
