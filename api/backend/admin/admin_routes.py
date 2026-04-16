from flask import Blueprint, request, jsonify, current_app
from backend.db_connection import get_db
from mysql.connector import Error

admin = Blueprint("admin", __name__)


# ------------------------------------------------------------
# GET /admin/audit-logs
# Return full timestamped audit log of animal record changes.
# Example: /admin/audit-logs
# User stories: [John-1]
# ------------------------------------------------------------
@admin.route("/audit-logs", methods=["GET"])
def get_audit_logs():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /admin/audit-logs")

        cursor.execute(
            """
            SELECT al.log_id,
                   a.name        AS animal_name,
                   CONCAT(e.first_name, ' ', e.last_name) AS changed_by,
                   al.action,
                   al.field_changed,
                   al.old_value,
                   al.new_value,
                   al.changed_at
            FROM   audit_log al
            LEFT JOIN animal   a ON al.animal_id   = a.animal_id
            LEFT JOIN employee e ON al.employee_id = e.employee_id
            ORDER  BY al.changed_at DESC
            """
        )
        logs = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(logs)} audit log entries")
        return jsonify(logs), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_audit_logs: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# DELETE /admin/audit-logs/<log_id>
# Remove a specific audit log entry.
# Example: DELETE /admin/audit-logs/1
# User stories: [John-1]
# ------------------------------------------------------------
@admin.route("/audit-logs/<int:log_id>", methods=["DELETE"])
def delete_audit_log(log_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        cursor.execute("SELECT log_id FROM audit_log WHERE log_id = %s", (log_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Log entry not found"}), 404

        cursor.execute("DELETE FROM audit_log WHERE log_id = %s", (log_id,))
        get_db().commit()

        current_app.logger.info(f"delete_audit_log(): deleted log_id={log_id}")
        return jsonify({"message": "Audit log entry deleted successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in delete_audit_log: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# GET /admin/employees
# Return all employees with their role and permissions.
# Example: /admin/employees
# User stories: [John-2]
# ------------------------------------------------------------
@admin.route("/employees", methods=["GET"])
def get_employees():
    cursor = get_db().cursor(dictionary=True)
    try:
        current_app.logger.info("GET /admin/employees")

        cursor.execute(
    """
    SELECT e.employee_id,
           e.first_name,
           e.last_name,
           e.email,
           e.address,
           e.created_at,
           er.role,
           CAST(er.permissions AS CHAR) AS permissions
    FROM   employee e
    LEFT JOIN employee_role er ON e.employee_id = er.employee_id
    ORDER  BY e.last_name ASC
    """
)  
        employees = cursor.fetchall()

        current_app.logger.info(f"Retrieved {len(employees)} employees")
        return jsonify(employees), 200
    except Error as e:
        current_app.logger.error(f"Database error in get_employees: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# POST /admin/employees
# Create a new employee account with role.
# Required fields: first_name, last_name, email
# User stories: [John-2]
# ------------------------------------------------------------
@admin.route("/employees", methods=["POST"])
def add_employee():
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        required_fields = ["first_name", "last_name", "email"]
        for field in required_fields:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        cursor.execute(
            """
            INSERT INTO employee (first_name, last_name, email, password, address)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                data["first_name"],
                data["last_name"],
                data["email"],
                data.get("password", "temp_password"),
                data.get("address"),
            ),
        )
        get_db().commit()
        new_id = cursor.lastrowid

        role        = data.get("role", "Volunteer")
        permissions = data.get("permissions", "view_animals")
        cursor.execute(
            "INSERT INTO employee_role (employee_id, role, permissions) VALUES (%s, %s, %s)",
            (new_id, role, permissions),
        )
        get_db().commit()

        current_app.logger.info(f"add_employee(): created employee_id={new_id}")
        return jsonify({"message": "Employee created successfully", "employee_id": new_id}), 201
    except Error as e:
        current_app.logger.error(f"Database error in add_employee: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# PUT /admin/employees/<employee_id>/role
# Update an employee's role and permission set.
# Example: PUT /admin/employees/1/role
# User stories: [John-5]
# ------------------------------------------------------------
@admin.route("/employees/<int:employee_id>/role", methods=["PUT"])
def update_employee_role(employee_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        data = request.get_json()

        cursor.execute("SELECT employee_id FROM employee WHERE employee_id = %s", (employee_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Employee not found"}), 404

        allowed_fields = ["role", "permissions"]
        update_fields = [f"{f} = %s" for f in allowed_fields if f in data]
        params = [data[f] for f in allowed_fields if f in data]

        if not update_fields:
            return jsonify({"error": "Provide role and/or permissions to update"}), 400

        params.append(employee_id)
        cursor.execute(
            f"""
            INSERT INTO employee_role (employee_id, role, permissions)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE {', '.join(update_fields)}
            """,
            [employee_id,
             data.get("role", "Volunteer"),
             data.get("permissions", "view_animals")] + params[:-1],
        )
        get_db().commit()

        current_app.logger.info(f"update_employee_role(): updated employee_id={employee_id}")
        return jsonify({"message": "Role updated successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in update_employee_role: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()


# ------------------------------------------------------------
# DELETE /admin/employees/<employee_id>
# Deactivate and remove a former staff member.
# Example: DELETE /admin/employees/1
# User stories: [John-6]
# ------------------------------------------------------------
@admin.route("/employees/<int:employee_id>", methods=["DELETE"])
def delete_employee(employee_id):
    cursor = get_db().cursor(dictionary=True)
    try:
        cursor.execute("SELECT employee_id FROM employee WHERE employee_id = %s", (employee_id,))
        if not cursor.fetchone():
            return jsonify({"error": "Employee not found"}), 404

        cursor.execute("DELETE FROM employee_role WHERE employee_id = %s", (employee_id,))
        cursor.execute("DELETE FROM employee WHERE employee_id = %s", (employee_id,))
        get_db().commit()

        current_app.logger.info(f"delete_employee(): removed employee_id={employee_id}")
        return jsonify({"message": "Employee removed successfully"}), 200
    except Error as e:
        current_app.logger.error(f"Database error in delete_employee: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()