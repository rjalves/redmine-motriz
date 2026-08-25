require_relative '../test_helper'

# O avatar por iniciais é um cache em disco: o gem letter_avatar grava o PNG em
# public/system/letter_avatars/<versao>/<iniciais>/ na primeira vez que aquelas
# iniciais aparecem.
#
# Como avatar() é chamado no layout base, uma falha de escrita ali não degrada o
# avatar — ela sobe pelo layout e devolve 500 na página inteira, para todo
# mundo. Foi o que derrubou o Redmine em produção depois que um processo root
# criou o diretório de cache e o Puma, que roda como `redmine`, passou a tomar
# Errno::EACCES.
class AvatarFallbackTest < ActionView::TestCase
  include AvatarsHelper

  def setup
    @user = User.find(2)
    # Sem gravatar o fallback do core é initials_avatar_tag, que só monta um
    # <span> — nenhum acesso a disco, que é justamente o ponto.
    Setting.gravatar_enabled = '0'
  end

  def test_o_patch_do_tema_esta_ativo
    assert AvatarsHelper.include?(RedmineAsapTheme::ApplicationAvatarPatch),
           'sem o patch aplicado, este teste não estaria exercitando nada'
  end

  def test_falha_de_escrita_no_cache_nao_derruba_a_pagina
    stubs(:letter_avatar_tag).raises(Errno::EACCES, 'public/system/letter_avatars/2/JS')

    html = nil
    assert_nothing_raised { html = avatar(@user, :size => '40') }
    assert html.present?, 'deveria devolver o avatar do core, não vazio'
    assert_match(/<span/, html)
  end

  # Disco cheio e sistema de arquivos somente-leitura entram pela mesma porta.
  def test_outras_falhas_de_io_tambem_degradam
    stubs(:letter_avatar_tag).raises(Errno::ENOSPC, 'no space left on device')
    assert_nothing_raised { avatar(@user, :size => '40') }

    stubs(:letter_avatar_tag).raises(IOError, 'closed stream')
    assert_nothing_raised { avatar(@user, :size => '40') }
  end

  # A degradação não pode virar silêncio: quem opera precisa saber que o cache
  # parou de funcionar.
  def test_a_falha_e_registrada_no_log
    stubs(:letter_avatar_tag).raises(Errno::EACCES, 'boom')
    Rails.logger.expects(:error).with(regexp_matches(/letter avatar/))
    avatar(@user, :size => '40')
  end

  # E o caminho feliz continua sendo o do tema, não o do core.
  def test_sem_falha_usa_o_avatar_do_tema
    stubs(:letter_avatar_tag).returns('<img class="user-avatar">'.html_safe)
    assert_match(/user-avatar/, avatar(@user, :size => '40'))
  end
end
