require_relative '../test_helper'

# Testes das ferramentas, exercitadas direto — sem HTTP.
class RedmineMcpServer::ToolsTest < ActiveSupport::TestCase
  T = RedmineMcpServer::Tools

  def setup
    @user = User.find(2)   # jsmith, membro do projeto 1
    User.current = @user
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'rate_limit' => '60'}
  end

  def teardown
    User.current = nil
  end

  def run_tool(klass, args = {})
    klass.new(@user).call(args)
  end

  # Dois cuidados aqui, os dois aprendidos na marra:
  #
  #   1. jsmith é membro de vários projetos, com papéis diferentes. Mexer em um
  #      papel só não muda allowed_to?(global: true), que aceita qualquer papel.
  #   2. Role#remove_permission! NÃO limpa a memoização de @allowed_permissions
  #      (app/models/role.rb:140-146), e User memoiza @roles. Sem recarregar, o
  #      objeto em memória continua respondendo com a permissão antiga.
  def grant(*permissions)
    Role.all.each { |r| r.add_permission!(*permissions) }
    reload_user
  end

  def revoke(*permissions)
    Role.all.each { |r| r.remove_permission!(*permissions) }
    reload_user
  end

  def reload_user
    @user = User.find(@user.id)
    User.current = @user
  end

  # ---------------------------------------------------------------- leitura

  def test_list_issues_devolve_so_o_que_o_usuario_enxerga
    out = run_tool(T::ListIssues, 'status' => 'all', 'limit' => 100)
    ids = out.structured['issues'].map { |i| i['id'] }
    visiveis = Issue.visible(@user).pluck(:id)
    assert (ids - visiveis).empty?, 'listou tarefa que o usuário não pode ver'
  end

  def test_list_issues_respeita_o_teto_de_100
    out = run_tool(T::ListIssues, 'limit' => 5000)
    assert_equal 100, out.structured['limit']
  end

  # IssueQuery inclui subprojetos por padrão, como as telas do Redmine. Manter
  # esse comportamento é o certo — o teste confere que nada de FORA da árvore
  # do projeto entrou.
  def test_list_issues_filtra_pela_arvore_do_projeto
    out = run_tool(T::ListIssues, 'project' => 'ecookbook', 'status' => 'all', 'limit' => 100)
    esperados = Project.find_by(identifier: 'ecookbook').self_and_descendants.pluck(:identifier)
    obtidos = out.structured['issues'].map { |i| i['project']['identifier'] }.uniq
    assert (obtidos - esperados).empty?, "vazou projeto de fora da árvore: #{obtidos - esperados}"
  end

  # Teste de segurança, então não pode virar skip por falta de fixture: cria a
  # tarefa invisível aqui mesmo, num projeto privado onde jsmith não é membro.
  def test_get_issue_recusa_tarefa_invisivel_sem_dizer_que_existe
    alheio = Project.where(is_public: false).find { |p| !@user.member_of?(p) }
    alheio ||= Project.generate!(is_public: false)
    invisivel = Issue.generate!(project: alheio, subject: 'confidencial')

    refute invisivel.visible?(@user), 'a fixture precisa ser realmente invisível'
    erro = assert_raises(T::Base::ExecutionError) { run_tool(T::GetIssue, 'id' => invisivel.id) }
    assert_match(/not found or not visible/, erro.message)
  end

  # A listagem não pode expor por outro caminho o que o get recusa.
  def test_list_issues_nao_traz_tarefa_de_projeto_alheio
    alheio = Project.where(is_public: false).find { |p| !@user.member_of?(p) }
    alheio ||= Project.generate!(is_public: false)
    invisivel = Issue.generate!(project: alheio, subject: 'confidencial')

    out = run_tool(T::ListIssues, 'status' => 'all', 'limit' => 100)
    refute_includes out.structured['issues'].map { |i| i['id'] }, invisivel.id
  end

  def test_get_issue_inexistente_da_a_mesma_mensagem_que_invisivel
    erro = assert_raises(T::Base::ExecutionError) { run_tool(T::GetIssue, 'id' => 999_999) }
    assert_match(/not found or not visible/, erro.message)
  end

  # Journal#visible? NÃO filtra nota privada — delega ao journalized. Quem filtra
  # é Issue#visible_journals_with_index. Este teste existe para o dia em que
  # alguém "simplificar" o presenter de volta.
  def test_nota_privada_nao_aparece_para_quem_nao_pode_ve_la
    issue = Issue.find(1)
    issue.init_journal(User.find(1), 'segredo industrial')
    issue.current_journal.private_notes = true
    issue.save!

    revoke(:view_private_notes)
    out = run_tool(T::GetIssue, 'id' => 1)
    notas = out.structured['journals'].map { |j| j['notes'] }
    refute_includes notas, 'segredo industrial'

    grant(:view_private_notes)
    out = run_tool(T::GetIssue, 'id' => 1)
    assert_includes out.structured['journals'].map { |j| j['notes'] }, 'segredo industrial'
  end

  def test_list_projects_so_traz_projetos_visiveis
    out = run_tool(T::ListProjects, 'limit' => 100)
    ids = out.structured['projects'].map { |p| p['id'] }
    assert (ids - Project.visible(@user).pluck(:id)).empty?
  end

  # A razão de existir da ferramenta: sem ela o assistente não converte
  # "atribuir ao Alberto" em assigned_to_id, porque nenhuma outra revela id de
  # pessoa. O escopo view_members era pedido no consentimento sem que nada o
  # usasse.
  def test_list_members_devolve_id_nome_e_papel
    out = run_tool(T::ListMembers, 'project_id' => 'ecookbook')
    membros = out.structured['members']
    assert membros.any?
    m = membros.first
    assert m['id'].is_a?(Integer)
    assert m['name'].present?
    assert_includes %w[user group], m['type']
    assert m['roles'].is_a?(Array)
  end

  # O id que ela devolve tem que servir de fato para assigned_to_id — é o único
  # motivo de a ferramenta existir.
  def test_id_de_list_members_serve_como_assigned_to_id
    grant(:add_issues)
    alvo = run_tool(T::ListMembers, 'project_id' => 'ecookbook')
             .structured['members'].find { |m| m['type'] == 'user' }

    out = run_tool(T::CreateIssue, 'project' => 'ecookbook', 'subject' => 'com responsável',
                                   'assigned_to_id' => alvo['id'])
    assert_equal alvo['id'], out.structured['assigned_to']['id']
  end

  # Montado explicitamente em vez de escolher um projeto das fixtures: jsmith é
  # membro de todos os privados que existem lá, então qualquer identificador
  # "óbvio" passaria no teste sem exercitar a visibilidade.
  def test_list_members_recusa_projeto_invisivel
    privado = Project.find(2)
    privado.update_columns(is_public: false)
    Member.where(project_id: privado.id, user_id: @user.id).destroy_all
    reload_user

    erro = assert_raises(T::Base::ExecutionError) do
      run_tool(T::ListMembers, 'project_id' => privado.identifier)
    end
    assert_match(/not found/i, erro.message)
  end

  def test_list_enumerations_traz_os_ids_necessarios_para_escrever
    out = run_tool(T::ListEnumerations)
    assert out.structured['trackers'].any?
    assert out.structured['issue_statuses'].any?
    assert out.structured['priorities'].any?
  end

  # ---------------------------------------------------------------- escrita

  def test_create_issue_cria_e_devolve_a_tarefa
    grant(:add_issues)
    out = assert_difference('Issue.count', 1) do
      run_tool(T::CreateIssue, 'project' => 'ecookbook', 'subject' => 'via MCP')
    end
    issue = Issue.find(out.structured['id'])
    assert_equal 'via MCP', issue.subject
    assert_equal @user, issue.author
  end

  def test_create_issue_recusa_sem_permissao
    revoke(:add_issues)
    assert_no_difference('Issue.count') do
      erro = assert_raises(T::Base::ExecutionError) do
        run_tool(T::CreateIssue, 'project' => 'ecookbook', 'subject' => 'não deveria')
      end
      assert_match(/add_issues/, erro.message)
    end
  end

  def test_create_issue_recusa_projeto_invisivel
    erro = assert_raises(T::Base::ExecutionError) do
      run_tool(T::CreateIssue, 'project' => 'projeto-que-nao-existe', 'subject' => 'x')
    end
    assert_match(/Project not found/, erro.message)
  end

  # Sem init_journal, o save não gera histórico. Este teste trava isso.
  def test_update_issue_gera_journal
    grant(:edit_issues)
    issue = Issue.find(1)
    assert_difference('Journal.count', 1) do
      run_tool(T::UpdateIssue, 'id' => issue.id, 'subject' => 'assunto novo',
                               'notes' => 'mudado pela IA')
    end
    assert_equal 'assunto novo', issue.reload.subject
    assert_equal 'mudado pela IA', issue.journals.last.notes
  end

  def test_update_issue_recusa_sem_permissao
    revoke(:edit_issues, :edit_own_issues)
    erro = assert_raises(T::Base::ExecutionError) do
      run_tool(T::UpdateIssue, 'id' => 1, 'subject' => 'não deveria')
    end
    assert_match(/cannot edit/, erro.message)
  end

  def test_add_issue_note_exige_set_notes_private_para_nota_privada
    grant(:add_issue_notes)
    revoke(:set_notes_private)
    erro = assert_raises(T::Base::ExecutionError) do
      run_tool(T::AddIssueNote, 'id' => 1, 'notes' => 'oi', 'private' => true)
    end
    assert_match(/set_notes_private/, erro.message)
  end

  def test_add_issue_note_recusa_texto_vazio
    grant(:add_issue_notes)
    assert_raises(T::Base::ExecutionError) do
      run_tool(T::AddIssueNote, 'id' => 1, 'notes' => '   ')
    end
  end

  def test_log_time_aponta_horas
    grant(:log_time)
    out = assert_difference('TimeEntry.count', 1) do
      run_tool(T::LogTime, 'issue_id' => 1, 'hours' => 1.5, 'comments' => 'via MCP')
    end
    assert_equal 1.5, out.structured['hours']
  end

  def test_log_time_recusa_sem_permissao
    revoke(:log_time)
    assert_no_difference('TimeEntry.count') do
      assert_raises(T::Base::ExecutionError) { run_tool(T::LogTime, 'issue_id' => 1, 'hours' => 1) }
    end
  end

  def test_log_time_recusa_horas_nao_positivas
    grant(:log_time)
    assert_raises(T::Base::ExecutionError) { run_tool(T::LogTime, 'issue_id' => 1, 'hours' => 0) }
  end

  # ------------------------------------------------- o escopo OAuth vale aqui

  # O ponto central do desenho: o escopo do token limita allowed_to? sozinho,
  # via Role#allowed_to?(action, @oauth_scope). Nenhum código do plugin faz isso.
  def test_escopo_oauth_restringe_as_ferramentas_disponiveis
    grant(:add_issues, :log_time)
    @user.oauth_scope = [:view_issues, :view_project, :search_project, :view_members]

    assert T::ListIssues.available_to?(@user)
    refute T::CreateIssue.available_to?(@user), 'escopo sem add_issues não pode expor create_issue'
    refute T::LogTime.available_to?(@user)
  end

  def test_escopo_oauth_barra_a_execucao_e_nao_so_a_listagem
    grant(:add_issues)
    @user.oauth_scope = [:view_issues, :view_project]

    erro = assert_raises(T::Base::ExecutionError) do
      run_tool(T::CreateIssue, 'project' => 'ecookbook', 'subject' => 'fora do escopo')
    end
    assert_match(/add_issues/, erro.message)
  end
end
