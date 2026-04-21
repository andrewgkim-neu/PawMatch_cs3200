from flask import Blueprint, request, jsonify
from backend.db_connection import get_db

foster_placements = Blueprint("foster_placements", __name__)


# GET /foster_placements/         — paginated list, optional filters
@foster_placements.route('/', methods=['GET'])
def get_foster_placements():
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 30))
    offset = (page - 1) * per_page

    # Optional query filters
    animal_id  = request.args.get('animal_id')
    adopter_id = request.args.get('adopter_id')
    return_reason = request.args.get('return_reason')

    base_query = """
        SELECT fp.placement_id,
               fp.adopter_id,
               CONCAT(a.first_name, ' ', a.last_name) AS foster_name,
               fp.animal_id,
               an.name AS animal_name,
               fp.start_date,
               fp.end_date,
               fp.return_reason,
               fp.health_notes,
               fp.behavior_notes
        FROM   foster_placement fp
        JOIN   adopter a  ON fp.adopter_id = a.adopter_id
        JOIN   animal  an ON fp.animal_id  = an.animal_id
        WHERE  1=1
    """
    params = []

    if animal_id:
        base_query += " AND fp.animal_id = %s"
        params.append(animal_id)
    if adopter_id:
        base_query += " AND fp.adopter_id = %s"
        params.append(adopter_id)
    if return_reason:
        base_query += " AND fp.return_reason = %s"
        params.append(return_reason)

    base_query += " ORDER BY fp.start_date DESC LIMIT %s OFFSET %s"
    params.extend([per_page, offset])

    db = get_db()
    cursor = db.cursor(dictionary=True)
    cursor.execute(base_query, params)
    rows = cursor.fetchall()
    return jsonify(rows), 200



# GET /foster_placements/<id>     — single placement by ID
@foster_placements.route('/<int:placement_id>', methods=['GET'])
def get_foster_placement(placement_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT fp.placement_id,
               fp.adopter_id,
               CONCAT(a.first_name, ' ', a.last_name) AS foster_name,
               fp.animal_id,
               an.name  AS animal_name,
               fp.start_date,
               fp.end_date,
               fp.return_reason,
               fp.health_notes,
               fp.behavior_notes
        FROM   foster_placement fp
        JOIN   adopter a  ON fp.adopter_id = a.adopter_id
        JOIN   animal  an ON fp.animal_id  = an.animal_id
        WHERE  fp.placement_id = %s
    """, (placement_id,))
    row = cursor.fetchone()
    if not row:
        return jsonify({"error": "Placement not found"}), 404
    return jsonify(row), 200


# POST /foster_placements/        — create a new placement
@foster_placements.route('/', methods=['POST'])
def create_foster_placement():
    data = request.get_json()
    required = ['adopter_id', 'animal_id', 'start_date']
    if not all(k in data for k in required):
        return jsonify({"error": f"Missing required fields: {required}"}), 400

    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO foster_placement
            (adopter_id, animal_id, start_date, end_date,
             health_notes, behavior_notes, return_reason)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (
        data['adopter_id'],
        data['animal_id'],
        data['start_date'],
        data.get('end_date'),
        data.get('health_notes'),
        data.get('behavior_notes'),
        data.get('return_reason')
    ))
    # Update animal status to Fostered
    cursor.execute("""
        UPDATE animal SET status = 'Fostered'
        WHERE animal_id = %s
    """, (data['animal_id'],))
    db.commit()
    return jsonify({"message": "Placement created", "placement_id": cursor.lastrowid}), 201



# PUT /foster_placements/<id>     — update notes / end date / reason
@foster_placements.route('/<int:placement_id>', methods=['PUT'])
def update_foster_placement(placement_id):
    data = request.get_json()
    allowed = ['health_notes', 'behavior_notes', 'end_date', 'return_reason']
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return jsonify({"error": "No valid fields to update"}), 400

    set_clause = ", ".join(f"{k} = %s" for k in updates)
    values = list(updates.values()) + [placement_id]

    db = get_db()
    cursor = db.cursor()
    cursor.execute(
        f"UPDATE foster_placement SET {set_clause} WHERE placement_id = %s",
        values
    )
    # If an end_date was set, mark the animal available again
    if 'end_date' in updates and updates['end_date']:
        cursor.execute("""
            UPDATE animal SET status = 'Available'
            WHERE animal_id = (
                SELECT animal_id FROM foster_placement WHERE placement_id = %s
            )
        """, (placement_id,))
    db.commit()
    return jsonify({"message": "Placement updated"}), 200



# DELETE /foster_placements/<id>  — remove a placement record
@foster_placements.route('/<int:placement_id>', methods=['DELETE'])
def delete_foster_placement(placement_id):
    db = get_db()
    cursor = db.cursor()

    # Grab animal_id before deleting so we can reset its status
    cursor.execute(
        "SELECT animal_id FROM foster_placement WHERE placement_id = %s",
        (placement_id,)
    )
    row = cursor.fetchone()
    if not row:
        return jsonify({"error": "Placement not found"}), 404

    cursor.execute(
        "DELETE FROM foster_placement WHERE placement_id = %s",
        (placement_id,)
    )
    cursor.execute(
        "UPDATE animal SET status = 'Available' WHERE animal_id = %s",
        (row['animal_id'],)
    )
    db.commit()
    return jsonify({"message": "Placement deleted"}), 200