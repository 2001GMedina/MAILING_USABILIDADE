import os
import sys
import pandas as pd
from pathlib import Path

from mods.logger import setup_logger, get_logger
from mods.sql_server import connect_sql_server, run_query
from mods.google_sheets import (
    auth_google_sheets,
    clear_worksheet,
    insert_dataframe_to_worksheet,
)

# Base directory (directory where this main.py is located)
BASE_DIR = Path(__file__).resolve().parent

# Fixed project paths (always relative to BASE_DIR, not to current working dir)
SQL_FILE_PATH = BASE_DIR / "sql" / "mailing_usabilidade.sql"
ENV_FILE_PATH = BASE_DIR / ".env"
GOOGLE_CREDS_PATH = BASE_DIR / "config" / "g_creds.json"

# Worksheet name in Google Sheets
WORKSHEET_NAME = "MAILING_USABILIDADE"  # change if needed


def load_env(path: Path = ENV_FILE_PATH):
    """
    Load environment variables from a .env file into os.environ.
    Expected format:
        KEY=value
    Blank lines and lines starting with # are ignored.
    """
    if not path.exists():
        return

    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            # Do not overwrite existing environment variables
            if key and key not in os.environ:
                os.environ[key] = value


def carregar_sql(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Arquivo SQL não encontrado: {path}")

    with path.open("r", encoding="utf-8") as f:
        return f.read()


def validar_config(logger):
    """
    Ensure required variables are available.
    Uses CONN_STRING and URL loaded from .env or system env.
    """
    obrigatorias = ["CONN_STRING", "URL"]

    faltando = [v for v in obrigatorias if not os.getenv(v)]
    if faltando:
        logger.error(f"Variáveis de ambiente faltando: {', '.join(faltando)}")
        raise EnvironmentError(
            "Configure CONN_STRING e URL no arquivo .env ou no ambiente."
        )

    if not GOOGLE_CREDS_PATH.exists():
        logger.error(f"Arquivo de credenciais Google não encontrado: {GOOGLE_CREDS_PATH}")
        raise FileNotFoundError(
            f"Credenciais do Google não encontradas em {GOOGLE_CREDS_PATH}"
        )


def main():
    # 1) Logger
    setup_logger()
    logger = get_logger()
    logger.info("Iniciando processo de mailing_usabilidade")
    logger.info(f"BASE_DIR definido como: {BASE_DIR}")

    try:
        # 2) Load .env (from BASE_DIR)
        load_env()
        logger.info(f".env carregado (se existente) em: {ENV_FILE_PATH}")

        # 3) Validate configuration
        validar_config(logger)

        conn_str = os.getenv("CONN_STRING")
        sheet_url = os.getenv("URL")

        logger.info("Configurações básicas validadas com sucesso.")
        logger.info(f"Usando CONN_STRING: {conn_str[:30]}...")  # opcional, só prefixo
        logger.info(f"URL da planilha: {sheet_url}")

        # 4) Load SQL
        logger.info(f"Lendo arquivo SQL em: {SQL_FILE_PATH}")
        query = carregar_sql(SQL_FILE_PATH)

        # 5) Connect to SQL Server and run query
        logger.info("Conectando ao SQL Server...")
        conn = connect_sql_server(conn_str)
        logger.info("Conexão com SQL Server estabelecida.")

        try:
            logger.info("Executando consulta mailing_usabilidade...")
            df = run_query(conn, query)
        finally:
            conn.close()
            logger.info("Conexão com SQL Server fechada.")

        # 6) Validate result
        if df.empty:
            logger.warning("A consulta retornou 0 registros. Processo encerrado.")
            return

        # === DATE FORMATTING ===
        logger.info("Formatando campos de data (DATA_INICIO_PLANO, DATA_NASCIMENTO).")
        for col in ["DATA_INICIO_PLANO", "DATA_NASCIMENTO"]:
            if col in df.columns:
                df[col] = (
                    pd.to_datetime(df[col], errors="coerce")
                    .dt.strftime("%d/%m/%Y")
                )

        # === DESCONTO_VALOR formatting (dot -> comma) ===
        if "DESCONTO_VALOR" in df.columns:
            logger.info("Formatando campo DESCONTO_VALOR para usar vírgula.")
            df["DESCONTO_VALOR"] = pd.to_numeric(
                df["DESCONTO_VALOR"], errors="coerce"
            )
            df["DESCONTO_VALOR"] = df["DESCONTO_VALOR"].apply(
                lambda v: "" if pd.isna(v) else f"{v:.2f}".replace(".", ",")
            )

        logger.info("Tratando valores ausentes (NaN) nas demais colunas.")
        df = df.fillna("")

        logger.info(f"Consulta retornou {len(df)} registros.")
        logger.info(f"Colunas retornadas: {list(df.columns)}")

        # Ensure all values are strings for gspread
        df = df.astype(str)

        # 7) Authenticate with Google Sheets
        logger.info("Autenticando no Google Sheets...")
        client = auth_google_sheets(str(GOOGLE_CREDS_PATH))
        logger.info("Autenticação no Google Sheets realizada com sucesso.")

        # 8) Clear worksheet
        logger.info(f"Limpando aba '{WORKSHEET_NAME}' na planilha...")
        clear_worksheet(client, sheet_url, WORKSHEET_NAME)
        logger.info("Aba limpa com sucesso.")

        # 9) Send DataFrame to worksheet
        logger.info("Enviando dados para o Google Sheets...")
        insert_dataframe_to_worksheet(client, sheet_url, WORKSHEET_NAME, df)
        logger.info("Dados inseridos na planilha com sucesso!")

    except Exception as e:
        logger = get_logger()
        logger.error(f"Erro durante a execução: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
