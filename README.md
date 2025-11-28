# Mailing Usability Automation

This project automates the full pipeline of generating a mailing dataset by:

- Connecting to a **SQL Server** database  
- Executing a predefined SQL script (`mailing_usabilidade.sql`)  
- Processing and formatting the data (dates, numeric values, missing fields)  
- Cleaning a worksheet in **Google Sheets**  
- Uploading the fresh dataset to the specified sheet  

This ensures a consistent, fast, and error-free update flow for mailing usage data.

---

## 📁 Project Structure

MAILING_USABILIDADE/
│
├── config/
│ ├── g_creds.json # Google Service Account credentials
│ └── g_creds_mold.txt # Template for credentials
│
├── mods/
│ ├── google_sheets.py # Google Sheets integration module
│ ├── logger.py # Logging utilities
│ └── sql_server.py # SQL Server connection & query runner
│
├── output/
│ └── app.log # Execution logs
│
├── sql/
│ ├── draft.sql
│ ├── inadimplentes.sql
│ └── mailing_usabilidade.sql # Main SQL query used in the automation
│
├── venv/ # Python virtual environment (ignored in Git)
│
├── .env # Environment variables (ignored in Git)
├── .gitignore
├── dot_env.txt # Example of .env structure
├── main.py # Main automation script
└── requirements.txt # Python dependencies


---

## ⚙️ Requirements

Install the necessary Python dependencies:

```bash
pip install -r requirements.txt

Recommended Python version: 3.10+

🔧 Environment Variables

The project expects a .env file in the root directory with:

CONN_STRING=your_sql_server_connection_string
URL=https://your-google-sheet-url


A template is available at:
dot_env.txt

You must also place your Google Service Account credentials at:
config/g_creds.json

▶️ How to Run

Simply execute:

python main.py

The script will:

Load .env variables

Connect to SQL Server

Run the mailing_usabilidade query

Format the resulting dataset

Authenticate with Google Sheets

Clear the target worksheet

Upload the new data

🧩 Key Modules
mods/sql_server.py

Handles the connection and query execution using pyodbc.

mods/google_sheets.py

Provides authentication, cleaning, and updating of Google Sheets via gspread.

mods/logger.py

Manages structured logging to both console and file.

📝 SQL Scripts

The /sql directory contains queries used to extract and preprocess mailing datasets.
The main script executed by the automation is:

sql/mailing_usabilidade.sql

🛡️ Logging

Execution logs are saved automatically in:

output/app.log

This helps track issues, execution status, and audit history.


