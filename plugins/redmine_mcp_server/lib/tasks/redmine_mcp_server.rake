namespace :redmine_mcp_server do
  desc 'Apaga registros de auditoria do MCP mais antigos que a retenção configurada'
  task purge_audit: :environment do
    days = RedmineMcpServer::Config.settings['retention_days'].to_i
    if days <= 0
      puts 'Retenção desligada (retention_days = 0); nada a fazer.'
    else
      removed = McpToolCall.purge_older_than(days)
      puts "Removidos #{removed} registro(s) com mais de #{days} dia(s)."
    end
  end
end
