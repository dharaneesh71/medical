from flask import Flask, jsonify, request
from flask_cors import CORS
import sqlite3
from datetime import datetime
from db import get_connection
from functools import wraps
from functools import wraps
from flask import request, jsonify


# ================= ROLE DECORATOR =================


def require_roles(allowed_roles):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            role = request.headers.get("X-Role")
            if role not in allowed_roles:
                return jsonify({"error": "Forbidden"}), 403
            return f(*args, **kwargs)
        return wrapper
    return decorator


app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})


# ================= INIT DB =================

def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    # ---------- PATIENTS ----------
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            date_of_birth TEXT,
            sex TEXT,
            note TEXT,
            is_active INTEGER DEFAULT 1
        )
    """)

    # ---------- MEDICATIONS ----------
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER,
            name TEXT,
            dosage TEXT,
            time TEXT,
            interval_hours INTEGER DEFAULT 8,
            is_active INTEGER DEFAULT 1
        )
    """)

    # ---------- ADHERENCE LOGS ----------
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS adherence_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER,
            medication_id INTEGER,
            status TEXT,
            timestamp TEXT
        )
    """)

    # ---------- USERS ----------
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            role TEXT
        )
    """)

    conn.commit()

    # ---------- SEED DATA ----------
    if cursor.execute("SELECT COUNT(*) FROM patients").fetchone()[0] == 0:

        cursor.execute("""
            INSERT INTO patients 
            (first_name, last_name, date_of_birth, sex, note)
            VALUES 
            ('John', 'Doe', '1980-05-12', 'Male', 'Diabetes patient')
        """)

        cursor.execute("""
            INSERT INTO patients 
            (first_name, last_name, date_of_birth, sex, note)
            VALUES 
            ('Mary', 'Smith', '1975-09-20', 'Female', 'Hypertension monitoring')
        """)

        cursor.execute(
            "INSERT INTO medications (patient_id,name,dosage,time,interval_hours) VALUES (1,'Aspirin','100mg','08:00',8)"
        )
        cursor.execute(
            "INSERT INTO medications (patient_id,name,dosage,time,interval_hours) VALUES (1,'Vitamin D','1000 IU','21:00',24)"
        )
        cursor.execute(
            "INSERT INTO medications (patient_id,name,dosage,time,interval_hours) VALUES (2,'Metformin','500mg','09:00',12)"
        )

    cursor.execute(
        "INSERT OR IGNORE INTO users (username,password,role) VALUES ('doctor1','1234','doctor')"
    )
    cursor.execute(
        "INSERT OR IGNORE INTO users (username,password,role) VALUES ('caregiver1','1234','caregiver')"
    )
    cursor.execute(
        "INSERT OR IGNORE INTO users (username,password,role) VALUES ('patient1','1234','patient')"
    )

    conn.commit()
    conn.close()
# ================= PATIENT =================


@app.get("/patients")
@require_roles(["doctor", "caregiver"])
def get_patients():
    conn = get_connection()
    rows = conn.execute("""
    SELECT 
        id,
        first_name,
        last_name,
        date_of_birth,
        sex,
        note
    FROM patients
    WHERE is_active=1
""").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


@app.post("/patients")
@require_roles(["doctor"])
def add_patient():
    data = request.get_json()
    conn = get_connection()

    conn.execute("""
        INSERT INTO patients
        (first_name, last_name, date_of_birth, sex, note)
        VALUES (?, ?, ?, ?, ?)
    """, (
        data["first_name"],
        data["last_name"],
        data.get("date_of_birth"),
        data.get("sex"),
        data.get("note"),
    ))

    conn.commit()
    conn.close()

    return jsonify({"message": "Patient added"}), 201


@app.delete("/patients/<int:patient_id>")
@require_roles(["doctor"])
def delete_patient(patient_id):
    conn = get_connection()
    conn.execute("DELETE FROM patients WHERE id=?", (patient_id,))
    conn.commit()
    conn.close()
    return jsonify({"message": "Patient deleted"})


# ================= MEDICATION =================

@app.get("/medications/<int:patient_id>")
@require_roles(["doctor", "caregiver", "patient"])
def get_medications(patient_id):
    conn = get_connection()
    rows = conn.execute(
        """
    SELECT id as medication_id, name, dosage, time, interval_hours
    FROM medications
    WHERE patient_id=? AND is_active=1
    """,
        (patient_id,)
    ).fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


@app.post("/medications")
@require_roles(["doctor", "caregiver"])
def add_medication():
    data = request.get_json()
    conn = get_connection()

    interval = data.get("interval_hours", 8)

    conn.execute(
        "INSERT INTO medications (patient_id,name,dosage,time,interval_hours) VALUES (?,?,?,?,?)",
        (
            data["patient_id"],
            data["name"],
            data["dosage"],
            data["time"],
            interval
        )
    )

    conn.commit()
    conn.close()

    return jsonify({"message": "Medication added"}), 201


@app.delete("/medications/<int:medication_id>")
@require_roles(["doctor"])
def delete_medication(medication_id):
    conn = get_connection()

    conn.execute(
        "UPDATE medications SET is_active=0 WHERE id=?",
        (medication_id,)
    )

    conn.commit()
    conn.close()

    return jsonify({"message": "Medication deactivated"})


@app.put("/medications/<int:medication_id>")
@require_roles(["doctor"])
def update_medication(medication_id):
    data = request.get_json()

    conn = get_connection()
    conn.execute(
        """
        UPDATE medications
        SET name=?, dosage=?, time=?, interval_hours=?
        WHERE id=?
        """,
        (
            data["name"],
            data["dosage"],
            data["time"],
            data.get("interval_hours", 8),
            medication_id
        )
    )
    conn.commit()
    conn.close()

    return jsonify({"message": "Medication updated"})


# ================= ADHERENCE =================

@app.post("/adherence/log")
@require_roles(["patient", "doctor", "caregiver"])
def log_adherence():
    data = request.get_json()
    conn = get_connection()
    cursor = conn.cursor()

    med = cursor.execute(
        "SELECT interval_hours FROM medications WHERE id=?",
        (data["medication_id"],)
    ).fetchone()

    interval = med["interval_hours"] if med else 8

    last_log = cursor.execute("""
        SELECT timestamp FROM adherence_logs
        WHERE patient_id=? AND medication_id=?
        ORDER BY timestamp DESC
        LIMIT 1
    """, (data["patient_id"], data["medication_id"])).fetchone()

    if last_log:
        last_time = datetime.fromisoformat(last_log["timestamp"])
        hours_passed = (datetime.now() - last_time).total_seconds() / 3600

        if hours_passed < interval:
            conn.close()
            return jsonify({
                "error": f"Too early. Next dose in {round(interval - hours_passed, 1)} hours."
            }), 400

    cursor.execute("""
        INSERT INTO adherence_logs (patient_id,medication_id,status,timestamp)
        VALUES (?,?,?,?)
    """, (
        data["patient_id"],
        data["medication_id"],
        data["status"],
        datetime.now().isoformat()
    ))

    conn.commit()
    conn.close()

    return jsonify({"message": "Logged"}), 201


@app.post("/adherence/reset/<int:patient_id>")
@require_roles(["doctor"])
def reset(patient_id):
    conn = get_connection()
    conn.execute(
        "DELETE FROM adherence_logs WHERE patient_id=?", (patient_id,))
    conn.commit()
    conn.close()
    return jsonify({"message": "Reset done"})


# ================= SUMMARY =================

@app.get("/adherence/summary/<int:patient_id>")
@require_roles(["doctor", "caregiver", "patient"])
def summary(patient_id):
    conn = get_connection()
    today = datetime.now().date().isoformat()

    rows = conn.execute("""
    SELECT adherence_logs.medication_id,
           adherence_logs.status,
           substr(adherence_logs.timestamp,1,10) as d
    FROM adherence_logs
    JOIN medications
        ON adherence_logs.medication_id = medications.id
    WHERE adherence_logs.patient_id=? 
      AND medications.is_active=1
""", (patient_id,)).fetchall()

    conn.close()

    taken = sum(1 for r in rows if r["status"] == "taken")
    missed = sum(1 for r in rows if r["status"] == "missed")
    total = len(rows)
    rate = round((taken/total)*100, 2) if total > 0 else 0

    today_status = {}
    for r in rows:
        if r["d"] == today:
            today_status[str(r["medication_id"])] = r["status"]

    return jsonify({
        "taken": taken,
        "missed": missed,
        "adherence_rate": rate,
        "today_status": today_status
    })
# ================= TREND =================

@app.get("/adherence/trend/<int:patient_id>")
@require_roles(["doctor", "caregiver"])
def adherence_trend(patient_id):

    conn = get_connection()

    rows = conn.execute("""
        SELECT 
            medications.name as medication_name,
            adherence_logs.status,
            adherence_logs.timestamp
        FROM adherence_logs
        JOIN medications 
            ON adherence_logs.medication_id = medications.id
        WHERE adherence_logs.patient_id = ?
        ORDER BY adherence_logs.timestamp ASC
    """, (patient_id,)).fetchall()

    conn.close()

    trend_data = {}

    for r in rows:
        med = r["medication_name"]
        if med not in trend_data:
            trend_data[med] = []

        trend_data[med].append({
            "status": r["status"],
            "timestamp": r["timestamp"]
        })

    return jsonify(trend_data)
# ================= LOG HISTORY =================


@app.get("/adherence/logs/<int:patient_id>")
def get_logs(patient_id):

    conn = get_connection()

    rows = conn.execute("""
        SELECT 
            adherence_logs.id,
            adherence_logs.status,
            adherence_logs.timestamp,
            medications.name as medication_name
        FROM adherence_logs
        JOIN medications 
            ON adherence_logs.medication_id = medications.id
        WHERE adherence_logs.patient_id = ?
        ORDER BY adherence_logs.timestamp DESC
    """, (patient_id,)).fetchall()

    conn.close()

    return jsonify([dict(r) for r in rows])


# ================= DOCTOR RISK =================

@app.get("/ai/risk-ranking")
@require_roles(["doctor"])
def risk_ranking():

    conn = get_connection()

    patients = conn.execute("""
        SELECT id, first_name, last_name
        FROM patients
        WHERE is_active=1
    """).fetchall()

    result = []

    for p in patients:
        logs = conn.execute(
            "SELECT status FROM adherence_logs WHERE patient_id=?",
            (p["id"],)
        ).fetchall()

        if not logs:
            adherence_rate = 0
        else:
            taken = sum(1 for r in logs if r["status"] == "taken")
            total = len(logs)
            adherence_rate = round((taken / total) * 100, 2)

        if adherence_rate >= 90:
            risk = "low"
            severity = 20
        elif adherence_rate >= 70:
            risk = "moderate"
            severity = 55
        else:
            risk = "high"
            severity = 85

        result.append({
            "id": p["id"],
            "first_name": p["first_name"],
            "last_name": p["last_name"],
            "adherence_rate": adherence_rate,
            "risk_level": risk,
            "severity_score": severity
        })

    conn.close()
    result.sort(key=lambda x: x["severity_score"], reverse=True)
    return jsonify(result)


# ================= LOGIN =================

@app.post("/login")
def login():
    data = request.get_json()

    username = data.get("username")
    password = data.get("password")

    conn = get_connection()
    user = conn.execute(
        "SELECT id, username, role FROM users WHERE username=? AND password=?",
        (username, password)
    ).fetchone()
    conn.close()

    if user:
        return jsonify(dict(user))
    else:
        return jsonify({"error": "Invalid credentials"}), 401


# ================= MAIN =================
if __name__ == "__main__":
    init_db()
    app.run(debug=True)
