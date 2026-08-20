import { Router } from "express";
import { consulta, transacao } from "./db.js";
import { exigeEditor } from "./auth.js";

const VAZIO = { partners: [], customers: [], deals: [] };

// Confere o formato antes de gravar. Não valida regra de negócio — isso é do
// painel — só impede gravar lixo por cima do que está bom.
function formatoOk(d) {
  return (
    d && typeof d === "object" &&
    Array.isArray(d.partners) && Array.isArray(d.customers) && Array.isArray(d.deals)
  );
}

export function rotasPipeline() {
  const r = Router();

  r.get("/pipeline", async (_req, res, next) => {
    try {
      const { rows } = await consulta(
        "select dados, versao, atualizado_em, atualizado_por from pipeline where id = 1",
      );
      if (!rows[0]) {
        res.json({ dados: VAZIO, versao: 0, atualizadoEm: null, atualizadoPor: null });
        return;
      }
      res.json({
        dados: rows[0].dados,
        versao: rows[0].versao,
        atualizadoEm: rows[0].atualizado_em,
        atualizadoPor: rows[0].atualizado_por,
      });
    } catch (e) {
      next(e);
    }
  });

  // Gravação com controle de versão: quem chegou com versão velha recebe 409 e
  // os dados atuais, em vez de passar por cima do trabalho do outro.
  r.put("/pipeline", exigeEditor, async (req, res, next) => {
    try {
      const { dados, versao } = req.body || {};
      if (!formatoOk(dados)) {
        res.status(400).json({ erro: "formato_invalido" });
        return;
      }
      const quem = req.usuario.nome;
      const saida = await transacao(async (c) => {
        const atual = await c.query("select versao, dados from pipeline where id = 1 for update");
        const versaoAtual = atual.rows[0]?.versao ?? 0;
        if (Number(versao) !== versaoAtual) {
          return { conflito: true, versao: versaoAtual, dados: atual.rows[0]?.dados ?? VAZIO };
        }
        if (atual.rows[0]) {
          // Guarda a versão que está saindo antes de sobrescrever.
          await c.query(
            `insert into pipeline_historico (versao, dados, atualizado_por)
             select versao, dados, atualizado_por from pipeline where id = 1`,
          );
          await c.query(
            `update pipeline
                set dados = $1, versao = versao + 1, atualizado_em = now(), atualizado_por = $2
              where id = 1`,
            [dados, quem],
          );
        } else {
          await c.query(
            `insert into pipeline (id, dados, versao, atualizado_por) values (1, $1, 1, $2)`,
            [dados, quem],
          );
        }
        const novo = await c.query("select versao, atualizado_em from pipeline where id = 1");
        return { versao: novo.rows[0].versao, atualizadoEm: novo.rows[0].atualizado_em };
      });

      if (saida.conflito) {
        res.status(409).json({
          erro: "versao_desatualizada",
          versao: saida.versao,
          dados: saida.dados,
        });
        return;
      }
      res.json({ versao: saida.versao, atualizadoEm: saida.atualizadoEm, atualizadoPor: quem });
    } catch (e) {
      next(e);
    }
  });

  // Lista as versões guardadas, sem os dados (só para saber o que existe).
  r.get("/versoes", async (_req, res, next) => {
    try {
      const { rows } = await consulta(
        `select versao, atualizado_em, atualizado_por,
                jsonb_array_length(dados->'deals') as negocios
           from pipeline_historico order by versao desc limit 50`,
      );
      res.json(rows);
    } catch (e) {
      next(e);
    }
  });

  return r;
}
