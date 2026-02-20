import sqlite3

conn = sqlite3.connect("adherence.db")
cursor = conn.cursor()

# connect patient1 to patient_id = 1
cursor.execute("""
    UPDATE users
    SET patient_id = 1
    WHERE username = 'patient1';
""")

conn.commit()
conn.close()

print("patient1 linked to patient_id = 1")
