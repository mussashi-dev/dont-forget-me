# DFM Team Hub MCP

Servidor MCP local para Antigravity, usando transporte stdio.

## Ferramentas
- project_status: caminho do projeto, branch e estado Git.
- list_project_files: inventário de arquivos, excluindo diretórios protegidos.
- read_project_file: leitura de arquivos de texto do projeto.
- create_new_project_file: cria arquivos novos; nunca sobrescreve.
- create_team_task / list_team_tasks / update_team_task: quadro de tarefas compartilhado em SQLite.

## Instalação (Windows PowerShell)
Na raiz do repositório:

\`\`\`powershell
py -3.11 -m venv .venv
.\\.venv\\Scripts\\Activate.ps1
python -m pip install -r tools\\dfm_team_mcp\\requirements.txt
\`\`\`

Copie \`.agents\\mcp_config.example.json\` para \`.agents\\mcp_config.json\` e ajuste os caminhos absolutos de Python e do projeto.

Reinicie/recarregue o Antigravity ou use o MCP manager para atualizar os servidores.

## Configuração
O exemplo espera:
- Python 3.11+ instalado.
- DFM_PROJECT_ROOT apontando para a pasta que contém \`project.godot\`.
- DFM_TEAM_DATA apontando para uma pasta local gravável para o banco SQLite.

## Segurança
- O servidor usa stdio local, sem abrir porta de rede.
- Não expõe terminal, shell arbitrário, Git push ou merge.
- Não apaga arquivos.
- Não sobrescreve arquivos existentes.
- Bloqueia .git, .godot, .env, .venv, node_modules e diretórios ocultos.
- O projeto tem regra em AGENTS.md exigindo autorização explícita antes de alterar arquivos de jogo existentes. Este MCP respeita essa regra.
- O banco SQLite fica fora do repositório, em DFM_TEAM_DATA.
