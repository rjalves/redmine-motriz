# frozen_string_literal: true

module RedmineAsapTheme
  # Regras de armazenamento dos papéis de parede da tela de login.
  #
  # São duas origens, e a diferença entre elas não é cosmética:
  #
  # - **embutidos**: os que vêm no pacote do plugin, em assets/images/login/.
  #   Ficam dentro da imagem Docker, que é recriada a cada deploy. São somente
  #   leitura: apagar o arquivo funcionaria até a próxima publicação e ele
  #   voltaria sozinho. Por isso "excluir" um embutido apenas o esconde.
  # - **enviados**: gravados em files/, o único caminho montado como volume e
  #   portanto o único que sobrevive a um redeploy. Esses são apagáveis de fato.
  #
  # O identificador de um enviado carrega o prefixo PREFIXO_ENVIADO; o de um
  # embutido é o nome do arquivo puro, que é o formato já gravado na
  # configuração antes desta funcionalidade existir.
  module Wallpapers
    EXTENSOES = %w[.jpg .jpeg .png .webp .gif].freeze

    TIPOS = {
      '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.png' => 'image/png',
      '.webp' => 'image/webp', '.gif' => 'image/gif'
    }.freeze

    TAMANHO_MAXIMO = 5 * 1024 * 1024

    PREFIXO_ENVIADO = 'enviado:'
    ARQUIVO_OCULTOS = '.ocultas'
    CHAVE_SELECAO = 'redmine_asap_login_wallpaper'

    module_function

    # --- localização ------------------------------------------------------

    def diretorio
      Rails.root.join('files', 'motriz2_wallpapers')
    end

    def diretorio_embutidos
      Rails.root.join('plugins', 'motriz_2', 'assets', 'images', 'login')
    end

    def garantir_diretorio
      FileUtils.mkdir_p(diretorio) unless File.directory?(diretorio)
      diretorio
    end

    # --- listagens --------------------------------------------------------

    def embutidos
      nomes = Dir.glob("#{diretorio_embutidos}/*").map { |f| File.basename(f) }
      nomes.select { |n| EXTENSOES.include?(File.extname(n).downcase) }.sort
    end

    def enviados
      return [] unless File.directory?(diretorio)

      nomes = Dir.glob("#{diretorio}/*").map { |f| File.basename(f) }
      nomes.select { |n| EXTENSOES.include?(File.extname(n).downcase) }.sort
    end

    def ocultos
      arq = diretorio.join(ARQUIVO_OCULTOS)
      return [] unless File.file?(arq)

      File.readlines(arq, chomp: true).map(&:strip).reject(&:empty?)
    end

    # Tudo que o administrador deve ver, já sem os embutidos escondidos.
    # Cada item é [identificador, nome_do_arquivo, enviado?].
    def disponiveis
      escondidos = ocultos
      visiveis = embutidos.reject { |n| escondidos.include?(n) }
      visiveis.map { |n| [n, n, false] } +
        enviados.map { |n| ["#{PREFIXO_ENVIADO}#{n}", n, true] }
    end

    def enviado?(identificador)
      identificador.to_s.start_with?(PREFIXO_ENVIADO)
    end

    def nome_de(identificador)
      identificador.to_s.delete_prefix(PREFIXO_ENVIADO)
    end

    # --- saneamento -------------------------------------------------------

    # Devolve o nome se ele for seguro de usar como arquivo, senão nil.
    # Cuidado deliberado: `show` responde sem sessão, então este é o único
    # ponto entre a internet e o sistema de arquivos.
    def nome_seguro(bruto)
      nome = File.basename(bruto.to_s.strip)
      return nil if nome.empty? || nome.start_with?('.')
      return nil unless nome.match?(/\A[A-Za-z0-9][A-Za-z0-9 ._-]*\z/)
      return nil unless EXTENSOES.include?(File.extname(nome).downcase)

      nome
    end

    # Caminho absoluto de um enviado, ou nil se o nome não for seguro ou o
    # arquivo cair fora do diretório (defesa contra link simbólico).
    def caminho_enviado(bruto)
      nome = nome_seguro(bruto)
      return nil unless nome

      caminho = diretorio.join(nome)
      return nil unless File.file?(caminho)

      real = File.realpath(caminho)
      return nil unless real.start_with?("#{File.realpath(diretorio)}#{File::SEPARATOR}")

      real
    end

    def tipo_de(nome)
      TIPOS[File.extname(nome.to_s).downcase]
    end

    # --- validação de conteúdo -------------------------------------------

    # Extensão e content-type do navegador são declarações do cliente, não
    # fatos. Quem decide é o começo do arquivo.
    def formato_reconhecido?(conteudo)
      bytes = conteudo.to_s.b
      return true if bytes.start_with?("\xFF\xD8\xFF".b)                       # JPEG
      return true if bytes.start_with?("\x89PNG\r\n\x1A\n".b)                  # PNG
      return true if bytes.start_with?('GIF87a'.b) || bytes.start_with?('GIF89a'.b)
      return true if bytes.start_with?('RIFF'.b) && bytes[8, 4] == 'WEBP'.b    # WEBP

      false
    end

    # --- escrita ----------------------------------------------------------

    # Devolve [identificador, nil] em caso de sucesso, ou [nil, :chave_do_erro].
    def gravar(upload)
      # Campo de arquivo vazio chega ora como nil, ora como uma parte sem nome,
      # dependendo do navegador. Os dois casos são "não escolheu arquivo".
      return [nil, :motriz_wallpaper_erro_vazio] if upload.blank?
      return [nil, :motriz_wallpaper_erro_vazio] unless upload.respond_to?(:read)
      return [nil, :motriz_wallpaper_erro_vazio] if upload.original_filename.to_s.strip.empty?

      nome = nome_seguro(upload.original_filename)
      return [nil, :motriz_wallpaper_erro_extensao] unless nome

      conteudo = upload.read
      return [nil, :motriz_wallpaper_erro_vazio] if conteudo.blank?
      return [nil, :motriz_wallpaper_erro_tamanho] if conteudo.bytesize > TAMANHO_MAXIMO
      return [nil, :motriz_wallpaper_erro_formato] unless formato_reconhecido?(conteudo)

      garantir_diretorio
      destino = nome_livre(nome)
      File.binwrite(diretorio.join(destino), conteudo)

      ["#{PREFIXO_ENVIADO}#{destino}", nil]
    end

    # Evita que um envio sobrescreva outro em silêncio.
    def nome_livre(nome)
      return nome unless File.exist?(diretorio.join(nome))

      base = File.basename(nome, '.*')
      ext  = File.extname(nome)
      i = 2
      i += 1 while File.exist?(diretorio.join("#{base}-#{i}#{ext}"))
      "#{base}-#{i}#{ext}"
    end

    # Apaga de fato, se enviado; esconde, se embutido.
    def excluir(identificador)
      if enviado?(identificador)
        caminho = caminho_enviado(nome_de(identificador))
        return false unless caminho

        File.delete(caminho)
      else
        nome = nome_seguro(identificador)
        return false unless nome && embutidos.include?(nome)

        garantir_diretorio
        File.write(diretorio.join(ARQUIVO_OCULTOS), (ocultos | [nome]).join("\n") + "\n")
      end

      reatribuir_selecao_se_preciso(identificador)
      true
    end

    def restaurar_embutidos
      arq = diretorio.join(ARQUIVO_OCULTOS)
      File.delete(arq) if File.file?(arq)
      true
    end

    # --- seleção ----------------------------------------------------------

    def selecionado
      Setting.plugin_motriz_2[CHAVE_SELECAO]
    end

    # Se o administrador removeu justamente o que estava em uso, a tela de
    # login ficaria sem fundo. Cai para a primeira opção que sobrou.
    def reatribuir_selecao_se_preciso(removido)
      return unless selecionado.to_s == removido.to_s

      substituto = disponiveis.first&.first
      Setting.plugin_motriz_2 = Setting.plugin_motriz_2.merge(CHAVE_SELECAO => substituto.to_s)
    end
  end
end
