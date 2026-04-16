from flask import Blueprint, request, jsonify, current_app
from backend.db_connection import get_db
from mysql.connector import Error

animals = Blueprint("animals", __name__)


# ------------------------------------------------------------
# GET /animals/
# List all animals with optional query-param filters.
# Example: /animals/?species=Dog&status=Available&min_age=12&max_age=48
# User stories: [Lisa-1], [Ayla-4]
# ------------------------------------------------------------
@animals.route("/", methods=["GET"])
def get_animals():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /a/")

        species = request.args.get("species")
        breed   = request.args.get("breed")
        status  = request.args.get("status")
        min_age = request.args.get("min_age")
        max_age = request.args.get("max_age")

        query = """
            SELECT animal_id, name, species, breed,
                   age_months, status, intake_date,
                   DATEDIFF(CURDATE(), intake_date) AS days_in_shelter,
                   flagged
            FROM   animal
            WHERE  1 = 1
        """
        params = []

        if species:
            query += " AND species = %s"
            params.append(species)
        if breed:
            query += " AND breed LIKE %s"
            params.append(f"%{breed}%")
        if status:
            query += " AND status = %s"
            params.append(status)
        if min_age:
            query += " AND age_months >= %s"
            params.append(int(min_age))
        if max_age:
            query += " AND age_months <= %s"
            params.append(int(max_age))

        query += " ORDER BY intake_date ASC"

        cursor.execute(query, params)
        animals_list = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(animals_list)} animals")
        return jsonify(animals_list), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_animals: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /animals/
# Create a new animal profile.
# Required fields: name, species
# Example: POST /animals/ with JSON body
# User stories: [Ayla-2]
# ------------------------------------------------------------
@animals.route("/", methods=["POST"])
def add_animal():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["name", "species"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO animal (name, species, breed, age_months, intake_date, status)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                data["name"],
                data["species"],
                data.get("breed"),
                data.get("age_months"),
                data.get("intake_date"),
                data.get("status", "Available"),
            ),
        )
        get_db().commit()

        current_app.logger.info(f"add_animal(): created animal_id={cursor.lastrowid}")
        return jsonify({"message": "Animal created successfully", "animal_id": cursor.lastrowid}), 201
    except Error as e:
        current_app.logger.error(f"Database error in add_animal: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /animals/flagged
# Return all animals flagged for extra promotion or foster placement.
# Example: /a/flagged
# User stories: [Ayla-5]
# ------------------------------------------------------------
@animals.route("/flagged", methods=["GET"])
def get_flagged_animals():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /a/flagged")

        cursor.execute(
            """
            SELECT animal_id, name, species, breed, status,
                   DATEDIFF(CURDATE(), intake_date) AS days_in_shelter
            FROM   animal
            WHERE  flagged = TRUE
            ORDER  BY days_in_shelter DESC
            """
        )
        flagged_list = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(flagged_list)} flagged animals")
        return jsonify(flagged_list), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_flagged_animals: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /animals/duplicates
# Return animal pairs sharing the same name and species.
# Example: /animals/duplicates
# User stories: [John-4]
# ------------------------------------------------------------
@animals.route("/duplicates", methods=["GET"])
def get_duplicate_animals():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /a/duplicates")

        cursor.execute(
            """
            SELECT a1.animal_id AS record_1_id,
                   a2.animal_id AS record_2_id,
                   a1.name,
                   a1.species
            FROM   animal a1
            JOIN   animal a2
                   ON  a1.animal_id < a2.animal_id
                   AND a1.name      = a2.name
                   AND a1.species   = a2.species
            """
        )
        duplicates = cursor.fetchall()

        current_app.logger.info(f"Found {len(duplicates)} duplicate pairs")
        return jsonify(duplicates), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_duplicate_animals: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /a/<animal_id>
# Return full animal profile including all medical records.
# Example: /a/1
# User stories: [Lisa-5]
# ------------------------------------------------------------
@animals.route("/<int:animal_id>", methods=["GET"])
def get_animal(animal_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT animal_id, name, species, breed,
                   age_months, status, intake_date,
                   DATEDIFF(CURDATE(), intake_date) AS days_in_shelter,
                   flagged
            FROM   animal
            WHERE  animal_id = %s
            """,
            (animal_id,),
        )
        animal = cursor.fetchone()

        if not animal:
            return jsonify({"error": "Animal not found"}), 404

        # Reuse the same cursor for the follow-up medical records query
        cursor.execute(
            """
            SELECT record_id, category, admin_date,
                   practitioner_name, notes
            FROM   medical_record
            WHERE  animal_id = %s
            ORDER  BY admin_date DESC
            """,
            (animal_id,),
        )
        animal["medical_records"] = cursor.fetchall()

        return jsonify(animal), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_animal: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# PUT /animals/<animal_id>
# Update animal fields (status, flagged, breed, age, etc).
# Can update any field except animal_id.
# Example: PUT /animals/1 with JSON body containing fields to update
# User stories: [John-3], [Ayla-5]
# ------------------------------------------------------------
@animals.route("/<int:animal_id>", methods=["PUT"])
def update_animal(animal_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        cursor.execute("SELECT animal_id FROM animal WHERE animal_id = %s", (animal_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Animal not found"}), 404

        allowed_fields = ["name", "species", "breed", "age_months", "status", "flagged"]
        update_fields = [f"{f} = %s" for f in allowed_fields if f in data]
        params = [data[f] for f in allowed_fields if f in data]

        if not update_fields:
            return jsonify({"error": "No valid fields to update"}), 400

        params.append(animal_id)
        cursor.execute(
            f"UPDATE animal SET {', '.join(update_fields)} WHERE animal_id = %s",
            params,
        )
        get_db().commit()

        current_app.logger.info(f"update_animal(): updated animal_id={animal_id}")
        return jsonify({"message": "Animal updated successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in update_animal: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# DELETE /animals/<animal_id>
# Remove an animal record (e.g. confirmed duplicate cleanup).
# Example: DELETE /animals/1
# User stories: [John-4]
# ------------------------------------------------------------
@animals.route("/<int:animal_id>", methods=["DELETE"])
def delete_animal(animal_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        cursor.execute("SELECT animal_id FROM animal WHERE animal_id = %s", (animal_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Animal not found"}), 404

        cursor.execute("DELETE FROM animal WHERE animal_id = %s", (animal_id,))
        get_db().commit()

        current_app.logger.info(f"delete_animal(): deleted animal_id={animal_id}")
        return jsonify({"message": "Animal deleted successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in delete_animal: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /animals/<animal_id>/medical
# Attach a new medical record to an animal.
# Required fields: category, admin_date
# Example: POST /animals/1/medical with JSON body
# User stories: [Ayla-1]
# ------------------------------------------------------------
@animals.route("/<int:animal_id>/medical", methods=["POST"])
def add_medical_record(animal_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        cursor.execute("SELECT animal_id FROM animal WHERE animal_id = %s", (animal_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Animal not found"}), 404

        required_fields = ["category", "admin_date"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO medical_record
                (animal_id, category, admin_date, practitioner_name, notes)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                animal_id,
                data["category"],
                data["admin_date"],
                data.get("practitioner_name"),
                data.get("notes"),
            ),
        )
        get_db().commit()

        current_app.logger.info(f"add_medical_record(): created record_id={cursor.lastrowid} for animal_id={animal_id}")
        return jsonify({"message": "Medical record added successfully", "record_id": cursor.lastrowid}), 201
    except Error as e:
        current_app.logger.error(f"Database error in add_medical_record: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()