# frozen_string_literal: true

module RedmineAsapTheme
  # Indicadores da tela inicial.
  #
  # Tudo aqui parte de `Issue.visible(user)`, nunca de `Issue.all`: o
  # visible_condition do Redmine aplica a visibilidade por papel, por módulo
  # habilitado e por tracker. Um número somado fora desse escopo vazaria a
  # existência de tarefas que a pessoa não pode ver.
  #
  # As consultas são agregadas no banco (GROUP BY + COUNT), não em Ruby, para
  # que o custo não cresça com o tamanho da instância. A única exceção é a série
  # temporal, e o motivo está comentado lá embaixo.
  module Dashboard
    SEMANAS         = 12  # janela da série temporal
    LIMITE_BARRAS   = 8   # projetos/responsáveis mostrados antes de agrupar em "outros"

    module_function

    def dados(user = User.current)
      escopo  = Issue.visible(user)
      abertas = escopo.open

      {
        :numeros         => numeros(user, escopo, abertas),
        :por_situacao    => por_situacao(abertas),
        :por_prioridade  => por_prioridade(abertas),
        :por_projeto     => por_projeto(abertas),
        :por_responsavel => por_responsavel(abertas),
        :evolucao        => evolucao(escopo, user)
      }
    end

    # --- cartões de número -------------------------------------------------

    def numeros(user, escopo, abertas)
      {
        :abertas         => abertas.count,
        :atrasadas       => abertas.where('issues.due_date < ?', user.today).count,
        :minhas          => user.logged? ? abertas.where(:assigned_to_id => user.id).count : 0,
        :sem_responsavel => abertas.where(:assigned_to_id => nil).count,
        :fechadas_semana => escopo.where('issues.closed_on >= ?', user.today - 7).count,
        :projetos        => Project.visible(user).where(:status => Project::STATUS_ACTIVE).count
      }
    end

    # --- distribuições -----------------------------------------------------

    # Situações na ordem do fluxo de trabalho (position), não na ordem de
    # contagem — é o mesmo eixo que o Quadro usa, e ler os dois juntos só
    # funciona se a ordem bater.
    def por_situacao(abertas)
      contagem = abertas.group(:status_id).count
      IssueStatus.sorted.filter_map do |s|
        n = contagem[s.id].to_i
        [s.name, n] if n.positive?
      end
    end

    def por_prioridade(abertas)
      contagem = abertas.group(:priority_id).count
      IssuePriority.active.sorted.filter_map do |p|
        n = contagem[p.id].to_i
        [p.name, n] if n.positive?
      end
    end

    def por_projeto(abertas)
      contagem = abertas.group(:project_id).count
      nomes = Project.where(:id => contagem.keys).pluck(:id, :name).to_h
      maiores(contagem.transform_keys { |id| nomes[id] }.compact)
    end

    def por_responsavel(abertas)
      contagem = abertas.group(:assigned_to_id).count
      sem_dono = contagem.delete(nil).to_i
      nomes = Principal.where(:id => contagem.keys).index_by(&:id)
      lista = maiores(contagem.filter_map { |id, n| [nomes[id]&.name, n] if nomes[id] }.to_h)
      # "Sem responsável" vai sempre ao fim e nunca é engolido pelo corte: é a
      # barra que representa trabalho que ninguém pegou, justamente a que
      # interessa enxergar.
      lista << [:sem_responsavel, sem_dono] if sem_dono.positive?
      lista
    end

    # Ordena por contagem e agrupa a cauda em "outros", para a barra não virar
    # uma lista de trinta linhas ilegíveis.
    def maiores(hash)
      ordenado = hash.sort_by { |_nome, n| -n }
      cabeca = ordenado.first(LIMITE_BARRAS)
      resto  = ordenado.drop(LIMITE_BARRAS)
      cabeca << [:outros, resto.sum { |_n, v| v }] if resto.any?
      cabeca
    end

    # --- série temporal ----------------------------------------------------

    # Doze semanas de criadas x fechadas.
    #
    # Aqui os timestamps são trazidos e agrupados em Ruby, em vez de um
    # DATE_TRUNC no banco, porque DATE_TRUNC é dialeto do PostgreSQL e o Redmine
    # roda também em MySQL e SQLite. O custo fica limitado pela JANELA, não pelo
    # tamanho da tabela: só entram as tarefas dos últimos 84 dias, e o pluck
    # devolve datas cruas sem instanciar objeto nenhum.
    def evolucao(escopo, user)
      inicio = semana_de(user.today) - (SEMANAS - 1) * 7

      criadas  = balde(escopo.where('issues.created_on >= ?', inicio).pluck(:created_on))
      fechadas = balde(escopo.where('issues.closed_on >= ?', inicio).pluck(:closed_on))

      semanas = (0...SEMANAS).map { |i| inicio + i * 7 }
      {
        :rotulos  => semanas.map { |d| d.strftime('%d/%m') },
        :criadas  => semanas.map { |d| criadas[d].to_i },
        :fechadas => semanas.map { |d| fechadas[d].to_i }
      }
    end

    def balde(datas)
      datas.compact.group_by { |t| semana_de(t.to_date) }.transform_values(&:size)
    end

    # Segunda-feira da semana da data.
    def semana_de(data)
      data - ((data.wday - 1) % 7)
    end
  end
end
