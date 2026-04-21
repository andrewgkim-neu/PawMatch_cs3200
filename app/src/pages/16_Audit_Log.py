import streamlit as st
import requests
import pandas as pd
from modules.nav import SideBarLinks

st.set_page_config(
    page_title="Audit Log | PawMatch",
    page_icon="📋",
    layout="wide"
)

SideBarLinks(show_home=True)

API = "http://web-api:4000"

st.title("📋 Audit Log")
st.markdown("Review all changes made to animal records — who made them and when.")
st.divider()

# Fetch logs
try:
    response = requests.get(f"{API}/admin/audit-logs")
    logs = response.json()
except:
    st.error("Could not connect to the API. Please check that the server is running.")
    st.stop()

if not logs:
    st.info("No audit log entries found.")
    st.stop()

df = pd.DataFrame(logs)

# Filters
col1, col2, col3 = st.columns(3)

with col1:
    action_options = ["All"] + sorted(df["action"].dropna().unique().tolist())
    selected_action = st.selectbox("Filter by Action", action_options)

with col2:
    employee_options = ["All"] + sorted(df["changed_by"].dropna().unique().tolist())
    selected_employee = st.selectbox("Filter by Employee", employee_options)

with col3:
    field_options = ["All"] + sorted(df["field_changed"].dropna().unique().tolist())
    selected_field = st.selectbox("Filter by Field Changed", field_options)

# Apply filters
filtered = df.copy()
if selected_action != "All":
    filtered = filtered[filtered["action"] == selected_action]
if selected_employee != "All":
    filtered = filtered[filtered["changed_by"] == selected_employee]
if selected_field != "All":
    filtered = filtered[filtered["field_changed"] == selected_field]

st.markdown(f"**{len(filtered)} entries found**")
st.divider()

# Display table
display_cols = [c for c in
    ["log_id", "changed_at", "animal_name", "changed_by", "action",
     "field_changed", "old_value", "new_value"]
    if c in filtered.columns]

st.dataframe(
    filtered[display_cols].sort_values("changed_at", ascending=False),
    use_container_width=True,
    hide_index=True
)

st.divider()

# Delete a log entry
st.subheader("🗑️ Delete Log Entry")
st.warning("Only delete entries that are confirmed as erroneous. This action cannot be undone.")

with st.form("delete_log_form"):
    log_id = st.number_input("Log ID to Delete", min_value=1, step=1)
    submitted = st.form_submit_button("Delete Entry", type="primary")

    if submitted:
        try:
            res = requests.delete(f"{API}/admin/audit-logs/{int(log_id)}")
            if res.status_code == 200:
                st.success(f"Log entry {int(log_id)} deleted successfully.")
                st.rerun()
            else:
                st.error(f"Error: {res.json().get('error', 'Unknown error')}")
        except Exception as e:
            st.error(f"Request failed: {e}")