# O middleware OmniAuth trata /auth/google (fase de request) e
# /auth/google/callback (fase de callback) e então repassa a requisição adiante
# — por isso o callback precisa de rota no Rails. /auth/failure é o on_failure
# padrão do OmniAuth.
match 'auth/google/callback', to: 'google_sso#callback', via: [:get, :post], as: 'google_sso_callback'
match 'auth/failure',         to: 'google_sso#failure',  via: [:get, :post], as: 'google_sso_failure'
