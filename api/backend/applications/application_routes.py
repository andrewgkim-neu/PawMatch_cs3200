from flask import Blueprint, request, jsonify
from backend.db_connection import get_db

applications = Blueprint("applications", __name__)


# FET /applications/ -- page list and optional filters
@applications.route('/', methods=['GET'])
def get_applications():
    page     = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 10))
    offset   = (page - 1) * per_page
 
    adopter_id = request.args.get('adopter_id')
    animal_id  = request.args.get('animal_id')
    status     = request.args.get('status')
 
    query = """
        SELECT ap.application_id,
               ap.adopter_id,
               CONCAT(a.first_name, ' ', a.last_name) AS adopter_name,
               ap.animal_id,
               an.name        AS animal_name,
               ap.status,
               ap.notes,
               ap.submission_date,
               ap.decision_date
        FROM   application ap
        JOIN   adopter a  ON ap.adopter_id = a.adopter_id
        JOIN   animal  an ON ap.animal_id  = an.animal_id
        WHERE  1=1
    """
    params = []
 
    if adopter_id:
        query += " AND ap.adopter_id = %s"
        params.append(adopter_id)
    if animal_id:
        query += " AND ap.animal_id = %s"
        params.append(animal_id)
    if status:
        query += " AND ap.status = %s"
        params.append(status)
 
    query += " ORDER BY ap.submission_date DESC LIMIT %s OFFSET %s"
    params.extend([per_page, offset])
 
    db = get_db()
    cursor = db.cursor()
    cursor.execute(query, params)
    rows = cursor.fetchall()
    return jsonify(rows), 200

#GET /applications/<id> -- single application by id
@applications.route('/<int:application_id>', methods=['GET'])
def get_application(application_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT ap.application_id,
               ap.adopter_id,
               CONCAT(a.first_name, ' ', a.last_name) AS adopter_name,
               ap.animal_id,
               an.name        AS animal_name,
               ap.status,
               ap.notes,
               ap.submission_date,
               ap.decision_date
        FROM   application ap
        JOIN   adopter a  ON ap.adopter_id = a.adopter_id
        JOIN   animal  an ON ap.animal_id  = an.animal_id
        WHERE  ap.application_id = %s
    """, (application_id,))
    row = cursor.fetchone()
    if not row:
        return jsonify({"error": "Application not found"}), 404
    return jsonify(row), 200


#Post /application/ -- submit a new application
@applications.route('/', methods=['POST'])
def create_application():
    data = request.get_json()
    required = ['adopter_id', 'animal_id', 'submission_date']
    if not all(k in data for k in required):
        return jsonify({"error": f"Missing required fields: {required}"}), 400
 
    db = get_db()
    cursor = db.cursor()
 
    # Guard: animal must be Available before accepting an application
    cursor.execute(
        "SELECT status FROM animal WHERE animal_id = %s",
        (data['animal_id'],)
    )
    animal = cursor.fetchone()
    if not animal:
        return jsonify({"error": "Animal not found"}), 404
    if animal['status'] != 'Available':
        return jsonify({"error": f"Animal is not available (status: {animal['status']})"}), 409
 
    # Insert the application row
    cursor.execute("""
        INSERT INTO application
            (adopter_id, animal_id, status, notes, submission_date)
        VALUES (%s, %s, 'Pending', %s, %s)
    """, (
        data['adopter_id'],
        data['animal_id'],
        data.get('notes'),
        data['submission_date'],
    ))
    new_application_id = cursor.lastrowid
 
    # Flip animal status to Pending Adoption
    cursor.execute(
        "UPDATE animal SET status = 'Pending Adoption' WHERE animal_id = %s",
        (data['animal_id'],)
    )
 
    db.commit()
    return jsonify({
        "message": "Application submitted",
        "application_id": new_application_id
    }), 201


#PUT /application/<id> -- update the status, notes, decision date
@applications.route('/<int:application_id>', methods=['PUT'])
def update_application(application_id):
    data = request.get_json()
    allowed = ['status', 'notes', 'decision_date']
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return jsonify({"error": "No valid fields to update"}), 400
 
    db = get_db()
    cursor = db.cursor()
 
    # Fetch current application to get animal_id
    cursor.execute(
        "SELECT animal_id FROM application WHERE application_id = %s",
        (application_id,)
    )
    app = cursor.fetchone()
    if not app:
        return jsonify({"error": "Application not found"}), 404
 
    # Update the application row
    set_clause = ", ".join(f"{k} = %s" for k in updates)
    values = list(updates.values()) + [application_id]
    cursor.execute(
        f"UPDATE application SET {set_clause} WHERE application_id = %s",
        values
    )
 
    # Sync animal status based on the new application status
    new_status = updates.get('status')
    if new_status == 'Approved':
        cursor.execute(
            "UPDATE animal SET status = 'Adopted' WHERE animal_id = %s",
            (app['animal_id'],)
        )
    elif new_status in ('Denied', 'Withdrawn'):
        cursor.execute(
            "UPDATE animal SET status = 'Available' WHERE animal_id = %s",
            (app['animal_id'],)
        )
 
    db.commit()
    return jsonify({"message": "Application updated"}), 200
 

# DELETE /applications/<id>  -- delete an application record
@applications.route('/<int:application_id>', methods=['DELETE'])
def delete_application(application_id):
    db = get_db()
    cursor = db.cursor()
 
    # Fetch animal_id and status before deleting
    cursor.execute(
        "SELECT animal_id, status FROM application WHERE application_id = %s",
        (application_id,)
    )
    app = cursor.fetchone()
    if not app:
        return jsonify({"error": "Application not found"}), 404
 
    cursor.execute(
        "DELETE FROM application WHERE application_id = %s",
        (application_id,)
    )
 
    # Only reset animal if it was still pending (not yet adopted)
    if app['status'] in ('Pending', 'Under Review'):
        cursor.execute(
            "UPDATE animal SET status = 'Available' WHERE animal_id = %s",
            (app['animal_id'],)
        )
 
    db.commit()
    return jsonify({"message": "Application deleted"}), 200
 