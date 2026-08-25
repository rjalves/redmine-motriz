// Gráficos do painel da tela inicial.
//
// O Chart.js não é empacotado aqui: ele já vem no importmap do próprio Redmine
// (config/importmap.rb, pin "chart.js"), que é o mesmo módulo usado pelos
// gráficos nativos de relatório e de estatística de repositório. O import é
// dinâmico e só acontece quando o painel existe na página.
//
// As cores saem das custom properties do tema (--color-*), publicadas no :root
// do application.css. Assim a paleta do gráfico acompanha a da marca e o modo
// escuro sem precisar repetir nenhum hex aqui.
(async function () {
  while (typeof Stimulus === 'undefined') {
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  const { Controller } = await import('@hotwired/stimulus');

  Stimulus.register("dashboard-charts", class extends Controller {
    static targets = ["situacao", "prioridade", "projeto", "responsavel", "evolucao"]
    static values  = { dados: Object }

    async connect() {
      this._charts = [];

      const mod = await import('chart.js');
      const Chart = mod.default;
      if (!Chart) return;

      const t = this._tema();
      Chart.defaults.font.family = t.fonte;
      Chart.defaults.font.size = 11;
      Chart.defaults.color = t.texto;

      const d = this.dadosValue || {};

      if (this.hasSituacaoTarget)    this._rosca(Chart, this.situacaoTarget, d.situacao, t);
      if (this.hasPrioridadeTarget)  this._barras(Chart, this.prioridadeTarget, d.prioridade, t, 'x');
      if (this.hasProjetoTarget)     this._barras(Chart, this.projetoTarget, d.projeto, t, 'y');
      if (this.hasResponsavelTarget) this._barras(Chart, this.responsavelTarget, d.responsavel, t, 'y');
      if (this.hasEvolucaoTarget)    this._linha(Chart, this.evolucaoTarget, d.evolucao, d.rotulos, t);
    }

    // Turbo troca o corpo da página sem recarregar. Sem destroy() os gráficos
    // antigos continuam presos ao canvas removido, segurando memória e
    // listeners de resize.
    disconnect() {
      this._charts.forEach(c => c.destroy());
      this._charts = [];
    }

    // --- tema ------------------------------------------------------------

    _var(nome, alternativa) {
      const v = getComputedStyle(document.documentElement).getPropertyValue(nome).trim();
      return v || alternativa;
    }

    _tema() {
      const escuro = document.documentElement.classList.contains('dark');
      return {
        fonte:  this._var('--font-sans', 'Archivo, Arial, sans-serif'),
        texto:  escuro ? this._var('--color-gray-400', '#9fa1a3') : this._var('--color-gray-500', '#6d6e71'),
        grade:  escuro ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.06)',
        fundo:  escuro ? this._var('--color-gray-800', '#27292a') : '#ffffff',
        criadas:  this._var('--color-blue-600', '#00828a'),
        fechadas: this._var('--color-green-500', '#458332'),
        // Paleta categórica na ordem da marca: verde institucional, ciano,
        // laranja, violeta, amarelo, verde educação, vermelho, azul petróleo.
        paleta: [
          this._var('--color-blue-700',   '#024b40'),
          this._var('--color-blue-600',   '#00828a'),
          this._var('--color-orange-500', '#b0532e'),
          this._var('--color-purple-600', '#633c94'),
          this._var('--color-amber-500',  '#ffc033'),
          this._var('--color-green-500',  '#458332'),
          this._var('--color-red-600',    '#cc4900'),
          this._var('--color-blue-400',   '#33b5bb'),
          this._var('--color-gray-400',   '#9fa1a3')
        ]
      };
    }

    _cores(t, n) {
      return Array.from({ length: n }, (_, i) => t.paleta[i % t.paleta.length]);
    }

    _registrar(chart) {
      this._charts.push(chart);
      return chart;
    }

    // --- tipos de gráfico ------------------------------------------------

    _rosca(Chart, canvas, pares, t) {
      if (!pares || !pares.length) return;
      this._registrar(new Chart(canvas, {
        type: 'doughnut',
        data: {
          labels: pares.map(p => p[0]),
          datasets: [{
            data: pares.map(p => p[1]),
            backgroundColor: this._cores(t, pares.length),
            borderColor: t.fundo,
            borderWidth: 2
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: '58%',
          plugins: {
            legend: { position: 'right', labels: { boxWidth: 10, boxHeight: 10, padding: 10, usePointStyle: true, pointStyle: 'circle' } }
          }
        }
      }));
    }

    // eixo 'y' = barras horizontais, para nomes longos de projeto e de pessoa
    // caberem sem girar o rótulo.
    _barras(Chart, canvas, pares, t, eixo) {
      if (!pares || !pares.length) return;
      const horizontal = eixo === 'y';
      this._registrar(new Chart(canvas, {
        type: 'bar',
        data: {
          labels: pares.map(p => p[0]),
          datasets: [{
            data: pares.map(p => p[1]),
            backgroundColor: this._cores(t, pares.length),
            borderRadius: 4,
            borderSkipped: false,
            maxBarThickness: 28
          }]
        },
        options: {
          indexAxis: eixo,
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: {
              beginAtZero: true,
              grid: { color: horizontal ? t.grade : 'transparent', drawBorder: false },
              ticks: horizontal ? { precision: 0 } : {}
            },
            y: {
              beginAtZero: true,
              grid: { color: horizontal ? 'transparent' : t.grade, drawBorder: false },
              ticks: horizontal ? { autoSkip: false } : { precision: 0 }
            }
          }
        }
      }));
    }

    _linha(Chart, canvas, ev, rotulos, t) {
      if (!ev || !ev.rotulos || !ev.rotulos.length) return;
      const serie = (dados, cor, nome) => ({
        label: nome,
        data: dados,
        borderColor: cor,
        backgroundColor: cor + '22',
        borderWidth: 2,
        fill: true,
        tension: 0.35,
        pointRadius: 2,
        pointHoverRadius: 4
      });
      this._registrar(new Chart(canvas, {
        type: 'line',
        data: {
          labels: ev.rotulos,
          datasets: [
            serie(ev.criadas,  t.criadas,  (rotulos && rotulos.criadas)  || 'Criadas'),
            serie(ev.fechadas, t.fechadas, (rotulos && rotulos.fechadas) || 'Fechadas')
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { mode: 'index', intersect: false },
          plugins: {
            legend: { position: 'bottom', labels: { boxWidth: 10, boxHeight: 10, padding: 12, usePointStyle: true, pointStyle: 'circle' } }
          },
          scales: {
            x: { grid: { display: false, drawBorder: false } },
            y: { beginAtZero: true, grid: { color: t.grade, drawBorder: false }, ticks: { precision: 0 } }
          }
        }
      }));
    }
  });
})();
