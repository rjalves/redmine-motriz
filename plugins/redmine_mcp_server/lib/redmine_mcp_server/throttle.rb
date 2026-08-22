# frozen_string_literal: true

module RedmineMcpServer
  # Limite de chamadas por usuário e por minuto.
  #
  # A especificação exige: "Servers MUST rate limit tool invocations". Um modelo
  # em laço dispara dezenas de chamadas em segundos, e cada uma vira consulta ao
  # Postgres.
  #
  # Janela fixa por minuto — não é um token bucket. Na virada do minuto o
  # contador zera, então um cliente pode emitir até 2x o teto na fronteira. Para
  # proteger o banco de um laço descontrolado isso basta; se um dia precisar de
  # precisão, troque por janela deslizante.
  #
  # O contador vive no Rails.cache. Com mais de um processo Puma e cache em
  # memória, cada processo conta o seu — o teto efetivo vira N x limite. Está
  # documentado no README; a instalação atual roda um processo só.
  module Throttle
    module_function

    def key_for(user_id, now = Time.now.utc)
      "mcp_server/throttle/#{user_id}/#{now.strftime('%Y%m%d%H%M')}"
    end

    # Um cache nulo faz todo increment devolver nil e o limite viraria no-op
    # silencioso — o pior dos mundos, porque parece protegido. O Redmine usa
    # :null_store em teste (config/environments/test.rb:36); em produção o
    # default do Rails é o file store, que funciona. Avisamos uma vez e
    # deixamos passar: derrubar o servidor porque o cache é nulo seria pior.
    def available?
      !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
    end

    # Devolve [permitido, restante].
    def hit(user_id, limit = Config.rate_limit)
      unless available?
        warn_once_about_null_store
        return [true, limit]
      end

      key = key_for(user_id)
      count = Rails.cache.increment(key, 1, expires_in: 120)

      # Alguns stores devolvem nil no primeiro increment de uma chave ausente.
      if count.nil?
        Rails.cache.write(key, 1, expires_in: 120, raw: true)
        count = 1
      end

      [count <= limit, [limit - count, 0].max]
    end

    def reset!(user_id)
      Rails.cache.delete(key_for(user_id))
    end

    def warn_once_about_null_store
      return if defined?(@warned) && @warned

      @warned = true
      Rails.logger.warn('MCP: Rails.cache is a NullStore — tool call rate limiting is INACTIVE.')
    end
  end
end
