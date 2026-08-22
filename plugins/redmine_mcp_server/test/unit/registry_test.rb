require_relative '../test_helper'

class RedmineMcpServer::RegistryTest < ActiveSupport::TestCase
  R = RedmineMcpServer::Registry

  def setup
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  # Recarrega o usuário depois de mexer em papéis: Role#remove_permission! não
  # limpa a memoização de @allowed_permissions (app/models/role.rb:140-146) e
  # User memoiza @roles.
  def revoke(user, *permissions)
    Role.all.each { |r| r.remove_permission!(*permissions) }
    User.find(user.id)
  end

  def grant(user, *permissions)
    Role.all.each { |r| r.add_permission!(*permissions) }
    User.find(user.id)
  end

  # A especificação permite que a lista varie pela autorização apresentada.
  # É esse o mecanismo que impede alguém de leitura de sequer ver create_issue.
  def test_usuario_sem_permissao_de_escrita_nao_ve_as_ferramentas_de_escrita
    user = revoke(User.find(2), :add_issues, :edit_issues, :add_issue_notes, :log_time)

    nomes = R.definitions_for(user).map { |d| d['name'] }
    assert_includes nomes, 'list_issues'
    refute_includes nomes, 'create_issue'
    refute_includes nomes, 'update_issue'
    refute_includes nomes, 'log_time'
  end

  def test_usuario_com_permissao_ve_as_ferramentas_de_escrita
    user = grant(User.find(2), :add_issues, :edit_issues)

    nomes = R.definitions_for(user).map { |d| d['name'] }
    assert_includes nomes, 'create_issue'
    assert_includes nomes, 'update_issue'
  end

  def test_anonimo_nao_ve_ferramenta_alguma
    assert_empty R.definitions_for(User.anonymous)
  end

  # Resolver por nome tem que aplicar a mesma checagem da listagem, senão
  # esconder a ferramenta seria só cosmético.
  def test_resolve_recusa_ferramenta_que_o_usuario_nao_pode_usar
    user = revoke(User.find(2), :add_issues)
    assert_nil R.resolve('create_issue', user)
    assert_nil R.resolve('ferramenta_que_nao_existe', user)
  end

  def test_definicoes_tem_o_formato_que_a_especificacao_exige
    user = grant(User.find(2), :add_issues)
    R.definitions_for(user).each do |d|
      assert d['name'].present?, 'toda tool precisa de name'
      assert d['description'].present?, "#{d['name']} sem description"
      assert_equal 'object', d['inputSchema']['type'], "#{d['name']} com inputSchema inválido"
      assert d['annotations'].key?('readOnlyHint'), "#{d['name']} sem readOnlyHint"
      assert_match(/\A[A-Za-z0-9_.-]{1,128}\z/, d['name'], "#{d['name']} fora do charset permitido")
    end
  end

  def test_as_ferramentas_de_escrita_nao_se_declaram_somente_leitura
    %w[create_issue update_issue add_issue_note log_time].each do |nome|
      a = R.find(nome).annotations
      refute a['readOnlyHint'], "#{nome} não pode ser readOnly"
    end
    assert R.find('update_issue').annotations['destructiveHint'],
           'update_issue sobrescreve valores: precisa de destructiveHint'
  end

  def test_a_ordem_da_lista_e_estavel
    assert_equal R.definitions_for(User.find(1)), R.definitions_for(User.find(1))
  end
end
