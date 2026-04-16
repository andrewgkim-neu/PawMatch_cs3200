from flask import Blueprint, request, jsonify, current_app
from backend.db_connection import get_db
from mysql.connector import Error

analytics = Blueprint("analytics", __name__)


# ------------------------------------------------------------
# GET /analytics/dashboard
# Return live shelter summary statistics.
# Example: /analytics/dashboard
# User stories: [Lucy-1]
# ------------------------------------------------------------
@analytics.route("/dashboard", methods=["GET"])
def get_dashboard():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /analytics/dashboard")

        cursor.execute("SELECT COUNT(*) AS total_animals FROM animal")
        total_animals = cursor.fetchone()["total_animals"]

        cursor.execute(
            """
            SELECT COUNT(*) AS adopted_this_month
            FROM   adoption
            WHERE  MONTH(adoption_date) = MONTH(CURDATE())
              AND  YEAR(adoption_date)  = YEAR(CURDATE())
              AND  outcome = 'Adopted'
            """
        )
        adopted_this_month = cursor.fetchone()["adopted_this_month"]

        cursor.execute(
            "SELECT COUNT(*) AS open_applications FROM application WHERE status IN ('Pending', 'Under Review')"
        )
        open_applications = cursor.fetchone()["open_applications"]

        cursor.execute("SELECT status, COUNT(*) AS count FROM animal GROUP BY status")
        status_breakdown = cursor.fetchall()

        cursor.execute(
            """
            SELECT animal_id, name, species,
                   DATEDIFF(CURDATE(), intake_date) AS days_in_shelter,
                   status
            FROM   animal
            ORDER  BY days_in_shelter DESC
            LIMIT  10
            """
        )
        longest_stays = cursor.fetchall()

        return jsonify({
            "total_animals":      total_animals,
            "adopted_this_month": adopted_this_month,
            "open_applications":  open_applications,
            "status_breakdown":   status_breakdown,
            "longest_stays":      longest_stays,
        }), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_dashboard: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /analytics/adoption-trends
# Return time-to-adoption averages; filter by species/breed.
# Example: /analytics/adoption-trends?species=Dog
# User stories: [Lucy-2]
# ------------------------------------------------------------
@analytics.route("/adoption-trends", methods=["GET"])
def get_adoption_trends():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /analytics/adoption-trends")

        species = request.args.get("species")
        breed   = request.args.get("breed")

        query = """
            SELECT a.species,
                   a.breed,
                   YEAR(ad.adoption_date)  AS year,
                   MONTH(ad.adoption_date) AS month,
                   COUNT(ad.adoption_id)   AS total_adoptions,
                   AVG(ad.days_to_adopt)   AS avg_days_to_adopt
            FROM   adoption ad
            JOIN   application app ON ad.application_id = app.application_id
            JOIN   animal      a   ON app.animal_id      = a.animal_id
            WHERE  ad.outcome = 'Adopted'
        """
        params = []

        if species:
            query += " AND a.species = %s"
            params.append(species)
        if breed:
            query += " AND a.breed LIKE %s"
            params.append(f"%{breed}%")

        query += " GROUP BY a.species, a.breed, year, month ORDER BY year, month"

        cursor.execute(query, params)
        trends = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(trends)} adoption trend rows")
        return jsonify(trends), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_adoption_trends: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /analytics/application-funnel
# Return application counts at each status stage.
# Example: /analytics/application-funnel
# User stories: [Lucy-5]
# ------------------------------------------------------------
@analytics.route("/application-funnel", methods=["GET"])
def get_application_funnel():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /analytics/application-funnel")

        cursor.execute(
            """
            SELECT status, COUNT(*) AS total
            FROM   application
            GROUP  BY status
            ORDER  BY FIELD(status,
                'Pending', 'Under Review', 'Approved',
                'Denied',  'Withdrawn',    'Completed')
            """
        )
        funnel = cursor.fetchall()

        return jsonify(funnel), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_application_funnel: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /analytics/reports/templates
# List all non-archived report templates.
# Example: /analytics/reports/templates
# User stories: [Lucy-3]
# ------------------------------------------------------------
@analytics.route("/reports/templates", methods=["GET"])
def get_report_templates():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /analytics/reports/templates")

        show_archived = request.args.get("archived", "false").lower() == "true"

        cursor.execute(
    """
    SELECT template_id, template_name, export_format,
           CAST(metric_included AS CHAR) AS metric_included,
           date_range_start, date_range_end,
           is_archived
    FROM   report_template
    WHERE  is_archived = %s
    ORDER  BY template_name ASC
    """,
    (show_archived,),
)
        templates = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(templates)} report templates")
        return jsonify(templates), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_report_templates: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /analytics/reports/templates
# Save a new custom report template.
# Required fields: template_name, date_range_start, date_range_end
# User stories: [Lucy-3]
# ------------------------------------------------------------
@analytics.route("/reports/templates", methods=["POST"])
def create_report_template():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["template_name", "date_range_start", "date_range_end"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO report_template
                (template_name, export_format, metric_included,
                 date_range_start, date_range_end, is_archived)
            VALUES (%s, %s, %s, %s, %s, FALSE)
            """,
            (
                data["template_name"],
                data.get("export_format", "PDF"),
                data.get("metric_included", "Total Adopted"),
                data["date_range_start"],
                data["date_range_end"],
            ),
        )
        get_db().commit()

        current_app.logger.info(f"create_report_template(): created template_id={cursor.lastrowid}")
        return jsonify({"message": "Template saved successfully", "template_id": cursor.lastrowid}), 201
    except Error as e:
        current_app.logger.error(f"Database error in create_report_template: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# PUT /analytics/reports/templates/<template_id>
# Update an existing template's parameters or name.
# Example: PUT /analytics/reports/templates/1
# User stories: [Lucy-3]
# ------------------------------------------------------------
@analytics.route("/reports/templates/<int:template_id>", methods=["PUT"])
def update_report_template(template_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        cursor.execute(
            "SELECT template_id FROM report_template WHERE template_id = %s",
            (template_id,),
        )
        if not cursor.fetchone():
            return jsonify({"error": "Template not found"}), 404

        allowed_fields = ["template_name", "export_format", "metric_included",
                          "date_range_start", "date_range_end"]
        update_fields = [f"{f} = %s" for f in allowed_fields if f in data]
        params = [data[f] for f in allowed_fields if f in data]

        if not update_fields:
            return jsonify({"error": "No valid fields to update"}), 400

        params.append(template_id)
        cursor.execute(
            f"UPDATE report_template SET {', '.join(update_fields)} WHERE template_id = %s",
            params,
        )
        get_db().commit()

        current_app.logger.info(f"update_report_template(): updated template_id={template_id}")
        return jsonify({"message": "Template updated successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in update_report_template: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# DELETE /analytics/reports/templates/<template_id>
# Archive (default) or permanently delete a saved template.
# Pass ?permanent=true to hard-delete.
# Example: DELETE /analytics/reports/templates/1
# User stories: [Lucy-6]
# ------------------------------------------------------------
@analytics.route("/reports/templates/<int:template_id>", methods=["DELETE"])
def delete_report_template(template_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT template_id FROM report_template WHERE template_id = %s",
            (template_id,),
        )
        if not cursor.fetchone():
            return jsonify({"error": "Template not found"}), 404

        permanent = request.args.get("permanent", "false").lower() == "true"

        if permanent:
            cursor.execute(
                "DELETE FROM report_template WHERE template_id = %s", (template_id,)
            )
            action = "deleted"
        else:
            cursor.execute(
                "UPDATE report_template SET is_archived = TRUE WHERE template_id = %s",
                (template_id,),
            )
            action = "archived"

        get_db().commit()

        current_app.logger.info(f"delete_report_template(): {action} template_id={template_id}")
        return jsonify({"message": f"Template {action} successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in delete_report_template: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /analytics/reports/monthly
# List all generated monthly reports.
# Example: /analytics/reports/monthly
# User stories: [Lucy-4]
# ------------------------------------------------------------
@analytics.route("/reports/monthly", methods=["GET"])
def get_monthly_reports():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /analytics/reports/monthly")

        cursor.execute(
            """
            SELECT mr.report_id,
                   mr.report_month,
                   mr.generated_date,
                   mr.total_adopted,
                   mr.avg_days_to_adopt,
                   mr.avg_length_of_stay,
                   rt.template_name
            FROM   monthly_report mr
            LEFT JOIN report_template rt ON mr.template_id = rt.template_id
            ORDER  BY mr.report_month DESC
            """
        )
        reports = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(reports)} monthly reports")
        return jsonify(reports), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_monthly_reports: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /analytics/reports/monthly
# Generate and store a new monthly outcome report.
# Required fields: report_month (YYYY-MM-DD)
# User stories: [Lucy-4]
# ------------------------------------------------------------
@analytics.route("/reports/monthly", methods=["POST"])
def generate_monthly_report():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        if "report_month" not in data:
            return jsonify({"error": "Missing required field: report_month"}), 400

        report_month = data["report_month"]
        template_id  = data.get("template_id")

        cursor.execute(
            """
            SELECT COUNT(CASE WHEN ad.outcome = 'Adopted' THEN 1 END) AS total_adopted,
                   AVG(ad.days_to_adopt)                               AS avg_days_to_adopt,
                   AVG(DATEDIFF(CURDATE(), a.intake_date))             AS avg_length_of_stay
            FROM   adoption ad
            JOIN   application app ON ad.application_id = app.application_id
            JOIN   animal      a   ON app.animal_id      = a.animal_id
            WHERE  DATE_FORMAT(ad.adoption_date, '%%Y-%%m') = DATE_FORMAT(%s, '%%Y-%%m')
            """,
            (report_month,),
        )
        stats = cursor.fetchone()

        cursor.execute(
            """
            INSERT INTO monthly_report
                (template_id, report_month, generated_date,
                 total_adopted, avg_days_to_adopt, avg_length_of_stay)
            VALUES (%s, %s, NOW(), %s, %s, %s)
            """,
            (
                template_id,
                report_month,
                stats["total_adopted"] or 0,
                stats["avg_days_to_adopt"],
                stats["avg_length_of_stay"],
            ),
        )
        get_db().commit()

        current_app.logger.info(f"generate_monthly_report(): created report_id={cursor.lastrowid}")
        return jsonify({
            "message":   "Monthly report generated successfully",
            "report_id": cursor.lastrowid,
            "stats":     stats,
        }), 201
    except Error as e:
        current_app.logger.error(f"Database error in generate_monthly_report: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()