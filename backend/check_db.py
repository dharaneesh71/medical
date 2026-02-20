import sqlite3

conn = sqlite3.connect("adherence.db")
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

print("=== TABLES ===")
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()
for t in tables:
    print(t["name"])

print("\n=== PATIENTS ===")
cursor.execute("SELECT * FROM patients;")
for row in cursor.fetchall():
    print(dict(row))

print("\n=== MEDICATIONS ===")
cursor.execute("SELECT * FROM medications;")
for row in cursor.fetchall():
    print(dict(row))

print("\n=== LOGS ===")
cursor.execute("SELECT * FROM adherence_logs;")
for row in cursor.fetchall():
    print(dict(row))



print("\n=== USERS ===")
cursor.execute("SELECT * FROM users;")
for row in cursor.fetchall():
    print(dict(row))

conn.close()