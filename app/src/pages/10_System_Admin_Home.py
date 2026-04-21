import streamlit as st
from modules.nav import SideBarLinks

st.set_page_config(
    page_title="System Admin Home | PawMatch",
    page_icon="🔧",
    layout="wide"
)

SideBarLinks(show_home=True)

# Header
st.title(f"Welcome, {st.session_state.get('first_name', 'Admin')} 👋")
st.markdown("##### System Administration Dashboard — PawMatch")
st.divider()

# Quick stat cards using the API
import requests

API = "http://web-api:4000"

col1, col2, col3, col4 = st.columns(4)

try:
    resp = requests.get(f"{API}/animals/")
    resp.raise_for_status()
    animals = resp.json()
    total_animals = len(animals)
    flagged = len([a for a in animals if a.get("flagged")])
except Exception as e:
    st.error(f"Animals API error: {e}")  # This will now show you the real problem
    total_animals = "—"
    flagged = "—"

try:
    employees = requests.get(f"{API}/admin/employees").json()
    total_employees = len(employees)
except:
    total_employees = "—"

try:
    logs = requests.get(f"{API}/admin/audit-logs").json()
    total_logs = len(logs)
except:
    total_logs = "—"

with col1:
    st.metric("Total Animals", total_animals)
with col2:
    st.metric("Flagged Animals", flagged)
with col3:
    st.metric("Total Employees", total_employees)
with col4:
    st.metric("Audit Log Entries", total_logs)

st.divider()

# Quick action links
st.subheader("Quick Actions")

c1, c2, c3 = st.columns(3)

with c1:
    st.markdown("#### 📁 Add New Animal")
    st.write("Register a new animal entering the shelter with full profile information.")
    if st.button("Go to Add Animal", use_container_width=True):
        st.switch_page("pages/14_Add_New_Animal.py")

with c2:
    st.markdown("#### ➕ Add New Employee")
    st.write("Create a new staff member account and assign their role and permissions.")
    if st.button("Go to Add Employee", use_container_width=True):
        st.switch_page("pages/15_Add_New_Employee.py")

with c3:
    st.markdown("#### 📋 Audit Log")
    st.write("Review all changes made to animal records — who changed what and when.")
    if st.button("Go to Audit Log", use_container_width=True):
        st.switch_page("pages/16_Audit_Log.py")

st.divider()

# Recent audit log preview
st.subheader("Recent Activity")
try:
    logs = requests.get(f"{API}/admin/audit-logs").json()
    if logs:
        import pandas as pd
        df = pd.DataFrame(logs[:5])
        display_cols = [c for c in ["changed_at", "animal_name", "changed_by", "action", "field_changed"] if c in df.columns]
        st.dataframe(df[display_cols], use_container_width=True, hide_index=True)
    else:
        st.info("No audit log entries yet.")
except:
    st.warning("Could not load recent activity.")