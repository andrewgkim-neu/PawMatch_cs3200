from flask import Blueprint, request, jsonify, current_app
from backend.db_connection import get_db
from mysql.connector import Error

adopters = Blueprint("adopters", __name__)


# ------------------------------------------------------------
# GET /adopters/applications
# List all applications; filter by adopter, animal, or status.
# Example: /adopters/applications?status=Pending
# User stories: [Ayla-3]
# ------------------------------------------------------------
@adopters.route("/applications", methods=["GET"])
def get_applications():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /adopters/applications")

        adopter_id = request.args.get("adopter_id")
        animal_id  = request.args.get("animal_id")
        status     = request.args.get("status")

        query = """
            SELECT app.application_id,
                   CONCAT(ad.first_name, ' ', ad.last_name) AS adopter_name,
                   an.name   AS animal_name,
                   an.species,
                   app.status,
                   app.submission_date,
                   app.decision_date,
                   app.notes
            FROM   application app
            JOIN   adopter ad ON app.adopter_id = ad.adopter_id
            JOIN   animal  an ON app.animal_id  = an.animal_id
            WHERE  1 = 1
        """
        params = []

        if adopter_id:
            query += " AND app.adopter_id = %s"
            params.append(int(adopter_id))
        if animal_id:
            query += " AND app.animal_id = %s"
            params.append(int(animal_id))
        if status:
            query += " AND app.status = %s"
            params.append(status)

        query += " ORDER BY app.submission_date DESC"

        cursor.execute(query, params)
        applications = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(applications)} applications")
        return jsonify(applications), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_applications: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /adopters/applications
# Submit a new adoption application.
# Required fields: adopter_id, animal_id
# User stories: [Lisa-2]
# ------------------------------------------------------------
@adopters.route("/applications", methods=["POST"])
def submit_application():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["adopter_id", "animal_id"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO application
                (adopter_id, animal_id, status, notes, submission_date)
            VALUES (%s, %s, 'Pending', %s, CURDATE())
            """,
            (
                data["adopter_id"],
                data["animal_id"],
                data.get("notes"),
            ),
        )
        get_db().commit()

        current_app.logger.info(f"submit_application(): created application_id={cursor.lastrowid}")
        return jsonify({"message": "Application submitted successfully", "application_id": cursor.lastrowid}), 201
    except Error as e:
        current_app.logger.error(f"Database error in submit_application: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# PUT /adopters/applications/<application_id>
# Update application status (Pending → Approved/Denied/etc).
# Example: PUT /adopters/applications/1
# User stories: [Ayla-3]
# ------------------------------------------------------------
@adopters.route("/applications/<int:application_id>", methods=["PUT"])
def update_application(application_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        cursor.execute(
            "SELECT application_id FROM application WHERE application_id = %s",
            (application_id,),
        )
        if not cursor.fetchone():
            return jsonify({"error": "Application not found"}), 404

        allowed_fields = ["status", "notes", "decision_date"]
        update_fields = [f"{f} = %s" for f in allowed_fields if f in data]
        params = [data[f] for f in allowed_fields if f in data]

        if not update_fields:
            return jsonify({"error": "No valid fields to update"}), 400

        params.append(application_id)
        cursor.execute(
            f"UPDATE application SET {', '.join(update_fields)} WHERE application_id = %s",
            params,
        )
        get_db().commit()

        current_app.logger.info(f"update_application(): updated application_id={application_id}")
        return jsonify({"message": "Application updated successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in update_application: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# DELETE /adopters/applications/<application_id>
# Withdraw a pending application.
# Example: DELETE /adopters/applications/1
# User stories: [Lisa-2]
# ------------------------------------------------------------
@adopters.route("/applications/<int:application_id>", methods=["DELETE"])
def withdraw_application(application_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT application_id FROM application WHERE application_id = %s AND status = 'Pending'",
            (application_id,),
        )
        if not cursor.fetchone():
            return jsonify({"error": "Application not found or already processed"}), 404

        cursor.execute(
            "DELETE FROM application WHERE application_id = %s",
            (application_id,),
        )
        get_db().commit()

        current_app.logger.info(f"withdraw_application(): withdrew application_id={application_id}")
        return jsonify({"message": "Application withdrawn successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in withdraw_application: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /adopters/quiz
# Submit compatibility quiz preferences.
# Required fields: adopter_id, activity_level
# User stories: [Lisa-3]
# ------------------------------------------------------------
@adopters.route("/quiz", methods=["POST"])
def submit_quiz():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["adopter_id", "activity_level"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO compatibility_quiz
                (adopter_id, activity_level, energy_pref, size_pref, living_situation, date_taken)
            VALUES (%s, %s, %s, %s, %s, CURDATE())
            """,
            (
                data["adopter_id"],
                data["activity_level"],
                data.get("energy_pref"),
                data.get("size_pref"),
                data.get("living_situation"),
            ),
        )
        get_db().commit()
        quiz_id = cursor.lastrowid

        # Auto-generate compatibility scores for available animals
        cursor.execute(
            """
            SELECT animal_id,
                   (CASE WHEN species = %s THEN 40 ELSE 10 END +
                    CASE WHEN status = 'Available' THEN 30 ELSE 0 END) AS score
            FROM   animal
            WHERE  status = 'Available'
            ORDER  BY score DESC
            LIMIT  10
            """,
            (data.get("species_pref", "Dog"),),
        )
        matches = cursor.fetchall()

        for match in matches:
            cursor.execute(
                "INSERT INTO quiz_rec (quiz_id, animal_id, compatibility_score) VALUES (%s, %s, %s)",
                (quiz_id, match["animal_id"], max(match["score"], 1)),
            )
        get_db().commit()

        current_app.logger.info(f"submit_quiz(): created quiz_id={quiz_id} with {len(matches)} matches")
        return jsonify({"message": "Quiz submitted successfully", "quiz_id": quiz_id}), 201
    except Error as e:
        current_app.logger.error(f"Database error in submit_quiz: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /adopters/quiz/<quiz_id>/recommendations
# Return animals ranked by compatibility score for a quiz.
# Example: /adopters/quiz/1/recommendations
# User stories: [Lisa-3]
# ------------------------------------------------------------
@adopters.route("/quiz/<int:quiz_id>/recommendations", methods=["GET"])
def get_recommendations(quiz_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info(f"GET /adopters/quiz/{quiz_id}/recommendations")

        cursor.execute("SELECT quiz_id FROM compatibility_quiz WHERE quiz_id = %s", (quiz_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Quiz not found"}), 404

        cursor.execute(
            """
            SELECT qr.compatibility_score,
                   a.animal_id,
                   a.name,
                   a.species,
                   a.breed,
                   a.age_months,
                   a.status
            FROM   quiz_rec qr
            JOIN   animal   a ON qr.animal_id = a.animal_id
            WHERE  qr.quiz_id = %s
            ORDER  BY qr.compatibility_score DESC
            """,
            (quiz_id,),
        )
        recommendations = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(recommendations)} recommendations for quiz_id={quiz_id}")
        return jsonify(recommendations), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_recommendations: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /adopters/appointments
# List all meet & greet appointments.
# Example: /adopters/appointments?adopter_id=1
# User stories: [Lisa-4]
# ------------------------------------------------------------
@adopters.route("/appointments", methods=["GET"])
def get_appointments():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /adopters/appointments")

        adopter_id = request.args.get("adopter_id")

        query = """
            SELECT ma.appointment_id,
                   CONCAT(ad.first_name, ' ', ad.last_name) AS adopter_name,
                   an.name AS animal_name,
                   ma.status,
                   ma.scheduled_for,
                   ma.notes
            FROM   meet_appointment ma
            JOIN   adopter ad ON ma.adopter_id = ad.adopter_id
            JOIN   animal  an ON ma.animal_id  = an.animal_id
            WHERE  1 = 1
        """
        params = []

        if adopter_id:
            query += " AND ma.adopter_id = %s"
            params.append(int(adopter_id))

        query += " ORDER BY ma.scheduled_for ASC"

        cursor.execute(query, params)
        appointments = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(appointments)} appointments")
        return jsonify(appointments), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_appointments: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /adopters/appointments
# Schedule a new meet & greet.
# Required fields: adopter_id, animal_id, scheduled_for
# User stories: [Lisa-4]
# ------------------------------------------------------------
@adopters.route("/appointments", methods=["POST"])
def schedule_appointment():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["adopter_id", "animal_id", "scheduled_for"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO meet_appointment
                (adopter_id, animal_id, status, scheduled_for, notes)
            VALUES (%s, %s, 'Scheduled', %s, %s)
            """,
            (
                data["adopter_id"],
                data["animal_id"],
                data["scheduled_for"],
                data.get("notes"),
            ),
        )
        get_db().commit()

        current_app.logger.info(f"schedule_appointment(): created appointment_id={cursor.lastrowid}")
        return jsonify({"message": "Appointment scheduled successfully", "appointment_id": cursor.lastrowid}), 201
    except Error as e:
        current_app.logger.error(f"Database error in schedule_appointment: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /adopters/success-stories
# Return all reviewed adoption success stories.
# Example: /adopters/success-stories
# User stories: [Lisa-6]
# ------------------------------------------------------------
@adopters.route("/success-stories", methods=["GET"])
def get_success_stories():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /adopters/success-stories")

        cursor.execute(
            """
            SELECT ss.story_id,
                   ss.content,
                   ss.rating,
                   ss.posted_at,
                   a.name    AS pet_name,
                   a.species,
                   CONCAT(ad.first_name, ' ', ad.last_name) AS adopter_name
            FROM   success_story ss
            JOIN   adopter ad ON ss.adopter_id = ad.adopter_id
            LEFT JOIN animal a ON ss.animal_id = a.animal_id
            WHERE  ss.is_reviewed = TRUE
            ORDER  BY ss.posted_at DESC
            """
        )
        stories = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(stories)} success stories")
        return jsonify(stories), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_success_stories: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /adopters/success-stories
# Post a new success story (pending review).
# Required fields: adopter_id, rating, content
# User stories: [Lisa-6]
# ------------------------------------------------------------
@adopters.route("/success-stories", methods=["POST"])
def post_success_story():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["adopter_id", "rating", "content"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO success_story
                (adopter_id, animal_id, rating, content, is_reviewed)
            VALUES (%s, %s, %s, %s, FALSE)
            """,
            (
                data["adopter_id"],
                data.get("animal_id"),
                data["rating"],
                data["content"],
            ),
        )
        get_db().commit()

        current_app.logger.info(f"post_success_story(): created story_id={cursor.lastrowid}")
        return jsonify({"message": "Success story submitted for review", "story_id": cursor.lastrowid}), 201
    except Error as e:
        current_app.logger.error(f"Database error in post_success_story: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()