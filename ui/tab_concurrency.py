"""
ui/tab_concurrency.py — Renderização da Tab 8: Concorrência & Transações (Etapa 2)
"""

import threading
import time
import datetime as dt
import streamlit as st
from database.connection import get_orm_session, get_orm_url
from database.models import EscalaPlantao


def render_tab_concurrency():
    """Renderiza a simulação concorrente multi-threading."""
    st.subheader("⚡ Concorrência & Transações")
    st.markdown("""
    Simula duas transações concorrentes tentando modificar a tabela `ESCALA_PLANTAO`
    ao mesmo tempo.

    * **Bloqueio pessimista** (`SELECT ... FOR UPDATE NOWAIT`): a segunda thread
      falha imediatamente ao tentar bloquear um registro já bloqueado.
    * **Restrição estrutural** (Trigger + UNIQUE): o PostgreSQL rejeita o segundo
      INSERT via trigger, garantindo consistência sem lock explícito.
    """)

    modo_lock = st.radio(
        "Mecanismo de controle:",
        ["Bloqueio Pessimista (FOR UPDATE NOWAIT)",
         "Trigger + UNIQUE constraint"],
        horizontal=True, key="lock_mode"
    )

    lock_logs = []

    def log_msg(msg: str) -> None:
        lock_logs.append(f"[{dt.datetime.now().strftime('%H:%M:%S.%f')[:-3]}] {msg}")

    def tx_pessimistic(name: str, escala_id: int, novo_turno: str, hold_secs: float, url: str) -> None:
        """Tenta adquirir FOR UPDATE NOWAIT e alterar o turno da escala."""
        sess = get_orm_session(url=url)
        try:
            log_msg(f"{name}: tentando adquirir lock na escala #{escala_id}...")
            esc = (
                sess.query(EscalaPlantao)
                .filter(EscalaPlantao.id_escala == escala_id)
                .with_for_update(nowait=True)
                .one_or_none()
            )
            if esc is None:
                log_msg(f"{name}: escala #{escala_id} não encontrada.")
                return
            log_msg(f"{name}: 🔒 lock adquirido (turno atual = '{esc.turno}'). Aguardando {hold_secs}s...")
            time.sleep(hold_secs)
            esc.turno = novo_turno
            sess.commit()
            log_msg(f"{name}: ✅ COMMIT — turno alterado para '{novo_turno}'.")
        except Exception as ex:
            sess.rollback()
            log_msg(f"{name}: ❌ BLOQUEADO / ERRO: {ex}")
        finally:
            sess.close()

    def tx_conflict_insert(name: str, res_id: int, unidade_id: int,
                           dia: str, turno: str, pre_id: int, url: str) -> None:
        """Tenta inserir escala que conflita com outra já existente."""
        sess = get_orm_session(url=url)
        try:
            log_msg(f"{name}: tentando inserir escala "
                    f"(residente={res_id}, unidade={unidade_id}, {dia}/{turno})...")
            nova = EscalaPlantao(
                id_unidade=unidade_id,
                dia_semana=dia,
                turno=turno,
                id_papel_residente=res_id,
                id_papel_preceptor=pre_id,
            )
            sess.add(nova)
            time.sleep(0.3)
            sess.commit()
            log_msg(f"{name}: ✅ INSERT realizado com sucesso.")
        except Exception as ex:
            sess.rollback()
            log_msg(f"{name}: 🛑 REJEITADO (trigger/constraint): {ex}")
        finally:
            sess.close()

    if st.button("🔥 Executar simulação concorrente", key="btn_concorrencia"):
        lock_logs.clear()
        log_msg("Iniciando simulação...")
        db_url = get_orm_url()

        if modo_lock.startswith("Bloqueio Pessimista"):
            t1 = threading.Thread(target=tx_pessimistic, args=("Thread-A", 1, "noite", 2.0, db_url))
            t2 = threading.Thread(target=tx_pessimistic, args=("Thread-B", 1, "tarde", 0.0, db_url))
            t1.start()
            time.sleep(0.15)  # garante que A adquira o lock primeiro
            t2.start()
            t1.join()
            t2.join()
        else:
            # Thread-A insere residente 6 na unidade 2 (segunda/manhã),
            # Thread-B tenta o mesmo residente numa unidade diferente — trigger rejeita.
            t1 = threading.Thread(
                target=tx_conflict_insert, args=("Thread-A", 6, 2, "segunda", "manhã", 1, db_url))
            t2 = threading.Thread(
                target=tx_conflict_insert, args=("Thread-B", 6, 3, "segunda", "manhã", 1, db_url))
            t1.start()
            t2.start()
            t1.join()
            t2.join()

        log_msg("Simulação concluída.")
        st.subheader("📜 Log da execução")
        for line in lock_logs:
            if "✅" in line:
                st.success(line)
            elif "❌" in line or "🛑" in line:
                st.error(line)
            elif "🔒" in line:
                st.warning(line)
            else:
                st.info(line)
