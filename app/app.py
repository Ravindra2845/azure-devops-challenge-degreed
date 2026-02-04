import os
import pyodbc
from flask import Flask, render_template_string
from azure.identity import DefaultAzureCredential

app = Flask(__name__)

def get_db_connection():
    # 1. Get the connection string from Key Vault (injected as Env Var)
    conn_str = os.environ.get('SQL_CONN_STR')
    if not conn_str:
        raise ValueError("SQL_CONN_STR environment variable is missing")

    # 2. Connect DIRECTLY (Using the User/Pass from the string)
    # We removed the complex 'token_struct' logic here.
    conn = pyodbc.connect(conn_str)
    return conn

def seed_database(cursor):
    try:
        cursor.execute("SELECT count(*) FROM Quotes")
    except:
        print("Table not found. Creating and seeding...")
        cursor.execute("""
            CREATE TABLE Quotes (
                id INT IDENTITY(1,1) PRIMARY KEY,
                quote_text NVARCHAR(MAX),
                author NVARCHAR(255)
            )
        """)
        quotes = [
            ("The only limit to our realization of tomorrow is our doubts of today.", "Franklin D. Roosevelt"),
            ("Do not wait to strike till the iron is hot; but make it hot by striking.", "William Butler Yeats"),
            ("The future belongs to those who believe in the beauty of their dreams.", "Eleanor Roosevelt"),
            ("It does not matter how slowly you go as long as you do not stop.", "Confucius")
        ]
        cursor.executemany("INSERT INTO Quotes (quote_text, author) VALUES (?, ?)", quotes)
        cursor.commit()
        print("Database seeded successfully.")

@app.route('/')
def index():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        seed_database(cursor) 

        cursor.execute("SELECT TOP 1 quote_text, author FROM Quotes ORDER BY NEWID()")
        row = cursor.fetchone()
        conn.close()

        if row:
            return render_template_string("""
                <div style="font-family: sans-serif; text-align: center; margin-top: 50px;">
                    <h1>Daily Wisdom</h1>
                    <h2 style="color: #0078d4;">"{{ quote }}"</h2>
                    <p>- <strong>{{ author }}</strong></p>
                </div>
            """, quote=row[0], author=row[1])
        else:
            return "Database initialized. Please refresh page."
    except Exception as e:
        return f"<h3>Status: Starting up...</h3><p>Details: {str(e)}</p>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)