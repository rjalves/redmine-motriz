Setting.ui_theme  = 'motriz'
Setting.app_title = 'Motriz Digital'
Setting.default_language = 'pt-BR'

u = User.find_by_login('admin')
u.update_columns(firstname: 'Roberto', lastname: 'Alves', language: 'pt-BR', must_change_passwd: false)

pessoas = [['Camila','Nogueira'],['Aline','Barbosa'],['Diego','Martins'],
           ['Rafael','Siqueira'],['Julia','Ferraz']]
usuarios = pessoas.map do |fn, ln|
  login = "#{fn.downcase}.#{ln.downcase}"
  User.find_by_login(login) || User.create!(login: login, firstname: fn, lastname: ln,
    mail: "#{login}@motriz.org.br", password: 'motriz123456', password_confirmation: 'motriz123456',
    language: 'pt-BR')
end

proj = Project.find_by_identifier('educacao') || Project.create!(
  name: 'Motriz Educação', identifier: 'educacao',
  description: 'Frente de atuação: melhoria da educação pública com equidade racial.')
proj.enabled_module_names = %w[issue_tracking time_tracking gantt calendar documents wiki files news]
proj.trackers = Tracker.all
proj.save!
papel = Role.find_by_name('Gerente') || Role.givable.first
usuarios.each { |x| Member.create!(project: proj, user: x, roles: [papel]) rescue nil }
Member.create!(project: proj, user: u, roles: [papel]) rescue nil

versao = proj.versions.find_by_name('Ciclo 2026.2') || Version.create!(project: proj, name: 'Ciclo 2026.2', effective_date: Date.new(2026,9,30))
cats = ['Alfabetização na Idade Certa','Escola das Adolescências','Recomposição das Aprendizagens','Educação Amazônia']
cats.each { |c| IssueCategory.create!(project: proj, name: c) rescue nil }

abertos  = IssueStatus.where(is_closed: false).order(:position).to_a
fechados = IssueStatus.where(is_closed: true).order(:position).to_a
prios    = IssuePriority.active.order(:position).to_a
tr       = Tracker.order(:position).to_a

dados = [
  ['Sem confirmação da secretaria para o Encontro Saber em Movimento', prios.last,  abertos[0], Date.today - 3,  0,  nil, cats[1]],
  ['Consolidar diagnóstico de alfabetização — Rede Municipal de Sobral', prios[-2], abertos[2] || abertos[1], Date.today + 7,  80, usuarios[0], cats[0]],
  ['Relatório de recomposição das aprendizagens — 12 redes de ensino',   prios[-2], abertos[1], Date.today + 15, 60, usuarios[1], cats[2]],
  ['Ajustar cronograma da imersão Escola das Adolescências',             prios[2],  abertos[1], Date.today + 12, 45, usuarios[2], cats[1]],
  ['Trilha de onboarding da turma 2026 do Trainee de Gestão Pública',    prios[2],  abertos[2] || abertos[1], Date.today + 21, 70, usuarios[3], cats[3]],
  ['Mapear lideranças públicas do território Amazônia',                  prios[0],  abertos[1], Date.today + 40, 25, usuarios[4], cats[3]],
  ['Publicar e-book Gestos que Alfabetizam',                             prios[2],  fechados[0], Date.today - 9, 100, usuarios[0], cats[0]],
  ['Base da onda 3 chegou sem código INEP em 4 escolas',                 prios[-1], abertos[1], Date.today - 1,  10, usuarios[1], cats[0]],
]
dados.each_with_index do |(assunto, prio, st, prazo, ratio, resp, cat), i|
  next if Issue.find_by_subject(assunto)
  Issue.create!(project: proj, tracker: tr[i % tr.size], author: u, subject: assunto,
    description: "Reunir os resultados das ondas de avaliação diagnóstica e produzir o consolidado que vai subsidiar o plano de recomposição.\n\nO consolidado precisa permitir leitura *por escola, por turma e por descritor*.",
    priority: prio, status: st, due_date: prazo, done_ratio: ratio,
    assigned_to: resp, category: IssueCategory.find_by(project: proj, name: cat), fixed_version: versao)
end
puts "tema=#{Setting.ui_theme}  projeto=#{proj.identifier}  tarefas=#{proj.issues.count}  usuarios=#{User.active.count}"
puts "statuses=#{IssueStatus.pluck(:id, :name).inspect}"
puts "prioridades=#{IssuePriority.active.map { |p| [p.id, p.name, p.position_name] }.inspect}"
