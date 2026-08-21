from playwright.sync_api import sync_playwright
import json, sys

OUT = "/Users/robertoalves/desenvolvimento/redmine-theme/design/validacao"
BASE = "http://localhost:3001"
achados = []

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1440, "height": 980}, device_scale_factor=2)

    # 1. Login
    pg.goto(f"{BASE}/login", wait_until="networkidle")
    pg.screenshot(path=f"{OUT}/01-login.png", full_page=False)
    pg.fill("#username", "admin"); pg.fill("#password", "motriz123456")
    pg.click("input[type=submit]"); pg.wait_for_load_state("networkidle")

    # 2. Lista de tarefas
    pg.goto(f"{BASE}/projects/educacao/issues?set_filter=1&sort=priority:desc", wait_until="networkidle")
    pg.wait_for_timeout(600)
    pg.screenshot(path=f"{OUT}/02-lista-tarefas.png", full_page=True)

    # medicoes na lista
    achados.append(("body font-family", pg.evaluate("getComputedStyle(document.body).fontFamily")))
    achados.append(("#header background", pg.evaluate("getComputedStyle(document.querySelector('#header')).backgroundColor")))
    achados.append(("#header background-image", pg.evaluate("getComputedStyle(document.querySelector('#header')).backgroundImage")[:70]))
    achados.append(("nav.top-menu background", pg.evaluate("getComputedStyle(document.querySelector('nav.top-menu')).backgroundColor")))
    achados.append(("#main flex-direction", pg.evaluate("getComputedStyle(document.querySelector('#main')).flexDirection")))
    achados.append(("h1 do header (texto)", pg.evaluate("getComputedStyle(document.querySelector('#header h1'),'::before').content")))
    achados.append(("#main-menu background", pg.evaluate("getComputedStyle(document.querySelector('#main-menu')).backgroundColor")))
    achados.append(("link do conteudo", pg.evaluate("const a=document.querySelector('#content a'); return a?getComputedStyle(a).color:'nenhum'") if False else pg.evaluate("(()=>{const a=document.querySelector('#content a');return a?getComputedStyle(a).color:'nenhum'})()")))
    achados.append(("h1 do conteudo", pg.evaluate("(()=>{const h=document.querySelector('#content h1');return h?getComputedStyle(h).color+' / '+getComputedStyle(h).fontFamily.split(',')[0]:'nenhum'})()")))
    achados.append(("td.subject alinhamento", pg.evaluate("(()=>{const t=document.querySelector('table.list td.subject');return t?getComputedStyle(t).textAlign:'nenhum'})()")))
    achados.append(("linha urgente tem marcador", pg.evaluate("(()=>{const t=document.querySelector('tr.issue[class*=priority-high] td.subject');return t?getComputedStyle(t).boxShadow:'nenhuma linha de alta prioridade'})()")))
    achados.append(("prazo vencido", pg.evaluate("(()=>{const t=document.querySelector('tr.overdue td.due_date');return t?getComputedStyle(t).color+' peso '+getComputedStyle(t).fontWeight:'nenhuma vencida'})()")))
    achados.append(("sidebar a esquerda?", pg.evaluate("(()=>{const s=document.querySelector('#sidebar'),c=document.querySelector('#content');if(!s||!c)return 'sem sidebar';return s.getBoundingClientRect().left < c.getBoundingClientRect().left ? 'SIM' : 'NAO'})()")))
    achados.append(("fonte Archivo carregou?", pg.evaluate("document.fonts.check('14px Archivo') ? 'SIM' : 'NAO'")))
    achados.append(("fonte Bricolage carregou?", pg.evaluate("document.fonts.check('26px \"Bricolage Grotesque\"') ? 'SIM' : 'NAO'")))

    # 3. Detalhe da tarefa
    href = pg.eval_on_selector("table.list td.subject a", "e => e.getAttribute('href')")
    pg.goto(f"{BASE}{href}", wait_until="networkidle"); pg.wait_for_timeout(400)
    pg.screenshot(path=f"{OUT}/03-detalhe-tarefa.png", full_page=True)

    # 4. Wiki / admin para checar telas densas
    pg.goto(f"{BASE}/admin", wait_until="networkidle"); pg.wait_for_timeout(300)
    pg.screenshot(path=f"{OUT}/04-administracao.png", full_page=False)

    # 5. Mobile
    m = b.new_page(viewport={"width": 390, "height": 844}, device_scale_factor=2, is_mobile=True, has_touch=True)
    m.goto(f"{BASE}/login", wait_until="networkidle")
    m.fill("#username","admin"); m.fill("#password","motriz123456")
    m.click("input[type=submit]"); m.wait_for_load_state("networkidle")
    m.goto(f"{BASE}/projects/educacao/issues", wait_until="networkidle"); m.wait_for_timeout(500)
    m.screenshot(path=f"{OUT}/05-mobile-lista.png", full_page=False)
    achados.append(("MOBILE #header bg", m.evaluate("getComputedStyle(document.querySelector('#header')).backgroundColor")))
    m.click(".js-flyout-menu-toggle-button"); m.wait_for_timeout(700)
    m.screenshot(path=f"{OUT}/06-mobile-flyout.png", full_page=False)
    achados.append(("MOBILE .flyout-menu bg", m.evaluate("getComputedStyle(document.querySelector('.flyout-menu')).backgroundColor")))
    achados.append(("MOBILE .flyout-menu h3 bg", m.evaluate("(()=>{const h=document.querySelector('.flyout-menu h3');return h?getComputedStyle(h).backgroundColor:'sem h3'})()")))

    b.close()

print(json.dumps(achados, ensure_ascii=False, indent=1))
