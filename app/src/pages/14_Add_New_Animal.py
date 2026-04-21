import streamlit as st
import requests
from datetime import date
from modules.nav import SideBarLinks

st.set_page_config(
    page_title="Add New Animal | PawMatch",
    page_icon="📁",
    layout="wide"
)

SideBarLinks(show_home=True)

API = "http://web-api:4000"
st.title("📁 Add New Animal")
st.markdown("Register a new animal entering the shelter. All fields marked * are required.")
st.divider()

# Check for duplicates section
st.subheader("🔍 Check for Duplicates First")
st.caption("Search for potential duplicate records before adding a new animal.")

with st.expander("View Potential Duplicate Records"):
    try:
        dupes = requests.get(f"{API}/animals/duplicates").json()
        if dupes:
            import pandas as pd
            st.warning(f"{len(dupes)} potential duplicate pair(s) found.")
            st.dataframe(pd.DataFrame(dupes), use_container_width=True, hide_index=True)
        else:
            st.success("No duplicate records found.")
    except:
        st.error("Could not load duplicate check.")

st.divider()

# Add animal form
st.subheader("Animal Profile")

with st.form("add_animal_form", clear_on_submit=True):
    col1, col2 = st.columns(2)

    with col1:
        name = st.text_input("Animal Name *")
        species = st.selectbox("Species *", ["Dog", "Cat", "Rabbit", "Other"])
        breed = st.text_input("Breed")
        age_months = st.number_input("Age (months)", min_value=0, step=1)

    with col2:
        intake_date = st.date_input("Intake Date *", value=date.today())
        status = st.selectbox(
            "Status *",
            ["Available", "Fostered", "Pending Adoption", "Medical Hold"]
        )
        flagged = st.checkbox("Flag for extra promotion / foster placement")

    st.divider()
    submitted = st.form_submit_button("➕ Add Animal", type="primary", use_container_width=True)

    if submitted:
        if not name:
            st.error("Animal name is required.")
        else:
            payload = {
                "name": name,
                "species": species,
                "breed": breed if breed else None,
                "age_months": int(age_months),
                "intake_date": str(intake_date),
                "status": status,
                "flagged": flagged
            }
            try:
                res = requests.post(f"{API}/animals/", json=payload)
                if res.status_code == 201:
                    data = res.json()
                    st.success(f"✅ Animal added successfully! Animal ID: {data['animal_id']}")
                else:
                    st.error(f"Error: {res.json().get('error', 'Unknown error')}")
            except Exception as e:
                st.error(f"Request failed: {e}")

st.divider()

# Update existing animal status
st.subheader("✏️ Update Existing Animal")
st.caption("Update status, flag, or other details for an existing animal. [John-3]")

with st.form("update_animal_form"):
    animal_id = st.number_input("Animal ID to Update", min_value=1, step=1)

    col1, col2 = st.columns(2)
    with col1:
        new_status = st.selectbox(
            "New Status (leave unchanged if not updating)",
            ["", "Available", "Adopted", "Pending Adoption", "Fostered", "Medical Hold"]
        )
    with col2:
        new_flagged = st.selectbox("Flagged", ["No change", "True", "False"])

    update_submitted = st.form_submit_button("Update Animal", type="primary")

    if update_submitted:
        payload = {}
        if new_status:
            payload["status"] = new_status
        if new_flagged != "No change":
            payload["flagged"] = new_flagged == "True"

        if not payload:
            st.warning("No changes specified.")
        else:
            try:
                res = requests.put(f"{API}/animals/{int(animal_id)}", json=payload)
                if res.status_code == 200:
                    st.success(f"Animal {int(animal_id)} updated successfully.")
                else:
                    st.error(f"Error: {res.json().get('error', 'Unknown error')}")
            except Exception as e:
                st.error(f"Request failed: {e}")