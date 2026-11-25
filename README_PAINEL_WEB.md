# Painel web do backend mock

O painel está em `web/admin.html` e usa como padrão a API `https://api-drytech.onrender.com/api`.

Para abrir localmente, execute na raiz do projeto:

```bash
python -m http.server 8080
```

Depois acesse `http://localhost:8080/web/admin.html`.

O painel usa as rotas existentes para criar ciclos, pausar, retomar e cancelar ciclos, e reconhecer alertas. A tela inicial do app consulta os ciclos do backend a cada 5 segundos.

A API atual não expõe uma rota genérica para editar telemetria ou campos de um ciclo já existente. O painel, portanto, altera apenas os dados que as rotas atuais permitem.
