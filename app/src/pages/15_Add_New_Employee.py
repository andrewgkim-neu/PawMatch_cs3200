import streamlit as st
import requests
import pandas as pd
from modules.nav import SideBarLinks

st.set_page_config(
    page_title="Manage Employees | PawMatch",
    page_icon="➕",
    layout="wide"
)

SideBarLinks(show_home=True)

API = "http://web-api:4000"
st.title("➕ Manage Employees")
st.markdown("Add new staff members, update roles and permissions, or remove former employees.")
st.divider()

# Current employees table
st.subheader("Current Employees")

try:
    employees = requests.get(f"{API}/admin/employees").json()
    if employees:
        df = pd.DataFrame(employees)
        display_cols = [c for c in
            ["employee_id", "first_name", "last_name", "email", "role", "permissions", "created_at"]
            if c in df.columns]
        st.dataframe(df[display_cols], use_container_width=True, hide_index=True)
    else:
        st.info("No employees found.")
except Exception as e:
    st.error(f"Could not load employee list: {e}")  # ← show the actual error

st.divider()

# Tabs for different actions
tab1, tab2, tab3 = st.tabs(["➕ Add New Employee", "🔑 Update Role & Permissions", "🗑️ Remove Employee"])

# --- Tab 1: Add new employee ---
with tab1:
    st.subheader("Add New Employee")

    with st.form("add_employee_form", clear_on_submit=True):
        col1, col2 = st.columns(2)

        with col1:
            first_name = st.text_input("First Name *")
            last_name  = st.text_input("Last Name *")
            email      = st.text_input("Email *")

        with col2:
            address  = st.text_input("Address")
            role     = st.selectbox("Role *", ["Volunteer", "Staff", "Analyst", "Admin", "Other"])
            password = st.text_input("Temporary Password *", type="password")

        permissions_options = [
            "view_animals", "edit_animals",
            "manage_adoptions", "view_reports", "manage_employees"
        ]
        permissions = st.multiselect("Permissions *", permissions_options, default=["view_animals"])

        submitted = st.form_submit_button("Add Employee", type="primary", use_container_width=True)

        if submitted:
            if not first_name or not last_name or not email or not permissions:
                st.error("First name, last name, email, and at least one permission are required.")
            else:
                payload = {
                    "first_name":  first_name,
                    "last_name":   last_name,
                    "email":       email,
                    "password":    password,
                    "address":     address if address else None,
                    "role":        role,
                    "permissions": ",".join(permissions)
                }
                try:
                    res = requests.post(f"{API}/admin/employees", json=payload)
                    if res.status_code == 201:
                        data = res.json()
                        st.success(f"✅ Employee added! Employee ID: {data['employee_id']}")
                        st.rerun()
                    else:
                        st.error(f"Error: {res.json().get('error', 'Unknown error')}")
                except Exception as e:
                    st.error(f"Request failed: {e}")

# --- Tab 2: Update role ---
with tab2:
    st.subheader("Update Role & Permissions")
    st.caption("Assign or modify a staff member's role and permission set. [John-5]")

    with st.form("update_role_form"):
        employee_id = st.number_input("Employee ID", min_value=1, step=1)

        col1, col2 = st.columns(2)
        with col1:
            new_role = st.selectbox("New Role", ["Volunteer", "Staff", "Analyst", "Admin", "Other"])
        with col2:
            perms_options = [
                "view_animals", "edit_animals",
                "manage_adoptions", "view_reports", "manage_employees"
            ]
            new_permissions = st.multiselect("New Permissions", perms_options, default=["view_animals"])

        update_submitted = st.form_submit_button("Update Role", type="primary")

        if update_submitted:
            if not new_permissions:
                st.error("Select at least one permission.")
            else:
                payload = {
                    "role":        new_role,
                    "permissions": ",".join(new_permissions)
                }
                try:
                    res = requests.put(f"{API}/admin/employees/{int(employee_id)}/role", json=payload)
                    if res.status_code == 200:
                        st.success(f"✅ Role updated for employee {int(employee_id)}.")
                        st.rerun()
                    else:
                        st.error(f"Error: {res.json().get('error', 'Unknown error')}")
                except Exception as e:
                    st.error(f"Request failed: {e}")

# --- Tab 3: Remove employee ---
with tab3:
    st.subheader("Remove Employee")
    st.error("⚠️ This permanently removes the employee's account. This action cannot be undone.")
    st.caption("Use this to deactivate former staff members so they can no longer access the system. [John-6]")

    with st.form("delete_employee_form"):
        del_employee_id = st.number_input("Employee ID to Remove", min_value=1, step=1)
        confirm = st.checkbox("I confirm I want to permanently remove this employee.")
        delete_submitted = st.form_submit_button("Remove Employee", type="primary")

        if delete_submitted:
            if not confirm:
                st.warning("Please confirm the deletion by checking the box.")
            else:
                try:
                    res = requests.delete(f"{API}/admin/employees/{int(del_employee_id)}")
                    if res.status_code == 200:
                        st.success(f"✅ Employee {int(del_employee_id)} removed successfully.")
                        st.rerun()
                    else:
                        st.error(f"Error: {res.json().get('error', 'Unknown error')}")
                except Exception as e:
                    st.error(f"Request failed: {e}")