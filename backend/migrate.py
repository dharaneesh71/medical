import sqlite3

conn = sqlite3.connect("adherence.db")
cursor = conn.cursor()

# add patient_id column if not exists
try:
    cursor.execute("ALTER TABLE users ADD COLUMN patient_id INTEGER;")
    print("Column added.")
except:
    print("Column probably already exists.")

conn.commit()
conn.close()
