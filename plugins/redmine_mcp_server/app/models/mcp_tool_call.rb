# frozen_string_literal: true

# Registro de auditoria de uma chamada de ferramenta pelo MCP.
#
# Guarda o que aconteceu, não o que foi dito: os **nomes** dos argumentos, nunca
# os valores. Um `create_issue` carrega a descrição inteira da tarefa e um
# `add_issue_note` carrega o texto do comentário; duplicar isso aqui criaria uma
# segunda cópia de conteúdo sensível, num lugar sem as regras de visibilidade
# que protegem o original. O conteúdo em si continua rastreável onde sempre
# esteve — no journal da tarefa.
class McpToolCall < ApplicationRecord
  belongs_to :user

  # Ferramentas que identificam o objeto afetado, para a tela de auditoria
  # conseguir linkar.
  TARGETS = {
    'create_issue' => 'Issue', 'update_issue' => 'Issue',
    'add_issue_note' => 'Issue', 'log_time' => 'TimeEntry'
  }.freeze

  scope :recent, -> { order(created_on: :desc, id: :desc) }
  scope :failed, -> { where(ok: false) }
  scope :writes, -> { where(tool_name: TARGETS.keys) }

  def self.record!(user:, tool_name:, argument_keys:, structured:, error:, duration_ms:)
    create!(
      user_id: user.id,
      tool_name: tool_name,
      argument_keys: Array(argument_keys).sort.join(','),
      target_type: TARGETS[tool_name],
      target_id: extract_target_id(tool_name, structured),
      ok: error.nil?,
      error_code: error&.to_s&.truncate(255),
      duration_ms: duration_ms,
      created_on: Time.now
    )
  end

  def self.extract_target_id(tool_name, structured)
    return nil unless structured.is_a?(Hash)

    case tool_name
    when 'create_issue', 'update_issue' then structured['id']
    when 'add_issue_note' then structured['issue_id']
    when 'log_time' then structured['id']
    end
  end

  # Purga por idade, chamada pela rake task do plugin.
  def self.purge_older_than(days)
    return 0 if days.to_i <= 0

    where(created_on: ...days.to_i.days.ago).delete_all
  end
end
